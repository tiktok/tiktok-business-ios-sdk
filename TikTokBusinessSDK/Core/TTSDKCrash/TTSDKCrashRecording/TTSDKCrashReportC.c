//
//  TTSDKCrashReport.m
//
//  Created by Karl Stenerud on 2012-01-28.
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

#include "TTSDKCrashReportC.h"

#include "TTSDKCPU.h"
#include "TTSDKCrashCachedData.h"
#include "TTSDKCrashMonitorHelper.h"
#include "TTSDKCrashMonitor_AppState.h"
#include "TTSDKCrashMonitor_CPPException.h"
#include "TTSDKCrashMonitor_Deadlock.h"
#include "TTSDKCrashMonitor_MachException.h"
#include "TTSDKCrashMonitor_Memory.h"
#include "TTSDKCrashMonitor_NSException.h"
#include "TTSDKCrashMonitor_Signal.h"
#include "TTSDKCrashMonitor_System.h"
#include "TTSDKCrashMonitor_User.h"
#include "TTSDKCrashMonitor_Zombie.h"
#include "TTSDKCrashReportFields.h"
#include "TTSDKCrashReportVersion.h"
#include "TTSDKCrashReportWriter.h"
#include "TTSDKDate.h"
#include "TTSDKDynamicLinker.h"
#include "TTSDKFileUtils.h"
#include "TTSDKJSONCodec.h"
#include "TTSDKMach.h"
#include "TTSDKMemory.h"
#include "TTSDKObjC.h"
#include "TTSDKSignalInfo.h"
#include "TTSDKStackCursor_Backtrace.h"
#include "TTSDKStackCursor_MachineContext.h"
#include "TTSDKString.h"
#include "TTSDKSystemCapabilities.h"
#include "TTSDKThread.h"

// #define TTSDKLogger_LocalLevel TRACE
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <unistd.h>

#include "TTSDKLogger.h"

// ============================================================================
#pragma mark - Constants -
// ============================================================================

/** Default number of objects, subobjects, and ivars to record from a memory loc */
#define kDefaultMemorySearchDepth 15

/** How far to search the stack (in pointer sized jumps) for notable data. */
#define kStackNotableSearchBackDistance 20
#define kStackNotableSearchForwardDistance 10

/** How much of the stack to dump (in pointer sized jumps). */
#define kStackContentsPushedDistance 20
#define kStackContentsPoppedDistance 10
#define kStackContentsTotalDistance (kStackContentsPushedDistance + kStackContentsPoppedDistance)

/** The minimum length for a valid string. */
#define kMinStringLength 4

// ============================================================================
#pragma mark - JSON Encoding -
// ============================================================================

#define getJsonContext(REPORT_WRITER) ((TTSDKJSONEncodeContext *)((REPORT_WRITER)->context))

/** Used for writing hex string values. */
static const char g_hexNybbles[] = { '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F' };

// ============================================================================
#pragma mark - Runtime Config -
// ============================================================================

typedef struct {
    /** If YES, introspect memory contents during a crash.
     * Any Objective-C objects or C strings near the stack pointer or referenced by
     * cpu registers or exceptions will be recorded in the crash report, along with
     * their contents.
     */
    bool enabled;

    /** List of classes that should never be introspected.
     * Whenever a class in this list is encountered, only the class name will be recorded.
     */
    const char **restrictedClasses;
    int restrictedClassesCount;
} TTSDKCrash_IntrospectionRules;

static const char *g_userInfoJSON;
static pthread_mutex_t g_userInfoMutex = PTHREAD_MUTEX_INITIALIZER;

static TTSDKCrash_IntrospectionRules g_introspectionRules;
static TTSDKReportWriteCallback g_userSectionWriteCallback;

extern void * TikTokBusinessSDKFuncBeginAddress(void);
extern void * TikTokBusinessSDKFuncEndAddress(void);

#pragma mark Callbacks

static void addBooleanElement(const TTSDKCrashReportWriter *const writer, const char *const key, const bool value)
{
    ttsdkjson_addBooleanElement(getJsonContext(writer), key, value);
}

static void addFloatingPointElement(const TTSDKCrashReportWriter *const writer, const char *const key, const double value)
{
    ttsdkjson_addFloatingPointElement(getJsonContext(writer), key, value);
}

static void addIntegerElement(const TTSDKCrashReportWriter *const writer, const char *const key, const int64_t value)
{
    ttsdkjson_addIntegerElement(getJsonContext(writer), key, value);
}

static void addUIntegerElement(const TTSDKCrashReportWriter *const writer, const char *const key, const uint64_t value)
{
    ttsdkjson_addUIntegerElement(getJsonContext(writer), key, value);
}

static void addStringElement(const TTSDKCrashReportWriter *const writer, const char *const key, const char *const value)
{
    ttsdkjson_addStringElement(getJsonContext(writer), key, value, TTSDKJSON_SIZE_AUTOMATIC);
}

static void addTextFileElement(const TTSDKCrashReportWriter *const writer, const char *const key,
                               const char *const filePath)
{
    const int fd = open(filePath, O_RDONLY);
    if (fd < 0) {
        TTSDKLOG_ERROR("Could not open file %s: %s", filePath, strerror(errno));
        return;
    }

    if (ttsdkjson_beginStringElement(getJsonContext(writer), key) != TTSDKJSON_OK) {
        TTSDKLOG_ERROR("Could not start string element");
        goto done;
    }

    char buffer[512];
    int bytesRead;
    for (bytesRead = (int)read(fd, buffer, sizeof(buffer)); bytesRead > 0;
         bytesRead = (int)read(fd, buffer, sizeof(buffer))) {
        if (ttsdkjson_appendStringElement(getJsonContext(writer), buffer, bytesRead) != TTSDKJSON_OK) {
            TTSDKLOG_ERROR("Could not append string element");
            goto done;
        }
    }

done:
    ttsdkjson_endStringElement(getJsonContext(writer));
    close(fd);
}

static void addDataElement(const TTSDKCrashReportWriter *const writer, const char *const key, const char *const value,
                           const int length)
{
    ttsdkjson_addDataElement(getJsonContext(writer), key, value, length);
}

static void beginDataElement(const TTSDKCrashReportWriter *const writer, const char *const key)
{
    ttsdkjson_beginDataElement(getJsonContext(writer), key);
}

static void appendDataElement(const TTSDKCrashReportWriter *const writer, const char *const value, const int length)
{
    ttsdkjson_appendDataElement(getJsonContext(writer), value, length);
}

static void endDataElement(const TTSDKCrashReportWriter *const writer) { ttsdkjson_endDataElement(getJsonContext(writer)); }

static void addUUIDElement(const TTSDKCrashReportWriter *const writer, const char *const key,
                           const unsigned char *const value)
{
    if (value == NULL) {
        ttsdkjson_addNullElement(getJsonContext(writer), key);
    } else {
        char uuidBuffer[37];
        const unsigned char *src = value;
        char *dst = uuidBuffer;
        for (int i = 0; i < 4; i++) {
            *dst++ = g_hexNybbles[(*src >> 4) & 15];
            *dst++ = g_hexNybbles[(*src++) & 15];
        }
        *dst++ = '-';
        for (int i = 0; i < 2; i++) {
            *dst++ = g_hexNybbles[(*src >> 4) & 15];
            *dst++ = g_hexNybbles[(*src++) & 15];
        }
        *dst++ = '-';
        for (int i = 0; i < 2; i++) {
            *dst++ = g_hexNybbles[(*src >> 4) & 15];
            *dst++ = g_hexNybbles[(*src++) & 15];
        }
        *dst++ = '-';
        for (int i = 0; i < 2; i++) {
            *dst++ = g_hexNybbles[(*src >> 4) & 15];
            *dst++ = g_hexNybbles[(*src++) & 15];
        }
        *dst++ = '-';
        for (int i = 0; i < 6; i++) {
            *dst++ = g_hexNybbles[(*src >> 4) & 15];
            *dst++ = g_hexNybbles[(*src++) & 15];
        }

        ttsdkjson_addStringElement(getJsonContext(writer), key, uuidBuffer, (int)(dst - uuidBuffer));
    }
}

