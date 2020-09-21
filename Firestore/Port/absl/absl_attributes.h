/*
 * Copyright 2017 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// Various macros for C++ attributes
// Most macros here are exposing GCC or Clang features, and are stubbed out for
// other compilers.
// GCC attributes documentation:
// https://gcc.gnu.org/onlinedocs/gcc-4.7.0/gcc/Function-Attributes.html
// https://gcc.gnu.org/onlinedocs/gcc-4.7.0/gcc/Variable-Attributes.html
// https://gcc.gnu.org/onlinedocs/gcc-4.7.0/gcc/Type-Attributes.html
//
// Most attributes in this file are already supported by GCC 4.7.
// However, some of them are not supported in older version of Clang.
// Thus, we check __has_attribute() first. If the check fails, we check if we
// are on GCC and assume the attribute exists on GCC (which is verified on GCC
// 4.7).
//
// For sanitizer-related attributes, define the following macros
// using -D along with the given value for -fsanitize:
// - ADDRESS_SANITIZER with -fsanitize=address (GCC 4.8+, Clang)
// - MEMORY_SANITIZER with -fsanitize=memory (Clang)
// - THREAD_SANITIZER with -fsanitize=thread (GCC 4.8+, Clang)
// - UNDEFINED_BEHAVIOR_SANITIZER with -fsanitize=undefined (GCC 4.9+, Clang)
// - CONTROL_FLOW_INTEGRITY with -fsanitize=cfi (Clang)
// Since these are only supported by GCC and Clang now, we only check for
// __GNUC__ (GCC or Clang) and the above macros.
#ifndef THIRD_PARTY_ABSL_BASE_ATTRIBUTES_H_
#define THIRD_PARTY_ABSL_BASE_ATTRIBUTES_H_

// ABSL_HAVE_ATTRIBUTE is a function-like feature checking macro.
// It's a wrapper around __has_attribute, which is defined by GCC 5+ and Clang.
// It evaluates to a nonzero constant integer if the attribute is supported
// or 0 if not.
// It evaluates to zero if __has_attribute is not defined by the compiler.
// GCC: https://gcc.gnu.org/gcc-5/changes.html
// Clang: https://clang.llvm.org/docs/LanguageExtensions.html
#ifdef __has_attribute
#define ABSL_HAVE_ATTRIBUTE(x) __has_attribute(x)
#else
#define ABSL_HAVE_ATTRIBUTE(x) 0
#endif

// ABSL_HAVE_CPP_ATTRIBUTE is a function-like feature checking macro that
// accepts C++11 style attributes. It's a wrapper around __has_cpp_attribute,
// defined by ISO C++ SD-6
// (http://en.cppreference.com/w/cpp/experimental/feature_test). If we don't
// find __has_cpp_attribute, will evaluate to 0.
#if defined(__cplusplus) && defined(__has_cpp_attribute)
// NOTE: requiring __cplusplus above should not be necessary, but
// works around https://bugs.llvm.org/show_bug.cgi?id=23435.
#define ABSL_HAVE_CPP_ATTRIBUTE(x) __has_cpp_attribute(x)
#else
#define ABSL_HAVE_CPP_ATTRIBUTE(x) 0
#endif

// -----------------------------------------------------------------------------
// Function Attributes
// -----------------------------------------------------------------------------
// GCC: https://gcc.gnu.org/onlinedocs/gcc/Function-Attributes.html
// Clang: https://clang.llvm.org/docs/AttributeReference.html

// PRINTF_ATTRIBUTE, SCANF_ATTRIBUTE
// Tell the compiler to do printf format std::string checking if the
// compiler supports it; see the 'format' attribute in
// <http://gcc.gnu.org/onlinedocs/gcc-4.7.0/gcc/Function-Attributes.html>.
//
// N.B.: As the GCC manual states, "[s]ince non-static C++ methods
// have an implicit 'this' argument, the arguments of such methods
// should be counted from two, not one."
#if ABSL_HAVE_ATTRIBUTE(format) || (defined(__GNUC__) && !defined(__clang__))
#define ABSL_PRINTF_ATTRIBUTE(string_index, first_to_check) \
  __attribute__((__format__(__printf__, string_index, first_to_check)))
#define ABSL_SCANF_ATTRIBUTE(string_index, first_to_check) \
  __attribute__((__format__(__scanf__, string_index, first_to_check)))
#else
#define ABSL_PRINTF_ATTRIBUTE(string_index, first_to_check)
#define ABSL_SCANF_ATTRIBUTE(string_index, first_to_check)
#endif

// To be deleted macros. All macros are going te be renamed with ABSL_ prefix.
#if ABSL_HAVE_ATTRIBUTE(format) || (defined(__GNUC__) && !defined(__clang__))
#define PRINTF_ATTRIBUTE(string_index, first_to_check) \
  __attribute__((__format__(__printf__, string_index, first_to_check)))
#define SCANF_ATTRIBUTE(string_index, first_to_check) \
  __attribute__((__format__(__scanf__, string_index, first_to_check)))
#else
#define PRINTF_ATTRIBUTE(string_index, first_to_check)
#define SCANF_ATTRIBUTE(string_index, first_to_check)
#endif

// ATTRIBUTE_ALWAYS_INLINE, ATTRIBUTE_NOINLINE
// For functions we want to force inline or not inline.
// Introduced in gcc 3.1.
#if ABSL_HAVE_ATTRIBUTE(always_inline) || (defined(__GNUC__) && !defined(__clang__))
#define ABSL_ATTRIBUTE_ALWAYS_INLINE __attribute__((always_inline))
#define ABSL_HAVE_ATTRIBUTE_ALWAYS_INLINE 1
#else
#define ABSL_ATTRIBUTE_ALWAYS_INLINE
#endif

#if ABSL_HAVE_ATTRIBUTE(noinline) || (defined(__GNUC__) && !defined(__clang__))
#define ABSL_ATTRIBUTE_NOINLINE __attribute__((noinline))
#define ABSL_HAVE_ATTRIBUTE_NOINLINE 1
#else
#define ABSL_ATTRIBUTE_NOINLINE
#endif

// To be deleted macros. All macros are going te be renamed with ABSL_ prefix.
#if ABSL_HAVE_ATTRIBUTE(always_inline) || (defined(__GNUC__) && !defined(__clang__))
#define ATTRIBUTE_ALWAYS_INLINE __attribute__((always_inline))
#define HAVE_ATTRIBUTE_ALWAYS_INLINE 1
#else
#define ATTRIBUTE_ALWAYS_INLINE
#endif

#if ABSL_HAVE_ATTRIBUTE(noinline) || (defined(__GNUC__) && !defined(__clang__))
#define ATTRIBUTE_NOINLINE __attribute__((noinline))
#define HAVE_ATTRIBUTE_NOINLINE 1
#else
#define ATTRIBUTE_NOINLINE
#endif

// ATTRIBUTE_NO_TAIL_CALL
// Prevent the compiler from optimizing away stack frames for functions which
// end in a call to another function.
#if ABSL_HAVE_ATTRIBUTE(disable_tail_calls)
#define ABSL_HAVE_ATTRIBUTE_NO_TAIL_CALL 1
#define ABSL_ATTRIBUTE_NO_TAIL_CALL __attribute__((disable_tail_calls))
#elif defined(__GNUC__) && !defined(__clang__)
#define ABSL_HAVE_ATTRIBUTE_NO_TAIL_CALL 1
#define ABSL_ATTRIBUTE_NO_TAIL_CALL __attribute__((optimize("no-optimize-sibling-calls")))
#else
#define ABSL_ATTRIBUTE_NO_TAIL_CALL
#define ABSL_HAVE_ATTRIBUTE_NO_TAIL_CALL 0
#endif

// To be deleted macros. All macros are going te be renamed with ABSL_ prefix.
#if ABSL_HAVE_ATTRIBUTE(disable_tail_calls)
#define HAVE_ATTRIBUTE_NO_TAIL_CALL 1
#define ATTRIBUTE_NO_TAIL_CALL __attribute__((disable_tail_calls))
#elif defined(__GNUC__) && !defined(__clang__)
#define HAVE_ATTRIBUTE_NO_TAIL_CALL 1
#define ATTRIBUTE_NO_TAIL_CALL __attribute__((optimize("no-optimize-sibling-calls")))
#else
#define ATTRIBUTE_NO_TAIL_CALL
#define HAVE_ATTRIBUTE_NO_TAIL_CALL 0
#endif

// ATTRIBUTE_WEAK
// For weak functions
#if ABSL_HAVE_ATTRIBUTE(weak) || (defined(__GNUC__) && !defined(__clang__))
#undef ABSL_ATTRIBUTE_WEAK
#define ABSL_ATTRIBUTE_WEAK __attribute__((weak))
#define ABSL_HAVE_ATTRIBUTE_WEAK 1
#else
#define ABSL_ATTRIBUTE_WEAK
#define ABSL_HAVE_ATTRIBUTE_WEAK 0
#endif

// To be deleted macros. All macros are going te be renamed with ABSL_ prefix.
#if ABSL_HAVE_ATTRIBUTE(weak) || (defined(__GNUC__) && !defined(__clang__))
#undef ATTRIBUTE_WEAK
#define ATTRIBUTE_WEAK __attribute__((weak))
#define HAVE_ATTRIBUTE_WEAK 1
#else
#define ATTRIBUTE_WEAK
#define HAVE_ATTRIBUTE_WEAK 0
#endif

// ATTRIBUTE_NONNULL
// Tell the compiler either that a particular function parameter
// should be a non-null pointer, or that all pointer arguments should
// be non-null.
//
// Note: As the GCC manual states, "[s]ince non-static C++ methods
// have an implicit 'this' argument, the arguments of such methods
// should be counted from two, not one."
//
// Args are indexed starting at 1.
// For non-static class member functions, the implicit "this" argument
// is arg 1, and the first explicit argument is arg 2.
// For static class member functions, there is no implicit "this", and
// the first explicit argument is arg 1.
//
//   /* arg_a cannot be null, but arg_b can */
//   void Function(void* arg_a, void* arg_b) ATTRIBUTE_NONNULL(1);
//
//   class C {
//     /* arg_a cannot be null, but arg_b can */
//     void Method(void* arg_a, void* arg_b) ATTRIBUTE_NONNULL(2);
//
//     /* arg_a cannot be null, but arg_b can */
//     static void StaticMethod(void* arg_a, void* arg_b) ATTRIBUTE_NONNULL(1);
//   };
//
// If no arguments are provided, then all pointer arguments should be non-null.
//
//  /* No pointer arguments may be null. */
//  void Function(void* arg_a, void* arg_b, int arg_c) ATTRIBUTE_NONNULL();
//
// NOTE: The GCC nonnull attribute actually accepts a list of arguments, but
// ATTRIBUTE_NONNULL does not.
#if ABSL_HAVE_ATTRIBUTE(nonnull) || (defined(__GNUC__) && !defined(__clang__))
#define ABSL_ATTRIBUTE_NONNULL(arg_index) __attribute__((nonnull(arg_index)))
#else
#define ABSL_ATTRIBUTE_NONNULL(...)
#endif

