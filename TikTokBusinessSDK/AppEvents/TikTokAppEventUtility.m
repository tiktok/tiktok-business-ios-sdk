//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import "TikTokAppEventUtility.h"

@implementation TikTokAppEventUtility

+ (NSString *)getCurrentTimestampInISO8601
{
    NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setTimeZone:timeZone];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
    NSDate *now = [NSDate date];
    return [dateFormatter stringFromDate:now];
}

+ (long)getCurrentTimestamp
{
    long currentTime = (long)(NSTimeInterval)([[NSDate date] timeIntervalSince1970]);
    NSLog(@"Date: %@", [NSDate date]);
    return currentTime;
}

+ (NSString *)getCurrentTimestampAsString
{
    long currentTime = (long)(NSTimeInterval)([[NSDate date] timeIntervalSince1970]);
    return [NSString stringWithFormat:@"%ld", currentTime];
}


+(NSNumber *)getCurrentTimestampAsNumber
{
    NSNumber *currentTime = [NSNumber numberWithInt:(NSTimeInterval)([[NSDate date] timeIntervalSince1970])] ;
    return currentTime;
}
@end
