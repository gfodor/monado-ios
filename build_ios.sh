#!/bin/bash

# Build script for iOS Monado OpenXR engine with ARKit support
# This script sets up the Xcode project and builds the ARKit driver for iOS

set -e

echo "Building iOS Monado with ARKit support..."

# Check if required tools are available
if ! command -v cmake &> /dev/null; then
    echo "Error: cmake is required but not installed"
    exit 1
fi

if ! command -v xcodebuild &> /dev/null; then
    echo "Error: xcodebuild is required but not installed"
    exit 1
fi

# Check if required dependencies are available
if ! brew list eigen &> /dev/null; then
    echo "Installing Eigen3..."
    brew install eigen
fi

if ! brew list molten-vk &> /dev/null; then
    echo "Installing MoltenVK..."
    brew install molten-vk
fi

# Clean previous build
echo "Cleaning previous build..."
rm -rf build-xcode

# Configure CMake for iOS with ARKit support
echo "Configuring CMake..."
cmake -G Xcode \
    -DCMAKE_TOOLCHAIN_FILE=ios.toolchain.cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DXRT_BUILD_DRIVER_ARKIT=ON \
    -DXRT_HAVE_APPLE=ON \
    -DIOS=ON \
    -DEIGEN3_INCLUDE_DIR=/opt/homebrew/opt/eigen/include/eigen3 \
    -DVulkan_INCLUDE_DIR=/opt/homebrew/opt/molten-vk/libexec/include \
    -DVulkan_LIBRARY=/opt/homebrew/opt/molten-vk/lib/libMoltenVK.dylib \
    -DXRT_HAVE_VULKAN=ON \
    -DXRT_MODULE_COMPOSITOR_MAIN=ON \
    -DXRT_FEATURE_SERVICE=OFF \
    -DXRT_FEATURE_OPENXR=ON \
    -DXRT_BUILD_DRIVER_WMR=OFF \
    -B build-xcode

# Build the ARKit driver
echo "Building ARKit driver..."
cd build-xcode
xcodebuild -project XRT.xcodeproj -scheme drv_arkit -configuration Release -sdk iphoneos build

echo "Build completed successfully!"
echo "ARKit driver library can be found in: build-xcode/src/xrt/drivers/Release-iphoneos/"

# Build the unified OpenXR runtime library (includes ARKit driver, compositor, etc.)
echo "Building unified OpenXR runtime library..."
xcodebuild -project XRT.xcodeproj -scheme openxr_monado -configuration Release -sdk iphoneos build

echo "Unified OpenXR library can be found in: build-xcode/src/xrt/targets/openxr/Release-iphoneos/"

echo ""
echo "To use the unified OpenXR library in your iOS project:"
echo "1. Link against libopenxr_monado.dylib from build-xcode/src/xrt/targets/openxr/Release-iphoneos/"
echo "2. Add the ARKit framework to your project"
echo "3. Add the Metal framework to your project"
echo "4. Include the necessary headers from src/xrt/include"
echo "5. Set up MoltenVK for Vulkan support"
echo ""
echo "This single dynamic library includes:"
echo "- OpenXR runtime implementation"
echo "- ARKit driver for iOS head tracking"
echo "- Metal compositor for rendering"
echo "- All auxiliary libraries (math, util, vulkan, etc.)"