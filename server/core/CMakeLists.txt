cmake_minimum_required(VERSION 3.16)
project(BedrockCore)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find required packages
find_package(PkgConfig REQUIRED)

# Set include directories
include_directories(/app/Bedrock)
include_directories(/app/Bedrock/libstuff)

# Add source files
set(SOURCES
    Core.cpp
    commands/HelloWorld.cpp
)

# Create shared library for the plugin
add_library(BedrockCore SHARED ${SOURCES})

# Link libraries (you may need to adjust these based on Bedrock's actual linking requirements)
target_link_libraries(BedrockCore
    pthread
    pcre
    z
)

# Set output directory
set_target_properties(BedrockCore PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib
)

# Install target
install(TARGETS BedrockCore
    LIBRARY DESTINATION /app/server/core/lib
)
