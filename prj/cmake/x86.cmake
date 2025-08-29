if(CMAKE_SYSTEM_PROCESSOR STREQUAL "i686")
	set(COMMON_CXX_FLAGS "${COMMON_CXX_FLAGS} -m32")
elseif(CMAKE_SYSTEM_PROCESSOR STREQUAL "x86_64")
	set(COMMON_CXX_FLAGS "${COMMON_CXX_FLAGS} -m64")
endif()

# ------------------------
# 基础 SIMD 源文件
# ------------------------
file(GLOB_RECURSE SIMD_BASE_SRC ${SIMD_ROOT}/src/Simd/SimdBase*.cpp)
set_source_files_properties(${SIMD_BASE_SRC} PROPERTIES COMPILE_FLAGS "${COMMON_CXX_FLAGS}")

# ------------------------
# SSE4.1 源文件
# ------------------------
file(GLOB_RECURSE SIMD_SSE41_SRC ${SIMD_ROOT}/src/Simd/SimdSse41*.cpp)
set_source_files_properties(${SIMD_SSE41_SRC} PROPERTIES COMPILE_FLAGS "${COMMON_CXX_FLAGS} -msse -msse2 -msse3 -mssse3 -msse4.1 -msse4.2")

# ------------------------
# AVX2 源文件
# ------------------------
file(GLOB_RECURSE SIMD_AVX2_SRC ${SIMD_ROOT}/src/Simd/SimdAvx2*.cpp)
if ((CMAKE_CXX_COMPILER MATCHES "clang") OR (CMAKE_CXX_COMPILER_ID MATCHES "Clang"))
	set_source_files_properties(${SIMD_AVX2_SRC} PROPERTIES COMPILE_FLAGS "${COMMON_CXX_FLAGS} -mavx -mavx2 -mfma -mf16c -mbmi -mbmi2 -mlzcnt")
else()
	set_source_files_properties(${SIMD_AVX2_SRC} PROPERTIES COMPILE_FLAGS "${COMMON_CXX_FLAGS} -mavx -mavx2 -mfma -mf16c -mbmi -mbmi2 -mlzcnt -mno-avx256-split-unaligned-load -mno-avx256-split-unaligned-store")
endif()

# ------------------------
# SIMD 库总 FLAGS
# ------------------------
set(SIMD_LIB_FLAGS "${COMMON_CXX_FLAGS} -mavx2 -mfma")
# ------------------------
# 汇总算法源文件
# ------------------------
set(SIMD_ALG_SRC ${SIMD_BASE_SRC} ${SIMD_SSE41_SRC} ${SIMD_AVX1_SRC} ${SIMD_AVX2_SRC})