static void addJSONElement(const TTSDKCrashReportWriter *const writer, const char *const key,
                           const char *const jsonElement, bool closeLastContainer)
{
    int jsonResult =
        ttsdkjson_addJSONElement(getJsonContext(writer), key, jsonElement, (int)strlen(jsonElement), closeLastContainer);
    if (jsonResult != TTSDKJSON_OK) {
        char errorBuff[100];
        snprintf(errorBuff, sizeof(errorBuff), "Invalid JSON data: %s", ttsdkjson_stringForError(jsonResult));
        ttsdkjson_beginObject(getJsonContext(writer), key);
        ttsdkjson_addStringElement(getJsonContext(writer), TTSDKCrashField_Error, errorBuff, TTSDKJSON_SIZE_AUTOMATIC);
        ttsdkjson_addStringElement(getJsonContext(writer), TTSDKCrashField_JSONData, jsonElement, TTSDKJSON_SIZE_AUTOMATIC);
        ttsdkjson_endContainer(getJsonContext(writer));
    }
}

static void addJSONElementFromFile(const TTSDKCrashReportWriter *const writer, const char *const key,
                                   const char *const filePath, bool closeLastContainer)
{
    ttsdkjson_addJSONFromFile(getJsonContext(writer), key, filePath, closeLastContainer);
}

static void beginObject(const TTSDKCrashReportWriter *const writer, const char *const key)
{
    ttsdkjson_beginObject(getJsonContext(writer), key);
}

static void beginArray(const TTSDKCrashReportWriter *const writer, const char *const key)
{
    ttsdkjson_beginArray(getJsonContext(writer), key);
}

static void endContainer(const TTSDKCrashReportWriter *const writer) { ttsdkjson_endContainer(getJsonContext(writer)); }

static void addTextLinesFromFile(const TTSDKCrashReportWriter *const writer, const char *const key,
                                 const char *const filePath)
{
    char readBuffer[1024];
    TTSDKBufferedReader reader;
    if (!ttsdkfu_openBufferedReader(&reader, filePath, readBuffer, sizeof(readBuffer))) {
        return;
    }
    char buffer[1024];
    beginArray(writer, key);
    {
        for (;;) {
            int length = sizeof(buffer);
            ttsdkfu_readBufferedReaderUntilChar(&reader, '\n', buffer, &length);
            if (length <= 0) {
                break;
            }
            buffer[length - 1] = '\0';
            ttsdkjson_addStringElement(getJsonContext(writer), NULL, buffer, TTSDKJSON_SIZE_AUTOMATIC);
        }
    }
    endContainer(writer);
    ttsdkfu_closeBufferedReader(&reader);
}

static int addJSONData(const char *restrict const data, const int length, void *restrict userData)
{
    TTSDKBufferedWriter *writer = (TTSDKBufferedWriter *)userData;
    const bool success = ttsdkfu_writeBufferedWriter(writer, data, length);
    return success ? TTSDKJSON_OK : TTSDKJSON_ERROR_CANNOT_ADD_DATA;
}

// ============================================================================
#pragma mark - Utility -
// ============================================================================

/** Check if a memory address points to a valid null terminated UTF-8 string.
 *
 * @param address The address to check.
 *
 * @return true if the address points to a string.
 */
static bool isValidString(const void *const address)
{
    if ((void *)address == NULL) {
        return false;
    }

    char buffer[500];
    if ((uintptr_t)address + sizeof(buffer) < (uintptr_t)address) {
        // Wrapped around the address range.
        return false;
    }
    if (!ttsdkmem_copySafely(address, buffer, sizeof(buffer))) {
        return false;
    }
    return ttsdkstring_isNullTerminatedUTF8String(buffer, kMinStringLength, sizeof(buffer));
}

/** Get the backtrace for the specified machine context.
 *
 * This function will choose how to fetch the backtrace based on the crash and
 * machine context. It may store the backtrace in backtraceBuffer unless it can
 * be fetched directly from memory. Do not count on backtraceBuffer containing
 * anything. Always use the return value.
 *
 * @param crash The crash handler context.
 *
 * @param machineContext The machine context.
 *
 * @param cursor The stack cursor to fill.
 *
 * @return True if the cursor was filled.
 */
static bool getStackCursor(const TTSDKCrash_MonitorContext *const crash,
                           const struct TTSDKMachineContext *const machineContext, TTSDKStackCursor *cursor)
{
    if (ttsdkmc_getThreadFromContext(machineContext) == ttsdkmc_getThreadFromContext(crash->offendingMachineContext)) {
        *cursor = *((TTSDKStackCursor *)crash->stackCursor);
        return true;
    }

    ttsdttsdkc_initWithMachineContext(cursor, TTSDKSC_STACK_OVERFLOW_THRESHOLD, machineContext);
    return true;
}

// ============================================================================
#pragma mark - Report Writing -
// ============================================================================

