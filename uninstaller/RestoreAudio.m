#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudio.h>

static AudioObjectPropertyAddress Addr(UInt32 s, UInt32 scope) { return (AudioObjectPropertyAddress){s,scope,0}; }
static OSStatus Get(AudioObjectID d, UInt32 s, UInt32 scope, UInt32 size, void *out) {
    AudioObjectPropertyAddress a=Addr(s,scope); return AudioObjectGetPropertyData(d,&a,0,NULL,&size,out);
}
static NSString *String(AudioObjectID d, UInt32 s) {
    CFStringRef value=NULL;
    if(Get(d,s,kAudioObjectPropertyScopeGlobal,sizeof(value),&value)) return @"";
    return CFBridgingRelease(value) ?: @"";
}
static UInt32 Number(AudioObjectID d, UInt32 s) {
    UInt32 v=0; Get(d,s,kAudioObjectPropertyScopeGlobal,sizeof(v),&v); return v;
}
static BOOL IsHush(AudioObjectID d) { return [String(d,kAudioDevicePropertyDeviceUID) isEqualToString:@"HushAudioDevice_UID"]; }
static NSArray *PhysicalOutputs(void) {
    AudioObjectPropertyAddress a=Addr(kAudioHardwarePropertyDevices,kAudioObjectPropertyScopeGlobal);
    UInt32 size=0;
    if(AudioObjectGetPropertyDataSize(kAudioObjectSystemObject,&a,0,NULL,&size)) return @[];
    NSMutableData *data=[NSMutableData dataWithLength:size];
    if(AudioObjectGetPropertyData(kAudioObjectSystemObject,&a,0,NULL,&size,data.mutableBytes)) return @[];
    NSMutableArray *devices=[NSMutableArray array];
    AudioObjectID *ids=data.mutableBytes;
    for(UInt32 i=0;i<size/sizeof(*ids);i++) {
        AudioObjectID d=ids[i]; UInt32 transport=Number(d,kAudioDevicePropertyTransportType);
        if(IsHush(d) || transport==kAudioDeviceTransportTypeVirtual || transport==kAudioDeviceTransportTypeAggregate || !Number(d,kAudioDevicePropertyDeviceIsAlive)) continue;
        a=Addr(kAudioDevicePropertyStreamConfiguration,kAudioDevicePropertyScopeOutput);
        UInt32 bytes=0;
        if(AudioObjectGetPropertyDataSize(d,&a,0,NULL,&bytes) || bytes<sizeof(AudioBufferList)) continue;
        NSMutableData *buffers=[NSMutableData dataWithLength:bytes];
        if(AudioObjectGetPropertyData(d,&a,0,NULL,&bytes,buffers.mutableBytes)) continue;
        AudioBufferList *list=buffers.mutableBytes; UInt32 channels=0;
        for(UInt32 b=0;b<list->mNumberBuffers;b++) channels+=list->mBuffers[b].mNumberChannels;
        if(channels) [devices addObject:@(d)];
    }
    return devices;
}
int main(int argc,const char **argv) {
    @autoreleasepool {
        BOOL apply=argc==2 && !strcmp(argv[1],"--apply");
        if(argc!=2 || (!apply && strcmp(argv[1],"--plan"))) return 2;
        UInt32 selectors[]={kAudioHardwarePropertyDefaultOutputDevice,kAudioHardwarePropertyDefaultSystemOutputDevice};
        NSArray *physical=PhysicalOutputs();
        AudioDeviceID targets[2]={0};
        for(int i=0;i<2;i++) {
            AudioDeviceID current=Number(kAudioObjectSystemObject,selectors[i]);
            if(!IsHush(current)) continue;
            AudioDeviceID target=0;
            NSString *readyUID=String(current,'huid');
            for(NSNumber *d in physical) if([String(d.unsignedIntValue,kAudioDevicePropertyDeviceUID) isEqualToString:readyUID]) { target=d.unsignedIntValue; break; }
            if(![physical containsObject:@(target)]) {
                target=0;
                for(NSNumber *d in physical) if(Number(d.unsignedIntValue,kAudioDevicePropertyTransportType)==kAudioDeviceTransportTypeBuiltIn) { target=d.unsignedIntValue; break; }
                if(!target) target=[physical.firstObject unsignedIntValue];
            }
            if(!target) { fputs("No physical audio output is available. Connect speakers or headphones and retry; Hush has not been removed.\n",stderr); return 1; }
            targets[i]=target;
            printf("Restore %s to %s\n",i ? "sound effects" : "playback",String(target,kAudioObjectPropertyName).UTF8String);
        }
        if(apply) {
            for(int i=0;i<2;i++) if(targets[i]) {
                AudioObjectPropertyAddress a=Addr(selectors[i],kAudioObjectPropertyScopeGlobal);
                OSStatus error=AudioObjectSetPropertyData(kAudioObjectSystemObject,&a,0,NULL,sizeof(targets[i]),&targets[i]);
                if(error || Number(kAudioObjectSystemObject,selectors[i])!=targets[i]) {
                    fprintf(stderr,"Could not restore physical audio (%d). Hush has not been removed.\n",(int)error); return 1;
                }
            }
        }
        puts(apply ? "Audio is no longer routed through Hush." : "Audio restoration preflight passed.");
    }
}
