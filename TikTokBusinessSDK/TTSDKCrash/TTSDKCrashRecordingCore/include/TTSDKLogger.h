//
//  TTSDKLogger.h
//
//  Created by Karl Stenerud on 11-06-25.
//
//  Copyright (c) 2011 Karl Stenerud. All rights reserved.
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

/**
 * TTSDKLogger
 * ========
 *
 * Prints log entries to the console consisting of:
 * - Level (Error, Warn, Info, Debug, Trace)
 * - File
 * - Line
 * - Function
 * - Message
 *
 * Allows setting the minimum logging level in the preprocessor.
 *
 * Works in C or Objective-C contexts, with or without ARC, using CLANG or GCC.
 *
 *
 * =====
 * USAGE
 * =====
 *
 * Set the log level in your "Preprocessor Macros" build setting. You may choose
 * TRACE, DEBUG, INFO, WARN, ERROR. If nothing is set, it defaults to ERROR.
 *
 * Example: TTSDKLogger_Level=WARN
 *
 * Anything below the level specified for TTSDKLogger_Level will not be compiled
 * or printed.
 *
 *
 * Next, include the header file:
 *
 * #include "TTSDKLogger.h"
 *
 *
 * Next, call the logger functions from your code (using objective-c strings
 * in objective-C files and regular strings in regular C files):
 *
 * Code:
 *    TTSDKLOG_ERROR(@"Some error message");
 *
 * Prints:
 *    2011-07-16 05:41:01.379 TestApp[4439:f803] ERROR: SomeClass.m (21): -[SomeFunction]: Some error message
 *
 * Code:
 *    TTSDKLOG_INFO(@"Info about %@", someObject);
 *
 * Prints:
 *    2011-07-16 05:44:05.239 TestApp[4473:f803] INFO : SomeClass.m (20): -[SomeFunction]: Info about <NSObject:
 * 0xb622840>
 *
 *
 * The "BASIC" versions of the macros behave exactly like NSLog() or printf(),
 * except they respect the TTSDKLogger_Level setting:
 *
 * Code:
 *    TTSDKLOGBASIC_ERROR(@"A basic log entry");
 *
 * Prints:
 *    2011-07-16 05:44:05.916 TestApp[4473:f803] A basic log entry
 *
 *
 * NOTE: In C files, use "" instead of @"" in the format field. Logging calls
 *       in C files do not print the NSLog preamble:
 *
 * Objective-C version:
 *    TTSDKLOG_ERROR(@"Some error message");
 *
 *    2011-07-16 05:41:01.379 TestApp[4439:f803] ERROR: SomeClass.m (21): -[SomeFunction]: Some error message
 *
 * C version:
 *    TTSDKLOG_ERROR("Some error message");
 *
 *    ERROR: SomeClass.c (21): SomeFunction(): Some error message
 *
 *
 * =============
 * LOCAL LOGGING
 * =============
 *
 * You can control logging messages at the local file level using the
 * "TTSDKLogger_LocalLevel" define. Note that it must be defined BEFORE
 * including TTSDKLogger.h
 *
 * The TTSDKLOG_XX() and TTSDKLOGBASIC_XX() macros will print out based on the LOWER
 * of TTSDKLogger_Level and TTSDKLogger_LocalLevel, so if TTSDKLogger_Level is DEBUG
 * and TTSDKLogger_LocalLevel is TRACE, it will print all the way down to the trace
 * level for the local file where TTSDKLogger_LocalLevel was defined, and to the
 * debug level everywhere else.
 *
 * Example:
 *
 * // TTSDKLogger_LocalLevel, if defined, MUST come BEFORE including TTSDKLogger.h
 * #define TTSDKLogger_LocalLevel TRACE
 * #import "TTSDKLogger.h"
 *
 *
 * ===============
 * IMPORTANT NOTES
 * ===============
 *
 * The C logger changes its behavior depending on the value of the preprocessor
 * define TTSDKLogger_CBufferSize.
 *
 * If TTSDKLogger_CBufferSize is > 0, the C logger will behave in an async-safe
 * manner, calling write() instead of printf(). Any log messages that exceed the
 * length specified by TTSDKLogger_CBufferSize will be truncated.
 *
 * If TTSDKLogger_CBufferSize == 0, the C logger will use printf(), and there will
 * be no limit on the log message length.
 *
 * TTSDKLogger_CBufferSize can only be set as a preprocessor define, and will
 * default to 1024 if not specified during compilation.
 */

