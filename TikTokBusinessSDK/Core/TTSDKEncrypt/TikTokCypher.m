//
//  TikTokCypher.m
//  TikTokBusinessSDK
//
//  Created by TikTok on 11/26/24.
//  Copyright © 2024 TikTok. All rights reserved.
//

#import "TikTokCypher.h"
#import "TikTokTypeUtility.h"
#import <zlib.h>
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonHMAC.h>

static const int kTikTokGodzippaChunkSize = 1024;

@implementation TikTokCypher

+ (NSData *)gzipCompressData:(NSData *)data error:(TikTokCypherResultErrorCode *)errorcode {
    z_stream zStream;
    bzero(&zStream, sizeof(zStream));
    zStream.zalloc = Z_NULL;
    zStream.zfree = Z_NULL;
    zStream.opaque = Z_NULL;
    zStream.avail_in = (uint)data.length;
    zStream.next_in = (Bytef *)(void *)data.bytes;
    zStream.total_out = 0;
    zStream.avail_out = 0;
    
    // int deflateInit2(z_streamp strm, int level, int method, int windowBits, int memLevel, int strategy);
    // memLevel=1 uses minimum memory but is slow and reduces compression ratio;
    // memLevel=9 uses maximum memory for optimal speed.
    // The default value is 8.
    // Add 16 to windowBits to write a simple gzip header and trailer around the compressed data instead of a zlib wrapper.
    if (deflateInit2(&zStream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, MAX_WBITS + 16, 8, Z_DEFAULT_STRATEGY) != Z_OK) {
        *errorcode = TikTokCypherResultGzipInitError;
        return nil;
    }
    NSMutableData *compressedData = [NSMutableData dataWithLength:kTikTokGodzippaChunkSize];
    
    while (zStream.avail_out == 0) {
        if (zStream.total_out >= [compressedData length]) {
            [compressedData increaseLengthBy:kTikTokGodzippaChunkSize];
        }
        
        zStream.next_out = (Bytef*)[compressedData mutableBytes] + zStream.total_out;
        zStream.avail_out = (unsigned int)([compressedData length] - zStream.total_out);
        deflate(&zStream, Z_FINISH);
    }
    
    deflateEnd(&zStream);
    
    [compressedData setLength:zStream.total_out];
    return compressedData;
}

+ (NSData *)gzipUncompressData:(NSData *)data error:(TikTokCypherResultErrorCode *)errorcode {
    if (![TikTokCypher isGzippedData:data]) {
        *errorcode = TikTokCypherResultGzipTypeError;
        return nil;
    }
    
    z_stream zStream;
    bzero(&zStream, sizeof(zStream));
    zStream.zalloc = Z_NULL;
    zStream.zfree = Z_NULL;
    zStream.avail_in = (uint)data.length;
    zStream.next_in = (Bytef *)data.bytes;
    zStream.total_out = 0;
    zStream.avail_out = 0;
    
    // int inflateInit2(z_streamp strm, int windowBits);
    // Add 32 to windowBits to enable zlib and gzip decoding with automatic header
    // detection, or add 16 to decode only the gzip format (the zlib format will return a Z_DATA_ERROR).
    if (inflateInit2(&zStream, MAX_WBITS + 32) != Z_OK) {
        *errorcode = TikTokCypherResultGzipInitError;
        return nil;
    }
    
    NSInteger length = data.length;
    NSMutableData *uncompressedData = [NSMutableData dataWithCapacity:length];
    OSStatus status = Z_OK;
    while (status == Z_OK) {
        // Make sure we have enough room and reset the lengths.
        if (zStream.total_out >= [uncompressedData length]) {
            [uncompressedData increaseLengthBy:length/2];
        }
        zStream.next_out = [uncompressedData mutableBytes] + zStream.total_out;
        zStream.avail_out = (unsigned int)([uncompressedData length] - zStream.total_out);
        
        // Inflate another chunk.
        status = inflate(&zStream, Z_SYNC_FLUSH);
    }
    
    if (inflateEnd(&zStream) != Z_OK) {
        *errorcode = TikTokCypherResultGzipUncompressError;
        return nil;
    }
    
    [uncompressedData setLength:zStream.total_out];
    return [NSData dataWithData:uncompressedData];
}

+ (BOOL)isGzippedData:(NSData *)data {
    const UInt8 *bytes = (const UInt8 *)data.bytes;
    return (data.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b);
}

+ (NSString *)hmacSHA256WithSecret:(NSString *)secret content:(NSString *)content {
    if (!TTCheckValidString(secret) || !TTCheckValidString(content)) {
        return @"";
    }
    const char *cKey  = [secret cStringUsingEncoding:NSASCIIStringEncoding];
    const char *cData = [content cStringUsingEncoding:NSUTF8StringEncoding];
    if (!cKey || !cData) {
        return @"";
    }
    unsigned char cHMAC[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, cKey, strlen(cKey), cData, strlen(cData), cHMAC);
    NSData *HMACData = [NSData dataWithBytes:cHMAC length:sizeof(cHMAC)];
    NSString *HMAC = [HMACData base64EncodedStringWithOptions:0];
    return HMAC;
}

@end
