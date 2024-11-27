#import "TTSDKCrashAppMemory.h"

#import "TTSDKCrashAppMemory+Private.h"

NS_ASSUME_NONNULL_BEGIN

@implementation TTSDKCrashAppMemory

- (instancetype)initWithFootprint:(uint64_t)footprint
                        remaining:(uint64_t)remaining
                         pressure:(TTSDKCrashAppMemoryState)pressure
{
    if (self = [super init]) {
        _footprint = footprint;
        _remaining = remaining;
        _pressure = pressure;
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:self.class]) {
        return NO;
    }
    TTSDKCrashAppMemory *comp = (TTSDKCrashAppMemory *)object;
    return comp.footprint == self.footprint && comp.remaining == self.remaining && comp.pressure == self.pressure;
}

- (uint64_t)limit
{
    return _footprint + _remaining;
}

- (TTSDKCrashAppMemoryState)level
{
    double usedRatio = (double)self.footprint / (double)self.limit;

    return usedRatio < 0.25   ? TTSDKCrashAppMemoryStateNormal
           : usedRatio < 0.50 ? TTSDKCrashAppMemoryStateWarn
           : usedRatio < 0.75 ? TTSDKCrashAppMemoryStateUrgent
           : usedRatio < 0.95 ? TTSDKCrashAppMemoryStateCritical
                              : TTSDKCrashAppMemoryStateTerminal;
}

- (BOOL)isOutOfMemory
{
    return self.level >= TTSDKCrashAppMemoryStateCritical || self.pressure >= TTSDKCrashAppMemoryStateCritical;
}

@end

const char *TTSDKCrashAppMemoryStateToString(TTSDKCrashAppMemoryState state)
{
    switch (state) {
        case TTSDKCrashAppMemoryStateNormal:
            return "normal";
        case TTSDKCrashAppMemoryStateWarn:
            return "warn";
        case TTSDKCrashAppMemoryStateUrgent:
            return "urgent";
        case TTSDKCrashAppMemoryStateCritical:
            return "critical";
        case TTSDKCrashAppMemoryStateTerminal:
            return "terminal";
    }
    assert(state <= TTSDKCrashAppMemoryStateTerminal);
}

TTSDKCrashAppMemoryState TTSDKCrashAppMemoryStateFromString(NSString *const string)
{
    if ([string isEqualToString:@"normal"]) {
        return TTSDKCrashAppMemoryStateNormal;
    }

    if ([string isEqualToString:@"warn"]) {
        return TTSDKCrashAppMemoryStateWarn;
    }

    if ([string isEqualToString:@"urgent"]) {
        return TTSDKCrashAppMemoryStateUrgent;
    }

    if ([string isEqualToString:@"critical"]) {
        return TTSDKCrashAppMemoryStateCritical;
    }

    if ([string isEqualToString:@"terminal"]) {
        return TTSDKCrashAppMemoryStateTerminal;
    }

    return TTSDKCrashAppMemoryStateNormal;
}

NSNotificationName const TTSDKCrashAppMemoryLevelChangedNotification = @"TTSDKCrashAppMemoryLevelChangedNotification";
NSNotificationName const TTSDKCrashAppMemoryPressureChangedNotification = @"TTSDKCrashAppMemoryPressureChangedNotification";
NSString *const TTSDKCrashAppMemoryNewValueKey = @"TTSDKCrashAppMemoryNewValueKey";
NSString *const TTSDKCrashAppMemoryOldValueKey = @"TTSDKCrashAppMemoryOldValueKey";

NS_ASSUME_NONNULL_END
