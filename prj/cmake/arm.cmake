# ------------------------
# ARM 特有编译选项
# ------------------------
if((CMAKE_CXX_COMPILER_ID MATCHES "GNU") AND (NOT CMAKE_CXX_COMPILER_VERSION VERSION_LESS "7.0.0"))
    set(COMMON_CXX_FLAGS "${COMMON_CXX_FLAGS} -Wno-psabi")
endif()

# ARM 32-bit NEON 支持
if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm" AND NOT CMAKE_SYSTEM_PROCESSOR MATCHES "arm64")
    if(NOT (CMAKE_CXX_COMPILER_ID STREQUAL "Clang" OR CMAKE_CXX_COMPILER MATCHES "clang" OR CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang"))
        set(CXX_NEON_FLAG "-mfpu=neon -mfpu=neon-fp16")
    endif()
    if(CMAKE_CXX_COMPILER_ID MATCHES "GNU")
        set(CXX_NEON_FLAG "${CXX_NEON_FLAG} -mfp16-format=ieee")
    endif()
else()
    set(CXX_NEON_FLAG "")
endif()

# Clang 不支持部分 NEON FP16
if((CMAKE_CXX_COMPILER_ID STREQUAL "Clang") OR (CMAKE_CXX_COMPILER MATCHES "clang")  OR (CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang"))
    add_definitions(-DSIMD_NEON_FP16_DISABLE)
endif()

# ------------------------
# 设置源文件编译选项
# ------------------------
file(GLOB_RECURSE SIMD_BASE_SRC ${SIMD_ROOT}/src/Simd/SimdBase*.cpp)
set_source_files_properties(${SIMD_BASE_SRC} PROPERTIES COMPILE_FLAGS "${COMMON_CXX_FLAGS}")

file(GLOB_RECURSE SIMD_NEON_SRC ${SIMD_ROOT}/src/Simd/SimdNeon*.cpp)
set_source_files_properties(${SIMD_NEON_SRC} PROPERTIES COMPILE_FLAGS "${COMMON_CXX_FLAGS} ${CXX_NEON_FLAG}")

file(GLOB_RECURSE SIMD_LIB_SRC ${SIMD_ROOT}/src/Simd/SimdLib.cpp)
set_source_files_properties(${SIMD_LIB_SRC} PROPERTIES COMPILE_FLAGS "${COMMON_CXX_FLAGS} ${CXX_NEON_FLAG}")

# ------------------------
# 创建 Simd 库
# ------------------------
add_library(Simd ${SIMD_LIB_TYPE} ${SIMD_LIB_SRC} ${SIMD_BASE_SRC} ${SIMD_NEON_SRC})

# ------------------------
# 测试代码
# ------------------------
if(SIMD_TEST)
    file(GLOB_RECURSE TEST_SRC_C ${SIMD_ROOT}/src/Test/*.c)
    file(GLOB_RECURSE TEST_SRC_CPP ${SIMD_ROOT}/src/Test/*.cpp)

    if(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
        # MSVC 编译测试
        set_source_files_properties(${TEST_SRC_CPP} PROPERTIES COMPILE_FLAGS "${COMMON_CXX_FLAGS}")
    elseif((NOT "${SIMD_TARGET}" STREQUAL "") OR (CMAKE_CXX_COMPILER_VERSION VERSION_LESS "5.0.0"))
        set_source_files_properties(${TEST_SRC_CPP} PROPERTIES COMPILE_FLAGS "${COMMON_CXX_FLAGS} ${CXX_NEON_FLAG} -D_GLIBCXX_USE_NANOSLEEP")
    else()
        set_source_files_properties(${TEST_SRC_CPP} PROPERTIES COMPILE_FLAGS "${COMMON_CXX_FLAGS} ${SIMD_TEST_FLAGS} -mtune=native -D_GLIBCXX_USE_NANOSLEEP")
    endif()

    add_executable(Test ${TEST_SRC_C} ${TEST_SRC_CPP})
    target_link_libraries(Test Simd)

    if(NOT MSVC)
        target_link_libraries(Test -lpthread -lstdc++ -lm)
    endif()

    # OpenCV 支持
    if(SIMD_OPENCV)
        find_package(OpenCV REQUIRED)
        target_compile_definitions(Test PUBLIC SIMD_OPENCV_ENABLE)
        target_link_libraries(Test ${OpenCV_LIBS})
        target_include_directories(Test PUBLIC ${OpenCV_INCLUDE_DIRS})
    endif()
endif()
