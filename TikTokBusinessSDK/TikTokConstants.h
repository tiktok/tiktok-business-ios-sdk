//
//  TikTokEventConstants.h
//  TikTokBusinessSDK
//
//  Created by TikTok on 2023/12/5.
//  Copyright © 2023 TikTok. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NSString * TTCurrency NS_STRING_ENUM;

FOUNDATION_EXTERN TTCurrency const TTCurrencyAED;
FOUNDATION_EXTERN TTCurrency const TTCurrencyARS;
FOUNDATION_EXTERN TTCurrency const TTCurrencyAUD;
FOUNDATION_EXTERN TTCurrency const TTCurrencyBDT;
FOUNDATION_EXTERN TTCurrency const TTCurrencyBGN;
FOUNDATION_EXTERN TTCurrency const TTCurrencyBHD;
FOUNDATION_EXTERN TTCurrency const TTCurrencyBIF;
FOUNDATION_EXTERN TTCurrency const TTCurrencyBOB;
FOUNDATION_EXTERN TTCurrency const TTCurrencyBRL;
FOUNDATION_EXTERN TTCurrency const TTCurrencyCAD;
FOUNDATION_EXTERN TTCurrency const TTCurrencyCHF;
FOUNDATION_EXTERN TTCurrency const TTCurrencyCLP;
FOUNDATION_EXTERN TTCurrency const TTCurrencyCNY;
FOUNDATION_EXTERN TTCurrency const TTCurrencyCOP;
FOUNDATION_EXTERN TTCurrency const TTCurrencyCRC;
FOUNDATION_EXTERN TTCurrency const TTCurrencyCZK;
FOUNDATION_EXTERN TTCurrency const TTCurrencyDKK;
FOUNDATION_EXTERN TTCurrency const TTCurrencyDZD;
FOUNDATION_EXTERN TTCurrency const TTCurrencyEGP;
FOUNDATION_EXTERN TTCurrency const TTCurrencyEUR;
FOUNDATION_EXTERN TTCurrency const TTCurrencyGBP;
FOUNDATION_EXTERN TTCurrency const TTCurrencyGTQ;
FOUNDATION_EXTERN TTCurrency const TTCurrencyHKD;
FOUNDATION_EXTERN TTCurrency const TTCurrencyHNL;
FOUNDATION_EXTERN TTCurrency const TTCurrencyHUF;
FOUNDATION_EXTERN TTCurrency const TTCurrencyIDR;
FOUNDATION_EXTERN TTCurrency const TTCurrencyILS;
FOUNDATION_EXTERN TTCurrency const TTCurrencyINR;
FOUNDATION_EXTERN TTCurrency const TTCurrencyIQD;
FOUNDATION_EXTERN TTCurrency const TTCurrencyISK;
FOUNDATION_EXTERN TTCurrency const TTCurrencyJOD;
FOUNDATION_EXTERN TTCurrency const TTCurrencyJPY;
FOUNDATION_EXTERN TTCurrency const TTCurrencyKES;
FOUNDATION_EXTERN TTCurrency const TTCurrencyKHR;
FOUNDATION_EXTERN TTCurrency const TTCurrencyKRW;
FOUNDATION_EXTERN TTCurrency const TTCurrencyKWD;
FOUNDATION_EXTERN TTCurrency const TTCurrencyKZT;
FOUNDATION_EXTERN TTCurrency const TTCurrencyLBP;
FOUNDATION_EXTERN TTCurrency const TTCurrencyMAD;
FOUNDATION_EXTERN TTCurrency const TTCurrencyMOP;
FOUNDATION_EXTERN TTCurrency const TTCurrencyMXN;
FOUNDATION_EXTERN TTCurrency const TTCurrencyMYR;
FOUNDATION_EXTERN TTCurrency const TTCurrencyNGN;
FOUNDATION_EXTERN TTCurrency const TTCurrencyNIO;
FOUNDATION_EXTERN TTCurrency const TTCurrencyNOK;
FOUNDATION_EXTERN TTCurrency const TTCurrencyNZD;
FOUNDATION_EXTERN TTCurrency const TTCurrencyOMR;
FOUNDATION_EXTERN TTCurrency const TTCurrencyPEN;
FOUNDATION_EXTERN TTCurrency const TTCurrencyPHP;
FOUNDATION_EXTERN TTCurrency const TTCurrencyPKR;
FOUNDATION_EXTERN TTCurrency const TTCurrencyPLN;
FOUNDATION_EXTERN TTCurrency const TTCurrencyPYG;
FOUNDATION_EXTERN TTCurrency const TTCurrencyQAR;
FOUNDATION_EXTERN TTCurrency const TTCurrencyRON;
FOUNDATION_EXTERN TTCurrency const TTCurrencyRUB;
FOUNDATION_EXTERN TTCurrency const TTCurrencySAR;
FOUNDATION_EXTERN TTCurrency const TTCurrencySEK;
FOUNDATION_EXTERN TTCurrency const TTCurrencySGD;
FOUNDATION_EXTERN TTCurrency const TTCurrencyTHB;
FOUNDATION_EXTERN TTCurrency const TTCurrencyTRY;
FOUNDATION_EXTERN TTCurrency const TTCurrencyTWD;
FOUNDATION_EXTERN TTCurrency const TTCurrencyTZS;
FOUNDATION_EXTERN TTCurrency const TTCurrencyUAH;
FOUNDATION_EXTERN TTCurrency const TTCurrencyUSD;
FOUNDATION_EXTERN TTCurrency const TTCurrencyVES;
FOUNDATION_EXTERN TTCurrency const TTCurrencyVND;
FOUNDATION_EXTERN TTCurrency const TTCurrencyZAR;