/** Write the contents of a memory location.
 * Also writes meta information about the data.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param address The memory address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
static void writeMemoryContents(const TTSDKCrashReportWriter *const writer, const char *const key, const uintptr_t address,
                                int *limit);

/** Write a string to the report.
 * This will only print the first child of the array.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param objectAddress The object's address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
static void writeNSStringContents(const TTSDKCrashReportWriter *const writer, const char *const key,
                                  const uintptr_t objectAddress, __unused int *limit)
{
    const void *object = (const void *)objectAddress;
    char buffer[200];
    if (ttsdkobjc_copyStringContents(object, buffer, sizeof(buffer))) {
        writer->addStringElement(writer, key, buffer);
    }
}

/** Write a URL to the report.
 * This will only print the first child of the array.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param objectAddress The object's address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
static void writeURLContents(const TTSDKCrashReportWriter *const writer, const char *const key,
                             const uintptr_t objectAddress, __unused int *limit)
{
    const void *object = (const void *)objectAddress;
    char buffer[200];
    if (ttsdkobjc_copyStringContents(object, buffer, sizeof(buffer))) {
        writer->addStringElement(writer, key, buffer);
    }
}

/** Write a date to the report.
 * This will only print the first child of the array.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param objectAddress The object's address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
static void writeDateContents(const TTSDKCrashReportWriter *const writer, const char *const key,
                              const uintptr_t objectAddress, __unused int *limit)
{
    const void *object = (const void *)objectAddress;
    writer->addFloatingPointElement(writer, key, ttsdkobjc_dateContents(object));
}

/** Write a number to the report.
 * This will only print the first child of the array.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param objectAddress The object's address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
static void writeNumberContents(const TTSDKCrashReportWriter *const writer, const char *const key,
                                const uintptr_t objectAddress, __unused int *limit)
{
    const void *object = (const void *)objectAddress;
    writer->addFloatingPointElement(writer, key, ttsdkobjc_numberAsFloat(object));
}

/** Write an array to the report.
 * This will only print the first child of the array.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param objectAddress The object's address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
static void writeArrayContents(const TTSDKCrashReportWriter *const writer, const char *const key,
                               const uintptr_t objectAddress, int *limit)
{
    const void *object = (const void *)objectAddress;
    uintptr_t firstObject;
    if (ttsdkobjc_arrayContents(object, &firstObject, 1) == 1) {
        writeMemoryContents(writer, key, firstObject, limit);
    }
}

/** Write out ivar information about an unknown object.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param objectAddress The object's address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
static void writeUnknownObjectContents(const TTSDKCrashReportWriter *const writer, const char *const key,
                                       const uintptr_t objectAddress, int *limit)
{
    (*limit)--;
    const void *object = (const void *)objectAddress;
    TTSDKObjCIvar ivars[10];
    int8_t s8;
    int16_t s16;
    int sInt;
    int32_t s32;
    int64_t s64;
    uint8_t u8;
    uint16_t u16;
    unsigned int uInt;
    uint32_t u32;
    uint64_t u64;
    float f32;
    double f64;
    bool b;
    void *pointer;

    writer->beginObject(writer, key);
    {
        if (ttsdkobjc_isTaggedPointer(object)) {
            writer->addIntegerElement(writer, "tagged_payload", (int64_t)ttsdkobjc_taggedPointerPayload(object));
        } else {
            const void *class = ttsdkobjc_isaPointer(object);
            int ivarCount = ttsdkobjc_ivarList(class, ivars, sizeof(ivars) / sizeof(*ivars));
            *limit -= ivarCount;
            for (int i = 0; i < ivarCount; i++) {
                TTSDKObjCIvar *ivar = &ivars[i];
                switch (ivar->type[0]) {
                    case 'c':
                        ttsdkobjc_ivarValue(object, ivar->index, &s8);
                        writer->addIntegerElement(writer, ivar->name, s8);
                        break;
                    case 'i':
                        ttsdkobjc_ivarValue(object, ivar->index, &sInt);
                        writer->addIntegerElement(writer, ivar->name, sInt);
                        break;
                    case 's':
                        ttsdkobjc_ivarValue(object, ivar->index, &s16);
                        writer->addIntegerElement(writer, ivar->name, s16);
                        break;
                    case 'l':
                        ttsdkobjc_ivarValue(object, ivar->index, &s32);
                        writer->addIntegerElement(writer, ivar->name, s32);
                        break;
                    case 'q':
                        ttsdkobjc_ivarValue(object, ivar->index, &s64);
                        writer->addIntegerElement(writer, ivar->name, s64);
                        break;
                    case 'C':
                        ttsdkobjc_ivarValue(object, ivar->index, &u8);
                        writer->addUIntegerElement(writer, ivar->name, u8);
                        break;
                    case 'I':
                        ttsdkobjc_ivarValue(object, ivar->index, &uInt);
                        writer->addUIntegerElement(writer, ivar->name, uInt);
                        break;
                    case 'S':
                        ttsdkobjc_ivarValue(object, ivar->index, &u16);
                        writer->addUIntegerElement(writer, ivar->name, u16);
                        break;
                    case 'L':
                        ttsdkobjc_ivarValue(object, ivar->index, &u32);
                        writer->addUIntegerElement(writer, ivar->name, u32);
                        break;
                    case 'Q':
                        ttsdkobjc_ivarValue(object, ivar->index, &u64);
                        writer->addUIntegerElement(writer, ivar->name, u64);
                        break;
                    case 'f':
                        ttsdkobjc_ivarValue(object, ivar->index, &f32);
                        writer->addFloatingPointElement(writer, ivar->name, f32);
                        break;
                    case 'd':
                        ttsdkobjc_ivarValue(object, ivar->index, &f64);
                        writer->addFloatingPointElement(writer, ivar->name, f64);
                        break;
                    case 'B':
                        ttsdkobjc_ivarValue(object, ivar->index, &b);
                        writer->addBooleanElement(writer, ivar->name, b);
                        break;
                    case '*':
                    case '@':
                    case '#':
                    case ':':
                        ttsdkobjc_ivarValue(object, ivar->index, &pointer);
                        writeMemoryContents(writer, ivar->name, (uintptr_t)pointer, limit);
                        break;
                    default:
                        TTSDKLOG_DEBUG("%s: Unknown ivar type [%s]", ivar->name, ivar->type);
                }
            }
        }
    }
    writer->endContainer(writer);
}

static bool isRestrictedClass(const char *name)
{
    if (g_introspectionRules.restrictedClasses != NULL) {
        for (int i = 0; i < g_introspectionRules.restrictedClassesCount; i++) {
            if (ttsdkstring_safeStrcmp(name, g_introspectionRules.restrictedClasses[i]) == 0) {
                return true;
            }
        }
    }
    return false;
}

static void writeZombieIfPresent(const TTSDKCrashReportWriter *const writer, const char *const key,
                                 const uintptr_t address)
{
#if TTSDKCRASH_HAS_OBJC
    const void *object = (const void *)address;
    const char *zombieClassName = ttsdkzombie_className(object);
    if (zombieClassName != NULL) {
        writer->addStringElement(writer, key, zombieClassName);
    }
#endif
}

static bool writeObjCObject(const TTSDKCrashReportWriter *const writer, const uintptr_t address, int *limit)
{
#if TTSDKCRASH_HAS_OBJC
    const void *object = (const void *)address;
    switch (ttsdkobjc_objectType(object)) {
        case TTSDKObjCTypeClass:
            writer->addStringElement(writer, TTSDKCrashField_Type, TTSDKCrashMemType_Class);
            writer->addStringElement(writer, TTSDKCrashField_Class, ttsdkobjc_className(object));
            return true;
        case TTSDKObjCTypeObject: {
            writer->addStringElement(writer, TTSDKCrashField_Type, TTSDKCrashMemType_Object);
            const char *className = ttsdkobjc_objectClassName(object);
            writer->addStringElement(writer, TTSDKCrashField_Class, className);
            if (!isRestrictedClass(className)) {
                switch (ttsdkobjc_objectClassType(object)) {
                    case TTSDKObjCClassTypeString:
                        writeNSStringContents(writer, TTSDKCrashField_Value, address, limit);
                        return true;
                    case TTSDKObjCClassTypeURL:
                        writeURLContents(writer, TTSDKCrashField_Value, address, limit);
                        return true;
                    case TTSDKObjCClassTypeDate:
                        writeDateContents(writer, TTSDKCrashField_Value, address, limit);
                        return true;
                    case TTSDKObjCClassTypeArray:
                        if (*limit > 0) {
                            writeArrayContents(writer, TTSDKCrashField_FirstObject, address, limit);
                        }
                        return true;
                    case TTSDKObjCClassTypeNumber:
                        writeNumberContents(writer, TTSDKCrashField_Value, address, limit);
                        return true;
                    case TTSDKObjCClassTypeDictionary:
                    case TTSDKObjCClassTypeException:
                        // TODO: Implement these.
                        if (*limit > 0) {
                            writeUnknownObjectContents(writer, TTSDKCrashField_Ivars, address, limit);
                        }
                        return true;
                    case TTSDKObjCClassTypeUnknown:
                        if (*limit > 0) {
                            writeUnknownObjectContents(writer, TTSDKCrashField_Ivars, address, limit);
                        }
                        return true;
                }
            }
            break;
        }
        case TTSDKObjCTypeBlock:
            writer->addStringElement(writer, TTSDKCrashField_Type, TTSDKCrashMemType_Block);
            const char *className = ttsdkobjc_objectClassName(object);
            writer->addStringElement(writer, TTSDKCrashField_Class, className);
            return true;
        case TTSDKObjCTypeUnknown:
            break;
    }
#endif

    return false;
}

/** Write the contents of a memory location.
 * Also writes meta information about the data.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param address The memory address.
 *
 * @param limit How many more subreferenced objects to write, if any.
 */
static void writeMemoryContents(const TTSDKCrashReportWriter *const writer, const char *const key, const uintptr_t address,
                                int *limit)
{
    (*limit)--;
    const void *object = (const void *)address;
    writer->beginObject(writer, key);
    {
        writer->addUIntegerElement(writer, TTSDKCrashField_Address, address);
        writeZombieIfPresent(writer, TTSDKCrashField_LastDeallocObject, address);
        if (!writeObjCObject(writer, address, limit)) {
            if (object == NULL) {
                writer->addStringElement(writer, TTSDKCrashField_Type, TTSDKCrashMemType_NullPointer);
            } else if (isValidString(object)) {
                writer->addStringElement(writer, TTSDKCrashField_Type, TTSDKCrashMemType_String);
                writer->addStringElement(writer, TTSDKCrashField_Value, (const char *)object);
            } else {
                writer->addStringElement(writer, TTSDKCrashField_Type, TTSDKCrashMemType_Unknown);
            }
        }
    }
    writer->endContainer(writer);
}

static bool isValidPointer(const uintptr_t address)
{
    if (address == (uintptr_t)NULL) {
        return false;
    }

#if TTSDKCRASH_HAS_OBJC
    if (ttsdkobjc_isTaggedPointer((const void *)address)) {
        if (!ttsdkobjc_isValidTaggedPointer((const void *)address)) {
            return false;
        }
    }
#endif

    return true;
}

static bool isNotableAddress(const uintptr_t address)
{
    if (!isValidPointer(address)) {
        return false;
    }

    const void *object = (const void *)address;

#if TTSDKCRASH_HAS_OBJC
    if (ttsdkzombie_className(object) != NULL) {
        return true;
    }

    if (ttsdkobjc_objectType(object) != TTSDKObjCTypeUnknown) {
        return true;
    }
#endif

    if (isValidString(object)) {
        return true;
    }

    return false;
}

/** Write the contents of a memory location only if it contains notable data.
 * Also writes meta information about the data.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param address The memory address.
 */
