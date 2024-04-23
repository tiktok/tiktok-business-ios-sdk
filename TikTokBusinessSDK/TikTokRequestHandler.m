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

#define SDK_VERSION @"0.1.20"

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
    self.apiVersion = @"v.1.1";
    // Default API domain
    self.apiDomain = @"business-api.tiktok.com";
    return self;
}



- (void)getRemoteSwitch:(TikTokConfig *)config
  withCompletionHandler:(void (^)(BOOL isRemoteSwitchOn, BOOL isGlobalConfigFetched))completionHandler
{
    NSNumber *configMonitorStartTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *url = [NSString stringWithFormat:@"%@%@%@%@%@%@", @"https://business-api.tiktok.com/open_api/business_sdk_config/get/?app_id=", config.appId, @"&sdk_version=", SDK_VERSION, @"&tiktok_app_id=", config.tiktokAppId];
    [request setURL:[NSURL URLWithString:url]];
    [request setValue:[[TikTokBusiness getInstance] accessToken] forHTTPHeaderField:@"Access-Token"];
    [request setHTTPMethod:@"GET"];
    
    if(self.logger == nil) {
        self.logger = [TikTokFactory getLogger];
    }
    if(self.session == nil) {
        self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    }
    [[self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        BOOL isSwitchOn = nil;
        BOOL isGlobalConfigFetched = NO;
        // handle basic connectivity issues
        if(error) {
            [self.logger error:@"[TikTokRequestHandler] error in connection: %@", error];
            // leave switch to on if error on request
            isSwitchOn = YES;
            completionHandler(isSwitchOn, isGlobalConfigFetched);
            return;
        }
        
        // handle HTTP errors
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
            
            if (statusCode != 200) {
                [self.logger error:@"[TikTokRequestHandler] HTTP error status code: %lu", statusCode];
                // leave switch to on if error on request
                isSwitchOn = YES;
                NSNumber *configMonitorEndTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
                NSDictionary *configMonitorEndMeta = @{
                    @"ts": configMonitorStartTime,
                    @"latency": [NSNumber numberWithInt:[configMonitorEndTime intValue] - [configMonitorStartTime intValue]],
                    @"success": [NSNumber numberWithBool:false],
                    @"log_id": @"LOL",
                };
                NSDictionary *monitorUserAgentStartProperties = @{
                    @"monitor_type": @"metric",
                    @"monitor_name": @"config_api",
                    @"meta": configMonitorEndMeta
                };
                TikTokAppEvent *configMonitorEndEvent = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:monitorUserAgentStartProperties withType:@"monitor"];
                NSMutableArray *appEventsToBeFlushed = [[NSMutableArray alloc] init];
                [appEventsToBeFlushed addObject:configMonitorEndEvent];
                @synchronized(self) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [TikTokAppEventStore persistAppEvents:appEventsToBeFlushed];
                        [[NSNotificationCenter defaultCenter] postNotificationName:@"inDiskEventQueueUpdated" object:nil];
                    });
                }
                completionHandler(isSwitchOn, isGlobalConfigFetched);
                return;
            }
            
        }
        
        id dataDictionary = [TikTokTypeUtility JSONObjectWithData:data options:0 error:nil origin:NSStringFromClass([self class])];
        if([dataDictionary isKindOfClass:[NSDictionary class]]) {
            NSNumber *code = [dataDictionary objectForKey:@"code"];
            // code != 0 indicates error from API call
            if([code intValue] != 0) {
                NSString *message = [dataDictionary objectForKey:@"message"];
                [self.logger error:@"[TikTokRequestHandler] code error: %@, message: %@", code, message];
                // leave switch to on if error on request
                isSwitchOn = YES;
                NSNumber *configMonitorEndTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
                NSDictionary *configMonitorEndMeta = @{
                    @"ts": configMonitorStartTime,
                    @"latency": [NSNumber numberWithInt:[configMonitorEndTime intValue] - [configMonitorStartTime intValue]],
                    @"success": [NSNumber numberWithBool:false],
                    @"log_id": @"LOL",
                };
                NSDictionary *monitorUserAgentStartProperties = @{
                    @"monitor_type": @"metric",
                    @"monitor_name": @"config_api",
                    @"meta": configMonitorEndMeta
                };
                TikTokAppEvent *configMonitorEndEvent = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:monitorUserAgentStartProperties withType:@"monitor"];
                NSMutableArray *appEventsToBeFlushed = [[NSMutableArray alloc] init];
                [appEventsToBeFlushed addObject:configMonitorEndEvent];
                @synchronized(self) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [TikTokAppEventStore persistAppEvents:appEventsToBeFlushed];
                        [[NSNotificationCenter defaultCenter] postNotificationName:@"inDiskEventQueueUpdated" object:nil];
                    });
                }
                completionHandler(isSwitchOn, isGlobalConfigFetched);
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
            isGlobalConfigFetched = YES;

            [[TikTokSKAdNetworkConversionConfiguration sharedInstance] initWithDict:dataValue];
            NSString *requestResponse = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
            NSNumber *configMonitorEndTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
            NSDictionary *configMonitorEndMeta = @{
                @"ts": configMonitorStartTime,
                @"latency": [NSNumber numberWithInt:[configMonitorEndTime intValue] - [configMonitorStartTime intValue]],
                @"success": [NSNumber numberWithBool:true],
                @"log_id": [dataDictionary objectForKey:@"request_id"],
            };
            NSDictionary *monitorUserAgentStartProperties = @{
                @"monitor_type": @"metric",
                @"monitor_name": @"config_api",
                @"meta": configMonitorEndMeta
            };
            TikTokAppEvent *configMonitorEndEvent = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:monitorUserAgentStartProperties withType:@"monitor"];
            NSMutableArray *appEventsToBeFlushed = [[NSMutableArray alloc] init];
            [appEventsToBeFlushed addObject:configMonitorEndEvent];
            @synchronized(self) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [TikTokAppEventStore persistAppEvents:appEventsToBeFlushed];
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"inDiskEventQueueUpdated" object:nil];
                });
            }
            [self.logger verbose:@"[TikTokRequestHandler] Request global config response: %@", requestResponse];
        }

        completionHandler(isSwitchOn, isGlobalConfigFetched);
    }] resume];
   
}

