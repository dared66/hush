#import <Cocoa/Cocoa.h>
#import <CoreAudio/CoreAudio.h>
#import <CoreAudio/CATapDescription.h>
#import <CoreAudio/AudioHardwareTapping.h>
#import "AudioRender.h"

static AudioObjectPropertyAddress address(AudioObjectPropertySelector sel, AudioObjectPropertyScope scope) {
    return (AudioObjectPropertyAddress){sel, scope, kAudioObjectPropertyElementMain};
}
static OSStatus readProperty(AudioObjectID obj, AudioObjectPropertySelector sel, AudioObjectPropertyScope scope, UInt32 size, void *value) {
    AudioObjectPropertyAddress a = address(sel, scope);
    return AudioObjectGetPropertyData(obj, &a, 0, NULL, &size, value);
}
static NSString *stringProperty(AudioObjectID obj, AudioObjectPropertySelector sel) {
    CFStringRef value = NULL;
    if (readProperty(obj, sel, kAudioObjectPropertyScopeGlobal, sizeof(value), &value) != noErr) return @"";
    return CFBridgingRelease(value) ?: @"";
}
static AudioDeviceID defaultOutput(void) {
    AudioDeviceID device = 0;
    readProperty(kAudioObjectSystemObject, kAudioHardwarePropertyDefaultOutputDevice, kAudioObjectPropertyScopeGlobal, sizeof(device), &device);
    return device;
}
static NSArray<NSValue *> *formats(AudioDeviceID device, AudioObjectPropertyScope scope) {
    AudioObjectPropertyAddress a = address(kAudioDevicePropertyStreams, scope);
    UInt32 size = 0;
    if (AudioObjectGetPropertyDataSize(device, &a, 0, NULL, &size) != noErr) return @[];
    AudioStreamID *streams = calloc(1, MAX(size, 1));
    if (!streams) return @[];
    NSMutableArray *result = [NSMutableArray array];
    if (AudioObjectGetPropertyData(device, &a, 0, NULL, &size, streams) == noErr) {
        for (UInt32 i = 0; i < size / sizeof(AudioStreamID); i++) {
            AudioStreamBasicDescription f = {0};
            if (readProperty(streams[i], kAudioStreamPropertyVirtualFormat, kAudioObjectPropertyScopeGlobal, sizeof(f), &f) == noErr)
                [result addObject:[NSValue valueWithBytes:&f objCType:@encode(AudioStreamBasicDescription)]];
        }
    }
    free(streams);
    return result;
}
static BOOL validFormat(AudioStreamBasicDescription f) {
    UInt32 channelsPerBuffer = (f.mFormatFlags & kAudioFormatFlagIsNonInterleaved) ? 1 : 2;
    return isfinite(f.mSampleRate) && f.mSampleRate > 0 &&
        f.mBytesPerFrame == sizeof(float) * channelsPerBuffer && f.mFramesPerPacket == 1 &&
        f.mFormatID == kAudioFormatLinearPCM && (f.mFormatFlags & kAudioFormatFlagIsFloat) &&
        !(f.mFormatFlags & kAudioFormatFlagIsBigEndian) && f.mBitsPerChannel == 32 && f.mChannelsPerFrame == 2;
}

@interface AudioController : NSObject {
@public
    Gain gain;
    AudioObjectID tap;
    AudioDeviceID aggregate;
    AudioDeviceID output;
    AudioDeviceIOProcID proc;
    BOOL started;
}
@property(copy) NSString *deviceName;
@property(copy) NSString *problem;
- (BOOL)start;
- (void)stop;
@end

