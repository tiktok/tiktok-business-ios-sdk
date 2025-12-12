//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import "TikTokAppEvent.h"
#import "TikTokRequestHandler.h"
#import "TikTokConfig.h"
#import "TikTokBusiness.h"
#import "TikTokLogger.h"
#import "TikTokFactory.h"
#import "TikTokTypeUtility.h"
#import "TikTokIdentifyUtility.h"
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import "TikTokAppEventUtility.h"
#import "TikTokSKAdNetworkConversionConfiguration.h"
#import "TikTokBusinessSDKMacros.h"
#import "TikTokBusiness+private.h"
#import "TikTokCurrencyUtility.h"
#import "TikTokUnityBridge.h"
#import "TikTokCypher.h"
#import "TikTokBaseEventPersistence.h"

@interface TikTokRequestHandler()

@property (nonatomic, strong) TikTokLogger *logger;
@property (nonatomic, assign) NSTimeInterval configTimeoutInterval;
@property (nonatomic, assign) NSTimeInterval eventTimeoutInterval;

@end

@implementation TikTokRequestHandler

- (id)init:(TikTokConfig *)config
{
    if (self == nil) {
        return nil;
    }
    
    self.logger = [TikTokFactory getLogger];
    // Default API version
    self.apiVersion = @"v1.2";
    // Default API domain
    self.apiDomain = @"analytics.us.tiktok.com";
    self.configTimeoutInterval = 2;
    self.eventTimeoutInterval = 10;
    return self;
}