static void writeMemoryContentsIfNotable(const TTSDKCrashReportWriter *const writer, const char *const key,
                                         const uintptr_t address)
{
    if (isNotableAddress(address)) {
        int limit = kDefaultMemorySearchDepth;
        writeMemoryContents(writer, key, address, &limit);
    }
}

/** Look for a hex value in a string and try to write whatever it references.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param string The string to search.
 */
static void writeAddressReferencedByString(const TTSDKCrashReportWriter *const writer, const char *const key,
                                           const char *string)
{
    uint64_t address = 0;
    if (string == NULL || !ttsdkstring_extractHexValue(string, (int)strlen(string), &address)) {
        return;
    }

    int limit = kDefaultMemorySearchDepth;
    writeMemoryContents(writer, key, (uintptr_t)address, &limit);
}

#pragma mark Backtrace

/** Write a backtrace to the report.
 *
 * @param writer The writer to write the backtrace to.
 *
 * @param key The object key, if needed.
 *
 * @param stackCursor The stack cursor to read from.
 */
static void writeBacktrace(const TTSDKCrashReportWriter *const writer, const char *const key, TTSDKStackCursor *stackCursor)
{
    writer->beginObject(writer, key);
    {
        writer->beginArray(writer, TTSDKCrashField_Contents);
        {
            while (stackCursor->advanceCursor(stackCursor)) {
                writer->beginObject(writer, NULL);
                {
                    if (stackCursor->symbolicate(stackCursor)) {
                        if (stackCursor->stackEntry.imageName != NULL) {
                            writer->addStringElement(writer, TTSDKCrashField_ObjectName,
                                                     ttsdkfu_lastPathEntry(stackCursor->stackEntry.imageName));
                        }
                        writer->addUIntegerElement(writer, TTSDKCrashField_ObjectAddr,
                                                   stackCursor->stackEntry.imageAddress);
                        if (stackCursor->stackEntry.symbolName != NULL) {
                            writer->addStringElement(writer, TTSDKCrashField_SymbolName,
                                                     stackCursor->stackEntry.symbolName);
                        }
                        writer->addUIntegerElement(writer, TTSDKCrashField_SymbolAddr,
                                                   stackCursor->stackEntry.symbolAddress);
                    }
                    writer->addUIntegerElement(writer, TTSDKCrashField_InstructionAddr, stackCursor->stackEntry.address);
                }
                writer->endContainer(writer);
            }
        }
        writer->endContainer(writer);
        writer->addIntegerElement(writer, TTSDKCrashField_Skipped, 0);
    }
    writer->endContainer(writer);
}

#pragma mark Stack

/** Write a dump of the stack contents to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param machineContext The context to retrieve the stack from.
 *
 * @param isStackOverflow If true, the stack has overflowed.
 */
static void writeStackContents(const TTSDKCrashReportWriter *const writer, const char *const key,
                               const struct TTSDKMachineContext *const machineContext, const bool isStackOverflow)
{
    uintptr_t sp = ttsdkcpu_stackPointer(machineContext);
    if ((void *)sp == NULL) {
        return;
    }

    uintptr_t lowAddress =
        sp + (uintptr_t)(kStackContentsPushedDistance * (int)sizeof(sp) * ttsdkcpu_stackGrowDirection() * -1);
    uintptr_t highAddress =
        sp + (uintptr_t)(kStackContentsPoppedDistance * (int)sizeof(sp) * ttsdkcpu_stackGrowDirection());
    if (highAddress < lowAddress) {
        uintptr_t tmp = lowAddress;
        lowAddress = highAddress;
        highAddress = tmp;
    }
    writer->beginObject(writer, key);
    {
        writer->addStringElement(writer, TTSDKCrashField_GrowDirection, ttsdkcpu_stackGrowDirection() > 0 ? "+" : "-");
        writer->addUIntegerElement(writer, TTSDKCrashField_DumpStart, lowAddress);
        writer->addUIntegerElement(writer, TTSDKCrashField_DumpEnd, highAddress);
        writer->addUIntegerElement(writer, TTSDKCrashField_StackPtr, sp);
        writer->addBooleanElement(writer, TTSDKCrashField_Overflow, isStackOverflow);
        uint8_t stackBuffer[kStackContentsTotalDistance * sizeof(sp)];
        int copyLength = (int)(highAddress - lowAddress);
        if (ttsdkmem_copySafely((void *)lowAddress, stackBuffer, copyLength)) {
            writer->addDataElement(writer, TTSDKCrashField_Contents, (void *)stackBuffer, copyLength);
        } else {
            writer->addStringElement(writer, TTSDKCrashField_Error, "Stack contents not accessible");
        }
    }
    writer->endContainer(writer);
}

/** Write any notable addresses near the stack pointer (above and below).
 *
 * @param writer The writer.
 *
 * @param machineContext The context to retrieve the stack from.
 *
 * @param backDistance The distance towards the beginning of the stack to check.
 *
 * @param forwardDistance The distance past the end of the stack to check.
 */
static void writeNotableStackContents(const TTSDKCrashReportWriter *const writer,
                                      const struct TTSDKMachineContext *const machineContext, const int backDistance,
                                      const int forwardDistance)
{
    uintptr_t sp = ttsdkcpu_stackPointer(machineContext);
    if ((void *)sp == NULL) {
        return;
    }

    uintptr_t lowAddress = sp + (uintptr_t)(backDistance * (int)sizeof(sp) * ttsdkcpu_stackGrowDirection() * -1);
    uintptr_t highAddress = sp + (uintptr_t)(forwardDistance * (int)sizeof(sp) * ttsdkcpu_stackGrowDirection());
    if (highAddress < lowAddress) {
        uintptr_t tmp = lowAddress;
        lowAddress = highAddress;
        highAddress = tmp;
    }
    uintptr_t contentsAsPointer;
    char nameBuffer[40];
    for (uintptr_t address = lowAddress; address < highAddress; address += sizeof(address)) {
        if (ttsdkmem_copySafely((void *)address, &contentsAsPointer, sizeof(contentsAsPointer))) {
            sprintf(nameBuffer, "stack@%p", (void *)address);
            writeMemoryContentsIfNotable(writer, nameBuffer, contentsAsPointer);
        }
    }
}

#pragma mark Registers

/** Write the contents of all regular registers to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param machineContext The context to retrieve the registers from.
 */
static void writeBasicRegisters(const TTSDKCrashReportWriter *const writer, const char *const key,
                                const struct TTSDKMachineContext *const machineContext)
{
    char registerNameBuff[30];
    const char *registerName;
    writer->beginObject(writer, key);
    {
        const int numRegisters = ttsdkcpu_numRegisters();
        for (int reg = 0; reg < numRegisters; reg++) {
            registerName = ttsdkcpu_registerName(reg);
            if (registerName == NULL) {
                snprintf(registerNameBuff, sizeof(registerNameBuff), "r%d", reg);
                registerName = registerNameBuff;
            }
            writer->addUIntegerElement(writer, registerName, ttsdkcpu_registerValue(machineContext, reg));
        }
    }
    writer->endContainer(writer);
}

/** Write the contents of all exception registers to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param machineContext The context to retrieve the registers from.
 */
static void writeExceptionRegisters(const TTSDKCrashReportWriter *const writer, const char *const key,
                                    const struct TTSDKMachineContext *const machineContext)
{
    char registerNameBuff[30];
    const char *registerName;
    writer->beginObject(writer, key);
    {
        const int numRegisters = ttsdkcpu_numExceptionRegisters();
        for (int reg = 0; reg < numRegisters; reg++) {
            registerName = ttsdkcpu_exceptionRegisterName(reg);
            if (registerName == NULL) {
                snprintf(registerNameBuff, sizeof(registerNameBuff), "r%d", reg);
                registerName = registerNameBuff;
            }
            writer->addUIntegerElement(writer, registerName, ttsdkcpu_exceptionRegisterValue(machineContext, reg));
        }
    }
    writer->endContainer(writer);
}

/** Write all applicable registers.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param machineContext The context to retrieve the registers from.
 */
static void writeRegisters(const TTSDKCrashReportWriter *const writer, const char *const key,
                           const struct TTSDKMachineContext *const machineContext)
{
    writer->beginObject(writer, key);
    {
        writeBasicRegisters(writer, TTSDKCrashField_Basic, machineContext);
        if (ttsdkmc_hasValidExceptionRegisters(machineContext)) {
            writeExceptionRegisters(writer, TTSDKCrashField_Exception, machineContext);
        }
    }
    writer->endContainer(writer);
}

