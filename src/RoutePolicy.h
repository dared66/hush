#import <Foundation/Foundation.h>
// Each device has uid, native (volume control), proxyable, builtin, rank.
// Higher rank favors headphones; newly connected devices never displace a higher-ranked output.
static inline NSDictionary *HushChooseRoute(NSArray<NSDictionary *> *devices, NSSet *previous,
                                            NSString *currentUID, NSString *systemUID,
                                            NSString *lastSystemUID, NSString *savedUID, NSString *readyOutputUID) {
    NSMutableDictionary *byUID = [NSMutableDictionary dictionary];
    for (NSDictionary *d in devices) byUID[d[@"uid"]] = d;
    NSDictionary *current = byUID[currentUID ?: @""];
    NSDictionary *proxyTarget = byUID[readyOutputUID ?: @""];
    if ([systemUID isEqualToString:@"HushAudioDevice_UID"] && proxyTarget && ![proxyTarget[@"native"] boolValue]) {
        // The proxy is absent from the physical-device list. Resolve it by stable UID.
        if (![systemUID isEqualToString:lastSystemUID]) return proxyTarget;
        current = proxyTarget;
    }
    NSDictionary *system = byUID[systemUID ?: @""];
    if (system && ![systemUID isEqualToString:lastSystemUID]) return system;
    if (previous) {
        NSDictionary *newest = nil;
        for (NSDictionary *d in devices) {
            if (![previous containsObject:d[@"uid"]] && ![d[@"builtin"] boolValue] &&
                [d[@"rank"] intValue] > [newest[@"rank"] intValue]) newest = d;
        }
        if (newest && (!current || [newest[@"rank"] intValue] >= [current[@"rank"] intValue])) return newest;
    }
    if (current) return current;
    if (system) return system;
    if (byUID[savedUID ?: @""]) return byUID[savedUID];
    for (NSDictionary *d in devices) if ([d[@"builtin"] boolValue]) return d;
    return devices.firstObject;
}