- (void)getRemoteSwitch:(TikTokConfig *)config
                isRetry:(BOOL)isRetry
  withCompletionHandler:(void (^)(BOOL isRemoteSwitchOn, NSDictionary *globalConfig))completionHandler
{
    NSDictionary *parametersDict = [self paramDictForConfig:config];
    
    NSData *paramData = [TikTokTypeUtility dataWithJSONObject:parametersDict options:NSJSONWritingPrettyPrinted error:nil origin:NSStringFromClass([self class])];
    
    TikTokCypherResultErrorCode gzipErr = TikTokCypherResultNone;
    NSData *dataToPost = [TikTokCypher gzipCompressData:paramData error:&gzipErr];
    if (!TTCheckValidData(dataToPost)) {
        if (gzipErr) {
            [self reportGzipErrorCode:gzipErr path:@"config"];
        }
        dataToPost = paramData;
    }
    
    NSString *postLength = [NSString stringWithFormat:@"%lu", [dataToPost length]];
    NSString *paramDataJSONString = [[NSString alloc] initWithData:paramData encoding:NSUTF8StringEncoding];
    [self.logger verbose:@"[TikTokRequestHandler] postDataJSON: %@", paramDataJSONString];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    
    NSString *urlPath = [NSString stringWithFormat:@"%@%@%@", @"https://", self.apiDomain == nil ? @"analytics.us.tiktok.com" : self.apiDomain, TT_CACHE_CONFIG_PATH];
    TikTokDeviceInfo *deviceInfo = [TikTokDeviceInfo deviceInfo];
    NSString *queryString = [self queryStringFromDict:@{
        @"tiktok_app_id": TTSafeString(config.tiktokAppId),
        @"sdk_version": SDK_VERSION,
        @"platform": @"ios",
        @"model": TTSafeString(deviceInfo.deviceName),
        @"app_version": TTSafeString(deviceInfo.appVersion),
        @"os_version": TTSafeString(deviceInfo.systemVersion),
        @"locale": TTSafeString(deviceInfo.localeInfo),
        @"namespace": TTSafeString(deviceInfo.appNamespace)
    }];
    
    NSString *url = TTSafeString([urlPath stringByAppendingString:queryString]);
    
    [request setURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    if (!gzipErr) {
        [request setValue:@"gzip" forHTTPHeaderField:@"Content-Encoding"];
    }
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setHTTPBody:dataToPost];
    [request setTimeoutInterval:self.configTimeoutInterval?:2];
    
    if(self.logger == nil) {
        self.logger = [TikTokFactory getLogger];
    }
    if(self.session == nil) {
        self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    }

    __block NSNumber *networkStartTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
    tt_weakify(self)
    [[self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        tt_strongify(self)
        BOOL isSwitchOn = NO;
        // handle basic connectivity issues
        if(error) {
            [self.logger error:@"[TikTokRequestHandler] error in connection: %@", error];
            // leave switch to on if error on request
            isSwitchOn = YES;
            completionHandler(isSwitchOn, nil);
            return;
        }
        NSNumber *networkEndTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
        long long duration = [networkEndTime longLongValue] - [networkStartTime longLongValue];
        id dataDictionary = [TikTokTypeUtility JSONObjectWithData:data options:0 error:nil origin:NSStringFromClass([self class])];
        // handle HTTP errors
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
            
            if (statusCode != 200) {
                [self.logger error:@"[TikTokRequestHandler] HTTP error status code: %lu", statusCode];
                // leave switch to on if error on request
                isSwitchOn = YES;
                completionHandler(isSwitchOn, nil);
                NSString *log_id = @"";
                if([dataDictionary isKindOfClass:[NSDictionary class]]) {
                    log_id = [dataDictionary objectForKey:@"request_id"];
                }
                NSDictionary *apiErrorMeta = @{
                    @"ts": networkEndTime,
                    @"latency": [NSNumber numberWithLongLong:duration],
                    @"api_type": [self urlType:url],
                    @"status_code": @(statusCode),
                    @"log_id":TTSafeString(log_id)
                };
                [self reportApiErrWithMeta:apiErrorMeta];
                [self reportNetworkReqforPath:[self urlType:url]
                                     duration:duration
                                        reqID:log_id
                                        error:[NSError errorWithDomain:@"com.TikTokBusinessSDK.error"
                                                                  code:statusCode
                                                              userInfo:@{
                    NSLocalizedDescriptionKey : @"http error",
                }]];
                if (!isRetry) {
                    [self getRemoteSwitch:config isRetry:YES withCompletionHandler:completionHandler];
                }
                return;
            }
            
        }
        
        if([dataDictionary isKindOfClass:[NSDictionary class]]) {
            NSString *log_id = @"";
            if([dataDictionary isKindOfClass:[NSDictionary class]]) {
                log_id = [dataDictionary objectForKey:@"request_id"];
            }
            NSNumber *code = [dataDictionary objectForKey:@"code"];
            // code != 0 indicates error from API call
            if([code intValue] != 0) {
                NSString *message = [dataDictionary objectForKey:@"message"];
                [self.logger error:@"[TikTokRequestHandler] code error: %@, message: %@", code, message];
                // leave switch to on if error on request
                isSwitchOn = YES;
                completionHandler(isSwitchOn, nil);
                
                
                NSDictionary *apiErrorMeta = @{
                    @"ts": networkEndTime,
                    @"latency": [NSNumber numberWithLongLong:duration],
                    @"api_type": [self urlType:url],
                    @"status_code": @([code intValue]),
                    @"log_id":TTSafeString(log_id),
                    @"message":TTSafeString(message)
                };
                [self reportApiErrWithMeta:apiErrorMeta];
                [self reportNetworkReqforPath:[self urlType:url]
                                     duration:duration
                                        reqID:log_id
                                        error:[NSError errorWithDomain:@"com.TikTokBusinessSDK.error"
                                                                  code:[code integerValue]
                                                              userInfo:@{
                    NSLocalizedDescriptionKey : TTSafeString(message),
                }]];
                if (!isRetry) {
                    [self getRemoteSwitch:config isRetry:YES withCompletionHandler:completionHandler];
                }
                return;
            }
            [self reportNetworkReqforPath:[self urlType:url]
                                 duration:duration
                                    reqID:log_id
                                    error:nil];
            
            NSDictionary *dataValue = [dataDictionary objectForKey:@"data"];
            NSDictionary *businessSDKConfig = [dataValue objectForKey:@"business_sdk_config"];
            isSwitchOn = [[businessSDKConfig objectForKey:@"enable_sdk"] boolValue];
            NSString *apiVersion = [businessSDKConfig objectForKey:@"available_version"];
            if(TTCheckValidString(apiVersion)) {
                self.apiVersion = apiVersion;
            }
            NSString *apiDomain = [businessSDKConfig objectForKey:@"domain"];
            if(TTCheckValidString(apiDomain)){
                self.apiDomain = apiDomain;
            }
            NSNumber *configTimeoutInterval = [businessSDKConfig objectForKey:@"network_timeout_config_interval"];
            if (TTCheckValidNumber(configTimeoutInterval)) {
                self.configTimeoutInterval = [configTimeoutInterval doubleValue];
            }
            NSNumber *eventTimeoutInterval = [businessSDKConfig objectForKey:@"network_timeout_event_interval"];
            if (TTCheckValidNumber(eventTimeoutInterval)) {
                self.eventTimeoutInterval = [eventTimeoutInterval doubleValue];
            }
            if (config.SKAdNetworkSupportEnabled) {
                NSDictionary *skanConfig = [dataValue objectForKey:@"skan4_event_config"];
                [[TikTokSKAdNetworkConversionConfiguration sharedInstance] configWithDict:skanConfig];
            }
            NSDictionary *currencyMap = [dataValue objectForKey:@"currency_exchange_info"];
            [[TikTokCurrencyUtility sharedInstance] configWithDict:currencyMap];
            
            if (config.isLowPerf) {
                NSMutableDictionary *tmpConfigDict = businessSDKConfig.mutableCopy;
                NSDictionary *tmpUnityConfigDict = [tmpConfigDict objectForKey:@"enhanced_data_postback_unity_config"];
                NSDictionary *tmpNativeConfigDict = [tmpConfigDict objectForKey:@"enhanced_data_postback_native_config"];
                if (TTCheckValidDictionary(tmpUnityConfigDict)) {
                    NSMutableDictionary *mcopyDict = tmpUnityConfigDict.mutableCopy;
                    [mcopyDict setObject:@(NO) forKey:@"enable_sdk"];
                    [tmpConfigDict setObject:mcopyDict.copy forKey:@"enhanced_data_postback_unity_config"];
                }
                if (TTCheckValidDictionary(tmpNativeConfigDict)) {
                    NSMutableDictionary *mcopyDict = tmpNativeConfigDict.mutableCopy;
                    [mcopyDict setObject:@(NO) forKey:@"enable_sdk"];
                    [tmpConfigDict setObject:mcopyDict.copy forKey:@"enhanced_data_postback_native_config"];
                }
                businessSDKConfig = tmpConfigDict.copy;
            }
            [TikTokUnityBridge sendConfigCallback:@{@"business_sdk_config": TTSafeDictionary(businessSDKConfig)}];
            
            completionHandler(isSwitchOn, businessSDKConfig);
            
            NSString *requestResponse = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
            
            [self.logger verbose:@"[TikTokRequestHandler] Request global config response: %@", requestResponse];
            return;
        }

        completionHandler(isSwitchOn, nil);
    }] resume];
   
}