/** Write any notable addresses contained in the CPU registers.
 *
 * @param writer The writer.
 *
 * @param machineContext The context to retrieve the registers from.
 */
static void writeNotableRegisters(const TTSDKCrashReportWriter *const writer,
                                  const struct TTSDKMachineContext *const machineContext)
{
    char registerNameBuff[30];
    const char *registerName;
    const int numRegisters = ttsdkcpu_numRegisters();
    for (int reg = 0; reg < numRegisters; reg++) {
        registerName = ttsdkcpu_registerName(reg);
        if (registerName == NULL) {
            snprintf(registerNameBuff, sizeof(registerNameBuff), "r%d", reg);
            registerName = registerNameBuff;
        }
        writeMemoryContentsIfNotable(writer, registerName, (uintptr_t)ttsdkcpu_registerValue(machineContext, reg));
    }
}

#pragma mark Thread-specific

/** Write any notable addresses in the stack or registers to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param machineContext The context to retrieve the registers from.
 */
static void writeNotableAddresses(const TTSDKCrashReportWriter *const writer, const char *const key,
                                  const struct TTSDKMachineContext *const machineContext)
{
    writer->beginObject(writer, key);
    {
        writeNotableRegisters(writer, machineContext);
        writeNotableStackContents(writer, machineContext, kStackNotableSearchBackDistance,
                                  kStackNotableSearchForwardDistance);
    }
    writer->endContainer(writer);
}

/** Write information about a thread to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param crash The crash handler context.
 *
 * @param machineContext The context whose thread to write about.
 *
 * @param shouldWriteNotableAddresses If true, write any notable addresses found.
 */
static void writeThread(const TTSDKCrashReportWriter *const writer, const char *const key,
                        const TTSDKCrash_MonitorContext *const crash, const struct TTSDKMachineContext *const machineContext,
                        const int threadIndex, const bool shouldWriteNotableAddresses)
{
    bool isCrashedThread = ttsdkmc_isCrashedContext(machineContext);
    TTSDKThread thread = ttsdkmc_getThreadFromContext(machineContext);
    TTSDKLOG_DEBUG("Writing thread %x (index %d). is crashed: %d", thread, threadIndex, isCrashedThread);

    TTSDKStackCursor stackCursor;
    bool hasBacktrace = getStackCursor(crash, machineContext, &stackCursor);

    writer->beginObject(writer, key);
    {
        if (hasBacktrace) {
            writeBacktrace(writer, TTSDKCrashField_Backtrace, &stackCursor);
        }
        if (ttsdkmc_canHaveCPUState(machineContext)) {
            writeRegisters(writer, TTSDKCrashField_Registers, machineContext);
        }
        writer->addIntegerElement(writer, TTSDKCrashField_Index, threadIndex);
        const char *name = ttsdkccd_getThreadName(thread);
        if (name != NULL) {
            writer->addStringElement(writer, TTSDKCrashField_Name, name);
        }
        name = ttsdkccd_getQueueName(thread);
        if (name != NULL) {
            writer->addStringElement(writer, TTSDKCrashField_DispatchQueue, name);
        }
        writer->addBooleanElement(writer, TTSDKCrashField_Crashed, isCrashedThread);
        writer->addBooleanElement(writer, TTSDKCrashField_CurrentThread, thread == ttsdkthread_self());
        if (isCrashedThread) {
            writeStackContents(writer, TTSDKCrashField_Stack, machineContext, stackCursor.state.hasGivenUp);
            if (shouldWriteNotableAddresses) {
                writeNotableAddresses(writer, TTSDKCrashField_NotableAddresses, machineContext);
            }
        }
    }
    writer->endContainer(writer);
}

/** Write information about all threads to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param crash The crash handler context.
 */
static void writeAllThreads(const TTSDKCrashReportWriter *const writer, const char *const key,
                            const TTSDKCrash_MonitorContext *const crash, bool writeNotableAddresses)
{
    const struct TTSDKMachineContext *const context = crash->offendingMachineContext;
    TTSDKThread offendingThread = ttsdkmc_getThreadFromContext(context);
    int threadCount = ttsdkmc_getThreadCount(context);
    TTSDKMC_NEW_CONTEXT(machineContext);

    // Fetch info for all threads.
    writer->beginArray(writer, key);
    {
        TTSDKLOG_DEBUG("Writing %d threads.", threadCount);
        for (int i = 0; i < threadCount; i++) {
            TTSDKThread thread = ttsdkmc_getThreadAtIndex(context, i);
            if (thread == offendingThread) {
                writeThread(writer, NULL, crash, context, i, writeNotableAddresses);
            } else {
                ttsdkmc_getContextForThread(thread, machineContext, false);
                writeThread(writer, NULL, crash, machineContext, i, writeNotableAddresses);
            }
        }
    }
    writer->endContainer(writer);
}

#pragma mark Global Report Data

/** Write information about a binary image to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param index Which image to write about.
 */
static void writeBinaryImage(const TTSDKCrashReportWriter *const writer, const char *const key, const int index)
{
    TTSDKBinaryImage image = { 0 };
    if (!ttsdkdl_getBinaryImage(index, &image)) {
        return;
    }

    writer->beginObject(writer, key);
    {
        writer->addUIntegerElement(writer, TTSDKCrashField_ImageAddress, image.address);
        writer->addUIntegerElement(writer, TTSDKCrashField_ImageVmAddress, image.vmAddress);
        writer->addUIntegerElement(writer, TTSDKCrashField_ImageSize, image.size);
        writer->addStringElement(writer, TTSDKCrashField_Name, image.name);
        writer->addUUIDElement(writer, TTSDKCrashField_UUID, image.uuid);
        writer->addIntegerElement(writer, TTSDKCrashField_CPUType, image.cpuType);
        writer->addIntegerElement(writer, TTSDKCrashField_CPUSubType, image.cpuSubType);
        writer->addUIntegerElement(writer, TTSDKCrashField_ImageMajorVersion, image.majorVersion);
        writer->addUIntegerElement(writer, TTSDKCrashField_ImageMinorVersion, image.minorVersion);
        writer->addUIntegerElement(writer, TTSDKCrashField_ImageRevisionVersion, image.revisionVersion);
        if (image.crashInfoMessage != NULL) {
            writer->addStringElement(writer, TTSDKCrashField_ImageCrashInfoMessage, image.crashInfoMessage);
        }
        if (image.crashInfoMessage2 != NULL) {
            writer->addStringElement(writer, TTSDKCrashField_ImageCrashInfoMessage2, image.crashInfoMessage2);
        }
        if (image.crashInfoBacktrace != NULL) {
            writer->addStringElement(writer, TTSDKCrashField_ImageCrashInfoBacktrace, image.crashInfoBacktrace);
        }
        if (image.crashInfoSignature != NULL) {
            writer->addStringElement(writer, TTSDKCrashField_ImageCrashInfoSignature, image.crashInfoSignature);
        }
    }
    writer->endContainer(writer);
}

/** Write information about all images to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 */
static void writeBinaryImages(const TTSDKCrashReportWriter *const writer, const char *const key)
{
    const int imageCount = ttsdkdl_imageCount();

    writer->beginArray(writer, key);
    {
        for (int iImg = 0; iImg < imageCount; iImg++) {
            writeBinaryImage(writer, NULL, iImg);
        }
    }
    writer->endContainer(writer);
}

/** Write information about system memory to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 */
static void writeMemoryInfo(const TTSDKCrashReportWriter *const writer, const char *const key,
                            const TTSDKCrash_MonitorContext *const monitorContext)
{
    writer->beginObject(writer, key);
    {
        writer->addUIntegerElement(writer, TTSDKCrashField_Size, monitorContext->System.memorySize);
        writer->addUIntegerElement(writer, TTSDKCrashField_Usable, monitorContext->System.usableMemory);
        writer->addUIntegerElement(writer, TTSDKCrashField_Free, monitorContext->System.freeMemory);
    }
    writer->endContainer(writer);
}

