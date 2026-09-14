#import <Cocoa/Cocoa.h>
#import <CoreAudio/CoreAudio.h>
#import <Security/Security.h>
#import "RoutePolicy.h"
#include <signal.h>

static NSString *const proxyUID = @"HushAudioDevice_UID";
static AudioObjectPropertyAddress Addr(UInt32 selector, UInt32 scope, UInt32 element) {
    return (AudioObjectPropertyAddress){selector, scope, element};
}
static OSStatus Get(AudioObjectID obj, UInt32 selector, UInt32 scope, UInt32 element, UInt32 size, void *data) {
    AudioObjectPropertyAddress a = Addr(selector, scope, element);
    return AudioObjectGetPropertyData(obj, &a, 0, NULL, &size, data);
}
static OSStatus Set(AudioObjectID obj, UInt32 selector, UInt32 scope, UInt32 element, UInt32 size, const void *data) {
    AudioObjectPropertyAddress a = Addr(selector, scope, element);
    return AudioObjectSetPropertyData(obj, &a, 0, NULL, size, data);
}
static NSString *String(AudioObjectID obj, UInt32 selector) {
    CFStringRef s = NULL;
    if (Get(obj, selector, kAudioObjectPropertyScopeGlobal, 0, sizeof(s), &s)) return @"";
    return CFBridgingRelease(s) ?: @"";
}
static UInt32 Integer(AudioObjectID obj, UInt32 selector, UInt32 scope) {
    UInt32 n = 0; Get(obj, selector, scope, 0, sizeof(n), &n); return n;
}
static AudioDeviceID Default(void) { return Integer(kAudioObjectSystemObject, kAudioHardwarePropertyDefaultOutputDevice, kAudioObjectPropertyScopeGlobal); }
static AudioDeviceID Lookup(NSString *uid, UInt32 selector) {
    AudioObjectPropertyAddress a = Addr(selector, kAudioObjectPropertyScopeGlobal, 0);
    CFStringRef value = (__bridge CFStringRef)uid;
    AudioObjectID obj = 0; UInt32 size = sizeof(obj);
    AudioObjectGetPropertyData(kAudioObjectSystemObject, &a, sizeof(value), &value, &size, &obj);
    return obj;
}
static AudioDeviceID Proxy(void) { return Lookup(proxyUID, kAudioHardwarePropertyTranslateUIDToDevice); }
static BOOL Writable(AudioDeviceID obj, UInt32 selector, UInt32 channel) {
    AudioObjectPropertyAddress a = Addr(selector, kAudioDevicePropertyScopeOutput, channel);
    Boolean yes = NO;
    return AudioObjectHasProperty(obj, &a) && !AudioObjectIsPropertySettable(obj, &a, &yes) && yes;
}
static NSArray<NSDictionary *> *Devices(void) {
    AudioObjectPropertyAddress a = Addr(kAudioHardwarePropertyDevices, kAudioObjectPropertyScopeGlobal, 0);
    UInt32 size = 0;
    if (AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &a, 0, NULL, &size)) return @[];
    NSMutableData *data = [NSMutableData dataWithLength:size];
    if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &a, 0, NULL, &size, data.mutableBytes)) return @[];
    NSMutableArray *result = [NSMutableArray array];
    AudioDeviceID *ids = data.mutableBytes;
    for (UInt32 i = 0; i < size / sizeof(AudioDeviceID); i++) {
        AudioDeviceID d = ids[i];
        NSString *uid = String(d, kAudioDevicePropertyDeviceUID);
        UInt32 transport = Integer(d, kAudioDevicePropertyTransportType, kAudioObjectPropertyScopeGlobal);
        if (!uid.length || [uid isEqualToString:proxyUID] || transport == kAudioDeviceTransportTypeVirtual || transport == kAudioDeviceTransportTypeAggregate ||
            !Integer(d, kAudioDevicePropertyDeviceIsAlive, kAudioObjectPropertyScopeGlobal)) continue;
        a = Addr(kAudioDevicePropertyStreamConfiguration, kAudioDevicePropertyScopeOutput, 0);
        UInt32 bytes = 0;
        if (AudioObjectGetPropertyDataSize(d, &a, 0, NULL, &bytes) || !bytes) continue;
        NSMutableData *config = [NSMutableData dataWithLength:bytes];
        if (AudioObjectGetPropertyData(d, &a, 0, NULL, &bytes, config.mutableBytes)) continue;
        AudioBufferList *buffers = config.mutableBytes;
        UInt32 channels = 0;
        for (UInt32 b = 0; b < buffers->mNumberBuffers; b++) channels += buffers->mBuffers[b].mNumberChannels;
        if (!channels) continue;
        BOOL native = Writable(d, kAudioDevicePropertyVolumeScalar, 0) ||
            (Writable(d, kAudioDevicePropertyVolumeScalar, 1) && (channels == 1 || Writable(d, kAudioDevicePropertyVolumeScalar, 2)));
        AudioStreamBasicDescription f = {0};
        BOOL proxyable = !Get(d, kAudioDevicePropertyStreamFormat, kAudioDevicePropertyScopeOutput, 0, sizeof(f), &f) &&
            f.mFormatID == kAudioFormatLinearPCM && (f.mFormatFlags & kAudioFormatFlagIsFloat) &&
            !(f.mFormatFlags & (kAudioFormatFlagIsNonInterleaved | kAudioFormatFlagIsBigEndian)) &&
            f.mBitsPerChannel == 32 && f.mChannelsPerFrame == 2 && f.mBytesPerFrame == 8 && f.mFramesPerPacket == 1;
        if (!native && !proxyable) continue;
        BOOL builtin = transport == kAudioDeviceTransportTypeBuiltIn;
        int rank = builtin ? 10 : 20;
        if (transport == kAudioDeviceTransportTypeUSB) rank = 30;
        if (transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE) rank = 40;
        [result addObject:@{@"id": @(d), @"uid": uid, @"name": String(d, kAudioObjectPropertyName), @"native": @(native), @"proxyable": @(proxyable), @"builtin": @(builtin), @"rank": @(rank)}];
    }
    return result;
}
static BOOL Configure(NSString *key, NSString *value) {
    AudioObjectID box = Lookup(@"HushAudioBox_UID", kAudioHardwarePropertyTranslateUIDToBox);
    if (!box) return NO;
    pid_t pid = getpid();
    if (Set(box, kAudioObjectPropertyIdentify, kAudioObjectPropertyScopeGlobal, 0, sizeof(pid), &pid)) return NO;
    CFStringRef s = (__bridge CFStringRef)[NSString stringWithFormat:@"%@=%@", key, value];
    return !Set(box, kAudioObjectPropertyName, kAudioObjectPropertyScopeGlobal, 0, sizeof(s), &s);
}
static Float32 Volume(AudioDeviceID d) {
    Float32 value = 0;
    if (!Get(d, kAudioDevicePropertyVolumeScalar, kAudioDevicePropertyScopeOutput, 0, sizeof(value), &value)) return value;
    Get(d, kAudioDevicePropertyVolumeScalar, kAudioDevicePropertyScopeOutput, 1, sizeof(value), &value);
    return value;
}
static BOOL SetVolume(AudioDeviceID d, Float32 volume) {
    if (!d || !isfinite(volume) || volume < 0 || volume > 1) return NO;
    if (Writable(d, kAudioDevicePropertyVolumeScalar, 0)) return !Set(d, kAudioDevicePropertyVolumeScalar, kAudioDevicePropertyScopeOutput, 0, sizeof(volume), &volume);
    OSStatus left = Set(d, kAudioDevicePropertyVolumeScalar, kAudioDevicePropertyScopeOutput, 1, sizeof(volume), &volume);
    OSStatus right = Set(d, kAudioDevicePropertyVolumeScalar, kAudioDevicePropertyScopeOutput, 2, sizeof(volume), &volume);
    return !left && !right;
}
static void Select(AudioDeviceID d) {
    if (!d) return;
    Set(kAudioObjectSystemObject, kAudioHardwarePropertyDefaultOutputDevice, kAudioObjectPropertyScopeGlobal, 0, sizeof(d), &d);
    Set(kAudioObjectSystemObject, kAudioHardwarePropertyDefaultSystemOutputDevice, kAudioObjectPropertyScopeGlobal, 0, sizeof(d), &d);
}
static void Status(void) {
    AudioDeviceID p = Proxy(), d = Default();
    Float64 meter[3] = {0};
    if (p) sscanf(String(p, 'hmet').UTF8String, "%lf %lf %lf", &meter[0], &meter[1], &meter[2]);
    NSDictionary *state = @{@"defaultID": @(d), @"defaultName": String(d, kAudioObjectPropertyName), @"proxyID": @(p),
        @"readyOutputUID": p ? String(p, 'huid') : @"",
        @"volume": @(Volume(d)), @"mute": @(Integer(d, kAudioDevicePropertyMute, kAudioDevicePropertyScopeOutput)),
        @"inputPeak": @(meter[0]), @"outputPeak": @(meter[1]), @"callbacks": @(meter[2]), @"devices": Devices()};
    NSData *json = [NSJSONSerialization dataWithJSONObject:state options:NSJSONWritingPrettyPrinted error:nil];
    puts([[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding].UTF8String);
}

@interface Hush : NSObject <NSApplicationDelegate>
@property NSTimer *timer;
@property NSWindow *settingsWindow;
@property NSString *routeUID;
@property NSString *lastSystemUID;
@property NSSet *previousUIDs;
@property NSDictionary *pending;
@property NSInteger attempts;
@property BOOL sleeping;
@property dispatch_source_t terminateSource;
@end
@implementation Hush
- (void)showSettings:(id)sender {
    if (!self.settingsWindow) {
        self.settingsWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 440, 260)
            styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];
        self.settingsWindow.title = @"Hush";
        self.settingsWindow.releasedWhenClosed = NO;
        NSImageView *icon = [[NSImageView alloc] initWithFrame:NSMakeRect(28, 156, 72, 72)];
        icon.image = [NSImage imageNamed:NSImageNameApplicationIcon];
        [self.settingsWindow.contentView addSubview:icon];
        NSTextField *title = [NSTextField labelWithString:@"Quietly in control."];
        title.font = [NSFont systemFontOfSize:23 weight:NSFontWeightSemibold];
        title.frame = NSMakeRect(116, 190, 300, 30);
        [self.settingsWindow.contentView addSubview:title];
        NSTextField *description = [NSTextField wrappingLabelWithString:@"Use your Mac’s volume keys or system slider. Hush handles your connected audio devices automatically."];
        description.frame = NSMakeRect(116, 120, 290, 65);
        [self.settingsWindow.contentView addSubview:description];
        NSTextField *hint = [NSTextField labelWithString:@"Closing this window keeps Hush running."];
        hint.textColor = NSColor.secondaryLabelColor;
        hint.frame = NSMakeRect(28, 78, 384, 22);
        [self.settingsWindow.contentView addSubview:hint];
        NSButton *remove = [NSButton buttonWithTitle:@"Uninstall Hush…" target:self action:@selector(uninstall:)];
        remove.frame = NSMakeRect(262, 25, 150, 32);
        [self.settingsWindow.contentView addSubview:remove];
        [self.settingsWindow center];
    }
    [self.settingsWindow makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}
