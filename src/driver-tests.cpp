#include <CoreAudio/AudioServerPlugIn.h>
#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <cassert>
#include <cstdio>
int main(int argc, char **argv) {
    assert(argc == 2);
    void *library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    if (!library) { puts(dlerror()); return 1; }
    auto factory = (void *(*)(CFAllocatorRef,CFUUIDRef))dlsym(library,"ProxyAudio_Create");
    assert(factory);
    auto driver = (AudioServerPlugInDriverRef)factory(nullptr,kAudioServerPlugInTypeUUID);
    assert(driver);
    AudioObjectPropertyAddress address = {kAudioObjectPropertyCustomPropertyInfoList,kAudioObjectPropertyScopeGlobal,0};
    assert((*driver)->HasProperty(driver,3,0,&address));
    UInt32 size = 0;
    assert((*driver)->GetPropertyDataSize(driver,3,0,&address,0,nullptr,&size)==0);
    assert(size == sizeof(AudioServerPlugInCustomPropertyInfo)*3);
    AudioServerPlugInCustomPropertyInfo info[3];
    assert((*driver)->GetPropertyData(driver,3,0,&address,0,nullptr,sizeof(info),&size,info)==0);
    for (int i=0;i<3;i++) {
        assert(info[i].mPropertyDataType == kAudioServerPlugInCustomPropertyDataTypeCFString);
        address.mSelector = info[i].mSelector;
        assert((*driver)->HasProperty(driver,3,0,&address));
        CFStringRef value = nullptr;
        assert((*driver)->GetPropertyData(driver,3,0,&address,0,nullptr,sizeof(value),&size,&value)==0);
        assert(value && CFGetTypeID(value)==CFStringGetTypeID());
        if (info[i].mSelector == 'huid') assert(CFStringGetLength(value) == 0);
        CFRelease(value);
    }
    puts("PASS: driver factory, custom-property registration, Core Audio marshaling types, readiness and telemetry strings.");
}
