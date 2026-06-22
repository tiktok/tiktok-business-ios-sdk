//
//  TTSDKCrashAppMemoryTracker.h
//
//  Created by Alexander Cohen on 2024-05-20.
//
//  Copyright (c) 2024 Alexander Cohen. All rights reserved.
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
#import <Foundation/Foundation.h>

#import "TTSDKCrashAppMemory.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, TTSDKCrashAppMemoryTrackerChangeType) {
    TTSDKCrashAppMemoryTrackerChangeTypeNone = 0,
    TTSDKCrashAppMemoryTrackerChangeTypeLevel = 1 << 0,
    TTSDKCrashAppMemoryTrackerChangeTypePressure = 1 << 1,
    TTSDKCrashAppMemoryTrackerChangeTypeFootprint = 1 << 2,
} NS_SWIFT_NAME(AppMemoryTrackerChangeType);

@protocol TTSDKCrashAppMemoryTrackerDelegate;

NS_SWIFT_NAME(AppMemoryTracker)
@interface TTSDKCrashAppMemoryTracker : NSObject

@property(atomic, readonly) TTSDKCrashAppMemoryState pressure;
@property(atomic, readonly) TTSDKCrashAppMemoryState level;

@property(nonatomic, weak) id<TTSDKCrashAppMemoryTrackerDelegate> delegate;

@property(nonatomic, readonly, nullable) TTSDKCrashAppMemory *currentAppMemory;

- (void)start;
- (void)stop;

@end

NS_SWIFT_NAME(AppMemoryTrackerDelegate)
@protocol TTSDKCrashAppMemoryTrackerDelegate <NSObject>

- (void)appMemoryTracker:(TTSDKCrashAppMemoryTracker *)tracker
                  memory:(TTSDKCrashAppMemory *)memory
                 changed:(TTSDKCrashAppMemoryTrackerChangeType)changes;

@end

NS_ASSUME_NONNULL_END
