//
//  TTSDKCrashReportFilterAppleFmt.m
//
//  Created by Karl Stenerud on 2012-02-24.
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

#import "TTSDKCrashReportFilterAppleFmt.h"
#import "TTSDKCrashReport.h"
#import "TTSDKSystemCapabilities.h"

#import <inttypes.h>
#include <mach-o/arch.h>
#import <mach/machine.h>

#import "TTSDKCPU.h"
#import "TTSDKCrashReportFields.h"
#import "TTSDKJSONCodecObjC.h"

// #define TTSDKLogger_LocalLevel TRACE
#import "TTSDKLogger.h"

#if defined(__LP64__)
#define FMT_LONG_DIGITS "16"
#define FMT_RJ_SPACES "18"
#else
#define FMT_LONG_DIGITS "8"
#define FMT_RJ_SPACES "10"
#endif

#define FMT_PTR_SHORT @"0x%" PRIxPTR
#define FMT_PTR_LONG @"0x%0" FMT_LONG_DIGITS PRIxPTR
// #define FMT_PTR_RJ           @"%#" FMT_RJ_SPACES PRIxPTR
#define FMT_PTR_RJ @"%#" PRIxPTR
#define FMT_OFFSET @"%" PRIuPTR
#define FMT_TRACE_PREAMBLE @"%-4d%-30s\t" FMT_PTR_LONG
#define FMT_TRACE_UNSYMBOLICATED FMT_PTR_SHORT @" + " FMT_OFFSET
#define FMT_TRACE_SYMBOLICATED @"%@ + " FMT_OFFSET

#define kAppleRedactedText @"<redacted>"

#define kExpectedMajorVersion 3

@interface TTSDKCrashReportFilterAppleFmt ()

@property(nonatomic, readwrite, assign) TTSDKAppleReportStyle reportStyle;

/** Convert a crash report to Apple format.
 *
 * @param JSONReport The crash report.
 *
 * @return The converted crash report.
 */
- (NSString *)toAppleFormat:(NSDictionary *)JSONReport;

/** Determine the major CPU type.
 *
 * @param CPUArch The CPU architecture name.
 *
 * @param isSystemInfoHeader Whether it is going to be used or not for system Information header
 *
 * @return the major CPU type.

 */
- (NSString *)CPUType:(NSString *)CPUArch isSystemInfoHeader:(BOOL)isSystemInfoHeader;

/** Determine the CPU architecture based on major/minor CPU architecture codes.
 *
 * @param majorCode The major part of the code.
 *
 * @param minorCode The minor part of the code.
 *
 * @return The CPU architecture.
 */
- (NSString *)CPUArchForMajor:(cpu_type_t)majorCode minor:(cpu_subtype_t)minorCode;

/** Take a UUID string and strip out all the dashes.
 *
 * @param uuid the UUID.
 *
 * @return the UUID in compact form.
 */
- (NSString *)toCompactUUID:(NSString *)uuid;

@end

@interface NSString (CompareRegisterNames)

- (NSComparisonResult)ttsdkcrash_compareRegisterName:(NSString *)other;

@end

@implementation NSString (CompareRegisterNames)

- (NSComparisonResult)ttsdkcrash_compareRegisterName:(NSString *)other
{
    BOOL containsNum = [self rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]].location != NSNotFound;
    BOOL otherContainsNum =
        [other rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]].location != NSNotFound;

    if (containsNum && !otherContainsNum) {
        return NSOrderedAscending;
    } else if (!containsNum && otherContainsNum) {
        return NSOrderedDescending;
    } else {
        return [self localizedStandardCompare:other];
    }
}

@end

@implementation TTSDKCrashReportFilterAppleFmt

/** Date formatter for Apple date format in crash reports. */
static NSDateFormatter *g_dateFormatter;

/** Date formatter for RFC3339 date format. */
static NSDateFormatter *g_rfc3339DateFormatter;

/** Printing order for registers. */
static NSDictionary *g_registerOrders;

