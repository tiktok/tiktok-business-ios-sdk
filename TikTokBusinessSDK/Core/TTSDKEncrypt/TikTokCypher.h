//
//  TikTokCypher.h
//  TikTokBusinessSDK
//
//  Created by TikTok on 11/26/24.
//  Copyright © 2024 TikTok. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TikTokCypherResultErrorCode) {
    TikTokCypherResultNone          = 0,
    TikTokCypherResultParamError,
    TikTokCypherResultSerializationError,
    TikTokCypherResultGzipInitError,
    TikTokCypherResultGzipTypeError,
    TikTokCypherResultGzipUncompressError,
    TikTokCypherResultCryptError
};

@interface TikTokCypher : NSObject

+ (NSData *)gzipCompressData:(NSData *)data error:(TikTokCypherResultErrorCode *)errorcode;

+ (NSData *)gzipUncompressData:(NSData *)data error:(TikTokCypherResultErrorCode *)errorcode;

+ (BOOL)isGzippedData:(NSData *)data;

+ (NSString *)hmacSHA256WithSecret:(NSString *)secret content:(NSString *)content;

@end

NS_ASSUME_NONNULL_END