// To be deleted macros. All macros are going te be renamed with ABSL_ prefix.
#if ABSL_HAVE_ATTRIBUTE(nonnull) || (defined(__GNUC__) && !defined(__clang__))
#define ATTRIBUTE_NONNULL(arg_index) __attribute__((nonnull(arg_index)))
#else
#define ATTRIBUTE_NONNULL(...)
#endif

// ATTRIBUTE_NORETURN
// Tell the compiler that a given function never returns
#if ABSL_HAVE_ATTRIBUTE(noreturn) || (defined(__GNUC__) && !defined(__clang__))
#define ABSL_ATTRIBUTE_NORETURN __attribute__((noreturn))
#elif defined(_MSC_VER)
#define ABSL_ATTRIBUTE_NORETURN __declspec(noreturn)
#else
#define ABSL_ATTRIBUTE_NORETURN
#endif

// To be deleted macros. All macros are going te be renamed with ABSL_ prefix.
#if ABSL_HAVE_ATTRIBUTE(noreturn) || (defined(__GNUC__) && !defined(__clang__))
#define ATTRIBUTE_NORETURN __attribute__((noreturn))
#elif defined(_MSC_VER)
#define ATTRIBUTE_NORETURN __declspec(noreturn)
#else
#define ATTRIBUTE_NORETURN
#endif