typedef NSString * TTEventName NS_STRING_ENUM;
FOUNDATION_EXTERN TTEventName const TTEventNameAchieveLevel;
FOUNDATION_EXTERN TTEventName const TTEventNameAddPaymentInfo;
FOUNDATION_EXTERN TTEventName const TTEventNameCompleteTutorial;
FOUNDATION_EXTERN TTEventName const TTEventNameCreateGroup;
FOUNDATION_EXTERN TTEventName const TTEventNameCreateRole;
FOUNDATION_EXTERN TTEventName const TTEventNameGenerateLead;
FOUNDATION_EXTERN TTEventName const TTEventNameImpressionLevelAdRevenue;
FOUNDATION_EXTERN TTEventName const TTEventNameInAppADClick;
FOUNDATION_EXTERN TTEventName const TTEventNameInAppADImpr;
FOUNDATION_EXTERN TTEventName const TTEventNameInstallApp;
FOUNDATION_EXTERN TTEventName const TTEventNameJoinGroup;
FOUNDATION_EXTERN TTEventName const TTEventNameLaunchAPP;
FOUNDATION_EXTERN TTEventName const TTEventNameLoanApplication;
FOUNDATION_EXTERN TTEventName const TTEventNameLoanApproval;
FOUNDATION_EXTERN TTEventName const TTEventNameLoanDisbursal;
FOUNDATION_EXTERN TTEventName const TTEventNameLogin;
FOUNDATION_EXTERN TTEventName const TTEventNameRate;
FOUNDATION_EXTERN TTEventName const TTEventNameRegistration;
FOUNDATION_EXTERN TTEventName const TTEventNameSearch;
FOUNDATION_EXTERN TTEventName const TTEventNameSpendCredits;
FOUNDATION_EXTERN TTEventName const TTEventNameStartTrial;
FOUNDATION_EXTERN TTEventName const TTEventNameSubscribe;
FOUNDATION_EXTERN TTEventName const TTEventNameUnlockAchievement;

FOUNDATION_EXPORT NSString * const TTAccumulatedSKANValuesKey;
FOUNDATION_EXPORT NSString * const TTLatestFineValueKey;
FOUNDATION_EXPORT NSString * const TTLatestCoarseValueKey;
FOUNDATION_EXPORT NSString * const TTSKANTimeWindowKey;

NS_ASSUME_NONNULL_BEGIN

@interface TikTokConstants : NSObject

@end

NS_ASSUME_NONNULL_END