- (void)sendBatchRequest:(NSArray *)eventsToBeFlushed
              withConfig:(TikTokConfig *)config
{
    
    TikTokDeviceInfo *deviceInfo = [TikTokDeviceInfo deviceInfoWithSdkPrefix:@""];

    // APP Info
    NSDictionary *app = [TikTokRequestHandler getAPPWithDeviceInfo:deviceInfo config:config];

    // Device Info
    NSDictionary *device = [TikTokRequestHandler getDeviceInfo:deviceInfo withConfig:config];

    // Library Info
    NSDictionary *library = [TikTokRequestHandler getLibrary];
    
    // format events into object[]
    NSMutableArray *batch = [[NSMutableArray alloc] init];
    NSMutableArray *monitorBatch = [[NSMutableArray alloc] init];
    NSMutableArray *appEventsToBeFlushed = [[NSMutableArray alloc] init];
    NSMutableArray *monitorEventsToBeFlushed = [[NSMutableArray alloc] init];
    for (TikTokAppEvent* event in eventsToBeFlushed) {
        NSLog(@"Event is of type: %@", event.type);
        if(![event.type isEqual:@"monitor"]){
            NSMutableDictionary *user = [NSMutableDictionary new];
            if(event.userInfo != nil) {
                [user addEntriesFromDictionary:event.userInfo];
            }
            [user setObject:event.anonymousID forKey:@"anonymous_id"];
            
            NSDictionary *context = @{
                @"app": app,
                @"device": device,
                @"library": library,
                @"locale": deviceInfo.localeInfo,
                @"ip": deviceInfo.ipInfo,
                @"user_agent": [TikTokRequestHandler getUserAgentWithDeviceInfo:deviceInfo],
                @"user": user,
            };
            
            NSMutableDictionary *eventDict = @{
                @"type" : event.type,
                @"event": event.eventName,
                @"timestamp":event.timestamp,
                @"context": context,
                @"properties": event.properties,
            }.mutableCopy;
            
            if ([TikTokBusiness isLDUMode]) {
                [eventDict setValue:@(YES) forKey:@"limited_data_use"];
            }
            
            [batch addObject:eventDict];
            [appEventsToBeFlushed addObject:event];
        } else {
            
            NSMutableDictionary *tempAppDict = [app mutableCopy];
            NSString *appNamespace = [tempAppDict objectForKey:@"namespace"];
            [tempAppDict removeObjectForKey:@"namespace"];
            [tempAppDict setObject:appNamespace forKey:@"app_namespace"];
            
            NSDictionary *tempMonitorDict = @{
                @"type": [event.properties objectForKey:@"monitor_type"] == nil ? @"metric" : [event.properties objectForKey:@"monitor_type"],
                @"name": [event.properties objectForKey:@"monitor_name"] == nil ? @"" : [event.properties objectForKey:@"monitor_name"],
                @"meta": [event.properties objectForKey:@"meta"] == nil ? @{} : [event.properties objectForKey:@"meta"],
                @"extra": [event.properties objectForKey:@"extra"] == nil ? @{} : [event.properties objectForKey:@"extra"],
            };
            
            NSMutableDictionary *monitorDict = @{
                @"monitor": tempMonitorDict,
                @"app": tempAppDict,
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
            [parametersDict setValue:@([config.tiktokAppId integerValue]) forKey:@"tiktok_app_id"];
        } else {
            [parametersDict setValue:config.appId forKey:@"app_id"];
        }
        
        if ([TikTokBusiness isDebugMode]
            && !TT_isEmptyString([TikTokBusiness getTestEventCode])) {
            [parametersDict setValue:[TikTokBusiness getTestEventCode] forKey:@"test_event_code"];
        }
        
        NSData *postData = [TikTokTypeUtility dataWithJSONObject:parametersDict options:NSJSONWritingPrettyPrinted error:nil origin:NSStringFromClass([self class])];
        NSString *postLength = [NSString stringWithFormat:@"%lu", [postData length]];
        
        NSString *postDataJSONString = [[NSString alloc] initWithData:postData encoding:NSUTF8StringEncoding];
        [self.logger verbose:@"[TikTokRequestHandler] Access token: %@", [[TikTokBusiness getInstance] accessToken]];
        [self.logger verbose:@"[TikTokRequestHandler] postDataJSON: %@", postDataJSONString];
        
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        
        NSString *url = [NSString stringWithFormat:@"%@%@%@%@%@", @"https://", self.apiDomain == nil ? @"ads-api.tiktok.com" : self.apiDomain, @"/open_api/", self.apiVersion == nil ? @"v1.1" : self.apiVersion, @"/app/batch/"];
        [request setURL:[NSURL URLWithString:url]];
        [request setHTTPMethod:@"POST"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:[[TikTokBusiness getInstance] accessToken] forHTTPHeaderField:@"Access-Token"];
        [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
        [request setHTTPBody:postData];
        
        if(self.session == nil) {
            self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        }
        [[self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            
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
            
            // handle HTTP errors
            if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
                
                if (statusCode != 200) {
                    [self.logger error:@"[TikTokRequestHandler] HTTP error status code: %lu", statusCode];
                    @synchronized(self) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [TikTokAppEventStore persistAppEvents:appEventsToBeFlushed];
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
            [parametersDict setValue:@([config.tiktokAppId integerValue]) forKey:@"tiktok_app_id"];
        }
        
        if ([TikTokBusiness isDebugMode]
            && !TT_isEmptyString([TikTokBusiness getTestEventCode])) {
            [parametersDict setValue:[TikTokBusiness getTestEventCode] forKey:@"test_event_code"];
        }
        
        NSData *postData = [TikTokTypeUtility dataWithJSONObject:parametersDict options:NSJSONWritingPrettyPrinted error:nil origin:NSStringFromClass([self class])];
        
        NSString *postDataJSONString = [[NSString alloc] initWithData:postData encoding:NSUTF8StringEncoding];
        [self.logger verbose:@"[TikTokRequestHandler] MonitorDataJSON: %@", postDataJSONString];
        
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        
        NSString *url = [NSString stringWithFormat:@"%@%@%@%@%@", @"https://", self.apiDomain == nil ? @"business-api.tiktok.com" : self.apiDomain, @"/open_api/", self.apiVersion == nil ? @"v1.2" : self.apiVersion, @"/app/monitor/"];
        [request setURL:[NSURL URLWithString:url]];
        [request setHTTPMethod:@"POST"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:postData];
        
        if(self.session == nil) {
            self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        }
        [[self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            
            // handle basic connectivity issues
            if(error) {
                [self.logger error:@"[TikTokRequestHandler] error in connection: %@", error];
                @synchronized(self) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [TikTokAppEventStore persistAppEvents:monitorEventsToBeFlushed];
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
                            [TikTokAppEventStore persistAppEvents:monitorEventsToBeFlushed];
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
                    NSLog(@"THis is where the code reaches!!");
                    @synchronized(self) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [TikTokAppEventStore persistAppEvents:monitorEventsToBeFlushed];
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
                            [TikTokAppEventStore persistAppEvents:monitorEventsToBeFlushed];
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

- (void)sendCrashReport:(NSDictionary *)crashReport
             withConfig:(TikTokConfig *)config
  withCompletionHandler:(void (^)(void))completionHandler
{
    TikTokDeviceInfo *deviceInfo = [TikTokDeviceInfo deviceInfoWithSdkPrefix:@""];

    NSDictionary *tempApp = [TikTokRequestHandler getAPPWithDeviceInfo:deviceInfo config:config];
    NSMutableDictionary *app = [[NSMutableDictionary alloc] initWithDictionary:tempApp];
    [app setValue:deviceInfo.appNamespace forKey:@"app_namespace"];
    [app removeObjectForKey:@"namespace"];
    NSDictionary *device = [TikTokRequestHandler getDeviceInfo:deviceInfo withConfig:config];
    NSDictionary *library = [TikTokRequestHandler getLibrary];
    NSDictionary *user = [TikTokRequestHandler getUser];

    NSDictionary *context = @{
        @"app": app,
        @"device": device,
        @"library": library,
        @"user_agent":[TikTokRequestHandler getUserAgentWithDeviceInfo:deviceInfo],
        @"user": user,
        @"crash_report": crashReport,
    };

    NSMutableDictionary *parametersDict = [[NSMutableDictionary alloc] initWithDictionary:context];

    if(config.tiktokAppId){
        // make sure the tiktokAppId is an integer value
        [parametersDict setValue:@([config.tiktokAppId integerValue]) forKey:@"tiktok_app_id"];
    } else {
        [parametersDict setValue:config.appId forKey:@"app_id"];
    }

    NSData *postData = [TikTokTypeUtility dataWithJSONObject:parametersDict options:NSJSONWritingPrettyPrinted error:nil origin:NSStringFromClass([self class])];
    NSString *postLength = [NSString stringWithFormat:@"%lu", [postData length]];

    NSString *postDataJSONString = [[NSString alloc] initWithData:postData encoding:NSUTF8StringEncoding];
    [self.logger verbose:@"[TikTokRequestHandler] Access token: %@", [[TikTokBusiness getInstance] accessToken]];
    [self.logger verbose:@"[TikTokRequestHandler] postDataJSON: %@", postDataJSONString];

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];

    NSString *url = [NSString stringWithFormat:@"%@%@%@%@%@", @"https://", self.apiDomain == nil ? @"business-api.tiktok.com" : self.apiDomain, @"/open_api/", self.apiVersion == nil ? @"v1.2" : self.apiVersion, @"/app/monitor/"];
    [request setURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[[TikTokBusiness getInstance] accessToken] forHTTPHeaderField:@"Access-Token"];

    [request setValue:@"1" forHTTPHeaderField:@"x-use-ppe"];
    [request setValue:@"ppe_yuzhong" forHTTPHeaderField:@"x-tt-env"];


    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setHTTPBody:postData];

    if(self.session == nil) {
        self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    }
    [[self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        // handle basic connectivity issues
        if(error) {
            [self.logger error:@"[TikTokRequestHandler] error in connection: %@", error];
            return;
        }

        // handle HTTP errors
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];

            if (statusCode != 200) {
                [self.logger error:@"[TikTokRequestHandler] HTTP error status code: %lu", statusCode];
                return;
            }

            id dataDictionary = [TikTokTypeUtility JSONObjectWithData:data options:0 error:nil origin:NSStringFromClass([self class])];
            NSLog(@"dataDictionary: %@", dataDictionary);
            if([dataDictionary isKindOfClass:[NSDictionary class]]) {
                NSNumber *code = [dataDictionary objectForKey:@"code"];
                NSString *message = [dataDictionary objectForKey:@"message"];

                if([code intValue] == 0) {
                    completionHandler();
                } else {
                    [self.logger error:@"[TikTokRequestHandler] Response error code: %lu; message %@", statusCode, message];
                }
            }
        }
    }] resume];
}

+ (NSString *)getSDKVersion
{
    return SDK_VERSION;
}

+ (NSDictionary *)getAPPWithDeviceInfo:(TikTokDeviceInfo *)deviceInfo
                                config:(TikTokConfig *)config
{
    NSDictionary *tempApp = @{
        @"name" : deviceInfo.appName,
        @"namespace": deviceInfo.appNamespace,
        @"version": deviceInfo.appVersion,
        @"build": deviceInfo.appBuild,
    };

    NSMutableDictionary *app = [[NSMutableDictionary alloc] initWithDictionary:tempApp];

    if(config.tiktokAppId){
        [app setValue:config.appId forKey:@"id"];
    }

    return [app copy];
}

+ (NSDictionary *)getDeviceInfo:(TikTokDeviceInfo *)deviceInfo
                     withConfig:(TikTokConfig *)config
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

    // API version compatibility b/w 1.0 and 2.0
    NSDictionary *tempDevice = @{
        @"att_status": attAuthorizationStatus,
        @"platform" : deviceInfo.devicePlatform,
        @"idfa": deviceInfo.deviceIdForAdvertisers,
        @"idfv": deviceInfo.deviceVendorId,
    };

    NSMutableDictionary *device = [[NSMutableDictionary alloc] initWithDictionary:tempDevice];

    if(config.tiktokAppId){
        [device setValue:deviceInfo.systemVersion forKey:@"version"];
    }

    return [device copy];
}

+ (NSDictionary *)getLibrary
{
    NSDictionary *library = @{
        @"name": @"tiktok/tiktok-business-ios-sdk",
        @"version": SDK_VERSION
    };

    return library;
}

+ (NSDictionary *)getUser
{
    NSMutableDictionary *user = [NSMutableDictionary new];
    [user setObject:[TikTokIdentifyUtility getOrGenerateAnonymousID] forKey:@"anonymous_id"];

    return [user copy];
}

+ (NSString *)getUserAgentWithDeviceInfo:(TikTokDeviceInfo *)deviceInfo
{
    return ( [deviceInfo getUserAgent] != nil) ? [NSString stringWithFormat:@"%@ %@", ([deviceInfo getUserAgent]), ([deviceInfo fallbackUserAgent])]  : [deviceInfo fallbackUserAgent];
}

@end