- (BOOL)applicationShouldHandleReopen:(NSApplication *)app hasVisibleWindows:(BOOL)visible {
    [self showSettings:nil]; return YES;
}
- (void)uninstall:(id)sender {
    NSAlert *confirm = [NSAlert new];
    confirm.messageText = @"Uninstall Hush?";
    confirm.informativeText = @"This removes Hush, its audio driver, and automatic startup. Audio will pause briefly and return to your device’s hardware volume. Pause playback before continuing.";
    [confirm addButtonWithTitle:@"Cancel"];
    [confirm addButtonWithTitle:@"Uninstall"];
    confirm.showsSuppressionButton = YES;
    confirm.suppressionButton.title = @"Also delete saved settings and backups";
    if ([confirm runModal] != NSAlertSecondButtonReturn) return;
    NSString *script = [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"Uninstaller/launch-uninstall.sh"];
    AuthorizationRef authorization = NULL;
    OSStatus result = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authorization);
    if (result == errAuthorizationSuccess) {
        char *arguments[] = {(char *)script.fileSystemRepresentation,
            confirm.suppressionButton.state == NSControlStateValueOn ? "--purge" : NULL, NULL};
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        result = AuthorizationExecuteWithPrivileges(authorization, "/bin/bash", kAuthorizationFlagDefaults, arguments, NULL);
#pragma clang diagnostic pop
        AuthorizationFree(authorization, kAuthorizationFlagDefaults);
    }
    if (result != errAuthorizationSuccess && result != errAuthorizationCanceled) {
        NSAlert *error = [NSAlert new]; error.messageText = @"Hush couldn’t start uninstalling.";
        error.informativeText = @"Administrator authorization was not completed. Hush is still installed.";
        [error runModal];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)note {
    [NSDistributedNotificationCenter.defaultCenter addObserver:self selector:@selector(showSettings:) name:@"local.hush.showSettings" object:nil];
    if (![NSProcessInfo.processInfo.arguments containsObject:@"--background"]) [self showSettings:nil];
    signal(SIGTERM, SIG_IGN);
    self.terminateSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGTERM, 0, dispatch_get_main_queue());
    dispatch_source_set_event_handler(self.terminateSource, ^{ [NSApplication.sharedApplication terminate:nil]; });
    dispatch_resume(self.terminateSource);
    [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self selector:@selector(sleep:) name:NSWorkspaceWillSleepNotification object:nil];
    [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self selector:@selector(wake:) name:NSWorkspaceDidWakeNotification object:nil];
    self.routeUID = [NSUserDefaults.standardUserDefaults stringForKey:@"lastOutputUID"];
    [self tick:nil];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(tick:) userInfo:nil repeats:YES];
}
- (void)remember {
    AudioDeviceID p = Proxy();
    if (p && self.routeUID && Default() == p && !self.pending) {
        [NSUserDefaults.standardUserDefaults setFloat:Volume(p) forKey:[@"volume:" stringByAppendingString:self.routeUID]];
        [NSUserDefaults.standardUserDefaults setBool:Integer(p, kAudioDevicePropertyMute, kAudioDevicePropertyScopeOutput) forKey:[@"mute:" stringByAppendingString:self.routeUID]];
    }
}
- (void)tick:(id)sender {
    if (self.sleeping) return;
    [self remember];
    NSArray *devices = Devices();
    AudioDeviceID p = Proxy();
    NSString *systemUID = String(Default(), kAudioDevicePropertyDeviceUID);
    NSSet *uids = [NSSet setWithArray:[devices valueForKey:@"uid"]];
    if (self.pending) {
        BOOL manualChange = ![systemUID isEqualToString:self.lastSystemUID] && ![systemUID isEqualToString:proxyUID];
        if (![uids containsObject:self.pending[@"uid"]] || manualChange || ++self.attempts > 20) {
            self.pending = nil;
            self.routeUID = nil;
        } else if ([String(p, 'huid') isEqualToString:self.pending[@"uid"]]) {
            self.routeUID = self.pending[@"uid"];
            NSString *key = [@"volume:" stringByAppendingString:self.routeUID];
            NSNumber *saved = [NSUserDefaults.standardUserDefaults objectForKey:key];
            NSDictionary *legacy = [NSUserDefaults.standardUserDefaults persistentDomainForName:@"local.krupa.MonitorVolume"];
            double oldLevel = [legacy[@"volume"] doubleValue] / 100.0;
            Float32 migrated = oldLevel > 0 ? fmaxf(0, fminf(1, (10 * log10(oldLevel * oldLevel) + 25) / 25)) : 0;
            Float32 level = saved ? saved.floatValue : (legacy[@"volume"] ? migrated : 0.30f);
            SetVolume(p, level);
            UInt32 muted = saved ? [NSUserDefaults.standardUserDefaults boolForKey:[@"mute:" stringByAppendingString:self.routeUID]] : [legacy[@"muted"] boolValue];
            Set(p, kAudioDevicePropertyMute, kAudioDevicePropertyScopeOutput, 0, sizeof(muted), &muted);
            Select(p);
            self.pending = nil;
            [NSUserDefaults.standardUserDefaults setObject:self.routeUID forKey:@"lastOutputUID"];
        }
        if (self.pending) { self.previousUIDs = uids; self.lastSystemUID = String(Default(), kAudioDevicePropertyDeviceUID); return; }
    }
    // Respect an intentionally chosen virtual or unsupported output rather than taking it over.
    if (Default() && Default() != p && ![uids containsObject:systemUID]) {
        self.routeUID = nil; self.previousUIDs = uids; self.lastSystemUID = systemUID; return;
    }
    NSDictionary *choice = HushChooseRoute(devices, self.previousUIDs, self.routeUID, systemUID, self.lastSystemUID,
        [NSUserDefaults.standardUserDefaults stringForKey:@"lastOutputUID"]);
    if (choice) {
        AudioDeviceID target = [choice[@"id"] unsignedIntValue];
        BOOL native = [choice[@"native"] boolValue];
        if (native) {
            self.routeUID = choice[@"uid"];
            if (Default() != target || Integer(kAudioObjectSystemObject, kAudioHardwarePropertyDefaultSystemOutputDevice, kAudioObjectPropertyScopeGlobal) != target) Select(target);
            [NSUserDefaults.standardUserDefaults setObject:self.routeUID forKey:@"lastOutputUID"];
        } else if (p && (Default() != p || ![self.routeUID isEqualToString:choice[@"uid"]] || ![String(p, 'huid') isEqualToString:choice[@"uid"]])) {
            // Configure first. Switch the default only after the driver confirms the target is ready.
            if (Configure(@"outputDevice", choice[@"uid"])) {
                Configure(@"deviceName", [NSString stringWithFormat:@"%@ (Hush)", choice[@"name"]]);
                Configure(@"outputDeviceActiveCondition", @"0");
                self.pending = choice;
                self.attempts = 0;
            }
        }
    }
    self.previousUIDs = uids;
    self.lastSystemUID = String(Default(), kAudioDevicePropertyDeviceUID);
}
- (void)sleep:(id)sender { [self remember]; self.sleeping = YES; }
- (void)wake:(id)sender { self.sleeping = NO; self.previousUIDs = nil; self.pending = nil; [self tick:nil]; }
- (void)applicationWillTerminate:(NSNotification *)note {
    [self remember];
    // The driver continues audio independently; do not jump to full physical volume on agent exit.
}
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc > 1 && strcmp(argv[1], "--background") != 0) {
            NSString *command = @(argv[1]);
            if ([command isEqualToString:@"--status"] || [command isEqualToString:@"--inspect"]) { Status(); return 0; }
            if ([command isEqualToString:@"--volume"] && argc == 3) return SetVolume(Default(), atof(argv[2])) ? 0 : 1;
            if ([command isEqualToString:@"--mute"] && argc == 3) {
                UInt32 mute = atoi(argv[2]) != 0;
                return Set(Default(), kAudioDevicePropertyMute, kAudioDevicePropertyScopeOutput, 0, sizeof(mute), &mute) ? 1 : 0;
            }
            if ([command isEqualToString:@"--output"] && argc == 3) {
                AudioDeviceID d = Lookup(@(argv[2]), kAudioHardwarePropertyTranslateUIDToDevice);
                if (!d) return 1;
                Select(d); return 0;
            }
            fputs("Usage: Hush [--status | --volume 0..1 | --mute 0|1 | --output DEVICE_UID]\n", stderr); return 2;
        }
        for (NSRunningApplication *other in [NSRunningApplication runningApplicationsWithBundleIdentifier:NSBundle.mainBundle.bundleIdentifier ?: @"local.hush.Hush"])
            if (other.processIdentifier != getpid()) {
                if (argc == 1) [NSDistributedNotificationCenter.defaultCenter postNotificationName:@"local.hush.showSettings" object:nil];
                return 0;
            }
        NSApplication *app = NSApplication.sharedApplication;
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        Hush *delegate = [Hush new]; app.delegate = delegate;
        [app run];
    }
}