# ------------------------
# AVX-512 / AMX 源文件 (只 GCC/Clang)
# ------------------------
if(NOT MSVC)
    # AVX-512BW
    if((((CMAKE_CXX_COMPILER_ID MATCHES "GNU") OR (CMAKE_CXX_COMPILER MATCHES "gnu")) AND (NOT(CMAKE_CXX_COMPILER_VERSION VERSION_LESS "5.5.0"))) OR (CMAKE_CXX_COMPILER MATCHES "clang") OR (CMAKE_CXX_COMPILER_ID MATCHES "Clang"))
        file(GLOB_RECURSE SIMD_AVX512BW_SRC ${SIMD_ROOT}/src/Simd/SimdAvx512bw*.cpp)
        set_source_files_properties(${SIMD_AVX512BW_SRC} PROPERTIES COMPILE_FLAGS "${COMMON_CXX_FLAGS} -mavx512f -mavx512cd -mavx512bw -mavx512vl -mavx512dq -mbmi -mbmi2 -mlzcnt -mfma -mf16c")

        if(UNIX AND SIMD_AVX512)
            set(SIMD_LIB_FLAGS "${SIMD_LIB_FLAGS} -mavx512bw")
            set(SIMD_ALG_SRC ${SIMD_ALG_SRC} ${SIMD_AVX512F_SRC} ${SIMD_AVX512BW_SRC})
            if(SIMD_INFO)
                message("Use AVX-512BW")
            endif()
        else()
            add_definitions(-DSIMD_AVX512BW_DISABLE -DSIMD_AVX512VNNI_DISABLE -DSIMD_AMXBF16_DISABLE)
        endif()
    else()
        add_definitions(-DSIMD_AVX512BW_DISABLE -DSIMD_AVX512VNNI_DISABLE -DSIMD_AMXBF16_DISABLE)
    endif()

    # AVX-512VNNI
    if(((CMAKE_CXX_COMPILER_ID MATCHES "GNU") OR (CMAKE_CXX_COMPILER MATCHES "gnu")) AND (NOT(CMAKE_CXX_COMPILER_VERSION VERSION_LESS "8.0.0")))    
        file(GLOB_RECURSE SIMD_AVX512VNNI_SRC ${SIMD_ROOT}/src/Simd/SimdAvx512vnni*.cpp)
        set_source_files_properties(${SIMD_AVX512VNNI_SRC} PROPERTIES COMPILE_FLAGS "${COMMON_CXX_FLAGS} -mavx512f -mavx512cd -mavx512bw -mavx512vl -mavx512dq -mavx512vnni")

        if(UNIX AND SIMD_AVX512VNNI)
            set(SIMD_LIB_FLAGS "${SIMD_LIB_FLAGS} -mavx512vnni")
            set(SIMD_ALG_SRC ${SIMD_ALG_SRC} ${SIMD_AVX512VNNI_SRC})
            if(SIMD_INFO)
                message("Use AVX-512VNNI")
            endif()
        else()
            add_definitions(-DSIMD_AVX512VNNI_DISABLE -DSIMD_AMXBF16_DISABLE)
        endif()
    else()
        add_definitions(-DSIMD_AVX512VNNI_DISABLE -DSIMD_AMXBF16_DISABLE)
    endif()

    # AMX-BF16
    if(((CMAKE_CXX_COMPILER_ID MATCHES "GNU") OR (CMAKE_CXX_COMPILER MATCHES "gnu")) AND (NOT(CMAKE_CXX_COMPILER_VERSION VERSION_LESS "11.0.0")))    
        file(GLOB_RECURSE SIMD_AMXBF16_SRC ${SIMD_ROOT}/src/Simd/SimdAmxBf16*.cpp)
        set_source_files_properties(${SIMD_AMXBF16_SRC} PROPERTIES COMPILE_FLAGS "${COMMON_CXX_FLAGS} -mavx512f -mavx512cd -mavx512bw -mavx512vl -mavx512dq -mavx512vnni -mavx512vbmi -mavx512bf16 -mamx-tile -mamx-int8 -mamx-bf16")

        if(UNIX AND ((SIMD_AMXBF16 AND (NOT(BINUTILS_VERSION VERSION_LESS "2.34"))) OR SIMD_AMX_EMULATE))
            set(SIMD_LIB_FLAGS "${SIMD_LIB_FLAGS} -mamx-tile -mamx-int8 -mamx-bf16 -mavx512bf16 -mavx512vbmi")
            set(SIMD_ALG_SRC ${SIMD_ALG_SRC} ${SIMD_AMXBF16_SRC})
            if(SIMD_INFO)
                message("Use AMX-INT8 and AMX-BF16")
            endif()
        else()
            add_definitions(-DSIMD_AMXBF16_DISABLE)
        endif()
    else()
        add_definitions(-DSIMD_AMXBF16_DISABLE)
    endif()
endif() # end MSVC check


# ------------------------
# SimdLib.cpp
# ------------------------
file(GLOB_RECURSE SIMD_LIB_SRC ${SIMD_ROOT}/src/Simd/SimdLib.cpp)
set_source_files_properties(${SIMD_LIB_SRC} PROPERTIES COMPILE_FLAGS "${SIMD_LIB_FLAGS}")

# ------------------------
# 添加库
# ------------------------
add_library(Simd ${SIMD_LIB_TYPE} ${SIMD_LIB_SRC} ${SIMD_ALG_SRC})
# MSVC 设置 Runtime Library
if(MSVC AND SIMD_LIB_TYPE STREQUAL "STATIC")
    set_target_properties(Simd PROPERTIES
        MSVC_RUNTIME_LIBRARY ${CMAKE_MSVC_RUNTIME_LIBRARY}
    )
endif()

# ------------------------
# 测试框架
# ------------------------
if(SIMD_TEST)
	file(GLOB_RECURSE TEST_SRC_C ${SIMD_ROOT}/src/Test/*.c)
	if((CMAKE_CXX_COMPILER MATCHES "clang") OR (CMAKE_CXX_COMPILER_ID MATCHES "Clang")) 
		set_source_files_properties(${TEST_SRC_C} PROPERTIES COMPILE_FLAGS "${CMAKE_C_FLAGS} -x c")
	endif()
	file(GLOB_RECURSE TEST_SRC_CPP ${SIMD_ROOT}/src/Test/*.cpp)
	if((NOT ${SIMD_TARGET} STREQUAL "") OR (NOT SIMD_AVX512))
		set_source_files_properties(${TEST_SRC_CPP} PROPERTIES COMPILE_FLAGS "${SIMD_LIB_FLAGS}")
	else()
		set_source_files_properties(${TEST_SRC_CPP} PROPERTIES COMPILE_FLAGS "${COMMON_CXX_FLAGS} ${SIMD_TEST_FLAGS} -mtune=native")
	endif()
	add_executable(Test ${TEST_SRC_C} ${TEST_SRC_CPP})
	target_link_libraries(Test Simd -lpthread -lstdc++ -lm)
	if(SIMD_OPENCV)
		target_compile_definitions(Test PUBLIC SIMD_OPENCV_ENABLE)
		target_link_libraries(Test ${OpenCV_LIBS})
		target_include_directories(Test PUBLIC ${OpenCV_INCLUDE_DIRS})
	endif()
endif()