static inline bool isCrashOfMonitorType(const TTSDKCrash_MonitorContext *const crash, const TTSDKCrashMonitorAPI *monitorAPI)
{
    return ttsdkstring_safeStrcmp(crash->monitorId, ttsdkcm_getMonitorId(monitorAPI)) == 0;
}

/** Write information about the error leading to the crash to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param crash The crash handler context.
 */
static void writeError(const TTSDKCrashReportWriter *const writer, const char *const key,
                       const TTSDKCrash_MonitorContext *const crash)
{
    writer->beginObject(writer, key);
    {
#if TTSDKCRASH_HOST_APPLE
        writer->beginObject(writer, TTSDKCrashField_Mach);
        {
            const char *machExceptionName = ttsdkmach_exceptionName(crash->mach.type);
            const char *machCodeName = crash->mach.code == 0 ? NULL : ttsdkmach_kernelReturnCodeName(crash->mach.code);
            writer->addUIntegerElement(writer, TTSDKCrashField_Exception, (unsigned)crash->mach.type);
            if (machExceptionName != NULL) {
                writer->addStringElement(writer, TTSDKCrashField_ExceptionName, machExceptionName);
            }
            writer->addUIntegerElement(writer, TTSDKCrashField_Code, (unsigned)crash->mach.code);
            if (machCodeName != NULL) {
                writer->addStringElement(writer, TTSDKCrashField_CodeName, machCodeName);
            }
            writer->addUIntegerElement(writer, TTSDKCrashField_Subcode, (size_t)crash->mach.subcode);
        }
        writer->endContainer(writer);
#endif
        writer->beginObject(writer, TTSDKCrashField_Signal);
        {
            const char *sigName = ttsdksignal_signalName(crash->signal.signum);
            const char *sigCodeName = ttsdksignal_signalCodeName(crash->signal.signum, crash->signal.sigcode);
            writer->addUIntegerElement(writer, TTSDKCrashField_Signal, (unsigned)crash->signal.signum);
            if (sigName != NULL) {
                writer->addStringElement(writer, TTSDKCrashField_Name, sigName);
            }
            writer->addUIntegerElement(writer, TTSDKCrashField_Code, (unsigned)crash->signal.sigcode);
            if (sigCodeName != NULL) {
                writer->addStringElement(writer, TTSDKCrashField_CodeName, sigCodeName);
            }
        }
        writer->endContainer(writer);

        writer->addUIntegerElement(writer, TTSDKCrashField_Address, crash->faultAddress);
        if (crash->crashReason != NULL) {
            writer->addStringElement(writer, TTSDKCrashField_Reason, crash->crashReason);
        }

        if (isCrashOfMonitorType(crash, ttsdkcm_nsexception_getAPI())) {
            writer->addStringElement(writer, TTSDKCrashField_Type, TTSDKCrashExcType_NSException);
            writer->beginObject(writer, TTSDKCrashField_NSException);
            {
                writer->addStringElement(writer, TTSDKCrashField_Name, crash->NSException.name);
                writer->addStringElement(writer, TTSDKCrashField_UserInfo, crash->NSException.userInfo);
                writeAddressReferencedByString(writer, TTSDKCrashField_ReferencedObject, crash->crashReason);
            }
            writer->endContainer(writer);
        } else if (isCrashOfMonitorType(crash, ttsdkcm_machexception_getAPI())) {
            writer->addStringElement(writer, TTSDKCrashField_Type, TTSDKCrashExcType_Mach);
        } else if (isCrashOfMonitorType(crash, ttsdkcm_signal_getAPI())) {
            writer->addStringElement(writer, TTSDKCrashField_Type, TTSDKCrashExcType_Signal);
        } else if (isCrashOfMonitorType(crash, ttsdkcm_cppexception_getAPI())) {
            writer->addStringElement(writer, TTSDKCrashField_Type, TTSDKCrashExcType_CPPException);
            writer->beginObject(writer, TTSDKCrashField_CPPException);
            {
                writer->addStringElement(writer, TTSDKCrashField_Name, crash->CPPException.name);
            }
            writer->endContainer(writer);
        } else if (isCrashOfMonitorType(crash, ttsdkcm_deadlock_getAPI())) {
            writer->addStringElement(writer, TTSDKCrashField_Type, TTSDKCrashExcType_Deadlock);
        } else if (isCrashOfMonitorType(crash, ttsdkcm_memory_getAPI())) {
            writer->addStringElement(writer, TTSDKCrashField_Type, TTSDKCrashExcType_MemoryTermination);
            writer->beginObject(writer, TTSDKCrashField_MemoryTermination);
            {
                writer->addStringElement(writer, TTSDKCrashField_MemoryPressure, crash->AppMemory.pressure);
                writer->addStringElement(writer, TTSDKCrashField_MemoryLevel, crash->AppMemory.level);
            }
            writer->endContainer(writer);
        } else if (isCrashOfMonitorType(crash, ttsdkcm_user_getAPI())) {
            writer->addStringElement(writer, TTSDKCrashField_Type, TTSDKCrashExcType_User);
            writer->beginObject(writer, TTSDKCrashField_UserReported);
            {
                writer->addStringElement(writer, TTSDKCrashField_Name, crash->userException.name);
                if (crash->userException.language != NULL) {
                    writer->addStringElement(writer, TTSDKCrashField_Language, crash->userException.language);
                }
                if (crash->userException.lineOfCode != NULL) {
                    writer->addStringElement(writer, TTSDKCrashField_LineOfCode, crash->userException.lineOfCode);
                }
                if (crash->userException.customStackTrace != NULL) {
                    writer->addJSONElement(writer, TTSDKCrashField_Backtrace, crash->userException.customStackTrace, true);
                }
            }
            writer->endContainer(writer);
        } else if (isCrashOfMonitorType(crash, ttsdkcm_system_getAPI()) ||
                   isCrashOfMonitorType(crash, ttsdkcm_appstate_getAPI()) ||
                   isCrashOfMonitorType(crash, ttsdkcm_zombie_getAPI())) {
            TTSDKLOG_ERROR("Crash monitor type %s shouldn't be able to cause events!", crash->monitorId);
        } else {
            TTSDKLOG_WARN("Unknown crash monitor type: %s", crash->monitorId);
        }
    }
    writer->endContainer(writer);
}

/** Write information about app runtime, etc to the report.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param monitorContext The event monitor context.
 */
static void writeAppStats(const TTSDKCrashReportWriter *const writer, const char *const key,
                          const TTSDKCrash_MonitorContext *const monitorContext)
{
    writer->beginObject(writer, key);
    {
        writer->addBooleanElement(writer, TTSDKCrashField_AppActive, monitorContext->AppState.applicationIsActive);
        writer->addBooleanElement(writer, TTSDKCrashField_AppInFG, monitorContext->AppState.applicationIsInForeground);

        writer->addIntegerElement(writer, TTSDKCrashField_LaunchesSinceCrash,
                                  monitorContext->AppState.launchesSinceLastCrash);
        writer->addIntegerElement(writer, TTSDKCrashField_SessionsSinceCrash,
                                  monitorContext->AppState.sessionsSinceLastCrash);
        writer->addFloatingPointElement(writer, TTSDKCrashField_ActiveTimeSinceCrash,
                                        monitorContext->AppState.activeDurationSinceLastCrash);
        writer->addFloatingPointElement(writer, TTSDKCrashField_BGTimeSinceCrash,
                                        monitorContext->AppState.backgroundDurationSinceLastCrash);

        writer->addIntegerElement(writer, TTSDKCrashField_SessionsSinceLaunch,
                                  monitorContext->AppState.sessionsSinceLaunch);
        writer->addFloatingPointElement(writer, TTSDKCrashField_ActiveTimeSinceLaunch,
                                        monitorContext->AppState.activeDurationSinceLaunch);
        writer->addFloatingPointElement(writer, TTSDKCrashField_BGTimeSinceLaunch,
                                        monitorContext->AppState.backgroundDurationSinceLaunch);
    }
    writer->endContainer(writer);
}

