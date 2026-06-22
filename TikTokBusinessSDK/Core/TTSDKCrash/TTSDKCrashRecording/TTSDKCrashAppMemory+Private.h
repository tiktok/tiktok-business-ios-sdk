#import <Foundation/Foundation.h>
#import "TTSDKCrashAppMemory.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Internal and for tests.
 */
@interface TTSDKCrashAppMemory ()
- (instancetype)initWithFootprint:(uint64_t)footprint
                        remaining:(uint64_t)remaining
                         pressure:(TTSDKCrashAppMemoryState)pressure NS_DESIGNATED_INITIALIZER;
@end

typedef TTSDKCrashAppMemory *_Nonnull (^TTSDKCrashAppMemoryProvider)(void);
FOUNDATION_EXPORT void __TTSDKCrashAppMemorySetProvider(TTSDKCrashAppMemoryProvider provider);

NS_ASSUME_NONNULL_END