@implementation AudioController
- (instancetype)init {
    if ((self = [super init])) {
        atomic_init(&gain.target, 0.25f);
        atomic_init(&gain.callbacks, 0);
        atomic_init(&gain.inputPeak, 0);
        atomic_init(&gain.outputPeak, 0);
    }
    return self;
}
- (BOOL)fail:(NSString *)operation status:(OSStatus)status {
    self.problem = [NSString stringWithFormat:@"%@ (%d).", operation, (int)status];
    [self stop];
    return NO;
}
- (BOOL)start {
    [self stop];
    self.problem = nil;
    self.deviceName = nil;
    output = defaultOutput();
    if (!output) return [self fail:@"No audio output found" status:-1];
    self.deviceName = stringProperty(output, kAudioObjectPropertyName);
    NSString *uid = stringProperty(output, kAudioDevicePropertyDeviceUID);
    NSArray *outFormats = formats(output, kAudioDevicePropertyScopeOutput);
    // Deliberately reject devices with input streams: their aggregate buffer layout differs.
    if (formats(output, kAudioDevicePropertyScopeInput).count || outFormats.count != 1 || !uid.length)
        return [self fail:@"Choose a stereo monitor or built-in speakers in Sound settings" status:-1];
    AudioStreamBasicDescription physical = {0};
    [outFormats.firstObject getValue:&physical];
    if (!validFormat(physical)) return [self fail:@"This output's audio format is unsupported" status:-1];

    // Exclude our own output to prevent an audio feedback loop.
    pid_t pid = getpid();
    AudioObjectID process = 0;
    UInt32 size = sizeof(process);
    AudioObjectPropertyAddress a = address(kAudioHardwarePropertyTranslatePIDToProcessObject, kAudioObjectPropertyScopeGlobal);
    OSStatus status = AudioObjectGetPropertyData(kAudioObjectSystemObject, &a, sizeof(pid), &pid, &size, &process);
    if (status || !process) return [self fail:@"Could not isolate app playback" status:status];
    CATapDescription *description = [[CATapDescription alloc] initExcludingProcesses:@[@(process)] andDeviceUID:uid withStream:0];
    description.name = @"Hush";
    description.privateTap = YES;
    description.muteBehavior = CATapMutedWhenTapped;
    status = AudioHardwareCreateProcessTap(description, &tap);
    if (status) return [self fail:@"Audio access is required. Allow Hush in System Settings" status:status];
    AudioStreamBasicDescription tapFormat = {0};
    status = readProperty(tap, kAudioTapPropertyFormat, kAudioObjectPropertyScopeGlobal, sizeof(tapFormat), &tapFormat);
    if (status || !validFormat(tapFormat) || tapFormat.mSampleRate != physical.mSampleRate)
        return [self fail:@"The monitor and audio tap formats do not match" status:status ?: -1];
    NSDictionary *configuration = @{
        @kAudioAggregateDeviceNameKey: @"Hush Audio",
        @kAudioAggregateDeviceUIDKey: [@"local.hush.audio." stringByAppendingString:NSUUID.UUID.UUIDString],
        @kAudioAggregateDeviceIsPrivateKey: @YES,
        @kAudioAggregateDeviceMainSubDeviceKey: uid,
        @kAudioAggregateDeviceSubDeviceListKey: @[@{@kAudioSubDeviceUIDKey: uid}],
        @kAudioAggregateDeviceTapListKey: @[@{@kAudioSubTapUIDKey: description.UUID.UUIDString, @kAudioSubTapDriftCompensationKey: @YES}],
        @kAudioAggregateDeviceTapAutoStartKey: @YES
    };
    status = AudioHardwareCreateAggregateDevice((__bridge CFDictionaryRef)configuration, &aggregate);
    if (status) return [self fail:@"Could not connect audio processing" status:status];
    NSArray *aggregateInputs = formats(aggregate, kAudioDevicePropertyScopeInput);
    NSArray *aggregateOutputs = formats(aggregate, kAudioDevicePropertyScopeOutput);
    if (aggregateInputs.count != 1 || aggregateOutputs.count != 1)
        return [self fail:@"Unexpected audio channel layout" status:-1];
    for (NSValue *value in [aggregateInputs arrayByAddingObjectsFromArray:aggregateOutputs]) {
        AudioStreamBasicDescription f = {0}; [value getValue:&f];
        if (!validFormat(f) || f.mSampleRate != physical.mSampleRate)
            return [self fail:@"Unexpected audio processing format" status:-1];
    }
    gain.current = 0;
    gain.step = 1.0f / (physical.mSampleRate * 0.02f);
    atomic_store(&gain.callbacks, 0);
    status = AudioDeviceCreateIOProcID(aggregate, HushRender, &gain, &proc);
    if (status) return [self fail:@"Could not prepare audio playback" status:status];
    status = AudioDeviceStart(aggregate, proc);
    if (status) return [self fail:@"Could not start audio. Check audio capture permission" status:status];
    started = YES;
    return YES;
}
- (void)stop {
    if (aggregate && proc) {
        AudioDeviceStop(aggregate, proc);
        AudioDeviceDestroyIOProcID(aggregate, proc);
    }
    proc = NULL;
    if (aggregate) AudioHardwareDestroyAggregateDevice(aggregate);
    aggregate = 0;
    if (tap) AudioHardwareDestroyProcessTap(tap);
    tap = 0;
    started = NO;
}
- (void)dealloc { [self stop]; }
@end

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property AudioController *audio;
@property NSStatusItem *item;
@property NSSlider *slider;
@property NSTextField *level;
@property NSTextField *device;
@property NSTextField *state;
@property NSMenuItem *toggleItem;
@property NSTimer *timer;
@property BOOL enabled;
@property BOOL muted;
@property double volume;
@property BOOL sleeping;
@end

