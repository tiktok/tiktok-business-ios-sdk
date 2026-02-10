//
//  TikTokViewUtility.m
//  TikTokBusinessSDK
//
//  Created by TikTok on 2024/2/29.
//  Copyright © 2024 TikTok. All rights reserved.
//

#import "TikTokViewUtility.h"
#import "TikTokBusinessSDKMacros.h"
#import "TikTokEDPConfig.h"
#import "TikTokTypeUtility.h"
#import "TikTokDefaults.h"
#import "TikTokDefaultsKeys.h"

NSString * const defaultPattern = @"([a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+\\.[a-zA-Z0-9._-]+)|(\\+?0?86-?)?1[3-9]\\d{9}|(\\+\\d{1,2}\\s?)?\\(?\\d{3}\\)?[\\s.-]?\\d{3}[\\s.-]?\\d{4}";

@implementation TikTokViewUtility

+ (NSInteger)maxDepthOfSubviews:(UIView *)view {
    if (view.subviews.count == 0) {
        return 1;
    }
    NSInteger maxDepth = 0;
    for (UIView *subview in view.subviews) {
        NSInteger subviewDepth = [self maxDepthOfSubviews:subview];
        if (subviewDepth > maxDepth) {
            maxDepth = subviewDepth;
        }
    }
    return maxDepth + 1;
}

+ (NSDictionary *)digView:(UIView *)view atDepth:(NSInteger)depth maxDepth:(NSInteger *)maxDepth {
    NSMutableDictionary *viewTree = [NSMutableDictionary dictionary];
    if (depth >= [TikTokEDPConfig sharedConfig].page_detail_upload_deep_count) {
        return viewTree.copy;;
    }
    [viewTree setObject:TTSafeString(NSStringFromClass(view.class)) forKey:@"class_name"];
    [viewTree setObject:@(view.frame.size.width) forKey:@"width"];
    [viewTree setObject:@(view.frame.size.height) forKey:@"height"];
    [viewTree setObject:@(view.frame.origin.y) forKey:@"top"];
    [viewTree setObject:@(view.frame.origin.x) forKey:@"left"];
    if ([view isKindOfClass:[UIScrollView class]]) {
        UIScrollView *scrollView = (UIScrollView *)view;
        [viewTree setObject:@(scrollView.contentOffset.x) forKey:@"scroll_x"];
        [viewTree setObject:@(scrollView.contentOffset.y) forKey:@"scroll_y"];
        
    }
    
    NSString *text = nil;
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *currentLabel = (UILabel *)view;
        text = TTSafeString(currentLabel.text);
    } else if ([view isKindOfClass:[UITextView class]]) {
        UITextView *currentTextView = (UITextView *)view;
        text = TTSafeString(currentTextView.text);
    }
    if (text != nil) {
        NSString *regexPattern = [TikTokViewUtility getSensigPattern];
        text = [TikTokViewUtility maskString:text withPattern:regexPattern];
        [viewTree setObject:TTSafeString(text) forKey:@"text"];
    }
    depth += 1;
    if (depth > *maxDepth) {
        *maxDepth = depth;
    }
    if (view.subviews.count == 0) {
        return viewTree.copy;
    } else {
        NSMutableArray *childViews = [NSMutableArray array];
        for (UIView *child in view.subviews) {
            [childViews addObject:[self digView:child atDepth:depth maxDepth:maxDepth]];
        }
        [viewTree setObject:childViews.copy forKey:@"child_views"];
    }
    return viewTree.copy;
}

+ (UIView *)bottommostSuperviewOfView:(UIView *)view {
    UIView *superview = view.superview;
    
    while (superview) {
        view = superview;
        superview = view.superview;
    }
    
    return view;
}

+ (NSString *)maskString:(NSString *)inputString withPattern:(NSString *)pattern {
    if (!TTCheckValidString(pattern)) {
        return inputString;
    }
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
    
    NSMutableString *mutableString = [inputString mutableCopy];
    
    
    __block NSInteger offset = 0;  // track the range offset of each replacement
    [regex enumerateMatchesInString:inputString options:0 range:NSMakeRange(0, [inputString length]) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop) {
        
        NSRange matchRange = [match range];
        NSString *matchedString = [inputString substringWithRange:matchRange];
        NSString *replacementString = [TikTokTypeUtility toSha256:matchedString origin:NSStringFromClass([self class])];
        
        matchRange.location += offset;
        // replace starting from location with offset
        [mutableString replaceCharactersInRange:matchRange withString:replacementString];
        offset += replacementString.length - matchRange.length;  // update offset
    }];
    return mutableString.copy;
}

+ (NSString *)getSensigPattern {
    NSString *regexPattern = [TikTokEDPConfig sharedConfig].sensig_filtering_regex_list.firstObject;
    NSNumber *regexVersion = [TikTokEDPConfig sharedConfig].sensig_filtering_regex_version;
    NSUserDefaults *defaults = [TikTokDefaults storage];
    NSString *resultPattern = defaultPattern;
    if (TTCheckValidString(regexPattern)) { // use the pattern from config
        NSNumber *prevRegexVersion = [defaults objectForKey:TikTokDefaultsKeySensigFilteringRegexVersion];
        if ([regexVersion doubleValue] > [prevRegexVersion doubleValue]) { // update if needed
            [defaults setObject:regexPattern forKey:TikTokDefaultsKeySensigFilteringRegexPattern];
            [defaults setObject:regexVersion forKey:TikTokDefaultsKeySensigFilteringRegexVersion];
        }
        resultPattern = regexPattern;
    } else {
        NSString *prevRegexPattern = [defaults objectForKey:TikTokDefaultsKeySensigFilteringRegexPattern];
        if (TTCheckValidString(prevRegexPattern)) { // use stored pattern if exist
            resultPattern = prevRegexPattern;
        }
    }
    return resultPattern;
}

+ (UIViewController *)getParentVCof: (UIView *)view {
    UIResponder *responder = view.nextResponder;
    while (![responder isKindOfClass:[UIViewController class]] && responder != nil) {
        responder = responder.nextResponder;
    }
    return (UIViewController *)responder;
}

@end