// ============================================================================
#pragma mark - (internal) -
// ============================================================================

#ifndef HDR_TTSDKLogger_h
#define HDR_TTSDKLogger_h

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifdef __OBJC__

#import <CoreFoundation/CoreFoundation.h>

void i_ttsdklog_logObjC(const char *level, const char *file, int line, const char *function, CFStringRef fmt, ...);

void i_ttsdklog_logObjCBasic(CFStringRef fmt, ...);

#define i_TTSDKLOG_FULL(LEVEL, FILE, LINE, FUNCTION, FMT, ...) \
    i_ttsdklog_logObjC(LEVEL, FILE, LINE, FUNCTION, (__bridge CFStringRef)FMT, ##__VA_ARGS__)
#define i_TTSDKLOG_BASIC(FMT, ...) i_ttsdklog_logObjCBasic((__bridge CFStringRef)FMT, ##__VA_ARGS__)

#else  // __OBJC__

void i_ttsdklog_logC(const char *level, const char *file, int line, const char *function, const char *fmt, ...);

void i_ttsdklog_logCBasic(const char *fmt, ...);

#define i_TTSDKLOG_FULL i_ttsdklog_logC
#define i_TTSDKLOG_BASIC i_ttsdklog_logCBasic

#endif  // __OBJC__

/* Back up any existing defines by the same name */
#ifdef TTSDK_NONE
#define TTSDKLOG_BAK_NONE TTSDK_NONE
#undef TTSDK_NONE
#endif
#ifdef ERROR
#define TTSDKLOG_BAK_ERROR ERROR
#undef ERROR
#endif
#ifdef WARN
#define TTSDKLOG_BAK_WARN WARN
#undef WARN
#endif
#ifdef INFO
#define TTSDKLOG_BAK_INFO INFO
#undef INFO
#endif
#ifdef DEBUG
#define TTSDKLOG_BAK_DEBUG DEBUG
#undef DEBUG
#endif
#ifdef TRACE
#define TTSDKLOG_BAK_TRACE TRACE
#undef TRACE
#endif

#define TTSDKLogger_Level_None 0
#define TTSDKLogger_Level_Error 10
#define TTSDKLogger_Level_Warn 20
#define TTSDKLogger_Level_Info 30
#define TTSDKLogger_Level_Debug 40
#define TTSDKLogger_Level_Trace 50

#define TTSDK_NONE TTSDKLogger_Level_None
#define ERROR TTSDKLogger_Level_Error
#define WARN TTSDKLogger_Level_Warn
#define INFO TTSDKLogger_Level_Info
#define DEBUG TTSDKLogger_Level_Debug
#define TRACE TTSDKLogger_Level_Trace

#ifndef TTSDKLogger_Level
#define TTSDKLogger_Level TTSDKLogger_Level_Error
#endif

#ifndef TTSDKLogger_LocalLevel
#define TTSDKLogger_LocalLevel TTSDKLogger_Level_None
#endif

#define a_TTSDKLOG_FULL(LEVEL, FMT, ...) i_TTSDKLOG_FULL(LEVEL, __FILE__, __LINE__, __PRETTY_FUNCTION__, FMT, ##__VA_ARGS__)

// ============================================================================
#pragma mark - API -
// ============================================================================

/** Set the filename to log to.
 *
 * @param filename The file to write to (NULL = write to stdout).
 *
 * @param overwrite If true, overwrite the log file.
 */
bool ttsdklog_setLogFilename(const char *filename, bool overwrite);

/** Clear the log file. */
bool ttsdklog_clearLogFile(void);

/** Tests if the logger would print at the specified level.
 *
 * @param LEVEL The level to test for. One of:
 *            TTSDKLogger_Level_Error,
 *            TTSDKLogger_Level_Warn,
 *            TTSDKLogger_Level_Info,
 *            TTSDKLogger_Level_Debug,
 *            TTSDKLogger_Level_Trace,
 *
 * @return TRUE if the logger would print at the specified level.
 */
#define TTSDKLOG_PRINTS_AT_LEVEL(LEVEL) (TTSDKLogger_Level >= LEVEL || TTSDKLogger_LocalLevel >= LEVEL)

/** Log a message regardless of the log settings.
 * Normal version prints out full context. Basic version prints directly.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#define TTSDKLOG_ALWAYS(FMT, ...) a_TTSDKLOG_FULL("FORCE", FMT, ##__VA_ARGS__)
#define TTSDKLOGBASIC_ALWAYS(FMT, ...) i_TTSDKLOG_BASIC(FMT, ##__VA_ARGS__)

/** Log an error.
 * Normal version prints out full context. Basic version prints directly.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#if TTSDKLOG_PRINTS_AT_LEVEL(TTSDKLogger_Level_Error)
#define TTSDKLOG_ERROR(FMT, ...) a_TTSDKLOG_FULL("ERROR", FMT, ##__VA_ARGS__)
#define TTSDKLOGBASIC_ERROR(FMT, ...) i_TTSDKLOG_BASIC(FMT, ##__VA_ARGS__)
#else
#define TTSDKLOG_ERROR(FMT, ...)
#define TTSDKLOGBASIC_ERROR(FMT, ...)
#endif

/** Log a warning.
 * Normal version prints out full context. Basic version prints directly.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#if TTSDKLOG_PRINTS_AT_LEVEL(TTSDKLogger_Level_Warn)
#define TTSDKLOG_WARN(FMT, ...) a_TTSDKLOG_FULL("WARN ", FMT, ##__VA_ARGS__)
#define TTSDKLOGBASIC_WARN(FMT, ...) i_TTSDKLOG_BASIC(FMT, ##__VA_ARGS__)
#else
#define TTSDKLOG_WARN(FMT, ...)
#define TTSDKLOGBASIC_WARN(FMT, ...)
#endif

/** Log an info message.
 * Normal version prints out full context. Basic version prints directly.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#if TTSDKLOG_PRINTS_AT_LEVEL(TTSDKLogger_Level_Info)
#define TTSDKLOG_INFO(FMT, ...) a_TTSDKLOG_FULL("INFO ", FMT, ##__VA_ARGS__)
#define TTSDKLOGBASIC_INFO(FMT, ...) i_TTSDKLOG_BASIC(FMT, ##__VA_ARGS__)
#else
#define TTSDKLOG_INFO(FMT, ...)
#define TTSDKLOGBASIC_INFO(FMT, ...)
#endif

/** Log a debug message.
 * Normal version prints out full context. Basic version prints directly.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#if TTSDKLOG_PRINTS_AT_LEVEL(TTSDKLogger_Level_Debug)
#define TTSDKLOG_DEBUG(FMT, ...) a_TTSDKLOG_FULL("DEBUG", FMT, ##__VA_ARGS__)
#define TTSDKLOGBASIC_DEBUG(FMT, ...) i_TTSDKLOG_BASIC(FMT, ##__VA_ARGS__)
#else
#define TTSDKLOG_DEBUG(FMT, ...)
#define TTSDKLOGBASIC_DEBUG(FMT, ...)
#endif

/** Log a trace message.
 * Normal version prints out full context. Basic version prints directly.
 *
 * @param FMT The format specifier, followed by its arguments.
 */
#if TTSDKLOG_PRINTS_AT_LEVEL(TTSDKLogger_Level_Trace)
#define TTSDKLOG_TRACE(FMT, ...) a_TTSDKLOG_FULL("TRACE", FMT, ##__VA_ARGS__)
#define TTSDKLOGBASIC_TRACE(FMT, ...) i_TTSDKLOG_BASIC(FMT, ##__VA_ARGS__)
#else
#define TTSDKLOG_TRACE(FMT, ...)
#define TTSDKLOGBASIC_TRACE(FMT, ...)
#endif

// ============================================================================
#pragma mark - (internal) -
// ============================================================================

/* Put everything back to the way we found it. */
#undef ERROR
#ifdef TTSDKLOG_BAK_ERROR
#define ERROR TTSDKLOG_BAK_ERROR
#undef TTSDKLOG_BAK_ERROR
#endif
#undef WARNING
#ifdef TTSDKLOG_BAK_WARN
#define WARNING TTSDKLOG_BAK_WARN
#undef TTSDKLOG_BAK_WARN
#endif
#undef INFO
#ifdef TTSDKLOG_BAK_INFO
#define INFO TTSDKLOG_BAK_INFO
#undef TTSDKLOG_BAK_INFO
#endif
#undef DEBUG
#ifdef TTSDKLOG_BAK_DEBUG
#define DEBUG TTSDKLOG_BAK_DEBUG
#undef TTSDKLOG_BAK_DEBUG
#endif
#undef TRACE
#ifdef TTSDKLOG_BAK_TRACE
#define TRACE TTSDKLOG_BAK_TRACE
#undef TTSDKLOG_BAK_TRACE
#endif

#ifdef __cplusplus
}
#endif

#endif  // HDR_TTSDKLogger_h
