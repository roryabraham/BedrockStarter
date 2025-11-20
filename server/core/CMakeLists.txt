cmake_minimum_required(VERSION 3.16)
project(BedrockCore)

# Generate compile_commands.json for clangd
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Force use of Clang
set(CMAKE_C_COMPILER clang)
set(CMAKE_CXX_COMPILER clang++)

# Set C++ standard to C++20 (matches Bedrock)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Use mold linker for faster linking
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fuse-ld=mold")
set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -fuse-ld=mold")

# Enable modern C++ features and optimizations
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -stdlib=libc++ -Wall -Wextra -Wpedantic")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -O3 -DNDEBUG -flto")
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -O0 -g -fsanitize=address -fsanitize=undefined")

# Find required packages
find_package(PkgConfig REQUIRED)

# Set Bedrock directory (environment variable or default to submodule)
set(BEDROCK_DIR $ENV{BEDROCK_DIR})
if(NOT BEDROCK_DIR)
    set(BEDROCK_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../Bedrock")
endif()

# Set include directories
include_directories(${BEDROCK_DIR})
include_directories(${BEDROCK_DIR}/libstuff)
include_directories(${BEDROCK_DIR}/mbedtls/include)

# Add source files
set(SOURCES
    Core.cpp
    commands/HelloWorld.cpp
)

# Create shared library for the plugin
add_library(Core SHARED ${SOURCES})

# Create lib directory and set output directory
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/lib)
set_target_properties(Core PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/lib
    OUTPUT_NAME "Core"
    PREFIX ""
)
