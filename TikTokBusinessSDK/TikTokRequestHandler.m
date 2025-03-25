//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import "TikTokAppEvent.h"
#import "TikTokRequestHandler.h"
#import "TikTokAppEventStore.h"
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
#import "TikTokCypher.h"
#import "TikTokCypher.h"

@interface TikTokRequestHandler()

@property (nonatomic, weak) id<TikTokLogger> logger;

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
    return self;
}



- (void)getRemoteSwitch:(TikTokConfig *)config
  withCompletionHandler:(void (^)(BOOL isRemoteSwitchOn, NSDictionary *globalConfig))completionHandler
{
    NSNumber *configMonitorStartTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
    
    TikTokDeviceInfo *deviceInfo = [TikTokDeviceInfo deviceInfo];
    // APP Info
    NSDictionary *app = [self getAPPWithDeviceInfo:deviceInfo config:config];
    // Device Info
    NSDictionary *device = [self getDeviceInfo:deviceInfo withConfig:config isMonitor:YES];
    // Library Info
    NSDictionary *library = [self getLibrary];
    
    NSDictionary *parametersDict = @{
        @"app": app,
        @"device": device,
        @"library": library,
        @"debug":@(config.debugModeEnabled)
    };
    
    NSData *postData = [TikTokTypeUtility dataWithJSONObject:parametersDict options:NSJSONWritingPrettyPrinted error:nil origin:NSStringFromClass([self class])];
    
    TikTokCypherResultErrorCode gzipErr;
    NSData *compressedData = [TikTokCypher gzipCompressData:postData error:&gzipErr];
    
    NSString *postLength = [NSString stringWithFormat:@"%lu", [compressedData length]];
    NSString *postDataJSONString = [[NSString alloc] initWithData:postData encoding:NSUTF8StringEncoding];
    [self.logger verbose:@"[TikTokRequestHandler] postDataJSON: %@", postDataJSONString];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    
    NSString *url = [NSString stringWithFormat:@"%@%@%@", @"https://", self.apiDomain == nil ? @"analytics.us.tiktok.com" : self.apiDomain, TT_CONFIG_PATH];
    [request setURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"gzip" forHTTPHeaderField:@"Content-Encoding"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setHTTPBody:compressedData];
    
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
        BOOL isSwitchOn = nil;
        // handle basic connectivity issues
        if(error) {
            [self.logger error:@"[TikTokRequestHandler] error in connection: %@", error];
            // leave switch to on if error on request
            isSwitchOn = YES;
            completionHandler(isSwitchOn, nil);
            return;
        }
        NSNumber *networkEndTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
        id dataDictionary = [TikTokTypeUtility JSONObjectWithData:data options:0 error:nil origin:NSStringFromClass([self class])];
        // handle HTTP errors
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
            
            if (statusCode != 200) {
                [self.logger error:@"[TikTokRequestHandler] HTTP error status code: %lu", statusCode];
                // leave switch to on if error on request
                isSwitchOn = YES;
                completionHandler(isSwitchOn, nil);
                NSNumber *configMonitorEndTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
                NSDictionary *configMonitorEndMeta = @{
                    @"ts": configMonitorStartTime,
                    @"latency": [NSNumber numberWithLongLong:[configMonitorEndTime longLongValue] - [configMonitorStartTime longLongValue]],
                    @"success": [NSNumber numberWithBool:false]
                };
                NSDictionary *monitorUserAgentStartProperties = @{
                    @"monitor_type": @"metric",
                    @"monitor_name": @"config_api",
                    @"meta": configMonitorEndMeta
                };
                TikTokAppEvent *configMonitorEndEvent = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:monitorUserAgentStartProperties withType:@"monitor"];
                @synchronized(self) {
                    [[TikTokBusiness getQueue] addEvent:configMonitorEndEvent];
                }
                NSString *log_id = @"";
                if([dataDictionary isKindOfClass:[NSDictionary class]]) {
                    log_id = [dataDictionary objectForKey:@"request_id"];
                }
                NSDictionary *apiErrorMeta = @{
                    @"ts": networkEndTime,
                    @"latency": [NSNumber numberWithLongLong:[networkEndTime longLongValue] - [networkStartTime longLongValue]],
                    @"api_type": [self urlType:url],
                    @"status_code": @(statusCode),
                    @"log_id":log_id
                };
                [self reportApiErrWithMeta:apiErrorMeta];
                return;
            }
            
        }
        
        if([dataDictionary isKindOfClass:[NSDictionary class]]) {
            NSNumber *code = [dataDictionary objectForKey:@"code"];
            // code != 0 indicates error from API call
            if([code intValue] != 0) {
                NSString *message = [dataDictionary objectForKey:@"message"];
                [self.logger error:@"[TikTokRequestHandler] code error: %@, message: %@", code, message];
                // leave switch to on if error on request
                isSwitchOn = YES;
                completionHandler(isSwitchOn, nil);
                NSNumber *configMonitorEndTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
                NSDictionary *configMonitorEndMeta = @{
                    @"ts": configMonitorStartTime,
                    @"latency": [NSNumber numberWithLongLong:[configMonitorEndTime longLongValue] - [configMonitorStartTime longLongValue]],
                    @"success": [NSNumber numberWithBool:false]
                };
                NSDictionary *monitorUserAgentStartProperties = @{
                    @"monitor_type": @"metric",
                    @"monitor_name": @"config_api",
                    @"meta": configMonitorEndMeta
                };
                TikTokAppEvent *configMonitorEndEvent = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:monitorUserAgentStartProperties withType:@"monitor"];
                @synchronized(self) {
                    [[TikTokBusiness getQueue] addEvent:configMonitorEndEvent];
                }
                NSString *log_id = @"";
                if([dataDictionary isKindOfClass:[NSDictionary class]]) {
                    log_id = [dataDictionary objectForKey:@"request_id"];
                }
                NSDictionary *apiErrorMeta = @{
                    @"ts": networkEndTime,
                    @"latency": [NSNumber numberWithLongLong:[networkEndTime longLongValue] - [networkStartTime longLongValue]],
                    @"api_type": [self urlType:url],
                    @"status_code": @([code intValue]),
                    @"log_id":TTSafeString(log_id),
                    @"message":TTSafeString(message)
                };
                [self reportApiErrWithMeta:apiErrorMeta];
                return;
            }
            NSDictionary *dataValue = [dataDictionary objectForKey:@"data"];
            NSDictionary *businessSDKConfig = [dataValue objectForKey:@"business_sdk_config"];
            isSwitchOn = [[businessSDKConfig objectForKey:@"enable_sdk"] boolValue];
            NSString *apiVersion = [businessSDKConfig objectForKey:@"available_version"];
            NSString *apiDomain = [businessSDKConfig objectForKey:@"domain"];
            if(apiVersion != nil) {
                self.apiVersion = apiVersion;
            }
            if(apiDomain != nil){
                self.apiDomain = apiDomain;
            }
            if (config.SKAdNetworkSupportEnabled) {
                NSDictionary *skanConfig = [dataValue objectForKey:@"skan4_event_config"];
                [[TikTokSKAdNetworkConversionConfiguration sharedInstance] configWithDict:skanConfig];
            }
            NSDictionary *currencyMap = [dataValue objectForKey:@"currency_exchange_info"];
            [[TikTokCurrencyUtility sharedInstance] configWithDict:currencyMap];
            
            completionHandler(isSwitchOn, businessSDKConfig);
            
            NSString *requestResponse = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
            NSNumber *configMonitorEndTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
            NSDictionary *configMonitorEndMeta = @{
                @"ts": configMonitorStartTime,
                @"latency": [NSNumber numberWithLongLong:[configMonitorEndTime longLongValue] - [configMonitorStartTime longLongValue]],
                @"success": [NSNumber numberWithBool:true],
                @"log_id": TTSafeString([dataDictionary objectForKey:@"request_id"]),
            };
            NSDictionary *monitorUserAgentStartProperties = @{
                @"monitor_type": @"metric",
                @"monitor_name": @"config_api",
                @"meta": configMonitorEndMeta
            };
            TikTokAppEvent *configMonitorEndEvent = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:monitorUserAgentStartProperties withType:@"monitor"];
            @synchronized(self) {
                [[TikTokBusiness getQueue] addEvent:configMonitorEndEvent];
            }
            [self.logger verbose:@"[TikTokRequestHandler] Request global config response: %@", requestResponse];
            return;
        }

        completionHandler(isSwitchOn, nil);
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
    NSDictionary *library = [self getLibrary];
    
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
                @"locale": deviceInfo.localeInfo,
                @"ip": deviceInfo.ipInfo,
                @"user_agent": [self getUserAgentWithDeviceInfo:deviceInfo],
                @"user": user,
            };
            
            NSMutableDictionary *eventDict = @{
                @"type" : TTSafeString(event.type),
                @"event": TTSafeString(event.eventName),
                @"timestamp":TTSafeString(event.timestamp),
                @"context": context,
                @"properties": event.properties,
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
        NSLog(@"Batch count was greater than 0!");
        // API version compatibility b/w 1.0 and 2.0
        NSDictionary *tempParametersDict = @{
            @"batch": batch,
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
        
        NSData *postData = [TikTokTypeUtility dataWithJSONObject:parametersDict options:NSJSONWritingPrettyPrinted error:nil origin:NSStringFromClass([self class])];
        
        TikTokCypherResultErrorCode gzipErr;
        NSData *compressedData = [TikTokCypher gzipCompressData:postData error:&gzipErr];
        
        NSString *postLength = [NSString stringWithFormat:@"%lu", [compressedData length]];
        NSString *postDataJSONString = [[NSString alloc] initWithData:postData encoding:NSUTF8StringEncoding];
        
        NSString *token = [[TikTokBusiness getInstance] accessToken];
        NSString *signature = [TikTokCypher hmacSHA256WithSecret:token content:postDataJSONString];
        
        [self.logger verbose:@"[TikTokRequestHandler] postDataJSON: %@", postDataJSONString];
        
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        
        NSString *url = [NSString stringWithFormat:@"%@%@%@", @"https://", self.apiDomain == nil ? @"analytics.us.tiktok.com" : self.apiDomain, TT_BATCH_EVENT_PATH];
        [request setURL:[NSURL URLWithString:url]];
        [request setHTTPMethod:@"POST"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:@"gzip" forHTTPHeaderField:@"Content-Encoding"];
        [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
        [request setValue:TTSafeString(signature) forHTTPHeaderField:@"X-TT-Signature"];
        [request setHTTPBody:compressedData];
        
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
                @synchronized(self) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [TikTokAppEventStore persistAppEvents:appEventsToBeFlushed];
                        [[NSNotificationCenter defaultCenter] postNotificationName:@"inDiskEventQueueUpdated" object:nil];
                    });
                }
                return;
            }
            NSNumber *networkEndTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
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
                        @"latency": [NSNumber numberWithLongLong:[networkEndTime longLongValue] - [networkStartTime longLongValue]],
                        @"api_type": [self urlType:url],
                        @"status_code": @(statusCode),
                        @"log_id":TTSafeString(log_id)
                    };
                    [self reportApiErrWithMeta:apiErrorMeta];
                    @synchronized(self) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [TikTokAppEventStore persistAppEvents:appEventsToBeFlushed];
                            [[NSNotificationCenter defaultCenter] postNotificationName:@"inDiskEventQueueUpdated" object:nil];
                        });
                    }
                    return;
                }
                
            }
            
            if([dataDictionary isKindOfClass:[NSDictionary class]]) {
                NSNumber *code = [dataDictionary objectForKey:@"code"];
                NSString *message = [dataDictionary objectForKey:@"message"];
                
                if ([code intValue] != 0) {
                    NSString *log_id = @"";
                    if([dataDictionary isKindOfClass:[NSDictionary class]]) {
                        log_id = [dataDictionary objectForKey:@"request_id"];
                    }
                    NSDictionary *apiErrorMeta = @{
                        @"ts": networkEndTime,
                        @"latency": [NSNumber numberWithLongLong:[networkEndTime longLongValue] - [networkStartTime longLongValue]],
                        @"api_type": [self urlType:url],
                        @"status_code": @([code intValue]),
                        @"log_id": TTSafeString(log_id),
                        @"message": TTSafeString(message)
                    };
                    [self reportApiErrWithMeta:apiErrorMeta];
                }
                // code == 40000 indicates error from API call
                // meaning all events have unhashed values or deprecated field is used
                // we do not persist events in the scenario
                if([code intValue] == 40000) {
                    [self.logger error:@"[TikTokRequestHandler] data error: %@, message: %@", code, message];
                
                // code == 20001 indicates partial error from API call
                // meaning some events have unhashed values
                } else if([code intValue] == 20001) {
                    [self.logger error:@"[TikTokRequestHandler] partial error: %@, message: %@", code, message];
                    NSDictionary *data = [dataDictionary objectForKey:@"data"];
                    NSArray *failedEventsFromResponse = [data objectForKey:@"failed_events"];
                    NSMutableIndexSet *failedIndicesSet = [[NSMutableIndexSet alloc] init];
                    for(NSDictionary* event in failedEventsFromResponse) {
                        if([event objectForKey:@"order_in_batch"] != nil) {
                            [failedIndicesSet addIndex:[[event objectForKey:@"order_in_batch"] intValue]];
                        }
                    }
                    for(int i = 0; i < [appEventsToBeFlushed count]; i++) {
                        if([failedIndicesSet containsIndex:i]) {
                            [self.logger error:@"[TikTokRequestHandler] event with error was not processed: %@", [[appEventsToBeFlushed objectAtIndex:i] eventName]];
                        }
                    }
                    [self.logger error:@"[TikTokRequestHandler] partial error data: %@", data];
                } else if([code intValue] != 0) { // code != 0 indicates error from API call
                    [self.logger error:@"[TikTokRequestHandler] code error: %@, message: %@", code, message];
                    @synchronized(self) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [TikTokAppEventStore persistAppEvents:appEventsToBeFlushed];
                            [[NSNotificationCenter defaultCenter] postNotificationName:@"inDiskEventQueueUpdated" object:nil];
                        });
                    }
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
    NSDictionary *library = [self getLibrary];
    
    // format events into object[]
    NSMutableArray *monitorBatch = [[NSMutableArray alloc] init];
    NSMutableArray *monitorEventsToBeFlushed = [[NSMutableArray alloc] init];
    for (TikTokAppEvent* event in eventsToBeFlushed) {
        NSLog(@"Event is of type: %@", event.type);
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
        NSLog(@"MonitorBatchCount count was greater than 0!");
        // API version compatibility b/w 1.0 and 2.0
        NSDictionary *tempParametersDict = @{
            @"batch": monitorBatch,
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
        
        NSData *postData = [TikTokTypeUtility dataWithJSONObject:parametersDict options:NSJSONWritingPrettyPrinted error:nil origin:NSStringFromClass([self class])];
        
        TikTokCypherResultErrorCode gzipErr;
        NSData *compressedData = [TikTokCypher gzipCompressData:postData error:&gzipErr];
        
        NSString *postLength = [NSString stringWithFormat:@"%lu", [compressedData length]];
        NSString *postDataJSONString = [[NSString alloc] initWithData:postData encoding:NSUTF8StringEncoding];
        
        NSString *token = [[TikTokBusiness getInstance] accessToken];
        NSString *signature = [TikTokCypher hmacSHA256WithSecret:token content:postDataJSONString];
        
        [self.logger verbose:@"[TikTokRequestHandler] MonitorDataJSON: %@", postDataJSONString];
        
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        
        NSString *url = [NSString stringWithFormat:@"%@%@%@", @"https://", self.apiDomain == nil ? @"analytics.us.tiktok.com" : self.apiDomain, TT_MONITOR_EVENT_PATH];
        [request setURL:[NSURL URLWithString:url]];
        [request setHTTPMethod:@"POST"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:@"gzip" forHTTPHeaderField:@"Content-Encoding"];
        [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
        [request setValue:TTSafeString(signature) forHTTPHeaderField:@"X-TT-Signature"];
        [request setHTTPBody:compressedData];
        
        if(self.session == nil) {
            self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        }
        tt_weakify(self)
        [[self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            tt_strongify(self)
            // handle basic connectivity issues
            if(error) {
                [self.logger error:@"[TikTokRequestHandler] error in connection: %@", error];
                @synchronized(self) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [TikTokAppEventStore persistMonitorEvents:monitorEventsToBeFlushed];
                        [[NSNotificationCenter defaultCenter] postNotificationName:@"inDiskEventQueueUpdated" object:nil];
                    });
                }
                return;
            }
            
            // handle HTTP errors
            if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
                
                if (statusCode != 200) {
                    [self.logger error:@"[TikTokRequestHandler] HTTP error status code: %lu", statusCode];
                    @synchronized(self) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [TikTokAppEventStore persistMonitorEvents:monitorEventsToBeFlushed];
                            [[NSNotificationCenter defaultCenter] postNotificationName:@"inDiskEventQueueUpdated" object:nil];
                        });
                    }
                    return;
                }
                
            }
            
            id dataDictionary = [TikTokTypeUtility JSONObjectWithData:data options:0 error:nil origin:NSStringFromClass([self class])];
            
            if([dataDictionary isKindOfClass:[NSDictionary class]]) {
                NSNumber *code = [dataDictionary objectForKey:@"code"];
                NSString *message = [dataDictionary objectForKey:@"message"];
                
                // code == 40000 indicates error from API call
                // meaning all events have unhashed values or deprecated field is used
                // we do not persist events in the scenario
                if([code intValue] == 40000) {
                    [self.logger error:@"[TikTokRequestHandler] data error: %@, message: %@", code, message];
                    @synchronized(self) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [TikTokAppEventStore persistMonitorEvents:monitorEventsToBeFlushed];
                            [[NSNotificationCenter defaultCenter] postNotificationName:@"inDiskEventQueueUpdated" object:nil];
                        });
                    }
                // code == 20001 indicates partial error from API call
                // meaning some events have unhashed values
                } else if([code intValue] == 20001) {
                    [self.logger error:@"[TikTokRequestHandler] partial error: %@, message: %@", code, message];
                    NSDictionary *data = [dataDictionary objectForKey:@"data"];
                    NSArray *failedEventsFromResponse = [data objectForKey:@"failed_events"];
                    NSMutableIndexSet *failedIndicesSet = [[NSMutableIndexSet alloc] init];
                    for(NSDictionary* event in failedEventsFromResponse) {
                        if([event objectForKey:@"order_in_batch"] != nil) {
                            [failedIndicesSet addIndex:[[event objectForKey:@"order_in_batch"] intValue]];
                        }
                    }
                    for(int i = 0; i < [monitorEventsToBeFlushed count]; i++) {
                        if([failedIndicesSet containsIndex:i]) {
                            [self.logger error:@"[TikTokRequestHandler] event with error was not processed: %@", [[monitorEventsToBeFlushed objectAtIndex:i] eventName]];
                        }
                    }
                    [self.logger error:@"[TikTokRequestHandler] partial error data: %@", data];
                } else if([code intValue] != 0) { // code != 0 indicates error from API call
                    [self.logger error:@"[TikTokRequestHandler] code error: %@, message: %@", code, message];
                    @synchronized(self) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [TikTokAppEventStore persistMonitorEvents:monitorEventsToBeFlushed];
                            [[NSNotificationCenter defaultCenter] postNotificationName:@"inDiskEventQueueUpdated" object:nil];
                        });
                    }
                    return;
                }
                
            }
            
            NSString *requestResponse = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
            [self.logger info:@"[TikTokRequestHandler] Request response from monitor: %@", requestResponse];
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
            NSError *error = [NSError errorWithDomain:@"com.TikTokBusinessSDK.error"
                                                 code:-3
                                             userInfo:@{
                NSLocalizedDescriptionKey : @"ATTrackingManager.AuthorizationStatus must be `authorized` to fetch deferred deep link. Read more at: https://developer.apple.com/documentation/apptrackingtransparency"
            }];
            completion(nil, error);
            return;
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
    
    NSData *postData = [TikTokTypeUtility dataWithJSONObject:parametersDict options:NSJSONWritingPrettyPrinted error:nil origin:NSStringFromClass([self class])];
    
    NSString *postDataJSONString = [[NSString alloc] initWithData:postData encoding:NSUTF8StringEncoding];
    [self.logger verbose:@"[TikTokRequestHandler] FetchDeferredDeeplinkString: %@", postDataJSONString];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    
    NSString *url = [NSString stringWithFormat:@"%@%@%@", @"https://", self.apiDomain == nil ? @"analytics.us.tiktok.com" : self.apiDomain, TT_FETCH_DDL_PATH];
    [request setURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postData];
    
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
                    @"latency": [NSNumber numberWithLongLong:[networkEndTime longLongValue] - [networkStartTime longLongValue]],
                    @"api_type": [self urlType:url],
                    @"status_code": @(statusCode),
                    @"log_id":TTSafeString(log_id)
                };
                [self reportApiErrWithMeta:apiErrorMeta];
                return;
            }
        }
        if([dataDictionary isKindOfClass:[NSDictionary class]]) {
            NSNumber *code = [dataDictionary objectForKey:@"code"];
            NSString *message = [dataDictionary objectForKey:@"message"];
            if([code intValue] != 0) {
                [self.logger error:@"[TikTokRequestHandler] data error: %@, message: %@", code, message];
                NSError *error = [NSError errorWithDomain:@"com.TikTokBusinessSDK.error"
                                                     code:[code intValue]
                                                 userInfo:@{
                    NSLocalizedDescriptionKey :message
                }];
                completion(nil, error);
                NSString *log_id = @"";
                if([dataDictionary isKindOfClass:[NSDictionary class]]) {
                    log_id = [dataDictionary objectForKey:@"request_id"];
                }
                NSDictionary *apiErrorMeta = @{
                    @"ts": networkEndTime,
                    @"latency": [NSNumber numberWithLongLong:[networkEndTime longLongValue] - [networkStartTime longLongValue]],
                    @"api_type": [self urlType:url],
                    @"status_code": @([code intValue]),
                    @"log_id": TTSafeString(log_id),
                    @"message": TTSafeString(message)
                };
                [self reportApiErrWithMeta:apiErrorMeta];
                return;
            } else{
                NSDictionary *data = [dataDictionary objectForKey:@"data"];
                NSString *deepLinkStr = [data objectForKey:@"ddl"];
                NSURL *deepLinkUrl = [[NSURL alloc] initWithString:TTSafeString(deepLinkStr)];
                completion(deepLinkUrl, nil);
            }
        }
        NSString *requestResponse = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
        [self.logger info:@"[TikTokRequestHandler] Request response from ddl: %@", requestResponse];
    }] resume];
    
}