// ATTRIBUTE_NO_SANITIZE_ADDRESS
// Tell AddressSanitizer (or other memory testing tools) to ignore a given
// function. Useful for cases when a function reads random locations on stack,
// calls _exit from a cloned subprocess, deliberately accesses buffer
// out of bounds or does other scary things with memory.
// NOTE: GCC supports AddressSanitizer(asan) since 4.8.
// https://gcc.gnu.org/gcc-4.8/changes.html
#if defined(__GNUC__) && defined(ADDRESS_SANITIZER)
#define ABSL_ATTRIBUTE_NO_SANITIZE_ADDRESS __attribute__((no_sanitize_address))
#else
#define ABSL_ATTRIBUTE_NO_SANITIZE_ADDRESS
#endif

// To be deleted macros. All macros are going te be renamed with ABSL_ prefix.
#if defined(__GNUC__) && defined(ADDRESS_SANITIZER)
#define ATTRIBUTE_NO_SANITIZE_ADDRESS __attribute__((no_sanitize_address))
#else
#define ATTRIBUTE_NO_SANITIZE_ADDRESS
#endif

// ATTRIBUTE_NO_SANITIZE_MEMORY
// Tell MemorySanitizer to relax the handling of a given function. All "Use of
// uninitialized value" warnings from such functions will be suppressed, and all
// values loaded from memory will be considered fully initialized.
// This is similar to the ADDRESS_SANITIZER attribute above, but deals with
// initializedness rather than addressability issues.
// NOTE: MemorySanitizer(msan) is supported by Clang but not GCC.
#if defined(__GNUC__) && defined(MEMORY_SANITIZER)
#define ABSL_ATTRIBUTE_NO_SANITIZE_MEMORY __attribute__((no_sanitize_memory))
#else
#define ABSL_ATTRIBUTE_NO_SANITIZE_MEMORY
#endif

