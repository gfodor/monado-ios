#!/bin/bash

# Create unified OpenXR static library for iOS
# This script combines all necessary static libraries into a single libopenxr_monado_unified.a

set -e

BUILD_DIR="/Users/gfodor/portal/ios-monado/build-xcode"
OUTPUT_DIR="$BUILD_DIR/unified"
OUTPUT_LIB="$OUTPUT_DIR/libopenxr_monado_unified.a"

echo "Creating unified OpenXR library for iOS..."

# Create output directory
mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

# Clean any previous extractions
rm -rf extracted_objects
mkdir extracted_objects
cd extracted_objects

echo "Extracting object files from static libraries..."

# Core OpenXR libraries
ar x "$BUILD_DIR/src/xrt/targets/openxr/Release-iphoneos/libopenxr_monado.a"
ar x "$BUILD_DIR/src/xrt/state_trackers/oxr/Release-iphoneos/libst_oxr.a"
ar x "$BUILD_DIR/src/xrt/state_trackers/prober/Release-iphoneos/libst_prober.a"

# Target libraries
ar x "$BUILD_DIR/src/xrt/targets/common/Release-iphoneos/libtarget_instance.a"
ar x "$BUILD_DIR/src/xrt/targets/common/Release-iphoneos/libtarget_lists.a"

# Compositor libraries
ar x "$BUILD_DIR/src/xrt/compositor/Release-iphoneos/libcomp_main.a"
ar x "$BUILD_DIR/src/xrt/compositor/Release-iphoneos/libcomp_client.a"
ar x "$BUILD_DIR/src/xrt/compositor/Release-iphoneos/libcomp_util.a"
ar x "$BUILD_DIR/src/xrt/compositor/Release-iphoneos/libcomp_render.a"
ar x "$BUILD_DIR/src/xrt/compositor/Release-iphoneos/libcomp_multi.a"

# Driver libraries
ar x "$BUILD_DIR/src/xrt/drivers/Release-iphoneos/libdrv_arkit.a"
ar x "$BUILD_DIR/src/xrt/drivers/Release-iphoneos/libdrv_multi.a"
ar x "$BUILD_DIR/src/xrt/drivers/Release-iphoneos/libdrv_simulated.a"

# Auxiliary libraries
ar x "$BUILD_DIR/src/xrt/auxiliary/util/Release-iphoneos/libaux_util.a"
ar x "$BUILD_DIR/src/xrt/auxiliary/math/Release-iphoneos/libaux_math.a"
ar x "$BUILD_DIR/src/xrt/auxiliary/vk/Release-iphoneos/libaux_vk.a"
ar x "$BUILD_DIR/src/xrt/auxiliary/tracking/Release-iphoneos/libaux_tracking.a"
ar x "$BUILD_DIR/src/xrt/auxiliary/os/Release-iphoneos/libaux_os.a"
ar x "$BUILD_DIR/src/xrt/auxiliary/bindings/Release-iphoneos/libaux_generated_bindings.a"

# External libraries
ar x "$BUILD_DIR/src/external/Release-iphoneos/libxrt-external-nanopb.a"

echo "Creating unified static library..."

# Create the unified library
ar rcs "$OUTPUT_LIB" *.o

cd ..
rm -rf extracted_objects

echo "Unified library created: $OUTPUT_LIB"
ls -lh "$OUTPUT_LIB"

echo ""
echo "To use this unified library in your iOS project:"
echo "1. Link against: $(basename "$OUTPUT_LIB")"
echo "2. Add frameworks: ARKit, Metal, MetalKit, QuartzCore"
echo "3. Add MoltenVK library and headers"
echo "4. Include headers from: src/xrt/include/openxr/"
echo ""
echo "This single library includes all necessary Monado OpenXR components:"
echo "- OpenXR 1.0 runtime implementation"
echo "- ARKit driver for iOS head tracking"
echo "- Metal compositor for rendering"
echo "- All auxiliary libraries (math, util, vulkan, etc.)"