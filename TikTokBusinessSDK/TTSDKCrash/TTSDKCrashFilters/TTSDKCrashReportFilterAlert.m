//
//  TTSDKCrashReportFilterAlert.m
//
//  Created by Karl Stenerud on 2012-08-24.
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

#import "TTSDKCrashReportFilterAlert.h"

#import "TTSDKCrashReport.h"
#import "TTSDKNSErrorHelper.h"
#import "TTSDKSystemCapabilities.h"

// #define TTSDKLogger_LocalLevel TRACE
#import "TTSDKLogger.h"

#if TTSDKCRASH_HAS_ALERTVIEW

#if TTSDKCRASH_HAS_UIKIT
#import <UIKit/UIKit.h>
#endif

#if TTSDKCRASH_HAS_NSALERT
#import <AppKit/AppKit.h>
#endif

@interface TTSDKCrashAlertViewProcess : NSObject

@property(nonatomic, readwrite, copy) NSArray<id<TTSDKCrashReport>> *reports;
@property(nonatomic, readwrite, copy) TTSDKCrashReportFilterCompletion onCompletion;
@property(nonatomic, readwrite, assign) NSInteger expectedButtonIndex;

+ (TTSDKCrashAlertViewProcess *)process;

- (void)startWithTitle:(NSString *)title
               message:(NSString *)message
             yesAnswer:(NSString *)yesAnswer
              noAnswer:(NSString *)noAnswer
               reports:(NSArray<id<TTSDKCrashReport>> *)reports
          onCompletion:(TTSDKCrashReportFilterCompletion)onCompletion;

@end

@implementation TTSDKCrashAlertViewProcess

+ (TTSDKCrashAlertViewProcess *)process
{
    return [[self alloc] init];
}

- (void)startWithTitle:(NSString *)title
               message:(NSString *)message
             yesAnswer:(NSString *)yesAnswer
              noAnswer:(NSString *)noAnswer
               reports:(NSArray<id<TTSDKCrashReport>> *)reports
          onCompletion:(TTSDKCrashReportFilterCompletion)onCompletion
{
    TTSDKLOG_TRACE(@"Starting alert view process");
    _reports = [reports copy];
    _onCompletion = [onCompletion copy];
    _expectedButtonIndex = noAnswer == nil ? 0 : 1;

#if TTSDKCRASH_HAS_UIALERTCONTROLLER
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *yesAction = [UIAlertAction actionWithTitle:yesAnswer
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(__unused UIAlertAction *_Nonnull action) {
                                                          ttsdkcrash_callCompletion(self.onCompletion, self.reports, nil);
                                                      }];
    UIAlertAction *noAction = [UIAlertAction
        actionWithTitle:noAnswer
                  style:UIAlertActionStyleCancel
                handler:^(__unused UIAlertAction *_Nonnull action) {
                    ttsdkcrash_callCompletion(self.onCompletion, self.reports, [[self class] cancellationError]);
                }];
    [alertController addAction:yesAction];
    [alertController addAction:noAction];
    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    [keyWindow.rootViewController presentViewController:alertController animated:YES completion:NULL];
#elif TTSDKCRASH_HAS_NSALERT
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:yesAnswer];
    if (noAnswer != nil) {
        [alert addButtonWithTitle:noAnswer];
    }
    [alert setMessageText:title];
    [alert setInformativeText:message];
    [alert setAlertStyle:NSAlertStyleInformational];

    NSModalResponse response = [alert runModal];
    NSError *error = nil;
    if (noAnswer != nil && response == NSAlertSecondButtonReturn) {
        error = [[self class] cancellationError];
    }
    ttsdkcrash_callCompletion(self.onCompletion, self.reports, error);
#endif
}

+ (NSError *)cancellationError
{
    return [TTSDKNSErrorHelper errorWithDomain:[[self class] description] code:0 description:@"Cancelled by user"];
}

- (void)alertView:(__unused id)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    BOOL success = buttonIndex == self.expectedButtonIndex;
    ttsdkcrash_callCompletion(self.onCompletion, self.reports, success ? nil : [[self class] cancellationError]);
}

@end

@interface TTSDKCrashReportFilterAlert ()

@property(nonatomic, readwrite, copy) NSString *title;
@property(nonatomic, readwrite, copy) NSString *message;
@property(nonatomic, readwrite, copy) NSString *yesAnswer;
@property(nonatomic, readwrite, copy) NSString *noAnswer;

@end

@implementation TTSDKCrashReportFilterAlert

- (instancetype)initWithTitle:(NSString *)title
                      message:(nullable NSString *)message
                    yesAnswer:(NSString *)yesAnswer
                     noAnswer:(nullable NSString *)noAnswer;
{
    if ((self = [super init])) {
        _title = [title copy];
        _message = [message copy];
        _yesAnswer = [yesAnswer copy];
        _noAnswer = [noAnswer copy];
    }
    return self;
}

- (void)filterReports:(NSArray<id<TTSDKCrashReport>> *)reports onCompletion:(TTSDKCrashReportFilterCompletion)onCompletion
{
    dispatch_async(dispatch_get_main_queue(), ^{
        TTSDKLOG_TRACE(@"Launching new alert view process");
        __block TTSDKCrashAlertViewProcess *process = [[TTSDKCrashAlertViewProcess alloc] init];
        [process startWithTitle:self.title
                        message:self.message
                      yesAnswer:self.yesAnswer
                       noAnswer:self.noAnswer
                        reports:reports
                   onCompletion:^(NSArray *filteredReports, NSError *error) {
                       TTSDKLOG_TRACE(@"alert process complete");
                       ttsdkcrash_callCompletion(onCompletion, filteredReports, error);
                       dispatch_async(dispatch_get_main_queue(), ^{
                           process = nil;
                       });
                   }];
    });
}

@end

#else

@implementation TTSDKCrashReportFilterAlert

+ (TTSDKCrashReportFilterAlert *)filterWithTitle:(NSString *)title
                                      message:(NSString *)message
                                    yesAnswer:(NSString *)yesAnswer
                                     noAnswer:(NSString *)noAnswer
{
    return [[self alloc] initWithTitle:title message:message yesAnswer:yesAnswer noAnswer:noAnswer];
}

- (id)initWithTitle:(__unused NSString *)title
            message:(__unused NSString *)message
          yesAnswer:(__unused NSString *)yesAnswer
           noAnswer:(__unused NSString *)noAnswer
{
    if ((self = [super init])) {
        TTSDKLOG_WARN(@"Alert filter not available on this platform.");
    }
    return self;
}

- (void)filterReports:(NSArray<id<TTSDKCrashReport>> *)reports onCompletion:(TTSDKCrashReportFilterCompletion)onCompletion
{
    TTSDKLOG_WARN(@"Alert filter not available on this platform.");
    ttsdkcrash_callCompletion(onCompletion, reports, nil);
}

@end

#endif