- (void)getDebugMode:(TikTokConfig *)config
withCompletionHandler:(void (^)(BOOL remoteDebugModeEnabled, NSError *error))completionHandler
{
    NSDictionary *parametersDict = [self paramDictForConfig:config];
    
    NSData *paramData = [TikTokTypeUtility dataWithJSONObject:parametersDict options:NSJSONWritingPrettyPrinted error:nil origin:NSStringFromClass([self class])];
    
    TikTokCypherResultErrorCode gzipErr = TikTokCypherResultNone;
    NSData *dataToPost = [TikTokCypher gzipCompressData:paramData error:&gzipErr];
    if (!TTCheckValidData(dataToPost)) {
        if (gzipErr) {
            [self reportGzipErrorCode:gzipErr path:@"debugMode"];
        }
        dataToPost = paramData;
    }
    
    NSString *postLength = [NSString stringWithFormat:@"%lu", [dataToPost length]];
    NSString *paramDataJSONString = [[NSString alloc] initWithData:paramData encoding:NSUTF8StringEncoding];
    [self.logger verbose:@"[TikTokRequestHandler] postDataJSON: %@", paramDataJSONString];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    
    NSString *url = [NSString stringWithFormat:@"%@%@%@", @"https://", self.apiDomain == nil ? @"analytics.us.tiktok.com" : self.apiDomain, TT_CONFIG_PATH];
    [request setURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    if (!gzipErr) {
        [request setValue:@"gzip" forHTTPHeaderField:@"Content-Encoding"];
    }
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setHTTPBody:dataToPost];
    [request setTimeoutInterval:self.configTimeoutInterval?:2];
    
    if(self.logger == nil) {
        self.logger = [TikTokFactory getLogger];
    }
    if(self.session == nil) {
        self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    }

    tt_weakify(self)
    [[self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        tt_strongify(self)
        // handle basic connectivity issues
        if(error) {
            [self.logger error:@"[TikTokRequestHandler] error in connection: %@", error];
            completionHandler(NO, error);
            return;
        }
        id dataDictionary = [TikTokTypeUtility JSONObjectWithData:data options:0 error:nil origin:NSStringFromClass([self class])];
        // handle HTTP errors
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
            
            if (statusCode != 200) {
                [self.logger error:@"[TikTokRequestHandler] HTTP error status code: %lu", statusCode];
                completionHandler(NO, [NSError errorWithDomain:@"com.TikTokBusinessSDK.error" code:statusCode userInfo:nil]);
                return;
            }
            
        }
        
        if([dataDictionary isKindOfClass:[NSDictionary class]]) {
            NSNumber *code = [dataDictionary objectForKey:@"code"];
            // code != 0 indicates error from API call
            if([code intValue] != 0) {
                NSString *message = [dataDictionary objectForKey:@"message"];
                [self.logger error:@"[TikTokRequestHandler] code error: %@, message: %@", code, message];
                NSError *error = [NSError errorWithDomain:@"com.TikTokBusinessSDK.error" code:[code integerValue] userInfo:@{
                    NSLocalizedDescriptionKey: TTSafeString(message)
                }];
                completionHandler(NO, error);
                return;
            }
            NSDictionary *dataValue = [dataDictionary objectForKey:@"data"];
            if (TTCheckValidDictionary(dataValue)) {
                NSDictionary *businessSDKConfig = [dataValue objectForKey:@"business_sdk_config"];
                if (TTCheckValidDictionary(businessSDKConfig)) {
                    BOOL remoteDebugModeEnabled = [[businessSDKConfig objectForKey:@"enable_debug_mode"] boolValue];
                    completionHandler(remoteDebugModeEnabled, nil);
                }
            }
            
            NSString *requestResponse = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
            [self.logger verbose:@"[TikTokRequestHandler] Request debug mode config response: %@", requestResponse];
            return;
        }

        completionHandler(NO, nil);
    }] resume];
   
}