// To be deleted macros. All macros are going te be renamed with ABSL_ prefix.
#if defined(__GNUC__) && defined(MEMORY_SANITIZER)
#define ATTRIBUTE_NO_SANITIZE_MEMORY __attribute__((no_sanitize_memory))
#else
#define ATTRIBUTE_NO_SANITIZE_MEMORY
#endif

// ATTRIBUTE_NO_SANITIZE_THREAD
// Tell ThreadSanitizer to not instrument a given function.
// If you are adding this attribute, please cc dynamic-tools@ on the cl.
// NOTE: GCC supports ThreadSanitizer(tsan) since 4.8.
// https://gcc.gnu.org/gcc-4.8/changes.html
#if defined(__GNUC__) && defined(THREAD_SANITIZER)
#define ABSL_ATTRIBUTE_NO_SANITIZE_THREAD __attribute__((no_sanitize_thread))
#else
#define ABSL_ATTRIBUTE_NO_SANITIZE_THREAD
#endif

// To be deleted macros. All macros are going te be renamed with ABSL_ prefix.
#if defined(__GNUC__) && defined(THREAD_SANITIZER)
#define ATTRIBUTE_NO_SANITIZE_THREAD __attribute__((no_sanitize_thread))
#else
#define ATTRIBUTE_NO_SANITIZE_THREAD
#endif

// ATTRIBUTE_NO_SANITIZE_UNDEFINED
// Tell UndefinedSanitizer to ignore a given function. Useful for cases
// where certain behavior (eg. devision by zero) is being used intentionally.
// NOTE: GCC supports UndefinedBehaviorSanitizer(ubsan) since 4.9.
// https://gcc.gnu.org/gcc-4.9/changes.html
#if defined(__GNUC__) && defined(UNDEFINED_BEHAVIOR_SANITIZER)
#define ABSL_ATTRIBUTE_NO_SANITIZE_UNDEFINED __attribute__((no_sanitize("undefined")))
#else
#define ABSL_ATTRIBUTE_NO_SANITIZE_UNDEFINED
#endif

// To be deleted macros. All macros are going te be renamed with ABSL_ prefix.
#if defined(__GNUC__) && defined(UNDEFINED_BEHAVIOR_SANITIZER)
#define ATTRIBUTE_NO_SANITIZE_UNDEFINED __attribute__((no_sanitize("undefined")))
#else
#define ATTRIBUTE_NO_SANITIZE_UNDEFINED
#endif

