cmake_minimum_required(VERSION 3.15)
project(Simd)

# ------------------------
# 选项
# ------------------------
option(SIMD_AVX512 "Enable AVX-512" ON)
option(SIMD_AVX512VNNI "Enable AVX-512VNNI" ON)
option(SIMD_AMXBF16 "Enable AMX-BF16/INT8" OFF)
option(SIMD_TEST "Enable test framework" ON)
option(SIMD_INFO "Print build info" ON)
option(SIMD_PERF "Internal performance statistic" OFF)
option(SIMD_SHARED "Build as SHARED library" OFF)
option(SIMD_GET_VERSION "Get Simd Library version" ON)
option(SIMD_SYNET "Synet optimizations enable" ON)
option(SIMD_INT8_DEBUG "Synet INT8 debug enable" OFF)
option(SIMD_HIDE "Hide internal functions" OFF)
option(SIMD_AMX_EMULATE "AMX emulation enable" OFF)
option(SIMD_RUNTIME "Runtime faster algorithm choise enable" ON)
option(SIMD_OPENCV "OpenCV tests enable" OFF)
option(SIMD_INSTALL "Enable install target" ON)
option(SIMD_UNINSTALL "Enable uninstall target" ON)
option(SIMD_PYTHON "Enable Python wrapper" ON)

set(MAX_ERRORS 5)