- (void)sendBatchRequest:(NSArray *)eventsToBeFlushed
              withConfig:(TikTokConfig *)config
{
    
    TikTokDeviceInfo *deviceInfo = [TikTokDeviceInfo deviceInfo];

    // APP Info
    NSDictionary *app = [self getAPPWithDeviceInfo:deviceInfo config:config];
    NSArray *ttAppIds = [self splitTTAppIDs:config.tiktokAppId];

    // Device Info
    NSDictionary *device = [self getDeviceInfo:deviceInfo withConfig:config isMonitor:NO];

    // Library Info
    NSDictionary *library = [self getLibraryWithConfig:config];
    
    // format events into object[]
    NSMutableArray *batch = [[NSMutableArray alloc] init];
    NSMutableArray *appEventsToBeFlushed = [[NSMutableArray alloc] init];
    for (TikTokAppEvent* event in eventsToBeFlushed) {
        if(![event.type isEqual:@"monitor"]){
            NSMutableDictionary *user = [NSMutableDictionary new];
            if(event.userInfo != nil) {
                [user addEntriesFromDictionary:event.userInfo];
            }
            
            NSMutableDictionary *tempAppDict = [app mutableCopy];
            [TikTokTypeUtility dictionary:tempAppDict setObject:event.anonymousID forKey:@"anonymous_id"];
            
            NSDictionary *context = @{
                @"app": tempAppDict.copy,
                @"device": device,
                @"library": library,
                @"locale": TTSafeString(deviceInfo.localeInfo),
                @"ip": TTSafeString(deviceInfo.ipInfo),
                @"user_agent": [self getUserAgentWithDeviceInfo:deviceInfo],
                @"user": user,
            };
            
            NSMutableDictionary *eventDict = @{
                @"type" : TTSafeString(event.type),
                @"event": TTSafeString(event.eventName),
                @"timestamp":TTSafeString(event.timestamp),
                @"context": context,
                @"properties": event.properties?:@{},
                @"event_id" : TTSafeString(event.eventID)
            }.mutableCopy;
            
            if ([TikTokBusiness isLDUMode]) {
                [eventDict setValue:@(YES) forKey:@"limited_data_use"];
            }
            
            if (TTCheckValidString(event.screenshot)) {
                [eventDict setObject:event.screenshot forKey:@"screenshot"];
            }
            [batch addObject:eventDict];
            [appEventsToBeFlushed addObject:event];
        }
    }
    
    if(self.logger == nil) {
        self.logger = [TikTokFactory getLogger];
    }
    
    if(batch.count > 0){
        [self.logger verbose:@"Batch count was greater than 0!"];
        // API version compatibility b/w 1.0 and 2.0
        NSDictionary *tempParametersDict = @{
            @"batch": batch,
            @"timestamp": [TikTokAppEventUtility getCurrentTimestampInISO8601],
            @"event_source": @"APP_EVENTS_SDK",
        };
        
        NSMutableDictionary *parametersDict = [[NSMutableDictionary alloc] initWithDictionary:tempParametersDict];
        
        if(config.tiktokAppId){
            // make sure the tiktokAppId is an integer value
            NSString *ttAppId = TTSafeString(ttAppIds.firstObject);
            [TikTokTypeUtility dictionary:parametersDict setObject:@([ttAppId longLongValue]) forKey:@"tiktok_app_id"];
        } else {
            [TikTokTypeUtility dictionary:parametersDict setObject:config.appId forKey:@"app_id"];
        }
        
        if ([TikTokBusiness isDebugMode]
            && !TT_isEmptyString([TikTokBusiness getTestEventCode])) {
            [TikTokTypeUtility dictionary:parametersDict setObject:[TikTokBusiness getTestEventCode] forKey:@"test_event_code"];
        }
        
        NSData *paramData = [TikTokTypeUtility dataWithJSONObject:parametersDict options:NSJSONWritingPrettyPrinted error:nil origin:NSStringFromClass([self class])];
        
        TikTokCypherResultErrorCode gzipErr = TikTokCypherResultNone;
        NSData *dataToPost = [TikTokCypher gzipCompressData:paramData error:&gzipErr];
        if (!TTCheckValidData(dataToPost)) {
            if (gzipErr) {
                [self reportGzipErrorCode:gzipErr path:@"batch"];
            }
            dataToPost = paramData;
        }
        
        NSString *postLength = [NSString stringWithFormat:@"%lu", [dataToPost length]];
        NSString *paramDataJSONString = [[NSString alloc] initWithData:paramData encoding:NSUTF8StringEncoding];
        
        NSString *token = [[TikTokBusiness getInstance] accessToken];
        NSString *signature = [TikTokCypher hmacSHA256WithSecret:token content:paramDataJSONString];
        
        [self.logger verbose:@"[TikTokRequestHandler] postDataJSON: %@", paramDataJSONString];
        
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        
        NSString *url = [NSString stringWithFormat:@"%@%@%@", @"https://", self.apiDomain == nil ? @"analytics.us.tiktok.com" : self.apiDomain, TT_BATCH_EVENT_PATH];
        [request setURL:[NSURL URLWithString:url]];
        [request setHTTPMethod:@"POST"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        if (!gzipErr) {
            [request setValue:@"gzip" forHTTPHeaderField:@"Content-Encoding"];
        }
        [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
        [request setValue:TTSafeString(signature) forHTTPHeaderField:@"X-TT-Signature"];
        [request setHTTPBody:dataToPost];
        [request setTimeoutInterval:self.eventTimeoutInterval ?: 10];
        
        if(self.session == nil) {
            self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        }
        
        __block NSNumber *networkStartTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
        tt_weakify(self)
        [[self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            tt_strongify(self)
            // handle basic connectivity issues
            if(error) {
                [self.logger error:@"[TikTokRequestHandler] error in connection: %@", error];
                [[TikTokAppEventPersistence persistence] handleSentResult:NO events:eventsToBeFlushed];
                return;
            }
            NSNumber *networkEndTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
            long long duration = [networkEndTime longLongValue] - [networkStartTime longLongValue];
            id dataDictionary = [TikTokTypeUtility JSONObjectWithData:data options:0 error:nil origin:NSStringFromClass([self class])];
            // handle HTTP errors
            if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
                if (statusCode != 200) {
                    [self.logger error:@"[TikTokRequestHandler] HTTP error status code: %lu", statusCode];
                    NSString *log_id = @"";
                    if([dataDictionary isKindOfClass:[NSDictionary class]]) {
                        log_id = [dataDictionary objectForKey:@"request_id"];
                    }
                    NSDictionary *apiErrorMeta = @{
                        @"ts": networkEndTime,
                        @"latency": [NSNumber numberWithLongLong:duration],
                        @"api_type": TTSafeString([self urlType:url]),
                        @"status_code": @(statusCode),
                        @"log_id":TTSafeString(log_id)
                    };
                    [self reportApiErrWithMeta:apiErrorMeta];
                    [self reportNetworkReqforPath:[self urlType:url]
                                         duration:duration
                                            reqID:log_id
                                            error:[NSError errorWithDomain:@"com.TikTokBusinessSDK.error"
                                                                      code:statusCode
                                                                  userInfo:@{
                        NSLocalizedDescriptionKey : @"http error",
                    }]];
                    [[TikTokAppEventPersistence persistence] handleSentResult:NO events:eventsToBeFlushed];
                    return;
                }
                
            }
            
            if([dataDictionary isKindOfClass:[NSDictionary class]]) {
                NSNumber *code = [dataDictionary objectForKey:@"code"];
                NSString *message = [dataDictionary objectForKey:@"message"];
                NSString *log_id = @"";
                if([dataDictionary isKindOfClass:[NSDictionary class]]) {
                    log_id = [dataDictionary objectForKey:@"request_id"];
                }
                
                if ([code intValue] != 0) {
                    NSDictionary *apiErrorMeta = @{
                        @"ts": networkEndTime,
                        @"latency": @(duration),
                        @"api_type": [self urlType:url],
                        @"status_code": @([code intValue]),
                        @"log_id": TTSafeString(log_id),
                        @"message": TTSafeString(message)
                    };
                    [self reportApiErrWithMeta:apiErrorMeta];
                    [self reportNetworkReqforPath:[self urlType:url]
                                         duration:duration
                                            reqID:log_id
                                            error:[NSError errorWithDomain:@"com.TikTokBusinessSDK.error"
                                                                      code:[code integerValue]
                                                                  userInfo:@{
                        NSLocalizedDescriptionKey : TTSafeString(message),
                    }]];
                }
                if ([code intValue] == 0) {
                    [self reportNetworkReqforPath:[self urlType:url]
                                         duration:duration
                                            reqID:log_id
                                            error:nil];
                    [[TikTokAppEventPersistence persistence] handleSentResult:YES events:eventsToBeFlushed];
                } else if([code intValue] == 40000) {
                    // code == 40000 indicates error from API call
                    // meaning all events have unhashed values or deprecated field is used
                    // we do not persist events in the scenario
                    [self.logger error:@"[TikTokRequestHandler] data error: %@, message: %@", code, message];
                    [[TikTokAppEventPersistence persistence] handleSentResult:YES events:eventsToBeFlushed];
                } else { // code != 0 indicates error from API call
                    [self.logger error:@"[TikTokRequestHandler] code error: %@, message: %@", code, message];
                    [[TikTokAppEventPersistence persistence] handleSentResult:NO events:eventsToBeFlushed];
                    return;
                }
                
            }
            
            NSString *requestResponse = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
            [self.logger info:@"[TikTokRequestHandler] Request response: %@", requestResponse];
        }] resume];
    }
}

