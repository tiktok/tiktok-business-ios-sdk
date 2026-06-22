//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import "TikTokLogger.h"

static NSString * const kLogTag = @"TikTok";

@interface TikTokLogger()

@property (nonatomic, assign) TikTokLogLevel logLevel;
@property (nonatomic, assign) BOOL logLevelLocked;

@end

#pragma mark - Public Class Interface
@implementation TikTokLogger

- (id)init
{
    self = [super init];
    if (self == nil) return nil;
    
    // default values
    _logLevel = TikTokLogLevelInfo;
    self.logLevelLocked = NO;
    
    return self;
}

- (void)setLogLevel:(TikTokLogLevel)logLevel
{
    if(self.logLevelLocked)
    {
        return;
    }
    _logLevel = logLevel; // instance log level
}

- (void)lockLogLevel
{
    self.logLevelLocked = YES;
}

- (void)verbose:(NSString *)message, ...
{
    if(self.logLevel > TikTokLogLevelVerbose) return;
    va_list parameters; va_start(parameters, message);
    [self logLevel: @"v" format: message parameters: parameters];
}

- (void)verboseMessage:(NSString *)message {
    if(self.logLevel > TikTokLogLevelVerbose) return;
    [self logMessage:message level:@"v"];
}

- (void)debug:(NSString *)message, ...
{
    if(self.logLevel > TikTokLogLevelDebug) return;
    va_list parameters; va_start(parameters, message);
    [self logLevel: @"d" format: message parameters: parameters];
}

- (void)debugMessage:(NSString *)message {
    if(self.logLevel > TikTokLogLevelDebug) return;
    [self logMessage:message level:@"d"];
}

- (void)info:(NSString *)message, ...
{
    if(self.logLevel > TikTokLogLevelInfo) return;
    va_list parameters; va_start(parameters, message);
    [self logLevel: @"i" format: message parameters: parameters];
}

- (void)infoMessage:(NSString *)message {
    if(self.logLevel > TikTokLogLevelInfo) return;
    [self logMessage:message level:@"i"];
}

- (void)warn:(NSString *)message, ...
{
    if(self.logLevel > TikTokLogLevelWarn) return;
    va_list parameters; va_start(parameters, message);
    [self logLevel: @"w" format: message parameters: parameters];
}

- (void)warnMessage:(NSString *)message {
    if(self.logLevel > TikTokLogLevelWarn) return;
    [self logMessage:message level:@"w"];
}

- (void)warnInProduction:(NSString *)message, ...
{
    if(self.logLevel > TikTokLogLevelWarn ) return;
    va_list parameters; va_start(parameters, message);
    [self logLevel: @"w" format: message parameters: parameters];
}

- (void)error:(NSString *)message, ...
{
    if(self.logLevel > TikTokLogLevelError) return;
    va_list parameters; va_start(parameters, message);
    [self logLevel: @"e" format: message parameters: parameters];
}

- (void)errorMessage:(NSString *)message {
    if(self.logLevel > TikTokLogLevelError) return;
    [self logMessage:message level:@"e"];
}

- (void)assert:(NSString *)message, ...
{
    if(self.logLevel > TikTokLogLevelAssert) return;
    va_list parameters; va_start(parameters, message);
    [self logLevel: @"a" format: message parameters: parameters];
}

- (void)assertMessage:(NSString *)message {
    if(self.logLevel > TikTokLogLevelAssert) return;
    [self logMessage:message level:@"a"];
}

- (void)logLevel: (NSString *)logLevel format: (NSString *)format parameters:(va_list)parameters
{
    NSString *string = [[NSString alloc] initWithFormat:format arguments:parameters];
    va_end(parameters);
    
    NSArray *lines = [string componentsSeparatedByString:@"\n"];
    for(NSString *line in lines)
    {
        NSLog(@"\t[%@]%@: %@", kLogTag, logLevel, line);
    }
}

- (void)logMessage:(NSString *)message level:(NSString *)logLevel {
    NSArray *lines = [message componentsSeparatedByString:@"\n"];
    for(NSString *line in lines)
    {
        NSLog(@"\t[%@]%@: %@", kLogTag, logLevel, line);
    }
}

@end
