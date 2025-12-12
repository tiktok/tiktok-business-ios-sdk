//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import "TikTokFactory.h"

static TikTokLogger *internalLogger = nil;
static TikTokRequestHandler *requestHandler = nil;

@implementation TikTokFactory

+ (TikTokLogger *)getLogger
{
    if (internalLogger == nil) {
        internalLogger = [[TikTokLogger alloc] init];
    }
    return internalLogger;
}

+ (void)setLogger:(TikTokLogger *)logger
{
    internalLogger = logger;
}

+ (TikTokRequestHandler*)getRequestHandler
{
    if (requestHandler == nil) {
        requestHandler = [[TikTokRequestHandler alloc] init];
    }
    return requestHandler;
}

@end