- (void)sendMonitorRequest:(NSArray *)eventsToBeFlushed
              withConfig:(TikTokConfig *)config {
    TikTokDeviceInfo *deviceInfo = [TikTokDeviceInfo deviceInfo];

    // APP Info
    NSDictionary *app = [self getAPPWithDeviceInfo:deviceInfo config:config];

    // Device Info
    NSDictionary *device = [self getDeviceInfo:deviceInfo withConfig:config isMonitor:YES];

    // Library Info
    NSDictionary *library = [self getLibraryWithConfig:config];
    
    // format events into object[]
    NSMutableArray *monitorBatch = [[NSMutableArray alloc] init];
    NSMutableArray *monitorEventsToBeFlushed = [[NSMutableArray alloc] init];
    for (TikTokAppEvent* event in eventsToBeFlushed) {
        [self.logger verbose:@"Event is of type: %@", event.type];
        if([event.type isEqualToString:@"monitor"]) {
            
            NSMutableDictionary *tempAppDict = [app mutableCopy];
            NSString *appNamespace = [tempAppDict objectForKey:@"namespace"];
            [tempAppDict removeObjectForKey:@"namespace"];
            [TikTokTypeUtility dictionary:tempAppDict setObject:appNamespace forKey:@"app_namespace"];
            [TikTokTypeUtility dictionary:tempAppDict setObject:config.tiktokAppId forKey:@"tiktok_app_id"];
            [TikTokTypeUtility dictionary:tempAppDict setObject:event.anonymousID forKey:@"anonymous_id"];
            
            NSDictionary *tempMonitorDict = @{
                @"type": [event.properties objectForKey:@"monitor_type"] == nil ? @"metric" : [event.properties objectForKey:@"monitor_type"],
                @"name": [event.properties objectForKey:@"monitor_name"] == nil ? @"" : [event.properties objectForKey:@"monitor_name"],
                @"meta": [event.properties objectForKey:@"meta"] == nil ? @{} : [event.properties objectForKey:@"meta"],
                @"extra": [event.properties objectForKey:@"extra"] == nil ? @{} : [event.properties objectForKey:@"extra"],
            };
            
            NSMutableDictionary *monitorDict = @{
                @"monitor": tempMonitorDict,
                @"app": tempAppDict.copy,
                @"library": library,
                @"device": device,
                @"timestamp":TTSafeString(event.timestamp),
                @"log_extra": @{}
            }.mutableCopy;
            
            if ([TikTokBusiness isLDUMode]) {
                [monitorDict setValue:@(YES) forKey:@"limited_data_use"];
            }
            
            [monitorBatch addObject:monitorDict];
            [monitorEventsToBeFlushed addObject:event];
        }
    }
    
    if(self.logger == nil) {
        self.logger = [TikTokFactory getLogger];
    }
    
    if(monitorBatch.count > 0){
        [self.logger verbose:@"MonitorBatchCount count was greater than 0!"];
        // API version compatibility b/w 1.0 and 2.0
        NSDictionary *tempParametersDict = @{
            @"batch": monitorBatch,
            @"timestamp": [TikTokAppEventUtility getCurrentTimestampInISO8601],
            @"event_source": @"APP_EVENTS_SDK",
        };
        
        NSMutableDictionary *parametersDict = [[NSMutableDictionary alloc] initWithDictionary:tempParametersDict];
        
        if(config.tiktokAppId){
            // make sure the tiktokAppId is an integer value
            NSArray *ttAppIds = [self splitTTAppIDs:config.tiktokAppId];
            NSString *ttAppId = TTSafeString(ttAppIds.firstObject);
            [TikTokTypeUtility dictionary:parametersDict setObject:@([ttAppId longLongValue]) forKey:@"tiktok_app_id"];
        }
        
        if ([TikTokBusiness isDebugMode]
            && !TT_isEmptyString([TikTokBusiness getTestEventCode])) {
            [TikTokTypeUtility dictionary:parametersDict setObject:[TikTokBusiness getTestEventCode] forKey:@"test_event_code"];
        }
        
        NSData *paramData = [TikTokTypeUtility dataWithJSONObject:parametersDict options:NSJSONWritingPrettyPrinted error:nil origin:NSStringFromClass([self class])];
        
        TikTokCypherResultErrorCode gzipErr = TikTokCypherResultNone;
        NSData *dataToPost = [TikTokCypher gzipCompressData:paramData error:&gzipErr];
        if (!TTCheckValidData(dataToPost)) {
            if (gzipErr) {
                [self reportGzipErrorCode:gzipErr path:@"monitor"];
            }
            dataToPost = paramData;
        }
        
        NSString *postLength = [NSString stringWithFormat:@"%lu", [dataToPost length]];
        NSString *paramDataJSONString = [[NSString alloc] initWithData:paramData encoding:NSUTF8StringEncoding];

        NSString *token = [[TikTokBusiness getInstance] accessToken];
        NSString *signature = [TikTokCypher hmacSHA256WithSecret:token content:paramDataJSONString];
        

        [self.logger verbose:@"[TikTokRequestHandler] MonitorDataJSON: %@", paramDataJSONString];
        
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        
        NSString *url = [NSString stringWithFormat:@"%@%@%@", @"https://", self.apiDomain == nil ? @"analytics.us.tiktok.com" : self.apiDomain, TT_MONITOR_EVENT_PATH];
        [request setURL:[NSURL URLWithString:url]];
        [request setHTTPMethod:@"POST"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        if (!gzipErr) {
            [request setValue:@"gzip" forHTTPHeaderField:@"Content-Encoding"];
        }
        [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
        [request setValue:TTSafeString(signature) forHTTPHeaderField:@"X-TT-Signature"];
        [request setHTTPBody:dataToPost];
        [request setTimeoutInterval:self.eventTimeoutInterval ?: 10];
        
        if(self.session == nil) {
            self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        }
        tt_weakify(self)
        [[self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            tt_strongify(self)
            // handle basic connectivity issues
            if(error) {
                [self.logger error:@"[TikTokRequestHandler] error in connection: %@", error];
                [[TikTokMonitorEventPersistence persistence] handleSentResult:NO events:eventsToBeFlushed];
                return;
            }
            
            // handle HTTP errors
            if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
                if (statusCode != 200) {
                    [self.logger error:@"[TikTokRequestHandler] HTTP error status code: %lu", statusCode];
                    [[TikTokMonitorEventPersistence persistence] handleSentResult:NO events:eventsToBeFlushed];
                    return;
                }
            }
            id dataDictionary = [TikTokTypeUtility JSONObjectWithData:data options:0 error:nil origin:NSStringFromClass([self class])];
            
            if([dataDictionary isKindOfClass:[NSDictionary class]]) {
                NSNumber *code = [dataDictionary objectForKey:@"code"];
                NSString *message = [dataDictionary objectForKey:@"message"];
                
                if ([code intValue] == 0) {
                    [[TikTokMonitorEventPersistence persistence] handleSentResult:YES events:eventsToBeFlushed];
                    
                } else if([code intValue] == 40000) {
                    // code == 40000 indicates error from API call
                    // meaning all events have unhashed values or deprecated field is used
                    // we do not persist events in the scenario
                    [self.logger error:@"[TikTokRequestHandler] data error: %@, message: %@", code, message];
                    [[TikTokMonitorEventPersistence persistence] handleSentResult:YES events:eventsToBeFlushed];
                } else { // code != 0 indicates error from API call
                    [self.logger error:@"[TikTokRequestHandler] code error: %@, message: %@", code, message];
                    [[TikTokMonitorEventPersistence persistence] handleSentResult:NO events:eventsToBeFlushed];
                    return;
                }
                
            }
            
            NSString *requestResponse = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
            [self.logger verbose:@"[TikTokRequestHandler] Request response from monitor: %@", requestResponse];
        }] resume];
    }
}

