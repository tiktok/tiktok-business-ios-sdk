//
//  TTSDKJSONCodecObjC.m
//
//  Created by Karl Stenerud on 2012-01-08.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "TTSDKJSONCodecObjC.h"

#import "TTSDKDate.h"
#import "TTSDKJSONCodec.h"
#import "TTSDKNSErrorHelper.h"

@interface TTSDKJSONCodec ()

#pragma mark Properties

/** Callbacks from the C library */
@property(nonatomic, readwrite, assign) TTSDKJSONDecodeCallbacks *callbacks;

/** Stack of arrays/objects as the decoded content is built */
@property(nonatomic, readwrite, strong) NSMutableArray *containerStack;

/** Current array or object being decoded (weak ref) */
@property(nonatomic, readwrite, assign) id currentContainer;

/** Top level array or object in the decoded tree */
@property(nonatomic, readwrite, strong) id topLevelContainer;

/** Data that has been serialized into JSON form */
@property(nonatomic, readwrite, strong) NSMutableData *serializedData;

/** Any error that has occurred */
@property(nonatomic, readwrite, strong) NSError *error;

/** If true, pretty print while encoding */
@property(nonatomic, readwrite, assign) bool prettyPrint;

/** If true, sort object keys while encoding */
@property(nonatomic, readwrite, assign) bool sorted;

/** If true, don't store nulls in arrays */
@property(nonatomic, readwrite, assign) bool ignoreNullsInArrays;

/** If true, don't store nulls in objects */
@property(nonatomic, readwrite, assign) bool ignoreNullsInObjects;

#pragma mark Constructors

/** Convenience constructor.
 *
 * @param encodeOptions Optional behavior when encoding to JSON.
 *
 * @param decodeOptions Optional behavior when decoding from JSON.
 *
 * @return A new codec.
 */
+ (TTSDKJSONCodec *)codecWithEncodeOptions:(TTSDKJSONEncodeOption)encodeOptions
                          decodeOptions:(TTSDKJSONDecodeOption)decodeOptions;

/** Initializer.
 *
 * @param encodeOptions Optional behavior when encoding to JSON.
 *
 * @param decodeOptions Optional behavior when decoding from JSON.
 *
 * @return The initialized codec.
 */
- (id)initWithEncodeOptions:(TTSDKJSONEncodeOption)encodeOptions decodeOptions:(TTSDKJSONDecodeOption)decodeOptions;

@end

#pragma mark -
#pragma mark -

@implementation TTSDKJSONCodec

#pragma mark Constructors/Destructor

+ (TTSDKJSONCodec *)codecWithEncodeOptions:(TTSDKJSONEncodeOption)encodeOptions
                          decodeOptions:(TTSDKJSONDecodeOption)decodeOptions
{
    return [[self alloc] initWithEncodeOptions:encodeOptions decodeOptions:decodeOptions];
}

- (id)initWithEncodeOptions:(TTSDKJSONEncodeOption)encodeOptions decodeOptions:(TTSDKJSONDecodeOption)decodeOptions
{
    if ((self = [super init])) {
        _containerStack = [NSMutableArray array];
        _callbacks = malloc(sizeof(*self.callbacks));
        _callbacks->onBeginArray = onBeginArray;
        _callbacks->onBeginObject = onBeginObject;
        _callbacks->onBooleanElement = onBooleanElement;
        _callbacks->onEndContainer = onEndContainer;
        _callbacks->onEndData = onEndData;
        _callbacks->onFloatingPointElement = onFloatingPointElement;
        _callbacks->onIntegerElement = onIntegerElement;
        _callbacks->onUnsignedIntegerElement = onUnsignedIntegerElement;
        _callbacks->onNullElement = onNullElement;
        _callbacks->onStringElement = onStringElement;
        _prettyPrint = (encodeOptions & TTSDKJSONEncodeOptionPretty) != 0;
        _sorted = (encodeOptions & TTSDKJSONEncodeOptionSorted) != 0;
        _ignoreNullsInArrays = (decodeOptions & TTSDKJSONDecodeOptionIgnoreNullInArray) != 0;
        _ignoreNullsInObjects = (decodeOptions & TTSDKJSONDecodeOptionIgnoreNullInObject) != 0;
    }
    return self;
}

