# CMake for macOS build ONLY
# Use Visual Studio .sln file on Windows.

cmake_minimum_required(VERSION 4.1.1)

# Universal binary by default: Intel (macOS 10.15+) and Apple Silicon
# (11.0+).  The static libs in libs/ carry both slices.  Override with
# -DCMAKE_OSX_ARCHITECTURES=arm64 for a faster single-arch dev build.
set(CMAKE_OSX_ARCHITECTURES "x86_64;arm64" CACHE STRING "macOS build architectures")
set(CMAKE_OSX_DEPLOYMENT_TARGET "10.15" CACHE STRING "Minimum macOS version")

project(LabraScope VERSION 1.0)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Options
option(BUILD_TESTS "Build test suite" OFF)
option(USE_STATIC_LIBS "Link libraries statically" ON)
set(CMAKE_BUILD_TYPE "Release") # defines NDEBUG

# System packages
find_package(OpenGL REQUIRED)

# Imported targets
# Function to create imported static library targets
set(EXTERNAL_DIR ${PROJECT_SOURCE_DIR}/libs)
function(add_static_library target_name lib_path include_path)
    add_library(${target_name} STATIC IMPORTED)
    set_target_properties(${target_name} PROPERTIES
        IMPORTED_LOCATION ${EXTERNAL_DIR}/${lib_path}
    )
    if(include_path)
        target_include_directories(${target_name} INTERFACE
            ${EXTERNAL_DIR}/${include_path}
        )
    endif()
endfunction()

add_static_library(libusb "libusb/libusb-1.0.a" "libusb/")
add_static_library(fftw "fftw/libfftw3.a" "fftw/")
add_static_library(nfd "nfd/libnfd.a" "nfd/")
add_static_library(glfw "glfw/libglfw3.a" "glfw/include")
# Vendored dfu-programmer core (libdfuprog): librador drives the bootloader
# through it (jump-to-bootloader, launch, firmware flash) instead of shelling
# out.  Compiled against the same static libusb as the rest of the app.
set(DFUPROG_DIR ${PROJECT_SOURCE_DIR}/libs/libdfuprog)
add_library(libdfuprog_vendored STATIC
    ${DFUPROG_DIR}/dfu-programmer/src/arguments.c
    ${DFUPROG_DIR}/dfu-programmer/src/atmel.c
    ${DFUPROG_DIR}/dfu-programmer/src/commands.c
    ${DFUPROG_DIR}/dfu-programmer/src/dfu.c
    ${DFUPROG_DIR}/dfu-programmer/src/intel_hex.c
    ${DFUPROG_DIR}/dfu-programmer/src/stm32.c
    ${DFUPROG_DIR}/dfu-programmer/src/util.c
    ${DFUPROG_DIR}/libdfuprog.c
)
target_include_directories(libdfuprog_vendored PRIVATE
    ${DFUPROG_DIR}
    ${DFUPROG_DIR}/dfu-programmer/src
)
target_compile_definitions(libdfuprog_vendored PRIVATE HAVE_CONFIG_H)
target_link_libraries(libdfuprog_vendored PRIVATE libusb)
# dfu-programmer predates C23 (dfu-bool.h defines enum constants named
# true/false, keywords from C23 on); pin the dialect.
set_target_properties(libdfuprog_vendored PROPERTIES C_STANDARD 17 C_EXTENSIONS ON)

# Define Sources
set(IMGUI_DIR libs/imgui)
set(LIBRADOR_DIR libs/librador)

set(SOURCES
    src/main.cpp 
    src/util.cpp
    backends/imgui_impl_glfw.cpp 
    backends/imgui_impl_opengl3.cpp
    misc/cpp/imgui_stdlib.cpp
    ${LIBRADOR_DIR}/librador.cpp
    ${LIBRADOR_DIR}/usbcallhandler.cpp
    ${LIBRADOR_DIR}/o1buffer.cpp
    ${LIBRADOR_DIR}/uartstyledecoder.cpp
    ${LIBRADOR_DIR}/isobufferbuffer.cpp
    ${LIBRADOR_DIR}/i2cdecoder.cpp
    ${IMGUI_DIR}/imgui.cpp
    ${IMGUI_DIR}/imgui_demo.cpp
    ${IMGUI_DIR}/imgui_draw.cpp
    ${IMGUI_DIR}/imgui_tables.cpp
    ${IMGUI_DIR}/imgui_widgets.cpp
    ${IMGUI_DIR}/implot.cpp
    ${IMGUI_DIR}/implot_demo.cpp
    ${IMGUI_DIR}/implot_items.cpp

)
# Add include directories
add_executable(${PROJECT_NAME} ${SOURCES})
target_compile_definitions(${PROJECT_NAME} PRIVATE LIBRADOR_ENABLE_LOGGING)

target_include_directories(${PROJECT_NAME} PRIVATE
    misc/cpp/
    backends/
    ${EXTERNAL_DIR}/exprtk
    ${IMGUI_DIR}/
    ${LIBRADOR_DIR}/
    ${DFUPROG_DIR}/
    # ${EXTERNAL_DIR}/glfw/include/
    src/
    ${EXTERNAL_DIR}/
)

target_link_libraries(${PROJECT_NAME}
    libdfuprog_vendored
    libusb
    fftw
    nfd
    glfw
)

if(APPLE)
    find_library(OPENGL_LIBRARY OpenGl)
    find_library(COCOA_LIBRARY Cocoa)
    find_library(IOKIT_LIBRARY IOKit)
    find_library(COREVIDEO_LIBRARY CoreVideo)
    find_library(APPKIT_LIBRARY AppKit)
    find_library(SECURITY_LIBRARY Security)
    target_link_libraries(${PROJECT_NAME}
        ${OPENGL_LIBRARY}
        ${COCOA_LIBRARY} 
        ${IOKIT_LIBRARY} 
        ${COREVIDEO_LIBRARY}
        ${APPKIT_LIBRARY}
        ${SECURITY_LIBRARY}
    )
endif()

if(CMAKE_BUILD_TYPE STREQUAL "Release")
    add_compile_definitions(NDEBUG)
endif()