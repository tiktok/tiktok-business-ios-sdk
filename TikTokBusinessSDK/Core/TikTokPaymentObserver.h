//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(PaymentObserver)

/**
 * @brief This class handles observation of successful Native iOS payments
 *        The startObservingTransaction and stopObservation functions can be
 *        called to enable or disable this functionality
*/
@interface TikTokPaymentObserver : NSObject

+ (void)startObservingTransactions;
+ (void)stopObservingTransactions;

@end

NS_ASSUME_NONNULL_END
