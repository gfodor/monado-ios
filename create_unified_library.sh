#!/bin/bash

# Create unified OpenXR dynamic library for iOS
# This script combines all necessary libraries into a single libopenxr_monado_unified.dylib

set -e

BUILD_DIR="/Users/gfodor/portal/ios-monado/build-xcode"
OUTPUT_DIR="$BUILD_DIR/unified"
OUTPUT_LIB="$OUTPUT_DIR/libopenxr_monado.dylib"

echo "Creating unified OpenXR library for iOS..."

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "Collecting dynamic libraries and object files..."

# Collect all dynamic libraries if they exist, otherwise use static libraries
LIBRARIES=(
    # Core OpenXR libraries
    "$BUILD_DIR/src/xrt/targets/openxr/Release-iphoneos/libopenxr_monado.dylib"
    "$BUILD_DIR/src/xrt/state_trackers/oxr/Release-iphoneos/libst_oxr.dylib"
    "$BUILD_DIR/src/xrt/state_trackers/prober/Release-iphoneos/libst_prober.dylib"
    
    # Target libraries
    "$BUILD_DIR/src/xrt/targets/common/Release-iphoneos/libtarget_instance.dylib"
    "$BUILD_DIR/src/xrt/targets/common/Release-iphoneos/libtarget_lists.dylib"
    
    # Compositor libraries
    "$BUILD_DIR/src/xrt/compositor/Release-iphoneos/libcomp_main.dylib"
    "$BUILD_DIR/src/xrt/compositor/Release-iphoneos/libcomp_client.dylib"
    "$BUILD_DIR/src/xrt/compositor/Release-iphoneos/libcomp_util.dylib"
    "$BUILD_DIR/src/xrt/compositor/Release-iphoneos/libcomp_render.dylib"
    "$BUILD_DIR/src/xrt/compositor/Release-iphoneos/libcomp_multi.dylib"
    
    # Driver libraries
    "$BUILD_DIR/src/xrt/drivers/Release-iphoneos/libdrv_arkit.dylib"
    "$BUILD_DIR/src/xrt/drivers/Release-iphoneos/libdrv_multi.dylib"
    "$BUILD_DIR/src/xrt/drivers/Release-iphoneos/libdrv_simulated.dylib"
    
    # Auxiliary libraries
    "$BUILD_DIR/src/xrt/auxiliary/util/Release-iphoneos/libaux_util.dylib"
    "$BUILD_DIR/src/xrt/auxiliary/math/Release-iphoneos/libaux_math.dylib"
    "$BUILD_DIR/src/xrt/auxiliary/vk/Release-iphoneos/libaux_vk.dylib"
    "$BUILD_DIR/src/xrt/auxiliary/tracking/Release-iphoneos/libaux_tracking.dylib"
    "$BUILD_DIR/src/xrt/auxiliary/os/Release-iphoneos/libaux_os.dylib"
    "$BUILD_DIR/src/xrt/auxiliary/bindings/Release-iphoneos/libaux_generated_bindings.dylib"
    
    # External libraries
    "$BUILD_DIR/src/external/Release-iphoneos/libxrt-external-nanopb.dylib"
)

# Fallback to static libraries if dynamic libraries don't exist
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

echo "Creating unified dynamic library..."

# Create the unified dynamic library using static libraries
# First check if we have dynamic libraries, otherwise use static libraries
EXISTING_LIBS=()
for lib in "${LIBRARIES[@]}"; do
    if [ -f "$lib" ]; then
        EXISTING_LIBS+=("$lib")
    fi
done

# If no dynamic libraries exist, fall back to static libraries
if [ ${#EXISTING_LIBS[@]} -eq 0 ]; then
    echo "No dynamic libraries found, using static libraries..."
    for lib in "${STATIC_LIBRARIES[@]}"; do
        if [ -f "$lib" ]; then
            EXISTING_LIBS+=("$lib")
        fi
    done
fi

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