/** Write information about this process.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 */
static void writeProcessState(const TTSDKCrashReportWriter *const writer, const char *const key,
                              const TTSDKCrash_MonitorContext *const monitorContext)
{
    writer->beginObject(writer, key);
    {
        if (monitorContext->ZombieException.address != 0) {
            writer->beginObject(writer, TTSDKCrashField_LastDeallocedNSException);
            {
                writer->addUIntegerElement(writer, TTSDKCrashField_Address, monitorContext->ZombieException.address);
                writer->addStringElement(writer, TTSDKCrashField_Name, monitorContext->ZombieException.name);
                writer->addStringElement(writer, TTSDKCrashField_Reason, monitorContext->ZombieException.reason);
                writeAddressReferencedByString(writer, TTSDKCrashField_ReferencedObject,
                                               monitorContext->ZombieException.reason);
            }
            writer->endContainer(writer);
        }
    }
    writer->endContainer(writer);
}

/** Write basic report information.
 *
 * @param writer The writer.
 *
 * @param key The object key, if needed.
 *
 * @param type The report type.
 *
 * @param reportID The report ID.
 */
static void writeReportInfo(const TTSDKCrashReportWriter *const writer, const char *const key, const char *const type,
                            const char *const reportID, const char *const processName)
{
    writer->beginObject(writer, key);
    {
        writer->addStringElement(writer, TTSDKCrashField_Version, TTSDKCRASH_REPORT_VERSION);
        writer->addStringElement(writer, TTSDKCrashField_ID, reportID);
        writer->addStringElement(writer, TTSDKCrashField_ProcessName, processName);
        writer->addIntegerElement(writer, TTSDKCrashField_Timestamp, ttsdkdate_microseconds());
        writer->addStringElement(writer, TTSDKCrashField_Type, type);
    }
    writer->endContainer(writer);
}

static void writeRecrash(const TTSDKCrashReportWriter *const writer, const char *const key, const char *crashReportPath)
{
    writer->addJSONFileElement(writer, key, crashReportPath, true);
}

#pragma mark Setup

/** Prepare a report writer for use.
 *
 * @oaram writer The writer to prepare.
 *
 * @param context JSON writer contextual information.
 */
static void prepareReportWriter(TTSDKCrashReportWriter *const writer, TTSDKJSONEncodeContext *const context)
{
    writer->addBooleanElement = addBooleanElement;
    writer->addFloatingPointElement = addFloatingPointElement;
    writer->addIntegerElement = addIntegerElement;
    writer->addUIntegerElement = addUIntegerElement;
    writer->addStringElement = addStringElement;
    writer->addTextFileElement = addTextFileElement;
    writer->addTextFileLinesElement = addTextLinesFromFile;
    writer->addJSONFileElement = addJSONElementFromFile;
    writer->addDataElement = addDataElement;
    writer->beginDataElement = beginDataElement;
    writer->appendDataElement = appendDataElement;
    writer->endDataElement = endDataElement;
    writer->addUUIDElement = addUUIDElement;
    writer->addJSONElement = addJSONElement;
    writer->beginObject = beginObject;
    writer->beginArray = beginArray;
    writer->endContainer = endContainer;
    writer->context = context;
}

// ============================================================================
#pragma mark - Main API -
// ============================================================================

void ttsdkcrashreport_writeRecrashReport(const TTSDKCrash_MonitorContext *const monitorContext, const char *const path)
{
    char writeBuffer[1024];
    TTSDKBufferedWriter bufferedWriter;
    static char tempPath[TTSDKFU_MAX_PATH_LENGTH];
    strncpy(tempPath, path, sizeof(tempPath) - 10);
    strncpy(tempPath + strlen(tempPath) - 5, ".old", 5);
    TTSDKLOG_INFO("Writing recrash report to %s", path);

    if (rename(path, tempPath) < 0) {
        TTSDKLOG_ERROR("Could not rename %s to %s: %s", path, tempPath, strerror(errno));
    }
    if (!ttsdkfu_openBufferedWriter(&bufferedWriter, path, writeBuffer, sizeof(writeBuffer))) {
        return;
    }

    ttsdkccd_freeze();

    TTSDKJSONEncodeContext jsonContext;
    jsonContext.userData = &bufferedWriter;
    TTSDKCrashReportWriter concreteWriter;
    TTSDKCrashReportWriter *writer = &concreteWriter;
    prepareReportWriter(writer, &jsonContext);

    ttsdkjson_beginEncode(getJsonContext(writer), true, addJSONData, &bufferedWriter);

    writer->beginObject(writer, TTSDKCrashField_Report);
    {
        writeRecrash(writer, TTSDKCrashField_RecrashReport, tempPath);
        ttsdkfu_flushBufferedWriter(&bufferedWriter);
        if (remove(tempPath) < 0) {
            TTSDKLOG_ERROR("Could not remove %s: %s", tempPath, strerror(errno));
        }
        writeReportInfo(writer, TTSDKCrashField_Report, TTSDKCrashReportType_Minimal, monitorContext->eventID,
                        monitorContext->System.processName);
        ttsdkfu_flushBufferedWriter(&bufferedWriter);

        writer->beginObject(writer, TTSDKCrashField_Crash);
        {
            writeError(writer, TTSDKCrashField_Error, monitorContext);
            ttsdkfu_flushBufferedWriter(&bufferedWriter);
            int threadIndex = ttsdkmc_indexOfThread(monitorContext->offendingMachineContext,
                                                 ttsdkmc_getThreadFromContext(monitorContext->offendingMachineContext));
            writeThread(writer, TTSDKCrashField_CrashedThread, monitorContext, monitorContext->offendingMachineContext,
                        threadIndex, false);
            ttsdkfu_flushBufferedWriter(&bufferedWriter);
        }
        writer->endContainer(writer);
    }
    writer->endContainer(writer);

    ttsdkjson_endEncode(getJsonContext(writer));
    ttsdkfu_closeBufferedWriter(&bufferedWriter);
    ttsdkccd_unfreeze();
}

static void writeAppMemoryInfo(const TTSDKCrashReportWriter *const writer, const char *const key,
                               const TTSDKCrash_MonitorContext *const monitorContext)
{
    writer->beginObject(writer, key);
    {
        writer->addUIntegerElement(writer, TTSDKCrashField_MemoryFootprint, monitorContext->AppMemory.footprint);
        writer->addUIntegerElement(writer, TTSDKCrashField_MemoryRemaining, monitorContext->AppMemory.remaining);
        writer->addStringElement(writer, TTSDKCrashField_MemoryPressure, monitorContext->AppMemory.pressure);
        writer->addStringElement(writer, TTSDKCrashField_MemoryLevel, monitorContext->AppMemory.level);
        writer->addUIntegerElement(writer, TTSDKCrashField_MemoryLimit, monitorContext->AppMemory.limit);
        writer->addStringElement(writer, TTSDKCrashField_AppTransitionState, monitorContext->AppMemory.state);
    }
    writer->endContainer(writer);
}