- (void)fetchDeferredDeeplinkWithConfig:(TikTokConfig * _Nullable)config completion:(void (^)(NSURL * _Nullable, NSError * _Nullable))completion {
    NSAssert(NSThread.isMainThread, @"Fetch deferred deeplink failed, please invoke from main thread.");
    if (!completion) {
        return;
    }
    TikTokDeviceInfo *deviceInfo = [TikTokDeviceInfo deviceInfo];
    if (@available(iOS 14.5, *)) {
        NSString *defaultAdvertiserID = @"00000000-0000-0000-0000-000000000000";
        
        BOOL identifierMissingOrDefault = !deviceInfo.deviceIdForAdvertisers
        || [deviceInfo.deviceIdForAdvertisers isEqualToString:defaultAdvertiserID];
        
        if (identifierMissingOrDefault) {
            [self.logger warn:@"ATT tracking not authorized, deferred deeplinks may not work properly. Read more at: https://developer.apple.com/documentation/apptrackingtransparency"];
        }
    }
    
    NSDictionary *app = [self getAPPWithDeviceInfo:deviceInfo config:config];
    NSDictionary *device = [self getDeviceInfo:deviceInfo withConfig:config isMonitor:NO];
    NSDictionary *userInfo = [[TikTokIdentifyUtility sharedInstance] getUserInfoDictionary];
    NSString *ip = deviceInfo.ipInfo;
    NSString *userAgent = [self getUserAgentWithDeviceInfo:deviceInfo];
    NSString *timeStamp = [TikTokAppEventUtility getCurrentTimestampInISO8601];
    
    NSMutableDictionary *parametersDict = [NSMutableDictionary dictionary];
    NSMutableDictionary *contextDict = [NSMutableDictionary dictionary];
    [TikTokTypeUtility dictionary:contextDict setObject:app forKey:@"app"];
    [TikTokTypeUtility dictionary:contextDict setObject:device forKey:@"device"];
    [TikTokTypeUtility dictionary:contextDict setObject:userInfo forKey:@"user"];
    
    [TikTokTypeUtility dictionary:parametersDict setObject:contextDict forKey:@"context"];
    [TikTokTypeUtility dictionary:parametersDict setObject:ip forKey:@"ip"];
    [TikTokTypeUtility dictionary:parametersDict setObject:config.tiktokAppId forKey:@"tiktok_app_id"];
    [TikTokTypeUtility dictionary:parametersDict setObject:userAgent forKey:@"user_agent"];
    [TikTokTypeUtility dictionary:parametersDict setObject:timeStamp forKey:@"timestamp"];
    
    NSData *paramData = [TikTokTypeUtility dataWithJSONObject:parametersDict options:NSJSONWritingPrettyPrinted error:nil origin:NSStringFromClass([self class])];
    NSString *postLength = [NSString stringWithFormat:@"%lu", [paramData length]];
    NSString *paramDataJSONString = [[NSString alloc] initWithData:paramData encoding:NSUTF8StringEncoding];
    [self.logger verbose:@"[TikTokRequestHandler] FetchDeferredDeeplinkString: %@", paramDataJSONString];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    
    NSString *url = [NSString stringWithFormat:@"%@%@%@", @"https://", self.apiDomain == nil ? @"analytics.us.tiktok.com" : self.apiDomain, TT_FETCH_DDL_PATH];
    [request setURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setHTTPBody:paramData];
    [request setTimeoutInterval:self.configTimeoutInterval ?: 2];
    
    if(self.session == nil) {
        self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    }
    __block NSNumber *networkStartTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
    tt_weakify(self)
    [[self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        tt_strongify(self)
        // handle basic connectivity issues
        if(error) {
            [self.logger error:@"[TikTokRequestHandler] error in connection: %@", error];
            completion(nil, error);
            return;
        }
        NSNumber *networkEndTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
        long long duration = [networkEndTime longLongValue] - [networkStartTime longLongValue];
        id dataDictionary = [TikTokTypeUtility JSONObjectWithData:data options:0 error:nil origin:NSStringFromClass([self class])];
        // handle HTTP errors
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
            if (statusCode != 200) {
                [self.logger error:@"[TikTokRequestHandler] HTTP error status code: %lu", statusCode];
                NSError *error = [NSError errorWithDomain:@"com.TikTokBusinessSDK.error"
                                                     code:-2
                                                 userInfo:@{
                    NSLocalizedDescriptionKey : [NSString stringWithFormat:@"HTTP error, status code: %lu", statusCode]
                }];
                completion(nil, error);
                NSString *log_id = @"";
                if([dataDictionary isKindOfClass:[NSDictionary class]]) {
                    log_id = [dataDictionary objectForKey:@"request_id"];
                }
                NSDictionary *apiErrorMeta = @{
                    @"ts": networkEndTime,
                    @"latency": [NSNumber numberWithLongLong:duration],
                    @"api_type": [self urlType:url],
                    @"status_code": @(statusCode),
                    @"log_id":TTSafeString(log_id)
                };
                [self reportApiErrWithMeta:apiErrorMeta];
                [self reportNetworkReqforPath:[self urlType:url] duration:duration reqID:log_id error:error];
                return;
            }
        }
        if([dataDictionary isKindOfClass:[NSDictionary class]]) {
            NSNumber *code = [dataDictionary objectForKey:@"code"];
            NSString *message = [dataDictionary objectForKey:@"message"];
            NSString *log_id = @"";
            if([dataDictionary isKindOfClass:[NSDictionary class]]) {
                log_id = [dataDictionary objectForKey:@"request_id"];
            }
            if([code intValue] != 0) {
                [self.logger error:@"[TikTokRequestHandler] data error: %@, message: %@", code, message];
                NSError *error = [NSError errorWithDomain:@"com.TikTokBusinessSDK.error"
                                                     code:[code intValue]
                                                 userInfo:@{
                    NSLocalizedDescriptionKey :message
                }];
                completion(nil, error);
                NSDictionary *apiErrorMeta = @{
                    @"ts": networkEndTime,
                    @"latency": [NSNumber numberWithLongLong:[networkEndTime longLongValue] - [networkStartTime longLongValue]],
                    @"api_type": [self urlType:url],
                    @"status_code": @([code intValue]),
                    @"log_id": TTSafeString(log_id),
                    @"message": TTSafeString(message)
                };
                [self reportApiErrWithMeta:apiErrorMeta];
                [self reportNetworkReqforPath:[self urlType:url] duration:duration reqID:log_id error:error];
                return;
            } else{
                NSDictionary *data = [dataDictionary objectForKey:@"data"];
                NSString *deepLinkStr = [data objectForKey:@"ddl"];
                NSURL *deepLinkUrl = [[NSURL alloc] initWithString:TTSafeString(deepLinkStr)];
                completion(deepLinkUrl, nil);
                [self reportNetworkReqforPath:[self urlType:url] duration:duration reqID:log_id error:nil];
            }
        }
        NSString *requestResponse = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
        [self.logger verbose:@"[TikTokRequestHandler] Request response from ddl: %@", requestResponse];
    }] resume];
    
}

