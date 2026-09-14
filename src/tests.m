#import <Foundation/Foundation.h>
#import "RoutePolicy.h"
#include <assert.h>

static NSDictionary *Device(NSString *uid, BOOL builtin, int rank) {
    return @{@"uid":uid, @"builtin":@(builtin), @"rank":@(rank)};
}
static NSString *Pick(NSArray *devices, NSSet *previous, NSString *current, NSString *system, NSString *last, NSString *saved) {
    return HushChooseRoute(devices, previous, current, system, last, saved)[@"uid"];
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
        puts("PASS: startup, stable routing, explicit output selection, headphone hotplug, priority, unplug fallback, reconnect, empty device list and saved route.");
    }
}