// ATTRIBUTE_NO_SANITIZE_CFI
// Tell ControlFlowIntegrity sanitizer to not instrument a given function.
#if defined(__GNUC__) && defined(CONTROL_FLOW_INTEGRITY)
#define ABSL_ATTRIBUTE_NO_SANITIZE_CFI __attribute__((no_sanitize("cfi")))
#else
#define ABSL_ATTRIBUTE_NO_SANITIZE_CFI
#endif

// To be deleted macros. All macros are going te be renamed with ABSL_ prefix.
#if defined(__GNUC__) && defined(CONTROL_FLOW_INTEGRITY)
#define ATTRIBUTE_NO_SANITIZE_CFI __attribute__((no_sanitize("cfi")))
#else
#define ATTRIBUTE_NO_SANITIZE_CFI
#endif

// ATTRIBUTE_SECTION
// Labeled sections are not supported on Darwin/iOS.
#ifdef ABSL_HAVE_ATTRIBUTE_SECTION
#error ABSL_HAVE_ATTRIBUTE_SECTION cannot be directly set
#elif (ABSL_HAVE_ATTRIBUTE(section) || (defined(__GNUC__) && !defined(__clang__))) && \
    !(defined(__APPLE__) && defined(__MACH__))
#define ABSL_HAVE_ATTRIBUTE_SECTION 1
//
// Tell the compiler/linker to put a given function into a section and define
// "__start_ ## name" and "__stop_ ## name" symbols to bracket the section.
// This functionality is supported by GNU linker.
// Any function with ATTRIBUTE_SECTION must not be inlined, or it will
// be placed into whatever section its caller is placed into.
//
#ifndef ABSL_ATTRIBUTE_SECTION
#define ABSL_ATTRIBUTE_SECTION(name) __attribute__((section(#name))) __attribute__((noinline))
#endif

// To be deleted macros. All macros are going te be renamed with ABSL_ prefix.
#ifndef ATTRIBUTE_SECTION
#define ATTRIBUTE_SECTION(name) __attribute__((section(#name))) __attribute__((noinline))
#endif

// Tell the compiler/linker to put a given variable into a section and define
// "__start_ ## name" and "__stop_ ## name" symbols to bracket the section.
// This functionality is supported by GNU linker.
#ifndef ABSL_ATTRIBUTE_SECTION_VARIABLE
#define ABSL_ATTRIBUTE_SECTION_VARIABLE(name) __attribute__((section(#name)))
#endif

// To be deleted macros. All macros are going te be renamed with ABSL_ prefix.
#ifndef ATTRIBUTE_SECTION_VARIABLE
#define ATTRIBUTE_SECTION_VARIABLE(name) __attribute__((section(#name)))
#endif

//
// Weak section declaration to be used as a global declaration
// for ATTRIBUTE_SECTION_START|STOP(name) to compile and link
// even without functions with ATTRIBUTE_SECTION(name).
// DEFINE_ATTRIBUTE_SECTION should be in the exactly one file; it's
// a no-op on ELF but not on Mach-O.
//
#ifndef ABSL_DECLARE_ATTRIBUTE_SECTION_VARS
#define ABSL_DECLARE_ATTRIBUTE_SECTION_VARS(name) \
  extern char __start_##name[] ATTRIBUTE_WEAK;    \
  extern char __stop_##name[] ATTRIBUTE_WEAK
#endif
#ifndef ABSL_DEFINE_ATTRIBUTE_SECTION_VARS
#define ABSL_INIT_ATTRIBUTE_SECTION_VARS(name)
#define ABSL_DEFINE_ATTRIBUTE_SECTION_VARS(name)
#endif

// To be deleted macros. All macros are going te be renamed with ABSL_ prefix.
#ifndef DECLARE_ATTRIBUTE_SECTION_VARS
#define DECLARE_ATTRIBUTE_SECTION_VARS(name)   \
  extern char __start_##name[] ATTRIBUTE_WEAK; \
  extern char __stop_##name[] ATTRIBUTE_WEAK
#endif
#ifndef DEFINE_ATTRIBUTE_SECTION_VARS
#define INIT_ATTRIBUTE_SECTION_VARS(name)
#define DEFINE_ATTRIBUTE_SECTION_VARS(name)
#endif