- (void)dealloc
{
    free(self.callbacks);
}

#pragma mark Utility

static inline NSString *stringFromCString(const char *const string)
{
    if (string == NULL) {
        return nil;
    }
    return [NSString stringWithCString:string encoding:NSUTF8StringEncoding];
}

#pragma mark Callbacks

static int onElement(TTSDKJSONCodec *codec, NSString *name, id element)
{
    if (codec->_currentContainer == nil) {
        codec.error = [TTSDKNSErrorHelper errorWithDomain:@"TTSDKJSONCodecObjC"
                                                  code:0
                                           description:@"Type %@ not allowed as top level container", [element class]];
        return TTSDKJSON_ERROR_INVALID_DATA;
    }

    if ([codec->_currentContainer isKindOfClass:[NSMutableDictionary class]]) {
        [(NSMutableDictionary *)codec->_currentContainer setValue:element forKey:name];
    } else {
        [(NSMutableArray *)codec->_currentContainer addObject:element];
    }
    return TTSDKJSON_OK;
}

static int onBeginContainer(TTSDKJSONCodec *codec, NSString *name, id container)
{
    if (codec->_topLevelContainer == nil) {
        codec->_topLevelContainer = container;
    } else {
        int result = onElement(codec, name, container);
        if (result != TTSDKJSON_OK) {
            return result;
        }
    }
    codec->_currentContainer = container;
    [codec->_containerStack addObject:container];
    return TTSDKJSON_OK;
}

static int onBooleanElement(const char *const cName, const bool value, void *const userData)
{
    NSString *name = stringFromCString(cName);
    id element = [NSNumber numberWithBool:value];
    TTSDKJSONCodec *codec = (__bridge TTSDKJSONCodec *)userData;
    return onElement(codec, name, element);
}

static int onFloatingPointElement(const char *const cName, const double value, void *const userData)
{
    NSString *name = stringFromCString(cName);
    id element = [NSNumber numberWithDouble:value];
    TTSDKJSONCodec *codec = (__bridge TTSDKJSONCodec *)userData;
    return onElement(codec, name, element);
}

static int onIntegerElement(const char *const cName, const int64_t value, void *const userData)
{
    NSString *name = stringFromCString(cName);
    id element = [NSNumber numberWithLongLong:value];
    TTSDKJSONCodec *codec = (__bridge TTSDKJSONCodec *)userData;
    return onElement(codec, name, element);
}

static int onUnsignedIntegerElement(const char *const cName, const uint64_t value, void *const userData)
{
    NSString *name = stringFromCString(cName);
    id element = [NSNumber numberWithUnsignedLongLong:value];
    TTSDKJSONCodec *codec = (__bridge TTSDKJSONCodec *)userData;
    return onElement(codec, name, element);
}

static int onNullElement(const char *const cName, void *const userData)
{
    NSString *name = stringFromCString(cName);
    TTSDKJSONCodec *codec = (__bridge TTSDKJSONCodec *)userData;

    if ((codec->_ignoreNullsInArrays && [codec->_currentContainer isKindOfClass:[NSArray class]]) ||
        (codec->_ignoreNullsInObjects && [codec->_currentContainer isKindOfClass:[NSDictionary class]])) {
        return TTSDKJSON_OK;
    }

    return onElement(codec, name, [NSNull null]);
}

static int onStringElement(const char *const cName, const char *const value, void *const userData)
{
    NSString *name = stringFromCString(cName);
    id element = [NSString stringWithCString:value encoding:NSUTF8StringEncoding];
    TTSDKJSONCodec *codec = (__bridge TTSDKJSONCodec *)userData;
    return onElement(codec, name, element);
}

static int onBeginObject(const char *const cName, void *const userData)
{
    NSString *name = stringFromCString(cName);
    id container = [NSMutableDictionary dictionary];
    TTSDKJSONCodec *codec = (__bridge TTSDKJSONCodec *)userData;
    return onBeginContainer(codec, name, container);
}

