#import <Foundation/Foundation.h>
#import "RoutePolicy.h"
#include <assert.h>

static NSDictionary *Device(NSString *uid, BOOL builtin, int rank) {
    return @{@"uid":uid, @"builtin":@(builtin), @"rank":@(rank), @"native":@(builtin || rank >= 30)};
}
static NSString *Pick(NSArray *devices, NSSet *previous, NSString *current, NSString *system, NSString *last, NSString *saved) {
    return HushChooseRoute(devices, previous, current, system, last, saved, nil)[@"uid"];
}
int main(void) {
    @autoreleasepool {
        NSDictionary *speaker=Device(@"speaker",YES,10), *monitor=Device(@"monitor",NO,20), *usb=Device(@"usb",NO,30), *headphones=Device(@"headphones",NO,40);
        NSArray *all=@[speaker,monitor,usb,headphones];
        NSSet *known=[NSSet setWithArray:@[@"speaker",@"monitor",@"usb",@"headphones"]];
        assert([Pick(all,nil,nil,@"monitor",nil,nil) isEqual:@"monitor"]);
        assert([Pick(all,known,@"monitor",@"Hush",@"Hush",nil) isEqual:@"monitor"]);
        assert([Pick(all,known,@"monitor",@"usb",@"Hush",nil) isEqual:@"usb"]);
        assert([Pick(all,[NSSet setWithArray:@[@"speaker",@"monitor",@"usb"]],@"monitor",@"Hush",@"Hush",nil) isEqual:@"headphones"]);
        assert([Pick(all,[NSSet setWithArray:@[@"speaker",@"usb",@"headphones"]],@"headphones",@"headphones",@"headphones",nil) isEqual:@"headphones"]);
        assert([Pick(@[speaker],known,@"monitor",@"Hush",@"Hush",@"monitor") isEqual:@"speaker"]);
        assert([Pick(@[speaker,monitor],[NSSet setWithObject:@"speaker"],@"speaker",@"speaker",@"speaker",@"speaker") isEqual:@"monitor"]);
        assert([Pick(all,known,@"headphones",@"monitor",@"headphones",nil) isEqual:@"monitor"]);
        assert(Pick(@[],known,@"monitor",@"Hush",@"Hush",@"monitor")==nil);
        assert([Pick(all,nil,@"monitor",@"Hush",nil,@"monitor") isEqual:@"monitor"]);
        // Selecting the proxy must select its real destination, not the last speaker.
        NSString *proxy = @"HushAudioDevice_UID";
        assert([HushChooseRoute(all, known, @"speaker", proxy, @"speaker", @"speaker", @"monitor")[@"uid"] isEqual:@"monitor"]);
        assert([HushChooseRoute(all, known, @"usb", proxy, @"usb", @"usb", @"monitor")[@"uid"] isEqual:@"monitor"]);
        assert([HushChooseRoute(all, nil, @"speaker", proxy, nil, @"speaker", @"monitor")[@"uid"] isEqual:@"monitor"]);
        assert([HushChooseRoute(all, known, @"speaker", proxy, proxy, @"speaker", @"monitor")[@"uid"] isEqual:@"monitor"]);
        assert([HushChooseRoute(all, known, @"monitor", @"speaker", proxy, @"monitor", @"monitor")[@"uid"] isEqual:@"speaker"]);
        assert([HushChooseRoute(@[speaker], known, @"monitor", proxy, @"speaker", @"monitor", @"monitor")[@"uid"] isEqual:@"speaker"]);
        assert([HushChooseRoute(all, known, @"speaker", proxy, @"speaker", @"speaker", @"")[@"uid"] isEqual:@"speaker"]);
        assert([HushChooseRoute(all, [NSSet setWithArray:@[@"speaker", @"monitor", @"usb"]], @"monitor", proxy, proxy, @"monitor", @"monitor")[@"uid"] isEqual:@"headphones"]);
        puts("PASS: direct proxy selection, startup with proxy selected, stale proxy destination fallback, stable routing, explicit output selection, headphone hotplug, priority, unplug fallback, reconnect, empty device list and saved route.");
    }
}