@implementation AppDelegate
- (NSTextField *)label:(NSString *)text frame:(NSRect)frame font:(NSFont *)font {
    NSTextField *label = [NSTextField labelWithString:text];
    label.frame = frame;
    label.font = font;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    return label;
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.audio = [AudioController new];
    NSNumber *saved = [NSUserDefaults.standardUserDefaults objectForKey:@"volume"];
    self.volume = saved ? fmax(0, fmin(100, saved.doubleValue)) : 50;
    self.muted = [NSUserDefaults.standardUserDefaults boolForKey:@"muted"];
    self.item = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    NSMenu *menu = [NSMenu new];
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 280, 114)];
    [view addSubview:[self label:@"Hush" frame:NSMakeRect(18, 84, 185, 20) font:[NSFont boldSystemFontOfSize:13]]];
    self.level = [self label:@"50%" frame:NSMakeRect(215, 84, 50, 20) font:[NSFont monospacedDigitSystemFontOfSize:13 weight:NSFontWeightRegular]];
    self.level.alignment = NSTextAlignmentRight;
    [view addSubview:self.level];
    self.device = [self label:@"" frame:NSMakeRect(18, 62, 245, 18) font:[NSFont systemFontOfSize:11]];
    self.device.textColor = NSColor.secondaryLabelColor;
    [view addSubview:self.device];
    self.slider = [NSSlider sliderWithValue:self.volume minValue:0 maxValue:100 target:self action:@selector(changeVolume:)];
    self.slider.frame = NSMakeRect(18, 32, 246, 25);
    self.slider.continuous = YES;
    self.slider.accessibilityLabel = @"Monitor volume";
    [view addSubview:self.slider];
    self.state = [self label:@"Starting…" frame:NSMakeRect(18, 8, 246, 18) font:[NSFont systemFontOfSize:11]];
    self.state.textColor = NSColor.secondaryLabelColor;
    [view addSubview:self.state];
    NSMenuItem *custom = [NSMenuItem new];
    custom.view = view;
    [menu addItem:custom];
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *mute = [[NSMenuItem alloc] initWithTitle:@"Mute / Unmute" action:@selector(toggleMute:) keyEquivalent:@""];
    mute.target = self;
    [menu addItem:mute];
    self.toggleItem = [[NSMenuItem alloc] initWithTitle:@"Pause volume control" action:@selector(toggle:) keyEquivalent:@""];
    self.toggleItem.target = self;
    [menu addItem:self.toggleItem];
    NSMenuItem *retry = [[NSMenuItem alloc] initWithTitle:@"Reconnect audio" action:@selector(reconnect:) keyEquivalent:@""];
    retry.target = self;
    [menu addItem:retry];
    NSMenuItem *settings = [[NSMenuItem alloc] initWithTitle:@"Audio access settings…" action:@selector(settings:) keyEquivalent:@""];
    settings.target = self;
    [menu addItem:settings];
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *quit = [[NSMenuItem alloc] initWithTitle:@"Quit — restore original audio" action:@selector(terminate:) keyEquivalent:@"q"];
    [menu addItem:quit];
    self.item.menu = menu;
    [self updateGain];
    self.enabled = YES;
    [self.audio start];
    [self updateUI];
    self.timer = [NSTimer timerWithTimeInterval:1 target:self selector:@selector(tick:) userInfo:nil repeats:YES];
    [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
    [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self selector:@selector(sleep:) name:NSWorkspaceWillSleepNotification object:nil];
    [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self selector:@selector(wake:) name:NSWorkspaceDidWakeNotification object:nil];
}
- (void)updateGain {
    // Quadratic taper gives finer control at quiet listening levels.
    atomic_store(&self.audio->gain.target, self.muted ? 0 : powf(self.volume / 100.0f, 2));
    [NSUserDefaults.standardUserDefaults setDouble:self.volume forKey:@"volume"];
    [NSUserDefaults.standardUserDefaults setBool:self.muted forKey:@"muted"];
}
- (void)updateUI {
    self.level.stringValue = self.muted ? @"Muted" : [NSString stringWithFormat:@"%.0f%%", self.volume];
    self.slider.doubleValue = self.volume;
    self.slider.enabled = self.audio->started;
    self.device.stringValue = self.audio.deviceName ?: @"No output";
    self.state.stringValue = !self.enabled ? @"Paused · original audio volume" : self.audio.problem ?: (atomic_load(&self.audio->gain.callbacks) ? @"Volume control on" : @"Waiting for audio / audio permission…");
    self.state.toolTip = self.audio.problem;
    self.toggleItem.title = self.enabled ? @"Pause volume control" : @"Enable volume control";
    NSString *symbol = !self.audio->started ? @"speaker.badge.exclamationmark" : (self.muted || self.volume == 0 ? @"speaker.slash.fill" : @"speaker.wave.2.fill");
    self.item.button.image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:@"Hush"];
    self.item.button.image.template = YES;
    self.item.button.toolTip = [NSString stringWithFormat:@"Hush · %@ · %@", self.level.stringValue, self.device.stringValue];
}
- (void)changeVolume:(NSSlider *)sender { self.volume = sender.doubleValue; self.muted = NO; [self updateGain]; [self updateUI]; }
- (void)toggleMute:(id)sender { self.muted = !self.muted; [self updateGain]; [self updateUI]; }
- (void)toggle:(id)sender { self.enabled = !self.enabled; if (self.enabled) [self.audio start]; else [self.audio stop]; [self updateUI]; }
- (void)reconnect:(id)sender { self.enabled = YES; [self.audio start]; [self updateUI]; }
- (void)settings:(id)sender { [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_AudioCapture"]]; }
- (void)tick:(id)sender {
    if (!self.sleeping && self.enabled && self.audio->output != defaultOutput()) [self.audio start];
    [self updateUI];
    // Optional development telemetry contains only numeric levels, never audio.
    NSArray *args = NSProcessInfo.processInfo.arguments;
    NSUInteger index = [args indexOfObject:@"--diagnostics"];
    if (index != NSNotFound && index + 1 < args.count) {
        NSDictionary *status = @{@"running": @(self.audio->started), @"device": self.audio.deviceName ?: @"",
            @"error": self.audio.problem ?: @"", @"callbacks": @(atomic_load(&self.audio->gain.callbacks)),
            @"inputPeak": @(atomic_load(&self.audio->gain.inputPeak)), @"outputPeak": @(atomic_load(&self.audio->gain.outputPeak)),
            @"gain": @(atomic_load(&self.audio->gain.target)), @"volume": @(self.volume)};
        [[NSJSONSerialization dataWithJSONObject:status options:NSJSONWritingPrettyPrinted error:nil] writeToFile:args[index + 1] atomically:YES];
    }
}
- (void)sleep:(id)sender { self.sleeping = YES; [self.audio stop]; }
- (void)wake:(id)sender { self.sleeping = NO; if (self.enabled) [self.audio start]; [self updateUI]; }
- (void)applicationWillTerminate:(NSNotification *)notification { [self.audio stop]; }
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc > 1 && strcmp(argv[1], "--inspect") == 0) {
            AudioDeviceID device = defaultOutput();
            printf("Default output: %u %s\n", device, stringProperty(device, kAudioObjectPropertyName).UTF8String);
            for (NSValue *value in formats(device, kAudioDevicePropertyScopeOutput)) {
                AudioStreamBasicDescription f; [value getValue:&f];
                printf("%.0f Hz, %u channels, %u bits, format %u, flags %u; supported: %s\n", f.mSampleRate, f.mChannelsPerFrame, f.mBitsPerChannel, f.mFormatID, f.mFormatFlags, validFormat(f) ? "yes" : "no");
            }
            return device ? 0 : 1;
        }
        // One controller per login session, even if opened again manually.
        NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
        for (NSRunningApplication *other in [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleID ?: @"local.hush.Hush"]) {
            if (other.processIdentifier != getpid()) return 0;
        }
        NSApplication *app = NSApplication.sharedApplication;
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        AppDelegate *delegate = [AppDelegate new];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