// MARK: - Utils

- (NSDictionary *)paramDictForConfig:(TikTokConfig *)config {
    TikTokDeviceInfo *deviceInfo = [TikTokDeviceInfo deviceInfo];
    // APP Info
    NSDictionary *app = [self getAPPWithDeviceInfo:deviceInfo config:config];
    // Device Info
    NSDictionary *device = [self getDeviceInfo:deviceInfo withConfig:config isMonitor:YES];
    // Library Info
    NSDictionary *library = [self getLibraryWithConfig:config];
    
    NSDictionary *parametersDict = @{
        @"app": app,
        @"device": device,
        @"library": library,
        @"debug":@(config.debugModeEnabled)
    };
    
    return parametersDict;
}

- (NSDictionary *)getAPPWithDeviceInfo:(TikTokDeviceInfo *)deviceInfo
                                config:(TikTokConfig *)config
{
    NSDictionary *tempApp = @{
        @"name" : TTSafeString(deviceInfo.appName),
        @"namespace": TTSafeString(deviceInfo.appNamespace),
        @"version": TTSafeString(deviceInfo.appVersion),
        @"build": TTSafeString(deviceInfo.appBuild),
        @"app_session_id":TTSafeString([[TikTokIdentifyUtility sharedInstance] app_session_id]) 
    };

    NSMutableDictionary *app = [[NSMutableDictionary alloc] initWithDictionary:tempApp];

    if (config.appId) {
        [TikTokTypeUtility dictionary:app setObject:config.appId forKey:@"id"];
    }
    if (config.tiktokAppId) {
        [TikTokTypeUtility dictionary:app setObject:config.tiktokAppId forKey:@"tiktok_app_id"];
    }
    return [app copy];
}

- (NSDictionary *)getDeviceInfo:(TikTokDeviceInfo *)deviceInfo
                     withConfig:(TikTokConfig *)config
                      isMonitor:(BOOL)isMonitor
{
    // ATT Authorization Status switch determined at flush
    // default status is NOT_APPLICABLE
    NSString *attAuthorizationStatus = @"NOT_APPLICABLE";
    if (@available(iOS 14, *)) {
        if(ATTrackingManager.trackingAuthorizationStatus == ATTrackingManagerAuthorizationStatusAuthorized) {
            attAuthorizationStatus = @"AUTHORIZED";
        } else if (ATTrackingManager.trackingAuthorizationStatus == ATTrackingManagerAuthorizationStatusDenied){
            attAuthorizationStatus = @"DENIED";
        } else if (ATTrackingManager.trackingAuthorizationStatus == ATTrackingManagerAuthorizationStatusNotDetermined){
            attAuthorizationStatus = @"NOT_DETERMINED";
        } else { // Restricted
            attAuthorizationStatus = @"RESTRICTED";
        }
    }
    
    [deviceInfo updateIdentifier];

    // API version compatibility b/w 1.0 and 2.0
    NSDictionary *tempDevice = @{
        @"att_status": attAuthorizationStatus,
        @"platform" : TTSafeString(deviceInfo.devicePlatform),
        @"idfa": TTSafeString(deviceInfo.deviceIdForAdvertisers),
        @"idfv": TTSafeString(deviceInfo.deviceVendorId),
        @"ip": TTSafeString(deviceInfo.ipInfo),
        @"user_agent": [self getUserAgentWithDeviceInfo:deviceInfo],
        @"locale": TTSafeString(deviceInfo.localeInfo),
        @"model" : TTSafeString(deviceInfo.deviceName)
    };

    NSMutableDictionary *device = [[NSMutableDictionary alloc] initWithDictionary:tempDevice];

    if(config.tiktokAppId){
        if (isMonitor) {
            [TikTokTypeUtility dictionary:device setObject:deviceInfo.systemVersion forKey:@"version"];
        } else {
            [TikTokTypeUtility dictionary:device setObject:deviceInfo.systemVersion forKey:@"os_version"];
        }
    }

    return [device copy];
}

