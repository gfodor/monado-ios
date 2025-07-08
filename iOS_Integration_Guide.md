# Monado OpenXR iOS Integration Guide

This guide will help you integrate the Monado OpenXR runtime into your iOS app and create a working Hello XR example.

## Prerequisites

- Xcode 14.0 or later
- iOS 15.0 or later target
- ARKit-compatible device (iPhone/iPad with A12 chip or later)
- MoltenVK SDK

## Step 1: Project Setup

### 1.1 Create New iOS Project
```bash
# Create a new iOS project in Xcode
# Choose "App" template
# Language: Objective-C or Swift
# Minimum iOS version: 15.0
```

### 1.2 Add Required Frameworks
In your Xcode project, add these frameworks:
- `ARKit.framework`
- `Metal.framework` 
- `MetalKit.framework`
- `QuartzCore.framework`
- `AVFoundation.framework`
- `CoreMotion.framework`
- `Foundation.framework`
- `UIKit.framework`

### 1.3 Add MoltenVK
1. Download MoltenVK from [GitHub](https://github.com/KhronosGroup/MoltenVK/releases)
2. Add `libMoltenVK.a` to your project
3. Add MoltenVK headers to your header search paths

## Step 2: Add Monado OpenXR Library

### 2.1 Copy Library and Headers
```bash
# Copy the unified library to your project
cp /Users/gfodor/portal/ios-monado/build-xcode/unified/libopenxr_monado_unified.a YourProject/Libraries/

# Copy OpenXR headers
cp -r /Users/gfodor/portal/ios-monado/src/xrt/include/openxr/ YourProject/Headers/
```

### 2.2 Xcode Project Settings
1. Add `libopenxr_monado_unified.a` to "Link Binary With Libraries"
2. Set Header Search Paths to include your headers directory
3. Set Library Search Paths to include your libraries directory
4. Add `-ObjC` to "Other Linker Flags"

## Step 3: Configure Info.plist

Add ARKit usage description:
```xml
<key>NSCameraUsageDescription</key>
<string>This app uses ARKit for head tracking in OpenXR</string>
<key>UIRequiredDeviceCapabilities</key>
<array>
    <string>arkit</string>
    <string>metal</string>
</array>
```

## Step 4: Hello XR Implementation

### 4.1 Basic OpenXR Headers (HelloXR.h)
```objc
#import <Foundation/Foundation.h>
#import <ARKit/ARKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

// OpenXR includes
#define XR_USE_PLATFORM_IOS
#define XR_USE_GRAPHICS_API_METAL
#include "openxr/openxr.h"
#include "openxr/openxr_platform.h"

@interface HelloXR : NSObject

@property (nonatomic, strong) id<MTLDevice> metalDevice;
@property (nonatomic, strong) MTKView *metalView;

// OpenXR objects
@property (nonatomic) XrInstance instance;
@property (nonatomic) XrSystemId systemId;
@property (nonatomic) XrSession session;
@property (nonatomic) XrSpace appSpace;
@property (nonatomic) XrSwapchain swapchain;

- (BOOL)initializeOpenXR;
- (BOOL)createSession;
- (void)renderFrame;
- (void)cleanup;

@end
```

### 4.2 OpenXR Implementation (HelloXR.m)
```objc
#import "HelloXR.h"

@implementation HelloXR

- (instancetype)init {
    self = [super init];
    if (self) {
        self.metalDevice = MTLCreateSystemDefaultDevice();
    }
    return self;
}

- (BOOL)initializeOpenXR {
    // Create OpenXR instance
    XrInstanceCreateInfo instanceCreateInfo = {
        .type = XR_TYPE_INSTANCE_CREATE_INFO,
        .applicationInfo = {
            .applicationName = "Hello XR iOS",
            .applicationVersion = 1,
            .engineName = "Custom Engine",
            .engineVersion = 1,
            .apiVersion = XR_CURRENT_API_VERSION
        }
    };
    
    // Enable required extensions
    const char* extensions[] = {
        XR_KHR_METAL_ENABLE_EXTENSION_NAME,
        XR_EXTX_OVERLAY_EXTENSION_NAME  // If using overlay
    };
    instanceCreateInfo.enabledExtensionCount = sizeof(extensions) / sizeof(extensions[0]);
    instanceCreateInfo.enabledExtensionNames = extensions;
    
    XrResult result = xrCreateInstance(&instanceCreateInfo, &_instance);
    if (XR_FAILED(result)) {
        NSLog(@"Failed to create OpenXR instance: %d", result);
        return NO;
    }
    
    // Get system
    XrSystemGetInfo systemGetInfo = {
        .type = XR_TYPE_SYSTEM_GET_INFO,
        .formFactor = XR_FORM_FACTOR_HEAD_MOUNTED_DISPLAY
    };
    
    result = xrGetSystem(_instance, &systemGetInfo, &_systemId);
    if (XR_FAILED(result)) {
        NSLog(@"Failed to get OpenXR system: %d", result);
        return NO;
    }
    
    NSLog(@"OpenXR instance and system created successfully");
    return YES;
}

- (BOOL)createSession {
    // Graphics binding for Metal
    XrGraphicsBindingMetalKHR metalBinding = {
        .type = XR_TYPE_GRAPHICS_BINDING_METAL_KHR,
        .device = (__bridge void*)self.metalDevice
    };
    
    XrSessionCreateInfo sessionCreateInfo = {
        .type = XR_TYPE_SESSION_CREATE_INFO,
        .next = &metalBinding,
        .systemId = _systemId
    };
    
    XrResult result = xrCreateSession(_instance, &sessionCreateInfo, &_session);
    if (XR_FAILED(result)) {
        NSLog(@"Failed to create OpenXR session: %d", result);
        return NO;
    }
    
    // Create reference space
    XrReferenceSpaceCreateInfo spaceCreateInfo = {
        .type = XR_TYPE_REFERENCE_SPACE_CREATE_INFO,
        .referenceSpaceType = XR_REFERENCE_SPACE_TYPE_LOCAL,
        .poseInReferenceSpace = {
            .orientation = {0, 0, 0, 1},
            .position = {0, 0, 0}
        }
    };
    
    result = xrCreateReferenceSpace(_session, &spaceCreateInfo, &_appSpace);
    if (XR_FAILED(result)) {
        NSLog(@"Failed to create reference space: %d", result);
        return NO;
    }
    
    NSLog(@"OpenXR session created successfully");
    return YES;
}

- (void)createSwapchain {
    // Query swapchain formats
    uint32_t formatCount;
    xrEnumerateSwapchainFormats(_session, 0, &formatCount, NULL);
    
    int64_t *formats = malloc(sizeof(int64_t) * formatCount);
    xrEnumerateSwapchainFormats(_session, formatCount, &formatCount, formats);
    
    // Choose a format (prefer BGRA8)
    int64_t chosenFormat = formats[0]; // Default to first
    for (uint32_t i = 0; i < formatCount; i++) {
        if (formats[i] == MTLPixelFormatBGRA8Unorm) {
            chosenFormat = formats[i];
            break;
        }
    }
    free(formats);
    
    // Create swapchain
    XrSwapchainCreateInfo swapchainCreateInfo = {
        .type = XR_TYPE_SWAPCHAIN_CREATE_INFO,
        .usageFlags = XR_SWAPCHAIN_USAGE_SAMPLED_BIT | XR_SWAPCHAIN_USAGE_COLOR_ATTACHMENT_BIT,
        .format = chosenFormat,
        .sampleCount = 1,
        .width = 1024,  // Adjust based on your needs
        .height = 1024,
        .faceCount = 1,
        .arraySize = 1,
        .mipCount = 1
    };
    
    XrResult result = xrCreateSwapchain(_session, &swapchainCreateInfo, &_swapchain);
    if (XR_FAILED(result)) {
        NSLog(@"Failed to create swapchain: %d", result);
    }
}

- (void)renderFrame {
    // Wait for frame
    XrFrameWaitInfo frameWaitInfo = {XR_TYPE_FRAME_WAIT_INFO};
    XrFrameState frameState = {XR_TYPE_FRAME_STATE};
    xrWaitFrame(_session, &frameWaitInfo, &frameState);
    
    // Begin frame
    XrFrameBeginInfo frameBeginInfo = {XR_TYPE_FRAME_BEGIN_INFO};
    xrBeginFrame(_session, &frameBeginInfo);
    
    // Render your content here
    // This is where you would render your 3D scene
    
    // End frame
    XrFrameEndInfo frameEndInfo = {
        .type = XR_TYPE_FRAME_END_INFO,
        .displayTime = frameState.predictedDisplayTime,
        .environmentBlendMode = XR_ENVIRONMENT_BLEND_MODE_OPAQUE
    };
    xrEndFrame(_session, &frameEndInfo);
}

- (void)cleanup {
    if (_swapchain != XR_NULL_HANDLE) {
        xrDestroySwapchain(_swapchain);
    }
    if (_appSpace != XR_NULL_HANDLE) {
        xrDestroySpace(_appSpace);
    }
    if (_session != XR_NULL_HANDLE) {
        xrDestroySession(_session);
    }
    if (_instance != XR_NULL_HANDLE) {
        xrDestroyInstance(_instance);
    }
}

@end
```

### 4.3 View Controller Integration (ViewController.m)
```objc
#import "ViewController.h"
#import "HelloXR.h"

@interface ViewController ()
@property (nonatomic, strong) HelloXR *openXRApp;
@property (nonatomic, strong) CADisplayLink *displayLink;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Initialize OpenXR
    self.openXRApp = [[HelloXR alloc] init];
    
    if (![self.openXRApp initializeOpenXR]) {
        NSLog(@"Failed to initialize OpenXR");
        return;
    }
    
    if (![self.openXRApp createSession]) {
        NSLog(@"Failed to create OpenXR session");
        return;
    }
    
    // Start render loop
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(renderLoop)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
}

- (void)renderLoop {
    [self.openXRApp renderFrame];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.displayLink invalidate];
    [self.openXRApp cleanup];
}

@end
```

## Step 5: Build Configuration

### 5.1 Compiler Flags
Add to "Other C Flags":
```
-DXR_USE_PLATFORM_IOS
-DXR_USE_GRAPHICS_API_METAL
```

### 5.2 Linker Flags  
Add to "Other Linker Flags":
```
-ObjC
-lc++
-framework ARKit
-framework Metal
-framework MetalKit
-framework QuartzCore
```

## Step 6: Testing

### 6.1 Device Requirements
- iPhone/iPad with A12 chip or later
- iOS 15.0 or later
- Good lighting conditions for ARKit

### 6.2 Basic Testing
1. Build and run on device (not simulator)
2. Grant camera permissions
3. Check console for OpenXR initialization messages
4. Verify ARKit session starts

## Step 7: Advanced Features

### 7.1 Hand Tracking (if supported)
```objc
// Enable hand tracking extension
const char* handTrackingExt = XR_EXT_HAND_TRACKING_EXTENSION_NAME;
// Add to extensions array in instance creation
```

### 7.2 Eye Tracking (if supported)
```objc
// Enable eye tracking extension  
const char* eyeTrackingExt = XR_EXT_EYE_GAZE_INTERACTION_EXTENSION_NAME;
// Add to extensions array in instance creation
```

## Troubleshooting

### Common Issues
1. **Library linking errors**: Ensure all frameworks are properly linked
2. **ARKit permissions**: Check camera usage description in Info.plist
3. **OpenXR initialization fails**: Verify device supports ARKit
4. **Metal errors**: Ensure Metal device creation succeeds

### Debug Tips
- Enable OpenXR validation layers in debug builds
- Use Xcode's Metal debugger for graphics issues
- Check ARKit session state
- Monitor console logs for OpenXR errors

## Next Steps

1. Implement proper 3D rendering
2. Add controller support
3. Implement spatial anchors
4. Add haptic feedback
5. Optimize for performance

This guide provides a foundation for OpenXR development on iOS using the Monado runtime. Extend it based on your specific application needs.