+ (void)initialize
{
    g_dateFormatter = [[NSDateFormatter alloc] init];
    [g_dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
    [g_dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS ZZZ"];

    g_rfc3339DateFormatter = [[NSDateFormatter alloc] init];
    [g_rfc3339DateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
    [g_rfc3339DateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'SSSSSS'Z'"];
    [g_rfc3339DateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];

    NSArray *armOrder = [NSArray arrayWithObjects:@"r0", @"r1", @"r2", @"r3", @"r4", @"r5", @"r6", @"r7", @"r8", @"r9",
                                                  @"r10", @"r11", @"ip", @"sp", @"lr", @"pc", @"cpsr", nil];

    NSArray *x86Order = [NSArray arrayWithObjects:@"eax", @"ebx", @"ecx", @"edx", @"edi", @"esi", @"ebp", @"esp", @"ss",
                                                  @"eflags", @"eip", @"cs", @"ds", @"es", @"fs", @"gs", nil];

    NSArray *x86_64Order =
        [NSArray arrayWithObjects:@"rax", @"rbx", @"rcx", @"rdx", @"rdi", @"rsi", @"rbp", @"rsp", @"r8", @"r9", @"r10",
                                  @"r11", @"r12", @"r13", @"r14", @"r15", @"rip", @"rflags", @"cs", @"fs", @"gs", nil];

    g_registerOrders = [[NSDictionary alloc]
        initWithObjectsAndKeys:armOrder, @"arm", armOrder, @"armv6", armOrder, @"armv7", armOrder, @"armv7f", armOrder,
                               @"armv7k", armOrder, @"armv7s", x86Order, @"x86", x86Order, @"i386", x86Order, @"i486",
                               x86Order, @"i686", x86_64Order, @"x86_64", nil];
}

- (instancetype)initWithReportStyle:(TTSDKAppleReportStyle)reportStyle
{
    if ((self = [super init])) {
        _reportStyle = reportStyle;
    }
    return self;
}

- (instancetype)init
{
    return [self initWithReportStyle:TTSDKAppleReportStyleSymbolicated];
}

- (int)majorVersion:(NSDictionary *)report
{
    NSDictionary *info = [self infoReport:report];
    NSString *version = [info objectForKey:TTSDKCrashField_Version];
    if ([version isKindOfClass:[NSDictionary class]]) {
        NSDictionary *oldVersion = (NSDictionary *)version;
        version = oldVersion[@"major"];
    }

    if ([version respondsToSelector:@selector(intValue)]) {
        return version.intValue;
    }
    return 0;
}

- (void)filterReports:(NSArray<id<TTSDKCrashReport>> *)reports onCompletion:(TTSDKCrashReportFilterCompletion)onCompletion
{
    NSMutableArray<id<TTSDKCrashReport>> *filteredReports = [NSMutableArray arrayWithCapacity:[reports count]];
    for (TTSDKCrashReportDictionary *report in reports) {
        if ([report isKindOfClass:[TTSDKCrashReportDictionary class]] == NO) {
            TTSDKLOG_ERROR(@"Unexpected non-dictionary report: %@", report);
            continue;
        }
        if ([self majorVersion:report.value] == kExpectedMajorVersion) {
            NSString *appleReportString = [self toAppleFormat:report.value];
            if (appleReportString != nil) {
                [filteredReports addObject:[TTSDKCrashReportString reportWithValue:appleReportString]];
            }
        }
    }

    ttsdkcrash_callCompletion(onCompletion, filteredReports, nil);
}

- (NSString *)CPUType:(NSString *)CPUArch isSystemInfoHeader:(BOOL)isSystemInfoHeader
{
    if (isSystemInfoHeader && [CPUArch rangeOfString:@"arm64e"].location == 0) {
        return @"ARM-64 (Native)";
    }
    if ([CPUArch rangeOfString:@"arm64"].location == 0) {
        return @"ARM-64";
    }
    if ([CPUArch rangeOfString:@"arm"].location == 0) {
        return @"ARM";
    }
    if ([CPUArch isEqualToString:@"x86"]) {
        return @"X86";
    }
    if ([CPUArch isEqualToString:@"x86_64"]) {
        return @"X86_64";
    }
    return @"Unknown";
}

- (NSString *)CPUArchForMajor:(cpu_type_t)majorCode minor:(cpu_subtype_t)minorCode
{
#if TTSDKCRASH_HOST_APPLE
    // In Apple platforms we can use this function to get the name of a particular architecture
    const char *archName = ttsdkcpu_archForCPU(majorCode, minorCode);
    if (archName) {
        return [[NSString alloc] initWithUTF8String:archName];
    }
#endif

    switch (majorCode) {
        case CPU_TYPE_ARM: {
            switch (minorCode) {
                case CPU_SUBTYPE_ARM_V6:
                    return @"armv6";
                case CPU_SUBTYPE_ARM_V7:
                    return @"armv7";
                case CPU_SUBTYPE_ARM_V7F:
                    return @"armv7f";
                case CPU_SUBTYPE_ARM_V7K:
                    return @"armv7k";
#ifdef CPU_SUBTYPE_ARM_V7S
                case CPU_SUBTYPE_ARM_V7S:
                    return @"armv7s";
#endif
            }
            return @"arm";
        }
        case CPU_TYPE_ARM64: {
            switch (minorCode) {
                case CPU_SUBTYPE_ARM64E:
                    return @"arm64e";
            }
            return @"arm64";
        }
        case CPU_TYPE_X86:
            return @"i386";
        case CPU_TYPE_X86_64:
            return @"x86_64";
    }
    return [NSString stringWithFormat:@"unknown(%d,%d)", majorCode, minorCode];
}

/** Convert a backtrace to a string.
 *
 * @param backtrace The backtrace to convert.
 *
 * @param reportStyle The style of report being generated.
 *
 * @param mainExecutableName Name of the app executable.
 *
 * @return The converted string.
 */
- (NSString *)backtraceString:(NSDictionary *)backtrace
                  reportStyle:(TTSDKAppleReportStyle)reportStyle
           mainExecutableName:(NSString *)mainExecutableName
{
    NSMutableString *str = [NSMutableString string];

    int traceNum = 0;
    for (NSDictionary *trace in [backtrace objectForKey:TTSDKCrashField_Contents]) {
        uintptr_t pc = (uintptr_t)[[trace objectForKey:TTSDKCrashField_InstructionAddr] longLongValue];
        uintptr_t objAddr = (uintptr_t)[[trace objectForKey:TTSDKCrashField_ObjectAddr] longLongValue];
        NSString *objName = [[trace objectForKey:TTSDKCrashField_ObjectName] lastPathComponent];
        uintptr_t symAddr = (uintptr_t)[[trace objectForKey:TTSDKCrashField_SymbolAddr] longLongValue];
        NSString *symName = [trace objectForKey:TTSDKCrashField_SymbolName];
        bool isMainExecutable = mainExecutableName && [objName isEqualToString:mainExecutableName];
        TTSDKAppleReportStyle thisLineStyle = reportStyle;
        if (thisLineStyle == TTSDKAppleReportStylePartiallySymbolicated) {
            thisLineStyle = isMainExecutable ? TTSDKAppleReportStyleUnsymbolicated : TTSDKAppleReportStyleSymbolicated;
        }

        NSString *preamble = [NSString stringWithFormat:FMT_TRACE_PREAMBLE, traceNum, [objName UTF8String], pc];
        NSString *unsymbolicated = [NSString stringWithFormat:FMT_TRACE_UNSYMBOLICATED, objAddr, pc - objAddr];
        NSString *symbolicated = @"(null)";
        if (thisLineStyle != TTSDKAppleReportStyleUnsymbolicated && [symName isKindOfClass:[NSString class]]) {
            symbolicated = [NSString stringWithFormat:FMT_TRACE_SYMBOLICATED, symName, pc - symAddr];
        } else {
            thisLineStyle = TTSDKAppleReportStyleUnsymbolicated;
        }

        // Apple has started replacing symbols for any function/method
        // beginning with an underscore with "<redacted>" in iOS 6.
        // No, I can't think of any valid reason to do this, either.
        if (thisLineStyle == TTSDKAppleReportStyleSymbolicated && [symName isEqualToString:kAppleRedactedText]) {
            thisLineStyle = TTSDKAppleReportStyleUnsymbolicated;
        }

        switch (thisLineStyle) {
            case TTSDKAppleReportStyleSymbolicatedSideBySide:
                [str appendFormat:@"%@ %@ (%@)\n", preamble, unsymbolicated, symbolicated];
                break;
            case TTSDKAppleReportStyleSymbolicated:
                [str appendFormat:@"%@ %@\n", preamble, symbolicated];
                break;
            case TTSDKAppleReportStylePartiallySymbolicated:  // Should not happen
            case TTSDKAppleReportStyleUnsymbolicated:
                [str appendFormat:@"%@ %@\n", preamble, unsymbolicated];
                break;
        }
        traceNum++;
    }

    return str;
}

- (NSString *)toCompactUUID:(NSString *)uuid
{
    return [[uuid lowercaseString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
}

- (NSString *)stringFromDate:(NSDate *)date
{
    if (![date isKindOfClass:[NSDate class]]) {
        return nil;
    }
    return [g_dateFormatter stringFromDate:date];
}

- (NSDictionary *)recrashReport:(NSDictionary *)report
{
    return [report objectForKey:TTSDKCrashField_RecrashReport];
}

- (NSDictionary *)systemReport:(NSDictionary *)report
{
    return [report objectForKey:TTSDKCrashField_System];
}

- (NSDictionary *)infoReport:(NSDictionary *)report
{
    return [report objectForKey:TTSDKCrashField_Report];
}

- (NSDictionary *)processReport:(NSDictionary *)report
{
    return [report objectForKey:TTSDKCrashField_ProcessState];
}

- (NSDictionary *)crashReport:(NSDictionary *)report
{
    return [report objectForKey:TTSDKCrashField_Crash];
}

- (NSArray *)binaryImagesReport:(NSDictionary *)report
{
    return [report objectForKey:TTSDKCrashField_BinaryImages];
}

- (NSDictionary *)crashedThread:(NSDictionary *)report
{
    NSDictionary *crash = [self crashReport:report];
    NSArray *threads = [crash objectForKey:TTSDKCrashField_Threads];
    for (NSDictionary *thread in threads) {
        BOOL crashed = [[thread objectForKey:TTSDKCrashField_Crashed] boolValue];
        if (crashed) {
            return thread;
        }
    }

    return [crash objectForKey:TTSDKCrashField_CrashedThread];
}

- (NSString *)mainExecutableNameForReport:(NSDictionary *)report
{
    NSDictionary *info = [self infoReport:report];
    return [info objectForKey:TTSDKCrashField_ProcessName];
}

- (NSString *)cpuArchForReport:(NSDictionary *)report
{
    NSDictionary *system = [self systemReport:report];
    cpu_type_t cpuType = [[system objectForKey:TTSDKCrashField_BinaryCPUType] intValue];
    cpu_subtype_t cpuSubType = [[system objectForKey:TTSDKCrashField_BinaryCPUSubType] intValue];
    return [self CPUArchForMajor:cpuType minor:cpuSubType];
}

- (NSString *)headerStringForReport:(NSDictionary *)report
{
    NSDictionary *system = [self systemReport:report];
    NSDictionary *reportInfo = [self infoReport:report];
    NSString *reportID = [reportInfo objectForKey:TTSDKCrashField_ID];
    NSDate *crashTime = [g_rfc3339DateFormatter dateFromString:[reportInfo objectForKey:TTSDKCrashField_Timestamp]];

    return [self headerStringForSystemInfo:system reportID:reportID crashTime:crashTime];
}

- (NSString *)headerStringForSystemInfo:(NSDictionary<NSString *, id> *)system
                               reportID:(nullable NSString *)reportID
                              crashTime:(nullable NSDate *)crashTime
{
    NSMutableString *str = [NSMutableString string];
    NSString *executablePath = [system objectForKey:TTSDKCrashField_ExecutablePath];
    NSString *cpuArch = [system objectForKey:TTSDKCrashField_CPUArch];
    NSString *cpuArchType = [self CPUType:cpuArch isSystemInfoHeader:YES];
    NSString *parentProcess = @"launchd";  // In iOS and most macOS regulard apps "launchd" is always the launcher. This
                                           // might need a fix for other kind of apps
    NSString *processRole = @"Foreground";  // In iOS and most macOS regulard apps the role is "Foreground". This might
                                            // need a fix for other kind of apps

    [str appendFormat:@"Incident Identifier: %@\n", reportID];
    [str appendFormat:@"CrashReporter Key:   %@\n", [system objectForKey:TTSDKCrashField_DeviceAppHash]];
    [str appendFormat:@"Hardware Model:      %@\n", [system objectForKey:TTSDKCrashField_Machine]];
    [str appendFormat:@"Process:             %@ [%@]\n", [system objectForKey:TTSDKCrashField_ProcessName],
                      [system objectForKey:TTSDKCrashField_ProcessID]];
    [str appendFormat:@"Path:                %@\n", executablePath];
    [str appendFormat:@"Identifier:          %@\n", [system objectForKey:TTSDKCrashField_BundleID]];
    [str appendFormat:@"Version:             %@ (%@)\n", [system objectForKey:TTSDKCrashField_BundleShortVersion],
                      [system objectForKey:TTSDKCrashField_BundleVersion]];
    [str appendFormat:@"Code Type:           %@\n", cpuArchType];
    [str appendFormat:@"Role:                %@\n", processRole];
    [str appendFormat:@"Parent Process:      %@ [%@]\n", parentProcess,
                      [system objectForKey:TTSDKCrashField_ParentProcessID]];
    [str appendFormat:@"\n"];
    [str appendFormat:@"Date/Time:           %@\n", [self stringFromDate:crashTime]];
    [str appendFormat:@"OS Version:          %@ %@ (%@)\n", [system objectForKey:TTSDKCrashField_SystemName],
                      [system objectForKey:TTSDKCrashField_SystemVersion], [system objectForKey:TTSDKCrashField_OSVersion]];
    [str appendFormat:@"Report Version:      104\n"];
    [str appendFormat:@"Address Range:       **%@**%@**\n", [system objectForKey:TTSDKCrashField_BeginAddress], [system objectForKey:TTSDKCrashField_EndAddress]];

    return str;
}

- (NSString *)binaryImagesStringForReport:(NSDictionary *)report
{
    NSMutableString *str = [NSMutableString string];

    NSArray *binaryImages = [self binaryImagesReport:report];

    [str appendString:@"\nBinary Images:\n"];
    if (binaryImages) {
        NSMutableArray *images = [NSMutableArray arrayWithArray:binaryImages];
        [images sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            NSNumber *num1 = [(NSDictionary *)obj1 objectForKey:TTSDKCrashField_ImageAddress];
            NSNumber *num2 = [(NSDictionary *)obj2 objectForKey:TTSDKCrashField_ImageAddress];
            if (num1 == nil || num2 == nil) {
                return NSOrderedSame;
            }
            return [num1 compare:num2];
        }];
        for (NSDictionary *image in images) {
            cpu_type_t cpuType = [[image objectForKey:TTSDKCrashField_CPUType] intValue];
            cpu_subtype_t cpuSubtype = [[image objectForKey:TTSDKCrashField_CPUSubType] intValue];
            uintptr_t imageAddr = (uintptr_t)[[image objectForKey:TTSDKCrashField_ImageAddress] longLongValue];
            uintptr_t imageSize = (uintptr_t)[[image objectForKey:TTSDKCrashField_ImageSize] longLongValue];
            NSString *path = [image objectForKey:TTSDKCrashField_Name];
            NSString *name = [path lastPathComponent];
            NSString *uuid = [self toCompactUUID:[image objectForKey:TTSDKCrashField_UUID]];
            NSString *arch = [self CPUArchForMajor:cpuType minor:cpuSubtype];
            [str appendFormat:FMT_PTR_RJ @" - " FMT_PTR_RJ @" %@ %@  <%@> %@\n", imageAddr, imageAddr + imageSize - 1,
                              name, arch, uuid, path];
        }
    }

    [str appendString:@"\nEOF\n\n"];

    return str;
}

- (NSString *)crashedThreadCPUStateStringForReport:(NSDictionary *)report cpuArch:(NSString *)cpuArch
{
    NSDictionary *thread = [self crashedThread:report];
    if (thread == nil) {
        return @"";
    }
    int threadIndex = [[thread objectForKey:TTSDKCrashField_Index] intValue];

    NSString *cpuArchType = [self CPUType:cpuArch isSystemInfoHeader:NO];

    NSMutableString *str = [NSMutableString string];

    [str appendFormat:@"\nThread %d crashed with %@ Thread State:\n", threadIndex, cpuArchType];

    NSDictionary *registers =
        [(NSDictionary *)[thread objectForKey:TTSDKCrashField_Registers] objectForKey:TTSDKCrashField_Basic];
    NSArray *regOrder = [g_registerOrders objectForKey:cpuArch];
    if (regOrder == nil) {
        regOrder = [[registers allKeys] sortedArrayUsingSelector:@selector(ttsdkcrash_compareRegisterName:)];
    }
    NSUInteger numRegisters = [regOrder count];
    NSUInteger i = 0;
    while (i < numRegisters) {
        NSUInteger nextBreak = i + 4;
        if (nextBreak > numRegisters) {
            nextBreak = numRegisters;
        }
        for (; i < nextBreak; i++) {
            NSString *regName = [regOrder objectAtIndex:i];
            uintptr_t addr = (uintptr_t)[[registers objectForKey:regName] longLongValue];
            [str appendFormat:@"%6s: " FMT_PTR_LONG @" ", [regName cStringUsingEncoding:NSUTF8StringEncoding], addr];
        }
        [str appendString:@"\n"];
    }

    return str;
}

- (NSString *)extraInfoStringForReport:(NSDictionary *)report mainExecutableName:(NSString *)mainExecutableName
{
    NSMutableString *str = [NSMutableString string];

    [str appendString:@"\nExtra Information:\n"];

    NSDictionary *system = [self systemReport:report];
    NSDictionary *crash = [self crashReport:report];
    NSDictionary *error = [crash objectForKey:TTSDKCrashField_Error];
    NSDictionary *nsexception = [error objectForKey:TTSDKCrashField_NSException];
    NSDictionary *referencedObject = [nsexception objectForKey:TTSDKCrashField_ReferencedObject];
    if (referencedObject != nil) {
        [str appendFormat:@"Object referenced by NSException:\n%@\n", [self JSONForObject:referencedObject]];
    }

    NSDictionary *crashedThread = [self crashedThread:report];
    if (crashedThread != nil) {
        NSDictionary *stack = [crashedThread objectForKey:TTSDKCrashField_Stack];
        if (stack != nil) {
            [str appendFormat:@"\nStack Dump (" FMT_PTR_LONG "-" FMT_PTR_LONG "):\n\n%@\n",
                              (uintptr_t)[[stack objectForKey:TTSDKCrashField_DumpStart] unsignedLongLongValue],
                              (uintptr_t)[[stack objectForKey:TTSDKCrashField_DumpEnd] unsignedLongLongValue],
                              [stack objectForKey:TTSDKCrashField_Contents]];
        }

        NSDictionary *notableAddresses = [crashedThread objectForKey:TTSDKCrashField_NotableAddresses];
        if (notableAddresses.count) {
            [str appendFormat:@"\nNotable Addresses:\n%@\n", [self JSONForObject:notableAddresses]];
        }
    }

    NSDictionary *lastException = [[self processReport:report] objectForKey:TTSDKCrashField_LastDeallocedNSException];
    if (lastException != nil) {
        uintptr_t address = (uintptr_t)[[lastException objectForKey:TTSDKCrashField_Address] unsignedLongLongValue];
        NSString *name = [lastException objectForKey:TTSDKCrashField_Name];
        NSString *reason = [lastException objectForKey:TTSDKCrashField_Reason];
        referencedObject = [lastException objectForKey:TTSDKCrashField_ReferencedObject];
        [str appendFormat:@"\nLast deallocated NSException (" FMT_PTR_LONG "): %@: %@\n", address, name, reason];
        if (referencedObject != nil) {
            [str appendFormat:@"Referenced object:\n%@\n", [self JSONForObject:referencedObject]];
        }
        [str appendString:[self backtraceString:[lastException objectForKey:TTSDKCrashField_Backtrace]
                                     reportStyle:self.reportStyle
                              mainExecutableName:mainExecutableName]];
    }

    NSDictionary *appStats = [system objectForKey:TTSDKCrashField_AppStats];
    if (appStats != nil) {
        [str appendFormat:@"\nApplication Stats:\n%@\n", [self JSONForObject:appStats]];
    }

    NSDictionary *memoryStats = [system objectForKey:TTSDKCrashField_AppMemory];
    if (memoryStats != nil) {
        [str appendFormat:@"\nMemory Statistics:\n%@\n", [self JSONForObject:memoryStats]];
    }

    NSDictionary *crashReport = [report objectForKey:TTSDKCrashField_Crash];
    NSString *diagnosis = [crashReport objectForKey:TTSDKCrashField_Diagnosis];
    if (diagnosis != nil) {
        [str appendFormat:@"\nCrashDoctor Diagnosis: %@\n", diagnosis];
    }

    return str;
}

- (NSString *)JSONForObject:(id)object
{
    NSError *error = nil;
    NSData *encoded = [TTSDKJSONCodec encode:object
                                  options:TTSDKJSONEncodeOptionPretty | TTSDKJSONEncodeOptionSorted
                                    error:&error];
    if (error != nil) {
        return [NSString stringWithFormat:@"Error encoding JSON: %@", error];
    } else {
        return [[NSString alloc] initWithData:encoded encoding:NSUTF8StringEncoding];
    }
}

- (BOOL)isZombieNSException:(NSDictionary *)report
{
    NSDictionary *crash = [self crashReport:report];
    NSDictionary *error = [crash objectForKey:TTSDKCrashField_Error];
    NSDictionary *mach = [error objectForKey:TTSDKCrashField_Mach];
    NSString *machExcName = [mach objectForKey:TTSDKCrashField_ExceptionName];
    NSString *machCodeName = [mach objectForKey:TTSDKCrashField_CodeName];
    if (![machExcName isEqualToString:@"EXC_BAD_ACCESS"] || ![machCodeName isEqualToString:@"KERN_INVALID_ADDRESS"]) {
        return NO;
    }

    NSDictionary *lastException = [[self processReport:report] objectForKey:TTSDKCrashField_LastDeallocedNSException];
    if (lastException == nil) {
        return NO;
    }
    NSNumber *lastExceptionAddress = [lastException objectForKey:TTSDKCrashField_Address];

    NSDictionary *thread = [self crashedThread:report];
    NSDictionary *registers =
        [(NSDictionary *)[thread objectForKey:TTSDKCrashField_Registers] objectForKey:TTSDKCrashField_Basic];

    for (NSString *reg in registers) {
        NSNumber *address = [registers objectForKey:reg];
        if (lastExceptionAddress && [address isEqualToNumber:lastExceptionAddress]) {
            return YES;
        }
    }

    return NO;
}

- (NSString *)errorInfoStringForReport:(NSDictionary *)report
{
    NSMutableString *str = [NSMutableString string];

    NSDictionary *thread = [self crashedThread:report];
    NSDictionary *crash = [self crashReport:report];
    NSDictionary *error = [crash objectForKey:TTSDKCrashField_Error];
    NSDictionary *type = [error objectForKey:TTSDKCrashField_Type];

    NSDictionary *nsexception = [error objectForKey:TTSDKCrashField_NSException];
    NSDictionary *cppexception = [error objectForKey:TTSDKCrashField_CPPException];
    NSDictionary *lastException = [[self processReport:report] objectForKey:TTSDKCrashField_LastDeallocedNSException];
    NSDictionary *userException = [error objectForKey:TTSDKCrashField_UserReported];
    NSDictionary *mach = [error objectForKey:TTSDKCrashField_Mach];
    NSDictionary *signal = [error objectForKey:TTSDKCrashField_Signal];

    NSString *machExcName = [mach objectForKey:TTSDKCrashField_ExceptionName];
    if (machExcName == nil) {
        machExcName = @"0";
    }
    NSString *signalName = [signal objectForKey:TTSDKCrashField_Name];
    if (signalName == nil) {
        signalName = [[signal objectForKey:TTSDKCrashField_Signal] stringValue];
    }
    NSString *machCodeName = [mach objectForKey:TTSDKCrashField_CodeName];
    if (machCodeName == nil) {
        machCodeName = @"0x00000000";
    }

    [str appendFormat:@"\n"];
    [str appendFormat:@"Exception Type:  %@ (%@)\n", machExcName, signalName];
    [str appendFormat:@"Exception Codes: %@ at " FMT_PTR_LONG @"\n", machCodeName,
                      (uintptr_t)[[error objectForKey:TTSDKCrashField_Address] longLongValue]];

    [str appendFormat:@"Triggered by Thread:  %d\n", [[thread objectForKey:TTSDKCrashField_Index] intValue]];

    if (nsexception != nil) {
        [str appendString:[self stringWithUncaughtExceptionName:[nsexception objectForKey:TTSDKCrashField_Name]
                                                         reason:[error objectForKey:TTSDKCrashField_Reason]]];
    } else if ([self isZombieNSException:report]) {
        [str appendString:[self stringWithUncaughtExceptionName:[lastException objectForKey:TTSDKCrashField_Name]
                                                         reason:[lastException objectForKey:TTSDKCrashField_Reason]]];
        [str appendString:@"NOTE: This exception has been deallocated! Stack trace is crash from attempting to access "
                          @"this zombie exception.\n"];
    } else if (userException != nil) {
        [str appendString:[self stringWithUncaughtExceptionName:[userException objectForKey:TTSDKCrashField_Name]
                                                         reason:[error objectForKey:TTSDKCrashField_Reason]]];
        NSString *trace = [self userExceptionTrace:userException];
        if (trace.length > 0) {
            [str appendFormat:@"\n%@\n", trace];
        }
    } else if ([type isEqual:TTSDKCrashExcType_CPPException]) {
        [str appendString:[self stringWithUncaughtExceptionName:[cppexception objectForKey:TTSDKCrashField_Name]
                                                         reason:[error objectForKey:TTSDKCrashField_Reason]]];
    }

    NSString *crashType = [error objectForKey:TTSDKCrashField_Type];
    if (crashType && [TTSDKCrashExcType_Deadlock isEqualToString:crashType]) {
        [str appendFormat:@"\nApplication main thread deadlocked\n"];
    }

    return str;
}

- (NSString *)stringWithUncaughtExceptionName:(NSString *)name reason:(NSString *)reason
{
    return [NSString stringWithFormat:@"\nApplication Specific Information:\n"
                                      @"*** Terminating app due to uncaught exception '%@', reason: '%@'\n",
                                      name, reason];
}

- (NSString *)userExceptionTrace:(NSDictionary *)userException
{
    NSMutableString *str = [NSMutableString string];
    NSString *line = [userException objectForKey:TTSDKCrashField_LineOfCode];
    if (line != nil) {
        [str appendFormat:@"Line: %@\n", line];
    }
    NSArray *backtrace = [userException objectForKey:TTSDKCrashField_Backtrace];
    for (NSString *entry in backtrace) {
        [str appendFormat:@"%@\n", entry];
    }

    if (str.length > 0) {
        return [@"Custom Backtrace:\n" stringByAppendingString:str];
    }
    return @"";
}

- (NSString *)threadStringForThread:(NSDictionary *)thread mainExecutableName:(NSString *)mainExecutableName
{
    NSMutableString *str = [NSMutableString string];

    [str appendFormat:@"\n"];
    BOOL crashed = [[thread objectForKey:TTSDKCrashField_Crashed] boolValue];
    int index = [[thread objectForKey:TTSDKCrashField_Index] intValue];
    NSString *name = [thread objectForKey:TTSDKCrashField_Name];
    NSString *queueName = [thread objectForKey:TTSDKCrashField_DispatchQueue];

    if (name != nil) {
        [str appendFormat:@"Thread %d name:  %@\n", index, name];
    } else if (queueName != nil) {
        [str appendFormat:@"Thread %d name:  Dispatch queue: %@\n", index, queueName];
    }

    if (crashed) {
        [str appendFormat:@"Thread %d Crashed:\n", index];
    } else {
        [str appendFormat:@"Thread %d:\n", index];
    }

    [str appendString:[self backtraceString:[thread objectForKey:TTSDKCrashField_Backtrace]
                                 reportStyle:self.reportStyle
                          mainExecutableName:mainExecutableName]];

    return str;
}

- (NSString *)threadListStringForReport:(NSDictionary *)report mainExecutableName:(NSString *)mainExecutableName
{
    NSMutableString *str = [NSMutableString string];

    NSDictionary *crash = [self crashReport:report];
    NSArray *threads = [crash objectForKey:TTSDKCrashField_Threads];

    for (NSDictionary *thread in threads) {
        [str appendString:[self threadStringForThread:thread mainExecutableName:mainExecutableName]];
    }

    return str;
}

- (NSString *)crashReportString:(NSDictionary *)report
{
    NSMutableString *str = [NSMutableString string];
    NSString *executableName = [self mainExecutableNameForReport:report];

    [str appendString:[self headerStringForReport:report]];
    [str appendString:[self errorInfoStringForReport:report]];
    [str appendString:[self threadListStringForReport:report mainExecutableName:executableName]];
    [str appendString:[self crashedThreadCPUStateStringForReport:report cpuArch:[self cpuArchForReport:report]]];
//    [str appendString:[self binaryImagesStringForReport:report]];
    [str appendString:[self extraInfoStringForReport:report mainExecutableName:executableName]];

    return str;
}

- (NSString *)recrashReportString:(NSDictionary *)report
{
    NSMutableString *str = [NSMutableString string];

    NSDictionary *recrashReport = [self recrashReport:report];
    NSDictionary *system = [self systemReport:recrashReport];
    NSString *executablePath = [system objectForKey:TTSDKCrashField_ExecutablePath];
    NSString *executableName = [executablePath lastPathComponent];
    NSDictionary *crash = [self crashReport:report];
    NSDictionary *thread = [crash objectForKey:TTSDKCrashField_CrashedThread];

    [str appendString:@"\nHandler crashed while reporting:\n"];
    [str appendString:[self errorInfoStringForReport:report]];
    [str appendString:[self threadStringForThread:thread mainExecutableName:executableName]];
    [str appendString:[self crashedThreadCPUStateStringForReport:report cpuArch:[self cpuArchForReport:recrashReport]]];
    NSString *diagnosis = [crash objectForKey:TTSDKCrashField_Diagnosis];
    if (diagnosis != nil) {
        [str appendFormat:@"\nRecrash Diagnosis: %@", diagnosis];
    }

    return str;
}

- (NSString *)toAppleFormat:(NSDictionary *)report
{
    NSMutableString *str = [NSMutableString string];

    NSDictionary *recrashReport = report[TTSDKCrashField_RecrashReport];
    if (recrashReport) {
        [str appendString:[self crashReportString:recrashReport]];
        [str appendString:[self recrashReportString:report]];
    } else {
        [str appendString:[self crashReportString:report]];
    }

    return str;
}

@end