static int onBeginArray(const char *const cName, void *const userData)
{
    NSString *name = stringFromCString(cName);
    id container = [NSMutableArray array];
    TTSDKJSONCodec *codec = (__bridge TTSDKJSONCodec *)userData;
    return onBeginContainer(codec, name, container);
}

static int onEndContainer(void *const userData)
{
    TTSDKJSONCodec *codec = (__bridge TTSDKJSONCodec *)userData;

    if ([codec->_containerStack count] == 0) {
        codec.error = [TTSDKNSErrorHelper errorWithDomain:@"TTSDKJSONCodecObjC"
                                                  code:0
                                           description:@"Already at the top level; no container left to end"];
        return TTSDKJSON_ERROR_INVALID_DATA;
    }
    [codec->_containerStack removeLastObject];
    NSUInteger count = [codec->_containerStack count];
    if (count > 0) {
        codec->_currentContainer = [codec->_containerStack objectAtIndex:count - 1];
    } else {
        codec->_currentContainer = nil;
    }
    return TTSDKJSON_OK;
}

static int onEndData(__unused void *const userData) { return TTSDKJSON_OK; }

static int addJSONData(const char *const bytes, const int length, void *const userData)
{
    NSMutableData *data = (__bridge NSMutableData *)userData;
    [data appendBytes:bytes length:(unsigned)length];
    return TTSDKJSON_OK;
}

static int encodeObject(TTSDKJSONCodec *codec, id object, NSString *name, TTSDKJSONEncodeContext *context)
{
    int result;
    const char *cName = [name UTF8String];
    if ([object isKindOfClass:[NSString class]]) {
        NSData *data = [object dataUsingEncoding:NSUTF8StringEncoding];
        result = ttsdkjson_addStringElement(context, cName, data.bytes, (int)data.length);
        if (result == TTSDKJSON_ERROR_INVALID_CHARACTER) {
            codec.error = [TTSDKNSErrorHelper errorWithDomain:@"TTSDKJSONCodecObjC"
                                                      code:0
                                               description:@"Invalid character in %@", object];
        }
        return result;
    }

    if ([object isKindOfClass:[NSNumber class]]) {
        CFNumberType numberType = CFNumberGetType((__bridge CFNumberRef)object);
        switch (numberType) {
            case kCFNumberFloat32Type:
            case kCFNumberFloat64Type:
            case kCFNumberFloatType:
            case kCFNumberCGFloatType:
            case kCFNumberDoubleType:
                return ttsdkjson_addFloatingPointElement(context, cName, [object doubleValue]);
            case kCFNumberCharType:
                // Char could be signed or unsigned, so we need to check its value
                if ([object charValue] == 0 || [object charValue] == 1) {
                    return ttsdkjson_addBooleanElement(context, cName, [object boolValue]);
                }
                // Fall through to integer handling if it's not a boolean
            case kCFNumberSInt8Type:
            case kCFNumberSInt16Type:
            case kCFNumberSInt32Type:
            case kCFNumberSInt64Type:
            case kCFNumberShortType:
            case kCFNumberIntType:
            case kCFNumberLongType:
            case kCFNumberLongLongType:
            case kCFNumberNSIntegerType:
            case kCFNumberCFIndexType:
                // Check if the value is negative
                if ([object compare:@0] == NSOrderedAscending) {
                    return ttsdkjson_addIntegerElement(context, cName, [object longLongValue]);
                } else {
                    // Non-negative value, could be larger than LLONG_MAX
                    return ttsdkjson_addUIntegerElement(context, cName, [object unsignedLongLongValue]);
                }
            default: {
                // For any unhandled types, try unsigned first, then fall back to signed if needed
                unsigned long long unsignedValue = [object unsignedLongLongValue];
                if (unsignedValue > LLONG_MAX) {
                    return ttsdkjson_addUIntegerElement(context, cName, unsignedValue);
                } else {
                    return ttsdkjson_addIntegerElement(context, cName, [object longLongValue]);
                }
            }
        }
    }

    if ([object isKindOfClass:[NSArray class]]) {
        if ((result = ttsdkjson_beginArray(context, cName)) != TTSDKJSON_OK) {
            return result;
        }
        for (id subObject in object) {
            if ((result = encodeObject(codec, subObject, NULL, context)) != TTSDKJSON_OK) {
                return result;
            }
        }
        return ttsdkjson_endContainer(context);
    }

    if ([object isKindOfClass:[NSDictionary class]]) {
        if ((result = ttsdkjson_beginObject(context, cName)) != TTSDKJSON_OK) {
            return result;
        }
        NSArray *keys = [(NSDictionary *)object allKeys];
        if (codec->_sorted) {
            keys = [keys sortedArrayUsingSelector:@selector(compare:)];
        }
        for (id key in keys) {
            if ([key isKindOfClass:[NSString class]] == NO) {
                codec.error = [TTSDKNSErrorHelper errorWithDomain:@"TTSDKJSONCodecObjC"
                                                          code:0
                                                   description:@"Invalid key: %@", key];
                return TTSDKJSON_ERROR_INVALID_DATA;
            }
            if ((result = encodeObject(codec, [object valueForKey:key], key, context)) != TTSDKJSON_OK) {
                return result;
            }
        }
        return ttsdkjson_endContainer(context);
    }

    if ([object isKindOfClass:[NSNull class]]) {
        return ttsdkjson_addNullElement(context, cName);
    }

    if ([object isKindOfClass:[NSDate class]]) {
        char string[21];
        time_t timestamp = (time_t)((NSDate *)object).timeIntervalSince1970;
        ttsdkdate_utcStringFromTimestamp(timestamp, string);
        NSData *data = [NSData dataWithBytes:string length:strnlen(string, 20)];
        return ttsdkjson_addStringElement(context, cName, data.bytes, (int)data.length);
    }

    if ([object isKindOfClass:[NSData class]]) {
        NSData *data = (NSData *)object;
        return ttsdkjson_addDataElement(context, cName, data.bytes, (int)data.length);
    }

    codec.error = [TTSDKNSErrorHelper errorWithDomain:@"TTSDKJSONCodecObjC"
                                              code:0
                                       description:@"Could not determine type of %@", [object class]];
    return TTSDKJSON_ERROR_INVALID_DATA;
}

