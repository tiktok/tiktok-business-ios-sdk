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
    // A fixed-format date formatter must use en_US_POSIX, otherwise the user's
    // 24-Hour Time setting rewrites the format string and the output is not
    // ISO 8601 (Apple QA1480).
    dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    [dateFormatter setTimeZone:timeZone];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
    NSDate *now = [NSDate date];
    return [dateFormatter stringFromDate:now];
}

+ (long long)getCurrentTimestamp
{
    long long currentTime = (long long)([[NSDate date] timeIntervalSince1970] * 1000);
    return currentTime;
}

+ (NSString *)getCurrentTimestampAsString
{
    long long currentTime = (long long)([[NSDate date] timeIntervalSince1970] * 1000);
    return [NSString stringWithFormat:@"%lld", currentTime];
}

+ (NSString *)timestampAsStringFromDate:(NSDate *)date {
    long long time = (long long)([date timeIntervalSince1970] * 1000);
    return [NSString stringWithFormat:@"%lld", time];
}


+(NSNumber *)getCurrentTimestampAsNumber
{
    NSNumber *currentTime = [NSNumber numberWithLongLong:([[NSDate date] timeIntervalSince1970] * 1000)] ;
    return currentTime;
}
@end
