//
//  TikTokDebugInfo.h
//  TikTokBusinessSDK
//
//  Created by Chuanqi on 7/11/25.
//  Copyright © 2025 TikTok. All rights reserved.
//

#import <Foundation/Foundation.h>

#define TTBTMsDictKey (@"bootTimeMsDict")
#define TTBTSDictKey  (@"bootTimeSDict")

NS_ASSUME_NONNULL_BEGIN

@interface TikTokDebugInfo : NSObject

+ (NSDictionary *)debugInfo;

@end

NS_ASSUME_NONNULL_END
