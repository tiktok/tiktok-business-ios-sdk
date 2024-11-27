//
//  TTSDKCrashReportFields.h
//
//  Created by Karl Stenerud on 2012-10-07.
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

#ifndef HDR_TTSDKCrashReportFields_h
#define HDR_TTSDKCrashReportFields_h

#ifdef __OBJC__
#include <Foundation/Foundation.h>
typedef NSString *TTSDKCrashReportField;
#define TTSDKCRF_CONVERT_STRING(str) @str
#else /* __OBJC__ */
typedef const char *TTSDKCrashReportField;
#define TTSDKCRF_CONVERT_STRING(str) str
#endif /* __OBJC__ */

#ifndef NS_TYPED_ENUM
#define NS_TYPED_ENUM
#endif

#ifndef NS_SWIFT_NAME
#define NS_SWIFT_NAME(_name)
#endif

#define TTSDKCRF_DEFINE_CONSTANT(type, name, swift_name, string) \
    static type const type##_##name NS_SWIFT_NAME(swift_name) = TTSDKCRF_CONVERT_STRING(string);

#ifdef __cplusplus
extern "C" {
#endif

#pragma mark - Report Types -

typedef TTSDKCrashReportField TTSDKCrashReportType NS_TYPED_ENUM NS_SWIFT_NAME(ReportType);

TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashReportType, Minimal, minimal, "minimal")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashReportType, Standard, standard, "standard")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashReportType, Custom, custom, "custom")

#pragma mark - Memory Types -

typedef TTSDKCrashReportField TTSDKCrashMemType NS_TYPED_ENUM NS_SWIFT_NAME(MemoryType);

TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashMemType, Block, block, "objc_block")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashMemType, Class, class, "objc_class")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashMemType, NullPointer, nullPointer, "null_pointer")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashMemType, Object, object, "objc_object")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashMemType, String, string, "string")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashMemType, Unknown, unknown, "unknown")

#pragma mark - Exception Types -

typedef TTSDKCrashReportField TTSDKCrashExcType NS_TYPED_ENUM NS_SWIFT_NAME(ExceptionType);

TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashExcType, CPPException, cppException, "cpp_exception")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashExcType, Deadlock, deadlock, "deadlock")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashExcType, Mach, mach, "mach")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashExcType, NSException, nsException, "nsexception")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashExcType, Signal, signal, "signal")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashExcType, User, user, "user")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashExcType, MemoryTermination, memoryTermination, "memory_termination")

#pragma mark - Common -

typedef TTSDKCrashReportField TTSDKCrashField NS_TYPED_ENUM NS_SWIFT_NAME(CrashField);

TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Address, address, "address")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Contents, contents, "contents")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Exception, exception, "exception")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, FirstObject, firstObject, "first_object")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Index, index, "index")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Ivars, ivars, "ivars")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Language, language, "language")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Name, name, "name")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, UserInfo, userInfo, "userInfo")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, ReferencedObject, referencedObject, "referenced_object")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Type, type, "type")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, UUID, uuid, "uuid")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Value, value, "value")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, MemoryLimit, memoryLimit, "memory_limit")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Error, error, "error")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, JSONData, jsonData, "json_data")

#pragma mark - Notable Address -

TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Class, class, "class")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, LastDeallocObject, lastDeallocObject, "last_deallocated_obj")

#pragma mark - Backtrace -

TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, InstructionAddr, instructionAddr, "instruction_addr")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, LineOfCode, lineOfCode, "line_of_code")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, ObjectAddr, objectAddr, "object_addr")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, ObjectName, objectName, "object_name")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, SymbolAddr, symbolAddr, "symbol_addr")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, SymbolName, symbolName, "symbol_name")

#pragma mark - Stack Dump -

TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, DumpEnd, dumpEnd, "dump_end")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, DumpStart, dumpStart, "dump_start")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, GrowDirection, growDirection, "grow_direction")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Overflow, overflow, "overflow")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, StackPtr, stackPtr, "stack_pointer")

#pragma mark - Thread Dump -

TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Backtrace, backtrace, "backtrace")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Basic, basic, "basic")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Crashed, crashed, "crashed")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, CurrentThread, currentThread, "current_thread")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, DispatchQueue, dispatchQueue, "dispatch_queue")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, NotableAddresses, notableAddresses, "notable_addresses")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Registers, registers, "registers")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Skipped, skipped, "skipped")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Stack, stack, "stack")

#pragma mark - Binary Image -

TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, CPUSubType, cpuSubType, "cpu_subtype")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, CPUType, cpuType, "cpu_type")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, ImageAddress, imageAddress, "image_addr")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, ImageVmAddress, imageVmAddress, "image_vmaddr")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, ImageSize, imageSize, "image_size")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, ImageMajorVersion, imageMajorVersion, "major_version")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, ImageMinorVersion, imageMinorVersion, "minor_version")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, ImageRevisionVersion, imageRevisionVersion, "revision_version")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, ImageCrashInfoMessage, imageCrashInfoMessage, "crash_info_message")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, ImageCrashInfoMessage2, imageCrashInfoMessage2, "crash_info_message2")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, ImageCrashInfoBacktrace, imageCrashInfoBacktrace, "crash_info_backtrace")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, ImageCrashInfoSignature, imageCrashInfoSignature, "crash_info_signature")

#pragma mark - Memory -

TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Free, free, "free")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Usable, usable, "usable")

#pragma mark - Error -

TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Code, code, "code")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, CodeName, codeName, "code_name")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, CPPException, cppException, "cpp_exception")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, ExceptionName, exceptionName, "exception_name")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Mach, mach, "mach")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, NSException, nsException, "nsexception")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Reason, reason, "reason")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Signal, signal, "signal")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Subcode, subcode, "subcode")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, UserReported, userReported, "user_reported")

#pragma mark - Process State -

TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, LastDeallocedNSException, lastDeallocedNSException, "last_dealloced_nsexception")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, ProcessState, processState, "process")

#pragma mark - App Stats -

TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, ActiveTimeSinceCrash, activeTimeSinceCrash, "active_time_since_last_crash")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, ActiveTimeSinceLaunch, activeTimeSinceLaunch, "active_time_since_launch")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, AppActive, appActive, "application_active")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, AppInFG, appInFG, "application_in_foreground")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, BGTimeSinceCrash, bgTimeSinceCrash, "background_time_since_last_crash")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, BGTimeSinceLaunch, bgTimeSinceLaunch, "background_time_since_launch")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, LaunchesSinceCrash, launchesSinceCrash, "launches_since_last_crash")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, SessionsSinceCrash, sessionsSinceCrash, "sessions_since_last_crash")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, SessionsSinceLaunch, sessionsSinceLaunch, "sessions_since_launch")

#pragma mark - Report -

TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Crash, crash, "crash")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Debug, debug, "debug")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Diagnosis, diagnosis, "diagnosis")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, ID, id, "id")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, ProcessName, processName, "process_name")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Report, report, "report")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Timestamp, timestamp, "timestamp")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Version, version, "version")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, AppMemory, appMemory, "app_memory")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, MemoryTermination, memoryTermination, "memory_termination")

TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, CrashedThread, crashedThread, "crashed_thread")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, AppStats, appStats, "application_stats")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, BinaryImages, binaryImages, "binary_images")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, System, system, "system")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Memory, memory, "memory")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Threads, threads, "threads")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, User, user, "user")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, ConsoleLog, consoleLog, "console_log")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Incomplete, incomplete, "incomplete")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, RecrashReport, recrashReport, "recrash_report")

TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, AppStartTime, appStartTime, "app_start_time")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, AppUUID, appUUID, "app_uuid")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, BootTime, bootTime, "boot_time")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, BundleID, bundleID, "CFBundleIdentifier")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, BundleName, bundleName, "CFBundleName")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, BundleShortVersion, bundleShortVersion, "CFBundleShortVersionString")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, BundleVersion, bundleVersion, "CFBundleVersion")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, CPUArch, cpuArch, "cpu_arch")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, BinaryCPUType, binaryCPUType, "binary_cpu_type")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, BinaryCPUSubType, binaryCPUSubType, "binary_cpu_subtype")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, DeviceAppHash, deviceAppHash, "device_app_hash")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Executable, executable, "CFBundleExecutable")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, ExecutablePath, executablePath, "CFBundleExecutablePath")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Jailbroken, jailbroken, "jailbroken")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, KernelVersion, kernelVersion, "kernel_version")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Machine, machine, "machine")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Model, model, "model")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, OSVersion, osVersion, "os_version")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, ParentProcessID, parentProcessID, "parent_process_id")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, ProcessID, processID, "process_id")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Size, size, "size")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, Storage, storage, "storage")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, SystemName, systemName, "system_name")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, SystemVersion, systemVersion, "system_version")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, TimeZone, timeZone, "time_zone")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, BuildType, buildType, "build_type")

TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, MemoryFootprint, memoryFootprint, "memory_footprint")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, MemoryRemaining, memoryRemaining, "memory_remaining")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, MemoryPressure, memoryPressure, "memory_pressure")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, MemoryLevel, memoryLevel, "memory_level")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, AppTransitionState, appTransitionState, "app_transition_state")

TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, BeginAddress, beginAddress, "begin_address")
TTSDKCRF_DEFINE_CONSTANT(TTSDKCrashField, EndAddress, endAddress, "end_address")

#ifdef __cplusplus
}
#endif

#endif  // HDR_TTSDKCrashReportFields_h