- (NSDictionary *)getAPPWithDeviceInfo:(TikTokDeviceInfo *)deviceInfo
                                config:(TikTokConfig *)config
{
    NSDictionary *tempApp = @{
        @"name" : deviceInfo.appName,
        @"namespace": deviceInfo.appNamespace,
        @"version": deviceInfo.appVersion,
        @"build": deviceInfo.appBuild,
        @"app_session_id": [[TikTokIdentifyUtility sharedInstance] app_session_id]
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
        @"att_status": TTSafeString(attAuthorizationStatus),
        @"platform" : TTSafeString(deviceInfo.devicePlatform),
        @"idfa": TTSafeString(deviceInfo.deviceIdForAdvertisers),
        @"idfv": TTSafeString(deviceInfo.deviceVendorId),
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

- (NSDictionary *)getLibrary
{
    NSString *libraryName = @"tiktok/tiktok-business-ios-sdk";
    if (NSClassFromString(@"UnityViewControllerBase") || NSClassFromString(@"UnityView")) {
        libraryName = @"tiktok/tiktok-business-unity-ios-sdk";
    }
    NSDictionary *library = @{
        @"name": libraryName,
        @"version": SDK_VERSION
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
    [[TikTokBusiness getQueue] addEvent:monitorApiErrorEvent];
}

- (NSString *)urlType:(NSString *)url {
    NSArray<NSString *> *components = [url componentsSeparatedByString:@"/app_sdk/"];
    NSString *type = url;
    if (components.count > 1) {
        type = TTSafeString(components[1]);
    }
    return type;
}


@end
