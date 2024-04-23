//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import "UIDevice+TikTokAdditions.h"
#import <sys/sysctl.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <net/if.h>
#import <AdSupport/ASIdentifierManager.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import "TikTokFactory.h"

#define IOS_CELLULAR    @"pdp_ip0"
#define IOS_WIFI        @"en0"
#define IOS_WIRED       @"en2"
#define IOS_VPN         @"utun0"
#define IP_ADDR_IPv4    @"ipv4"
#define IP_ADDR_IPv6    @"ipv6"

@implementation UIDevice(TikTokAdditions)

- (void)requestTrackingAuthorizationWithCompletionHandler:(void (^)(NSUInteger))completion
{
    NSString *trackingDesc = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSUserTrackingUsageDescription"];
    if (@available(iOS 14, *)) {
        if (trackingDesc) {
            [ATTrackingManager requestTrackingAuthorizationWithCompletionHandler:^(ATTrackingManagerAuthorizationStatus status) {
                if(completion) {
                    completion(status);
                }
            }];
        } else {
            [[TikTokFactory getLogger] warn:@"Please set NSUserTrackingUsageDescription in Property List before calling App Tracking Dialog"];
        }
    } else {
        // Fallback on earlier versions
    }
}

- (BOOL)tiktokUserTrackingEnabled
{
    if (@available(iOS 14, *)) {
        ATTrackingManagerAuthorizationStatus trackingStatus = ATTrackingManager.trackingAuthorizationStatus;
        if (trackingStatus == ATTrackingManagerAuthorizationStatusAuthorized) {
            return YES;
        } else {
            return NO;
        }
    } else {
        // Fallback on earlier versions
        return YES;
    }
}

- (NSString *)tiktokDeviceType
{
    NSString *type = [self.model stringByReplacingOccurrencesOfString:@" " withString:@""];
    return type;
}

- (NSString *)tiktokDeviceName
{
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *name = malloc(size);
    sysctlbyname("hw.machine", name, &size, NULL, 0);
    NSString *machine = [NSString stringWithUTF8String:name];
    free(name);
    return machine;
}

- (NSString *)tiktokCreateUuid {
    CFUUIDRef newUniqueId = CFUUIDCreate(kCFAllocatorDefault);
    CFStringRef stringRef = CFUUIDCreateString(kCFAllocatorDefault, newUniqueId);
    NSString *uuidString = (__bridge_transfer NSString*)stringRef;
    NSString *lowerUuid = [uuidString lowercaseString];
    CFRelease(newUniqueId);
    return lowerUuid;
}

- (NSString *)tiktokVendorId
{
    if ([UIDevice.currentDevice respondsToSelector:@selector(identifierForVendor)]) {
        return [UIDevice.currentDevice.identifierForVendor UUIDString];
    }
    return @"";
}

- (NSString *)tiktokDeviceIp
{
    return [self getIPAddress: YES];
}


- (NSString *)getIPAddress:(BOOL)preferIPv4
{
    NSArray *searchArray = preferIPv4 ?
                            @[ IOS_WIFI @"/" IP_ADDR_IPv4, IOS_WIFI @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6 ] :
                            @[ IOS_WIFI @"/" IP_ADDR_IPv6, IOS_WIFI @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4 ] ;

    NSDictionary *addresses = [self getIPAddresses];

    __block NSString *address;
    [searchArray enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop)
        {
            address = addresses[key];
            if(address) *stop = YES;
        } ];
    return address ? address : @"0.0.0.0";
}

- (NSDictionary *)getIPAddresses
{
    NSMutableDictionary *addresses = [NSMutableDictionary dictionaryWithCapacity: 8];

    // retrieve the current interfaces - returns 0 on success
    struct ifaddrs *interfaces;
    if(!getifaddrs(&interfaces)) {
        // Loop through linked list of interfaces
        struct ifaddrs *interface;
        for(interface=interfaces; interface; interface=interface->ifa_next) {
            if(!(interface->ifa_flags & IFF_UP) /* || (interface->ifa_flags & IFF_LOOPBACK) */ ) {
                continue; // deeply nested code harder to read
            }
            const struct sockaddr_in *addr = (const struct sockaddr_in*)interface->ifa_addr;
            char addrBuf[ MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN) ];
            if(addr && (addr->sin_family==AF_INET || addr->sin_family==AF_INET6)) {
                NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
                NSString *type;
                if(addr->sin_family == AF_INET) {
                    if(inet_ntop(AF_INET, &addr->sin_addr, addrBuf, INET_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv4;
                    }
                } else {
                    const struct sockaddr_in6 *addr6 = (const struct sockaddr_in6*)interface->ifa_addr;
                    if(inet_ntop(AF_INET6, &addr6->sin6_addr, addrBuf, INET6_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv6;
                    }
                }
                if(type) {
                    NSString *key = [NSString stringWithFormat:@"%@/%@", name, type];
                    addresses[key] = [NSString stringWithUTF8String:addrBuf];
                }
            }
        }
        // Free memory
        freeifaddrs(interfaces);
    }
    return [addresses count] ? addresses : nil;
}

@end