# ------------------------
# 根目录 & 构建类型
# ------------------------
if(NOT DEFINED SIMD_ROOT OR SIMD_ROOT STREQUAL "")
    set(SIMD_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../..")
endif()

if(NOT DEFINED CMAKE_BUILD_TYPE OR CMAKE_BUILD_TYPE STREQUAL "")
    set(CMAKE_BUILD_TYPE "Release")
endif()

if(NOT "${SIMD_TARGET}" STREQUAL "")
    set(CMAKE_SYSTEM_PROCESSOR ${SIMD_TARGET})
endif()

if(SIMD_HIDE AND SIMD_TEST)
    message("Test framework requires access to internal functions! SIMD_HIDE ignored")
    set(SIMD_HIDE OFF)
endif()

# ------------------------
# 库类型
# ------------------------
if(SIMD_SHARED)
    set(SIMD_LIB_TYPE "SHARED")
else()
    set(SIMD_LIB_TYPE "STATIC")
    add_definitions(-DSIMD_STATIC)
endif()

# ------------------------
# 自定义工具链
# ------------------------
if(NOT SIMD_TOOLCHAIN STREQUAL "")
    set(CMAKE_C_COMPILER ${SIMD_TOOLCHAIN})
    set(CMAKE_CXX_COMPILER ${SIMD_TOOLCHAIN})
    execute_process(COMMAND "${CMAKE_CXX_COMPILER}" -dumpversion OUTPUT_VARIABLE CMAKE_CXX_COMPILER_VERSION)
    string(REGEX REPLACE "\n$" "" CMAKE_CXX_COMPILER_VERSION "${CMAKE_CXX_COMPILER_VERSION}")
endif()

# ------------------------
# 编译信息输出
# ------------------------
if(SIMD_INFO)
    message("Simd Library:")
    message("Build type: '${CMAKE_BUILD_TYPE}'")
    message("Target: ${CMAKE_SYSTEM_PROCESSOR}")
    message("Library type: ${SIMD_LIB_TYPE}")
    message("Toolchain: ${CMAKE_CXX_COMPILER}")
    message("Compiler ID: ${CMAKE_CXX_COMPILER_ID}")
    message("Compiler Version: ${CMAKE_CXX_COMPILER_VERSION}")
    message("Test framework: ${SIMD_TEST}")
    message("Performance statistic: ${SIMD_PERF}")
    message("Synet: ${SIMD_SYNET}")
    message("Debug INT8: ${SIMD_INT8_DEBUG}")
    message("Hide internal: ${SIMD_HIDE}")
    message("AMX emulation: ${SIMD_AMX_EMULATE}")
    message("Runtime algorithm choice: ${SIMD_RUNTIME}")
    message("OpenCV tests: ${SIMD_OPENCV}")
    message("Install target: ${SIMD_INSTALL}")
    message("Uninstall target: ${SIMD_UNINSTALL}")
    message("Python wrapper: ${SIMD_PYTHON}")
endif()

# ------------------------
# 定义宏
# ------------------------
if(NOT SIMD_SYNET)
    add_definitions(-DSIMD_SYNET_DISABLE)
endif()

if(NOT SIMD_INT8_DEBUG)
    add_definitions(-DSIMD_INT8_DEBUG_DISABLE)
endif()

if(SIMD_HIDE)
    add_definitions(-DSIMD_HIDE_INTERNAL)
endif()

if(SIMD_PERF)
    add_definitions(-DSIMD_PERFORMANCE_STATISTIC)
endif()

if(SIMD_AMX_EMULATE)
    add_definitions(-DSIMD_AMX_EMULATE)
endif()

if(NOT SIMD_RUNTIME)
    add_definitions(-DSIMD_RUNTIME_DISABLE)
endif()

# ------------------------
# 包含目录
# ------------------------
include_directories("${SIMD_ROOT}/src")

# ------------------------
# 获取版本号
# ------------------------
if(SIMD_GET_VERSION)
    if (WIN32 AND NOT (CYGWIN OR MSYS))
        string(REPLACE "/" "\\" SIMD_ROOT_WINDOWS ${SIMD_ROOT})
        execute_process(COMMAND "${SIMD_ROOT}/prj/cmd/GetVersion.cmd" "${SIMD_ROOT_WINDOWS}" "${SIMD_INFO}")
    else()
        execute_process(COMMAND bash "${SIMD_ROOT}/prj/sh/GetVersion.sh" "${SIMD_ROOT}" "${SIMD_INFO}")
    endif()
elseif(SIMD_VERSION)
    add_definitions(-DSIMD_VERSION=${SIMD_VERSION})
else()
    add_definitions(-DSIMD_VERSION="unknown")
endif()

# ------------------------
# 通用编译选项
# ------------------------
if(MSVC)
    set(COMMON_CXX_FLAGS "/arch:AVX2 /EHsc /utf-8")
else()
    string(REGEX REPLACE "(-march=[a-zA-Z0-9-]*)|(-mtune=[a-zA-Z0-9-]*)|(-msse[0-9,\\.]*)|(-mavx[a-z0-9]*)|(-mfma)|(-mamx-[a-z0-9]*)" "" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")

    if(CMAKE_BUILD_TYPE STREQUAL "Release")
        set(COMMON_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fPIC -std=c++11 -O3")
    elseif(CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
        set(COMMON_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fPIC -std=c++11 -O3 -g")
    elseif(CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(COMMON_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fPIC -std=c++11 -O0 -g")
    else()
        message(FATAL_ERROR "Unknown CMAKE_BUILD_TYPE: ${CMAKE_BUILD_TYPE}")
    endif()

    if((CMAKE_CXX_COMPILER MATCHES "clang") OR (CMAKE_CXX_COMPILER_ID MATCHES "Clang") OR (CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang"))
        set(COMMON_CXX_FLAGS "${COMMON_CXX_FLAGS} -ferror-limit=${MAX_ERRORS}")
    else()
        set(COMMON_CXX_FLAGS "${COMMON_CXX_FLAGS} -fmax-errors=${MAX_ERRORS}")
    endif()

    if(SIMD_HIDE)
        set(COMMON_CXX_FLAGS "${COMMON_CXX_FLAGS} -fvisibility=hidden")
    endif()
endif()

# ------------------------
# 平台处理
# ------------------------
if(CMAKE_GENERATOR MATCHES "Visual Studio")
    add_compile_options(/EHsc)
    string(TOLOWER ${CMAKE_VS_PLATFORM_NAME} ARCH)
    if(ARCH STREQUAL "x64" OR ARCH STREQUAL "x86" OR ARCH STREQUAL "win32")
        include(x86.cmake)
    elseif(ARCH STREQUAL "arm" OR ARCH STREQUAL "arm64")
        add_definitions(-DSIMD_AVX512BW_DISABLE -DSIMD_AVX512VNNI_DISABLE -DSIMD_AMXBF16_DISABLE)
        include(arm.cmake)
    else()
        message(FATAL_ERROR "Unknown CMAKE_VS_PLATFORM_NAME: ${ARCH}")
    endif()
else()
    string(TOLOWER ${CMAKE_SYSTEM_PROCESSOR} ARCH)
    if(ARCH STREQUAL "i686" OR ARCH STREQUAL "x86_64" OR ARCH STREQUAL "amd64")
        include(x86.cmake)
    elseif(ARCH MATCHES "arm" OR ARCH STREQUAL "aarch64" OR ARCH STREQUAL "arm64")
        add_definitions(-DSIMD_AVX512BW_DISABLE -DSIMD_AVX512VNNI_DISABLE -DSIMD_AMXBF16_DISABLE)
        include(arm.cmake)
    else()
        message(FATAL_ERROR "Unknown CMAKE_SYSTEM_PROCESSOR: ${ARCH}")
    endif()
endif()

# ------------------------
# Python wrapper
# ------------------------
if(SIMD_PYTHON)
    add_custom_command(TARGET Simd POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy ${SIMD_ROOT}/py/SimdPy/Simd.py ${CMAKE_BINARY_DIR})
    if(SIMD_TEST)
        add_custom_command(TARGET Test POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy ${SIMD_ROOT}/py/SimdPy/Test.py ${CMAKE_BINARY_DIR})
    endif()
endif()

# ------------------------
# Install / Uninstall
# ------------------------
if(SIMD_INSTALL)
    file(GLOB_RECURSE SIMD_LIB_HPP ${SIMD_ROOT}/src/Simd/Simd*.hpp)
    set_target_properties(Simd PROPERTIES PUBLIC_HEADER "${SIMD_ROOT}/src/Simd/SimdLib.h;${SIMD_LIB_HPP}")
    install(TARGETS Simd EXPORT simdConfig
        LIBRARY DESTINATION "lib"
        ARCHIVE DESTINATION "lib"
        PUBLIC_HEADER DESTINATION "include/Simd")
    install(EXPORT simdConfig DESTINATION share/simd)
endif()

if(SIMD_UNINSTALL)
    add_custom_target("uninstall")
    add_custom_command(TARGET "uninstall" POST_BUILD COMMENT "Uninstall Simd Library..."
        COMMAND cat install_manifest.txt | sudo xargs rm -v
        COMMAND cat install_manifest.txt | xargs -L1 dirname | grep '/[Ss]imd' | uniq | sudo xargs rmdir -v)
endif()