//
// Return void* pointers to start/end of a section of code with
// functions having ATTRIBUTE_SECTION(name).
// Returns 0 if no such functions exits.
// One must DECLARE_ATTRIBUTE_SECTION_VARS(name) for this to compile and link.
//
#define ABSL_ATTRIBUTE_SECTION_START(name) (reinterpret_cast<void *>(__start_##name))
#define ABSL_ATTRIBUTE_SECTION_STOP(name) (reinterpret_cast<void *>(__stop_##name))

// To be deleted macros. All macros are going te be renamed with ABSL_ prefix.
#define ATTRIBUTE_SECTION_START(name) (reinterpret_cast<void *>(__start_##name))
#define ATTRIBUTE_SECTION_STOP(name) (reinterpret_cast<void *>(__stop_##name))

#else  // !ABSL_HAVE_ATTRIBUTE_SECTION

#define ABSL_HAVE_ATTRIBUTE_SECTION 0

// provide dummy definitions
#define ABSL_ATTRIBUTE_SECTION(name)
#define ABSL_ATTRIBUTE_SECTION_VARIABLE(name)
#define ABSL_INIT_ATTRIBUTE_SECTION_VARS(name)
#define ABSL_DEFINE_ATTRIBUTE_SECTION_VARS(name)
#define ABSL_DECLARE_ATTRIBUTE_SECTION_VARS(name)
#define ABSL_ATTRIBUTE_SECTION_START(name) (reinterpret_cast<void *>(0))
#define ABSL_ATTRIBUTE_SECTION_STOP(name) (reinterpret_cast<void *>(0))

// To be deleted macros. All macros are going te be renamed with ABSL_ prefix.
#define ATTRIBUTE_SECTION(name)
#define ATTRIBUTE_SECTION_VARIABLE(name)
#define INIT_ATTRIBUTE_SECTION_VARS(name)
#define DEFINE_ATTRIBUTE_SECTION_VARS(name)
#define DECLARE_ATTRIBUTE_SECTION_VARS(name)
#define ATTRIBUTE_SECTION_START(name) (reinterpret_cast<void *>(0))
#define ATTRIBUTE_SECTION_STOP(name) (reinterpret_cast<void *>(0))

#endif  // ATTRIBUTE_SECTION

// ATTRIBUTE_STACK_ALIGN_FOR_OLD_LIBC
// Support for aligning the stack on 32-bit x86.
#if ABSL_HAVE_ATTRIBUTE(force_align_arg_pointer) || (defined(__GNUC__) && !defined(__clang__))
#if defined(__i386__)
#define ABSL_ATTRIBUTE_STACK_ALIGN_FOR_OLD_LIBC __attribute__((force_align_arg_pointer))
#define ABSL_REQUIRE_STACK_ALIGN_TRAMPOLINE (0)
#elif defined(__x86_64__)
#define ABSL_REQUIRE_STACK_ALIGN_TRAMPOLINE (1)
#define ABSL_ATTRIBUTE_STACK_ALIGN_FOR_OLD_LIBC
#else  // !__i386__ && !__x86_64
#define ABSL_REQUIRE_STACK_ALIGN_TRAMPOLINE (0)
#define ABSL_ATTRIBUTE_STACK_ALIGN_FOR_OLD_LIBC
#endif  // __i386__
#else
#define ABSL_ATTRIBUTE_STACK_ALIGN_FOR_OLD_LIBC
#define ABSL_REQUIRE_STACK_ALIGN_TRAMPOLINE (0)
#endif

// To be deleted macros. All macros are going te be renamed with ABSL_ prefix.
#if ABSL_HAVE_ATTRIBUTE(force_align_arg_pointer) || (defined(__GNUC__) && !defined(__clang__))
#if defined(__i386__)
#define ATTRIBUTE_STACK_ALIGN_FOR_OLD_LIBC __attribute__((force_align_arg_pointer))
#define REQUIRE_STACK_ALIGN_TRAMPOLINE (0)
#elif defined(__x86_64__)
#define REQUIRE_STACK_ALIGN_TRAMPOLINE (1)
#define ATTRIBUTE_STACK_ALIGN_FOR_OLD_LIBC
#else  // !__i386__ && !__x86_64
#define REQUIRE_STACK_ALIGN_TRAMPOLINE (0)
#define ATTRIBUTE_STACK_ALIGN_FOR_OLD_LIBC
#endif  // __i386__
#else
#define ATTRIBUTE_STACK_ALIGN_FOR_OLD_LIBC
#define REQUIRE_STACK_ALIGN_TRAMPOLINE (0)
#endif

