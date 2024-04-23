//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import "TikTokLogger.h"
#import "TikTokRequestHandler.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Handles shared classes like TikTokLogger across multiple objects
*/
@interface TikTokFactory : NSObject

+ (id<TikTokLogger>)getLogger;
+ (void)setLogger:(id<TikTokLogger>)logger;
+ (TikTokRequestHandler*)getRequestHandler;

@end

NS_ASSUME_NONNULL_END