- (NSDictionary *)getLibraryWithConfig:(TikTokConfig *)config
{
    NSString *libraryName = @"tiktok/tiktok-business-ios-sdk";
    if (NSClassFromString(@"UnityViewControllerBase") || NSClassFromString(@"UnityView")) {
        libraryName = @"tiktok/tiktok-business-unity-ios-sdk";
    }
    NSDictionary *library = @{
        @"name": libraryName,
        @"version": SDK_VERSION,
        @"smart_sdk_client_flag": @(config.autoEDPEventEnabled),
        @"auto_iap_track_config":@(config.paymentTrackingStatus)
    };

    return library;
}

- (NSDictionary *)getUser
{
    NSMutableDictionary *user = [NSMutableDictionary new];
    [TikTokTypeUtility dictionary:user setObject:[[TikTokIdentifyUtility sharedInstance] getOrGenerateAnonymousID] forKey:@"anonymous_id"];

    return [user copy];
}

- (NSString *)getUserAgentWithDeviceInfo:(TikTokDeviceInfo *)deviceInfo
{
    return ( [deviceInfo getUserAgent] != nil) ? [NSString stringWithFormat:@"%@ %@", ([deviceInfo getUserAgent]), ([deviceInfo fallbackUserAgent])]  : [deviceInfo fallbackUserAgent];
}

- (NSArray<NSString *> *)splitTTAppIDs:(NSString *)ttAppIds {
    NSMutableArray<NSString *> *resultArray = [NSMutableArray array];
    
    if (!TTCheckValidString(ttAppIds)) {
        return resultArray.copy;
    }
    
    NSString *processedString = [ttAppIds stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSArray<NSString *> *components = [processedString componentsSeparatedByString:@","];
    for (NSString *component in components) {
        if (TTCheckValidString(component)) {
            [resultArray addObject:component];
        }
    }
    return resultArray.copy;
}

- (void)reportApiErrWithMeta:(NSDictionary *)meta {
    NSDictionary *apiErrorProperties = @{
        @"monitor_type": @"metric",
        @"monitor_name": @"api_err",
        @"meta": meta
    };
    TikTokAppEvent *monitorApiErrorEvent = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:apiErrorProperties withType:@"monitor"];
    [[TikTokBusiness getEventLogger] addEvent:monitorApiErrorEvent];
}

- (void)reportNetworkReqforPath:(NSString *)path duration:(long long)duration reqID:(NSString *)reqID error:(NSError *)error {
    NSMutableDictionary *meta = @{
        @"duration": @(duration),
        @"result": @(error!=nil?1:0),
        @"path": TTSafeString(path)
    }.mutableCopy;
    if (error) {
        [meta setValue:@(error.code) forKey:@"err_code"];
        [meta setValue:TTSafeString(error.localizedDescription) forKey:@"err_msg"];
    }
    if (TTCheckValidString(reqID)) {
        [meta setValue:TTSafeString(reqID) forKey:@"req_id"];
    }
    NSDictionary *apiErrorProperties = @{
        @"monitor_type": @"metric",
        @"monitor_name": @"network_req",
        @"meta": meta
    };
    TikTokAppEvent *monitorApiErrorEvent = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:apiErrorProperties withType:@"monitor"];
    [[TikTokBusiness getEventLogger] addEvent:monitorApiErrorEvent];
}

- (void)reportGzipErrorCode:(NSInteger)code path:(NSString *)path {
    long long timestamp = [TikTokAppEventUtility getCurrentTimestamp];
    NSDictionary *meta = @{
        @"ts": @(timestamp),
        @"code": @(code),
        @"path": TTSafeString(path)
    };
    NSDictionary *gzipErrorProperties = @{
        @"monitor_type": @"metric",
        @"monitor_name": @"gzip_err",
        @"meta": meta
    };
    TikTokAppEvent *monitorGzipErrorEvent = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:gzipErrorProperties withType:@"monitor"];
    [[TikTokBusiness getEventLogger] addEvent:monitorGzipErrorEvent];
}

- (NSString *)urlType:(NSString *)url {
    NSArray<NSString *> *components = [url componentsSeparatedByString:@"/app_sdk/"];
    NSString *type = url;
    if (components.count > 1) {
        type = TTSafeString(components[1]);
    }
    return type;
}

- (NSString *)queryStringFromDict:(NSDictionary *)dict {
    if (!TTCheckValidDictionary(dict)) {
        return @"";
    }
    
    NSMutableArray *queryComponents = [NSMutableArray array];
    
    [dict enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull value, BOOL * _Nonnull stop) {
        if (![key isKindOfClass:[NSString class]]) {
            return;
        }
        NSString *keyStr = (NSString *)key;
        
        if (value == nil || value == [NSNull null]) {
            return;
        }
        
        NSString *valueStr;
        if ([value isKindOfClass:[NSString class]]) {
            valueStr = (NSString *)value;
        } else if ([value respondsToSelector:@selector(stringValue)]) {
            valueStr = [value stringValue];
        } else {
            valueStr = [NSString stringWithFormat:@"%@", value];
        }
        
        // spcial characters
        NSString *encodedKey = [keyStr stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        NSString *encodedValue = [valueStr stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        
        if (encodedKey && encodedValue) {
            [queryComponents addObject:[NSString stringWithFormat:@"%@=%@", encodedKey, encodedValue]];
        }
    }];
    
    if (queryComponents.count == 0) {
        return @"";
    }
    
    NSString *result = [NSString stringWithFormat:@"?%@", [queryComponents componentsJoinedByString:@"&"]];
    
    return TTSafeString(result);
}


@end