// MUST_USE_RESULT
// Tell the compiler to warn about unused return values for functions declared
// with this macro. The macro must appear as the very first part of a function
// declaration or definition:
//
//   MUST_USE_RESULT Sprocket* AllocateSprocket();
//
// This placement has the broadest compatibility with GCC, Clang, and MSVC, with
// both defs and decls, and with GCC-style attributes, MSVC declspec, and C++11
// attributes. Note: past advice was to place the macro after the argument list.
#if ABSL_HAVE_ATTRIBUTE(warn_unused_result) || (defined(__GNUC__) && !defined(__clang__))
#define ABSL_MUST_USE_RESULT __attribute__((warn_unused_result))
#else
#define ABSL_MUST_USE_RESULT
#endif

// To be deleted macros. All macros are going te be renamed with ABSL_ prefix.
#if ABSL_HAVE_ATTRIBUTE(warn_unused_result) || (defined(__GNUC__) && !defined(__clang__))
#define MUST_USE_RESULT __attribute__((warn_unused_result))
#else
#define MUST_USE_RESULT
#endif

// ATTRIBUTE_HOT, ATTRIBUTE_COLD
// Tell GCC that a function is hot or cold. GCC can use this information to
// improve static analysis, i.e. a conditional branch to a cold function
// is likely to be not-taken.
// This annotation is used for function declarations, e.g.:
//   int foo() ATTRIBUTE_HOT;
#if ABSL_HAVE_ATTRIBUTE(hot) || (defined(__GNUC__) && !defined(__clang__))
#define ABSL_ATTRIBUTE_HOT __attribute__((hot))
#else
#define ABSL_ATTRIBUTE_HOT
#endif

#if ABSL_HAVE_ATTRIBUTE(cold) || (defined(__GNUC__) && !defined(__clang__))
#define ABSL_ATTRIBUTE_COLD __attribute__((cold))
#else
#define ABSL_ATTRIBUTE_COLD
#endif

// To be deleted macros. All macros are going te be renamed with ABSL_ prefix.
#if ABSL_HAVE_ATTRIBUTE(hot) || (defined(__GNUC__) && !defined(__clang__))
#define ATTRIBUTE_HOT __attribute__((hot))
#else
#define ATTRIBUTE_HOT
#endif

#if ABSL_HAVE_ATTRIBUTE(cold) || (defined(__GNUC__) && !defined(__clang__))
#define ATTRIBUTE_COLD __attribute__((cold))
#else
#define ATTRIBUTE_COLD
#endif

// ABSL_XRAY_ALWAYS_INSTRUMENT, ABSL_XRAY_NEVER_INSTRUMENT, ABSL_XRAY_LOG_ARGS
//
// We define the ABSL_XRAY_ALWAYS_INSTRUMENT and ABSL_XRAY_NEVER_INSTRUMENT
// macro used as an attribute to mark functions that must always or never be
// instrumented by XRay. Currently, this is only supported in Clang/LLVM.
//
// For reference on the LLVM XRay instrumentation, see
// http://llvm.org/docs/XRay.html.
//
// A function with the XRAY_ALWAYS_INSTRUMENT macro attribute in its declaration
// will always get the XRay instrumentation sleds. These sleds may introduce
// some binary size and runtime overhead and must be used sparingly.
//
// These attributes only take effect when the following conditions are met:
//
//   - The file/target is built in at least C++11 mode, with a Clang compiler
//   that supports XRay attributes.
//   - The file/target is built with the -fxray-instrument flag set for the
//   Clang/LLVM compiler.
//   - The function is defined in the translation unit (the compiler honors the
//   attribute in either the definition or the declaration, and must match).
//
// There are cases when, even when building with XRay instrumentation, users
// might want to control specifically which functions are instrumented for a
// particular build using special-case lists provided to the compiler. These
// special case lists are provided to Clang via the
// -fxray-always-instrument=... and -fxray-never-instrument=... flags. The
// attributes in source take precedence over these special-case lists.
//
// To disable the XRay attributes at build-time, users may define
// ABSL_NO_XRAY_ATTRIBUTES. Do NOT define ABSL_NO_XRAY_ATTRIBUTES on specific
// packages/targets, as this may lead to conflicting definitions of functions at
// link-time.
//
#if ABSL_HAVE_CPP_ATTRIBUTE(clang::xray_always_instrument) && !defined(ABSL_NO_XRAY_ATTRIBUTES)
#define ABSL_XRAY_ALWAYS_INSTRUMENT [[clang::xray_always_instrument]]
#define ABSL_XRAY_NEVER_INSTRUMENT [[clang::xray_never_instrument]]
#define ABSL_XRAY_LOG_ARGS(N) [[ clang::xray_always_instrument, clang::xray_log_args(N) ]]
#else
#define ABSL_XRAY_ALWAYS_INSTRUMENT
#define ABSL_XRAY_NEVER_INSTRUMENT
#define ABSL_XRAY_LOG_ARGS(N)
#endif

