//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import "TikTokTypeUtility.h"
#import "TikTokErrorHandler.h"
#import <CommonCrypto/CommonDigest.h>


@implementation TikTokTypeUtility

+ (id)objectValue:(id)object
{
    return ([object isKindOfClass:[NSNull class]] ? nil : object);
}

+ (NSData *)dataWithJSONObject:(id)obj
                       options:(NSJSONWritingOptions)opt
                         error:(NSError *__autoreleasing  _Nullable *)error
                        origin:(NSString *)origin
{
  NSData *data;

  @try {
    data = [NSJSONSerialization dataWithJSONObject:obj options:opt error:error];
  } @catch (NSException *exception) {
      [TikTokErrorHandler handleErrorWithOrigin:origin message:@"JSONSerialization dataWithJSONObject:options:error failure" exception:exception];
  }
  return data;
}

+ (id)JSONObjectWithData:(NSData *)data
                 options:(NSJSONReadingOptions)opt
                   error:(NSError *__autoreleasing  _Nullable *)error
                  origin:(NSString *)origin
{
  if (![data isKindOfClass:NSData.class]) {
    return nil;
  }

  id object;
  @try {
     object = [NSJSONSerialization JSONObjectWithData:data options:opt error:error];
  } @catch (NSException *exception) {
      [TikTokErrorHandler handleErrorWithOrigin:origin message:@"JSONSerialization JSONObjectWithData:options:error failure" exception:exception];
  }
  return object;
}

+ (NSString *)toSha256:(NSObject *)input
                origin:(nullable NSString *)origin
{
  NSData *data = nil;

  if ([input isKindOfClass:[NSData class]]) {
    data = (NSData *)input;
  } else if ([input isKindOfClass:[NSString class]]) {
    data = [(NSString *)input dataUsingEncoding:NSUTF8StringEncoding];
  }

  if (!data) {
    [TikTokErrorHandler handleErrorWithOrigin:origin message:@"input for SHA256 conversion is incorrect"];
    return nil;
  }

  uint8_t digest[CC_SHA256_DIGEST_LENGTH];
  CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
  NSMutableString *hashedItem = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
  for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
    [hashedItem appendFormat:@"%02x", digest[i]];
  }

  return [hashedItem copy];
}

+ (NSDictionary *)dictionaryValue:(id)object
{
      
    return (NSDictionary *)[self _objectValue:object ofClass:[NSDictionary class]];
}

#pragma mark - Helper Methods

+ (id)_objectValue:(id)object ofClass:(Class)expectedClass
{
  return ([object isKindOfClass:expectedClass] ? object : nil);
}

+ (void)dictionary:(NSMutableDictionary *)dictionary setObject:(id)object forKey:(id<NSCopying>)key
{
  if (object && key) {
    dictionary[key] = object;
  }
}

+ (NSString *)matchString:(NSString *)inputString withRegex:(NSString *)pattern {
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
    if (regex) {
        NSRange range = [regex rangeOfFirstMatchInString:inputString options:0 range:NSMakeRange(0, [inputString length])];
        if (range.location != NSNotFound) {
            NSString *matchedString = [inputString substringWithRange:range];
            return matchedString;
        }
    } else {
        NSLog(@"Error creating regex: %@", [error localizedDescription]);
    }
    return @"";
}

@end
