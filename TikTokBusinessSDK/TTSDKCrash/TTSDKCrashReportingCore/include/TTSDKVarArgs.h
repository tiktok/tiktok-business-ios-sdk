//
//  TTSDKVarArgs.h
//
//  Created by Karl Stenerud on 2012-08-19.
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

/* TTSDKVarArgs is a set of macros designed to make dealing with variable arguments
 * easier in Objective-C. All macros assume that the varargs list contains only
 * objective-c objects or object-like structures (assignable to type id).
 *
 * The base macro ttsdkva_iterate_list() iterates over the variable arguments,
 * invoking a block for each argument, until it encounters a terminating nil.
 *
 * The other macros are for convenience when converting to common collections.
 */

/** Block type used by ttsdkva_iterate_list.
 *
 * @param entry The current argument in the vararg list.
 */
typedef void (^TTSDKVA_Block)(id entry);

/**
 * Iterate over a va_list, executing the specified code block for each entry.
 *
 * @param FIRST_ARG_NAME The name of the first argument in the vararg list.
 * @param BLOCK A code block of type TTSDKVA_Block.
 */
#define ttsdkva_iterate_list(FIRST_ARG_NAME, BLOCK)                                                \
    {                                                                                           \
        TTSDKVA_Block ttsdkva_block = BLOCK;                                                          \
        va_list ttsdkva_args;                                                                      \
        va_start(ttsdkva_args, FIRST_ARG_NAME);                                                    \
        for (id ttsdkva_arg = FIRST_ARG_NAME; ttsdkva_arg != nil; ttsdkva_arg = va_arg(ttsdkva_args, id)) { \
            ttsdkva_block(ttsdkva_arg);                                                               \
        }                                                                                       \
        va_end(ttsdkva_args);                                                                      \
    }

/**
 * Convert a variable argument list into an array. An autoreleased
 * NSMutableArray will be created in the current scope with the specified name.
 *
 * @param FIRST_ARG_NAME The name of the first argument in the vararg list.
 * @param ARRAY_NAME The name of the array to create in the current scope.
 */
#define ttsdkva_list_to_nsarray(FIRST_ARG_NAME, ARRAY_NAME) \
    NSMutableArray *ARRAY_NAME = [NSMutableArray array]; \
    ttsdkva_iterate_list(FIRST_ARG_NAME, ^(id entry) {      \
        [ARRAY_NAME addObject:entry];                    \
    })

/**
 * Convert a variable argument list into a dictionary, interpreting the vararg
 * list as object, key, object, key, ...
 * An autoreleased NSMutableDictionary will be created in the current scope with
 * the specified name.
 *
 * @param FIRST_ARG_NAME The name of the first argument in the vararg list.
 * @param DICT_NAME The name of the dictionary to create in the current scope.
 */
#define ttsdkva_list_to_nsdictionary(FIRST_ARG_NAME, DICT_NAME)           \
    NSMutableDictionary *DICT_NAME = [NSMutableDictionary dictionary]; \
    {                                                                  \
        __block id ttsdkva_object = nil;                                  \
        ttsdkva_iterate_list(FIRST_ARG_NAME, ^(id entry) {                \
            if (ttsdkva_object == nil) {                                  \
                ttsdkva_object = entry;                                   \
            } else {                                                   \
                [DICT_NAME setObject:ttsdkva_object forKey:entry];        \
                ttsdkva_object = nil;                                     \
            }                                                          \
        });                                                            \
    }