// -----------------------------------------------------------------------------
// Variable Attributes
// -----------------------------------------------------------------------------

// ATTRIBUTE_UNUSED
// Prevent the compiler from complaining about or optimizing away variables
// that appear unused.
#if ABSL_HAVE_ATTRIBUTE(unused) || (defined(__GNUC__) && !defined(__clang__))
#undef ABSL_ATTRIBUTE_UNUSED
#define ABSL_ATTRIBUTE_UNUSED __attribute__((__unused__))
#else
#define ABSL_ATTRIBUTE_UNUSED
#endif

// To be deleted macros. All macros are going te be renamed with ABSL_ prefix.
#if ABSL_HAVE_ATTRIBUTE(unused) || (defined(__GNUC__) && !defined(__clang__))
#undef ATTRIBUTE_UNUSED
#define ATTRIBUTE_UNUSED __attribute__((__unused__))
#else
#define ATTRIBUTE_UNUSED
#endif

// ATTRIBUTE_INITIAL_EXEC
// Tell the compiler to use "initial-exec" mode for a thread-local variable.
// See http://people.redhat.com/drepper/tls.pdf for the gory details.
#if ABSL_HAVE_ATTRIBUTE(tls_model) || (defined(__GNUC__) && !defined(__clang__))
#define ABSL_ATTRIBUTE_INITIAL_EXEC __attribute__((tls_model("initial-exec")))
#else
#define ABSL_ATTRIBUTE_INITIAL_EXEC
#endif

// To be deleted macros. All macros are going te be renamed with ABSL_ prefix.
#if ABSL_HAVE_ATTRIBUTE(tls_model) || (defined(__GNUC__) && !defined(__clang__))
#define ATTRIBUTE_INITIAL_EXEC __attribute__((tls_model("initial-exec")))
#else
#define ATTRIBUTE_INITIAL_EXEC
#endif

// ATTRIBUTE_PACKED
// Prevent the compiler from padding a structure to natural alignment
#if ABSL_HAVE_ATTRIBUTE(packed) || (defined(__GNUC__) && !defined(__clang__))
#define ABSL_ATTRIBUTE_PACKED __attribute__((__packed__))
#else
#define ABSL_ATTRIBUTE_PACKED
#endif

// To be deleted macros. All macros are going te be renamed with ABSL_ prefix.
#if ABSL_HAVE_ATTRIBUTE(packed) || (defined(__GNUC__) && !defined(__clang__))
#define ATTRIBUTE_PACKED __attribute__((__packed__))
#else
#define ATTRIBUTE_PACKED
#endif

// ABSL_CONST_INIT
// A variable declaration annotated with the ABSL_CONST_INIT attribute will
// not compile (on supported platforms) unless the variable has a constant
// initializer. This is useful for variables with static and thread storage
// duration, because it guarantees that they will not suffer from the so-called
// "static init order fiasco".
//
// Sample usage:
//
// ABSL_CONST_INIT static MyType my_var = MakeMyType(...);
//
// Note that this attribute is redundant if the variable is declared constexpr.
#if ABSL_HAVE_CPP_ATTRIBUTE(clang::require_constant_initialization)
// NOLINTNEXTLINE(whitespace/braces) (b/36288871)
#define ABSL_CONST_INIT [[clang::require_constant_initialization]]
#else
#define ABSL_CONST_INIT
#endif  // ABSL_HAVE_CPP_ATTRIBUTE(clang::require_constant_initialization)

#endif  // THIRD_PARTY_ABSL_BASE_ATTRIBUTES_H_