static void writeSystemInfo(const TTSDKCrashReportWriter *const writer, const char *const key,
                            const TTSDKCrash_MonitorContext *const monitorContext)
{
    writer->beginObject(writer, key);
    {
        writer->addStringElement(writer, TTSDKCrashField_SystemName, monitorContext->System.systemName);
        writer->addStringElement(writer, TTSDKCrashField_SystemVersion, monitorContext->System.systemVersion);
        writer->addStringElement(writer, TTSDKCrashField_Machine, monitorContext->System.machine);
        writer->addStringElement(writer, TTSDKCrashField_Model, monitorContext->System.model);
        writer->addStringElement(writer, TTSDKCrashField_KernelVersion, monitorContext->System.kernelVersion);
        writer->addStringElement(writer, TTSDKCrashField_OSVersion, monitorContext->System.osVersion);
        writer->addBooleanElement(writer, TTSDKCrashField_Jailbroken, monitorContext->System.isJailbroken);
        writer->addStringElement(writer, TTSDKCrashField_BootTime, monitorContext->System.bootTime);
        writer->addStringElement(writer, TTSDKCrashField_AppStartTime, monitorContext->System.appStartTime);
        writer->addStringElement(writer, TTSDKCrashField_ExecutablePath, monitorContext->System.executablePath);
        writer->addStringElement(writer, TTSDKCrashField_Executable, monitorContext->System.executableName);
        writer->addStringElement(writer, TTSDKCrashField_BundleID, monitorContext->System.bundleID);
        writer->addStringElement(writer, TTSDKCrashField_BundleName, monitorContext->System.bundleName);
        writer->addStringElement(writer, TTSDKCrashField_BundleVersion, monitorContext->System.bundleVersion);
        writer->addStringElement(writer, TTSDKCrashField_BundleShortVersion, monitorContext->System.bundleShortVersion);
        writer->addStringElement(writer, TTSDKCrashField_AppUUID, monitorContext->System.appID);
        writer->addStringElement(writer, TTSDKCrashField_CPUArch, monitorContext->System.cpuArchitecture);
        writer->addIntegerElement(writer, TTSDKCrashField_CPUType, monitorContext->System.cpuType);
        writer->addIntegerElement(writer, TTSDKCrashField_CPUSubType, monitorContext->System.cpuSubType);
        writer->addIntegerElement(writer, TTSDKCrashField_BinaryCPUType, monitorContext->System.binaryCPUType);
        writer->addIntegerElement(writer, TTSDKCrashField_BinaryCPUSubType, monitorContext->System.binaryCPUSubType);
        writer->addStringElement(writer, TTSDKCrashField_TimeZone, monitorContext->System.timezone);
        writer->addStringElement(writer, TTSDKCrashField_ProcessName, monitorContext->System.processName);
        writer->addIntegerElement(writer, TTSDKCrashField_ProcessID, monitorContext->System.processID);
        writer->addIntegerElement(writer, TTSDKCrashField_ParentProcessID, monitorContext->System.parentProcessID);
        writer->addStringElement(writer, TTSDKCrashField_DeviceAppHash, monitorContext->System.deviceAppHash);
        writer->addStringElement(writer, TTSDKCrashField_BuildType, monitorContext->System.buildType);
        writer->addIntegerElement(writer, TTSDKCrashField_Storage, (int64_t)monitorContext->System.storageSize);
        
        writer->addIntegerElement(writer, TTSDKCrashField_BeginAddress, (int64_t)TikTokBusinessSDKFuncBeginAddress());
        writer->addIntegerElement(writer, TTSDKCrashField_EndAddress, (int64_t)TikTokBusinessSDKFuncEndAddress());

        writeMemoryInfo(writer, TTSDKCrashField_Memory, monitorContext);
        writeAppStats(writer, TTSDKCrashField_AppStats, monitorContext);
        writeAppMemoryInfo(writer, TTSDKCrashField_AppMemory, monitorContext);
    }
    writer->endContainer(writer);
}

static void writeDebugInfo(const TTSDKCrashReportWriter *const writer, const char *const key,
                           const TTSDKCrash_MonitorContext *const monitorContext)
{
    writer->beginObject(writer, key);
    {
        if (monitorContext->consoleLogPath != NULL) {
            addTextLinesFromFile(writer, TTSDKCrashField_ConsoleLog, monitorContext->consoleLogPath);
        }
    }
    writer->endContainer(writer);
}

void ttsdkcrashreport_writeStandardReport(const TTSDKCrash_MonitorContext *const monitorContext, const char *const path)
{
    TTSDKLOG_INFO("Writing crash report to %s", path);
    char writeBuffer[1024];
    TTSDKBufferedWriter bufferedWriter;

    if (!ttsdkfu_openBufferedWriter(&bufferedWriter, path, writeBuffer, sizeof(writeBuffer))) {
        return;
    }

    ttsdkccd_freeze();

    TTSDKJSONEncodeContext jsonContext;
    jsonContext.userData = &bufferedWriter;
    TTSDKCrashReportWriter concreteWriter;
    TTSDKCrashReportWriter *writer = &concreteWriter;
    prepareReportWriter(writer, &jsonContext);

    ttsdkjson_beginEncode(getJsonContext(writer), true, addJSONData, &bufferedWriter);

    writer->beginObject(writer, TTSDKCrashField_Report);
    {
        writeReportInfo(writer, TTSDKCrashField_Report, TTSDKCrashReportType_Standard, monitorContext->eventID,
                        monitorContext->System.processName);
        ttsdkfu_flushBufferedWriter(&bufferedWriter);

        if (!monitorContext->omitBinaryImages) {
            writeBinaryImages(writer, TTSDKCrashField_BinaryImages);
            ttsdkfu_flushBufferedWriter(&bufferedWriter);
        }

        writeProcessState(writer, TTSDKCrashField_ProcessState, monitorContext);
        ttsdkfu_flushBufferedWriter(&bufferedWriter);

        writeSystemInfo(writer, TTSDKCrashField_System, monitorContext);
        ttsdkfu_flushBufferedWriter(&bufferedWriter);

        writer->beginObject(writer, TTSDKCrashField_Crash);
        {
            writeError(writer, TTSDKCrashField_Error, monitorContext);
            ttsdkfu_flushBufferedWriter(&bufferedWriter);
            writeAllThreads(writer, TTSDKCrashField_Threads, monitorContext, g_introspectionRules.enabled);
            ttsdkfu_flushBufferedWriter(&bufferedWriter);
        }
        writer->endContainer(writer);

        if (g_userInfoJSON != NULL) {
            addJSONElement(writer, TTSDKCrashField_User, g_userInfoJSON, false);
            ttsdkfu_flushBufferedWriter(&bufferedWriter);
        } else {
            writer->beginObject(writer, TTSDKCrashField_User);
        }
        if (g_userSectionWriteCallback != NULL) {
            ttsdkfu_flushBufferedWriter(&bufferedWriter);
            if (monitorContext->currentSnapshotUserReported == false) {
                g_userSectionWriteCallback(writer);
            }
        }
        writer->endContainer(writer);
        ttsdkfu_flushBufferedWriter(&bufferedWriter);

        writeDebugInfo(writer, TTSDKCrashField_Debug, monitorContext);
    }
    writer->endContainer(writer);

    ttsdkjson_endEncode(getJsonContext(writer));
    ttsdkfu_closeBufferedWriter(&bufferedWriter);
    ttsdkccd_unfreeze();
}

void ttsdkcrashreport_setUserInfoJSON(const char *const userInfoJSON)
{
    TTSDKLOG_TRACE("Setting userInfoJSON to %p", userInfoJSON);

    pthread_mutex_lock(&g_userInfoMutex);
    if (g_userInfoJSON != NULL) {
        free((void *)g_userInfoJSON);
    }
    if (userInfoJSON == NULL) {
        g_userInfoJSON = NULL;
    } else {
        g_userInfoJSON = strdup(userInfoJSON);
    }
    pthread_mutex_unlock(&g_userInfoMutex);
}

const char *ttsdkcrashreport_getUserInfoJSON(void)
{
    const char *userInfoJSONCopy = NULL;

    pthread_mutex_lock(&g_userInfoMutex);
    if (g_userInfoJSON != NULL) {
        userInfoJSONCopy = strdup(g_userInfoJSON);
    }
    pthread_mutex_unlock(&g_userInfoMutex);

    return userInfoJSONCopy;
}

void ttsdkcrashreport_setIntrospectMemory(bool shouldIntrospectMemory)
{
    g_introspectionRules.enabled = shouldIntrospectMemory;
}

void ttsdkcrashreport_setDoNotIntrospectClasses(const char **doNotIntrospectClasses, int length)
{
    const char **oldClasses = g_introspectionRules.restrictedClasses;
    int oldClassesLength = g_introspectionRules.restrictedClassesCount;
    const char **newClasses = NULL;
    int newClassesLength = 0;

    if (doNotIntrospectClasses != NULL && length > 0) {
        newClassesLength = length;
        newClasses = malloc(sizeof(*newClasses) * (unsigned)newClassesLength);
        if (newClasses == NULL) {
            TTSDKLOG_ERROR("Could not allocate memory");
            return;
        }

        for (int i = 0; i < newClassesLength; i++) {
            newClasses[i] = strdup(doNotIntrospectClasses[i]);
        }
    }

    g_introspectionRules.restrictedClasses = newClasses;
    g_introspectionRules.restrictedClassesCount = newClassesLength;

    if (oldClasses != NULL) {
        for (int i = 0; i < oldClassesLength; i++) {
            free((void *)oldClasses[i]);
        }
        free(oldClasses);
    }
}

void ttsdkcrashreport_setUserSectionWriteCallback(const TTSDKReportWriteCallback userSectionWriteCallback)
{
    TTSDKLOG_TRACE("Set userSectionWriteCallback to %p", userSectionWriteCallback);
    g_userSectionWriteCallback = userSectionWriteCallback;
}
