#!/bin/bash

# Build script for iOS Monado OpenXR engine with ARKit support
# This script builds and creates a unified dylib for iOS

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
    -DBUILD_SHARED_LIBS=OFF \
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

# Build all required components (excluding test targets)
echo "Building all required components..."
cd build-xcode
xcodebuild -project XRT.xcodeproj -target openxr_monado -configuration Release -sdk iphoneos build

echo "Build completed successfully!"

# Create unified dylib
echo "Creating unified OpenXR library for iOS..."

BUILD_DIR="/Users/gfodor/portal/ios-monado/build-xcode"
OUTPUT_DIR="$BUILD_DIR/unified"
OUTPUT_LIB="$OUTPUT_DIR/libopenxr_monado.dylib"

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "Collecting static libraries..."

# Static libraries to combine
STATIC_LIBRARIES=(
    # Core OpenXR libraries
    "$BUILD_DIR/src/xrt/targets/openxr/Release-iphoneos/libopenxr_monado.a"
    "$BUILD_DIR/src/xrt/state_trackers/oxr/Release-iphoneos/libst_oxr.a"
    "$BUILD_DIR/src/xrt/state_trackers/prober/Release-iphoneos/libst_prober.a"
    
    # Target libraries
    "$BUILD_DIR/src/xrt/targets/common/Release-iphoneos/libtarget_instance.a"
    "$BUILD_DIR/src/xrt/targets/common/Release-iphoneos/libtarget_lists.a"
    
    # Compositor libraries
    "$BUILD_DIR/src/xrt/compositor/Release-iphoneos/libcomp_main.a"
    "$BUILD_DIR/src/xrt/compositor/Release-iphoneos/libcomp_client.a"
    "$BUILD_DIR/src/xrt/compositor/Release-iphoneos/libcomp_util.a"
    "$BUILD_DIR/src/xrt/compositor/Release-iphoneos/libcomp_render.a"
    "$BUILD_DIR/src/xrt/compositor/Release-iphoneos/libcomp_multi.a"
    
    # Driver libraries
    "$BUILD_DIR/src/xrt/drivers/Release-iphoneos/libdrv_arkit.a"
    "$BUILD_DIR/src/xrt/drivers/Release-iphoneos/libdrv_multi.a"
    "$BUILD_DIR/src/xrt/drivers/Release-iphoneos/libdrv_simulated.a"
    
    # Auxiliary libraries
    "$BUILD_DIR/src/xrt/auxiliary/util/Release-iphoneos/libaux_util.a"
    "$BUILD_DIR/src/xrt/auxiliary/math/Release-iphoneos/libaux_math.a"
    "$BUILD_DIR/src/xrt/auxiliary/vk/Release-iphoneos/libaux_vk.a"
    "$BUILD_DIR/src/xrt/auxiliary/tracking/Release-iphoneos/libaux_tracking.a"
    "$BUILD_DIR/src/xrt/auxiliary/os/Release-iphoneos/libaux_os.a"
    "$BUILD_DIR/src/xrt/auxiliary/bindings/Release-iphoneos/libaux_generated_bindings.a"
    
    # External libraries
    "$BUILD_DIR/src/external/Release-iphoneos/libxrt-external-nanopb.a"
)

# Collect existing libraries
EXISTING_LIBS=()
for lib in "${STATIC_LIBRARIES[@]}"; do
    if [ -f "$lib" ]; then
        EXISTING_LIBS+=("$lib")
    fi
done

# Extract all object files from static libraries
echo "Extracting object files from static libraries..."
cd "$OUTPUT_DIR"
rm -rf extracted_objects
mkdir extracted_objects
cd extracted_objects

for lib in "${EXISTING_LIBS[@]}"; do
    if [ -f "$lib" ]; then
        echo "Extracting from $(basename "$lib")..."
        ar x "$lib"
    fi
done

# Create the unified dynamic library using clang++ directly
echo "Creating unified dynamic library using clang++..."
MOLTENVK_PATH="/Users/gfodor/portal/ios-OpenXR-SDK-Source/external/MoltenVK/MoltenVK/static/MoltenVK.xcframework/ios-arm64/libMoltenVK.a"
clang++ -dynamiclib -o "$OUTPUT_LIB" *.o \
    "$MOLTENVK_PATH" \
    -target arm64-apple-ios15.0 \
    -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS18.5.sdk \
    -framework Foundation \
    -framework ARKit \
    -framework Metal \
    -framework MetalKit \
    -framework QuartzCore \
    -framework UIKit \
    -framework CoreGraphics \
    -lc++ \
    -install_name "@rpath/libopenxr_monado.dylib" \
    -Wl,-undefined,suppress

cd ..
rm -rf extracted_objects

echo "Unified library created: $OUTPUT_LIB"
ls -lh "$OUTPUT_LIB"

echo ""
echo "To use this unified dynamic library in your iOS project:"
echo "1. Link against: $(basename "$OUTPUT_LIB")"
echo "2. Add frameworks: ARKit, Metal, MetalKit, QuartzCore"
echo "3. Add MoltenVK library and headers"
echo "4. Include headers from: src/xrt/include/openxr/"
echo "5. Ensure the dynamic library is bundled with your app"
echo ""
echo "This single dynamic library includes all necessary Monado OpenXR components:"
echo "- OpenXR 1.0 runtime implementation"
echo "- ARKit driver for iOS head tracking"
echo "- Metal compositor for rendering"
echo "- All auxiliary libraries (math, util, vulkan, etc.)"