#pragma mark Public API

+ (NSData *)encode:(id)object options:(TTSDKJSONEncodeOption)encodeOptions error:(NSError *__autoreleasing *)error
{
    NSMutableData *data = [NSMutableData data];
    TTSDKJSONEncodeContext JSONContext;
    ttsdkjson_beginEncode(&JSONContext, encodeOptions & TTSDKJSONEncodeOptionPretty, addJSONData, (__bridge void *)data);
    TTSDKJSONCodec *codec = [self codecWithEncodeOptions:encodeOptions decodeOptions:TTSDKJSONDecodeOptionNone];

    int result = encodeObject(codec, object, NULL, &JSONContext);
    if (error != NULL) {
        *error = codec.error;
    }
    return result == TTSDKJSON_OK ? data : nil;
}

+ (id)decode:(NSData *)JSONData options:(TTSDKJSONDecodeOption)decodeOptions error:(NSError *__autoreleasing *)error
{
    TTSDKJSONCodec *codec = [self codecWithEncodeOptions:0 decodeOptions:decodeOptions];
    NSMutableData *stringData = [NSMutableData dataWithLength:10001];
    int errorOffset;
    int result = ttsdkjson_decode(JSONData.bytes, (int)JSONData.length, stringData.mutableBytes, (int)stringData.length,
                               codec.callbacks, (__bridge void *)codec, &errorOffset);
    if (result != TTSDKJSON_OK && codec.error == nil) {
        codec.error = [TTSDKNSErrorHelper errorWithDomain:@"TTSDKJSONCodecObjC"
                                                  code:0
                                           description:@"%s (offset %d)", ttsdkjson_stringForError(result), errorOffset];
    }
    if (error != NULL) {
        *error = codec.error;
    }

    if (result != TTSDKJSON_OK && !(decodeOptions & TTSDKJSONDecodeOptionKeepPartialObject)) {
        return nil;
    }
    return codec.topLevelContainer;
}

@end
