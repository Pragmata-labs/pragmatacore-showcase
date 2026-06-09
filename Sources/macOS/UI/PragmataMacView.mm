#import "PragmataMacView.h"
#import "AppLog.h"
#import "PragmataCoreIOSBridge.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

const float MAC_FOCAL_LENGTH_MM  = 55.0f;
const float MAC_SENSOR_HEIGHT_MM = 24.0f;

static float macVerticalFOV() {
    float r = 2.0f * atanf(MAC_SENSOR_HEIGHT_MM / (2.0f * MAC_FOCAL_LENGTH_MM));
    return r * 180.0f / M_PI;
}

@interface PragmataMacView () <MTKViewDelegate, NSGestureRecognizerDelegate>
@property (nonatomic, strong) PragmataCoreIOSBridge *engineBridge;
@property (nonatomic, strong) MTKView *mtkView;
@property (nonatomic) NSTimeInterval lastFrameTime;
@property (nonatomic) float cachedAspect;
@property (nonatomic) BOOL engineSetupPending;
@property (nonatomic) BOOL engineLoading;
@property (nonatomic) NSTimeInterval initialLoadStartTime;
@property (nonatomic, strong) NSPanGestureRecognizer *orbitPanGesture;
@property (nonatomic, strong) NSMagnificationGestureRecognizer *orbitPinchGesture;
@end

@implementation PragmataMacView

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) [self setup];
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.engineBridge cleanup];
}

- (void)setup {
    self.wantsLayer = YES;
    self.layer.backgroundColor = NSColor.blackColor.CGColor;

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) {
        APP_LOG("PragmataMacView", "❌ No Metal device");
        return;
    }

    self.mtkView = [[MTKView alloc] initWithFrame:self.bounds device:device];
    self.mtkView.delegate = self;
    self.mtkView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.mtkView.colorPixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;  // sRGB: correct gamma for Filament tonemapping, reduces bloom HDR→LDR artifacts
    self.mtkView.clearColor = MTLClearColorMake(0, 0, 0, 1);
    self.mtkView.preferredFramesPerSecond = 60;
    self.mtkView.paused = NO;
    self.mtkView.enableSetNeedsDisplay = NO;
    self.mtkView.framebufferOnly = NO;  // desktop post-processing passes need to sample the drawable
    [self addSubview:self.mtkView];

    // Orbit rotation handled by SwiftUI DragGesture in MacConfiguratorView.
    // Only scroll-wheel zoom is handled natively here (scrollWheel: override).

    self.engineSetupPending = YES;
    dispatch_async(dispatch_get_main_queue(), ^{ [self setupEngineIfReady]; });

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(appDidHide)
               name:NSApplicationDidHideNotification object:nil];
    [nc addObserver:self selector:@selector(appWillUnhide)
               name:NSApplicationWillUnhideNotification object:nil];
}

// Called when the view moves to a window (or is removed from one).
// Subscribe to occlusion changes only when we have a window.
- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self name:NSWindowDidChangeOcclusionStateNotification object:nil];
    if (self.window) {
        [nc addObserver:self selector:@selector(occlusionStateChanged)
                   name:NSWindowDidChangeOcclusionStateNotification
                 object:self.window];
    }
}

- (void)occlusionStateChanged {
    BOOL visible = (self.window.occlusionState & NSWindowOcclusionStateVisible) != 0;
    self.mtkView.paused = !visible;
    if (visible) {
        APP_LOG("PragmataMacView", "▶️ Renderer resumed (window visible)");
    } else {
        APP_LOG("PragmataMacView", "⏸️ Renderer paused (window occluded)");
    }
}

- (void)appDidHide {
    self.mtkView.paused = YES;
    APP_LOG("PragmataMacView", "⏸️ Renderer paused (app hidden)");
}

- (void)appWillUnhide {
    self.mtkView.paused = NO;
    APP_LOG("PragmataMacView", "▶️ Renderer resumed (app unhidden)");
}

- (void)layout {
    [super layout];
    if (self.mtkView && !NSEqualSizes(self.mtkView.frame.size, self.bounds.size))
        self.mtkView.frame = self.bounds;
    if (self.engineSetupPending && self.bounds.size.width > 0 && self.bounds.size.height > 0)
        [self setupEngineIfReady];
}

- (void)setupEngineIfReady {
    if (!self.mtkView || !self.engineSetupPending) return;
    CGSize sz = self.mtkView.drawableSize;
    if (sz.width == 0 || sz.height == 0) {
        // drawableSize not yet set — scale logical bounds by Retina factor manually
        CGFloat scale = self.window ? self.window.backingScaleFactor : NSScreen.mainScreen.backingScaleFactor;
        if (scale <= 0) scale = 2.0;
        sz = CGSizeMake(self.mtkView.bounds.size.width  * scale,
                        self.mtkView.bounds.size.height * scale);
    }
    if (sz.width == 0 || sz.height == 0) return;
    self.engineSetupPending = NO;
    [self setupEngineWithSize:sz];
}

- (void)setupEngineWithSize:(CGSize)sz {
    self.engineBridge = [[PragmataCoreIOSBridge alloc] init];
    if (![self.engineBridge setupWithMTKView:self.mtkView]) {
        APP_LOG("PragmataMacView", "❌ Engine setup failed");
        self.engineSetupPending = YES;
        return;
    }

    self.engineLoading = YES;

    float aspect = sz.width / sz.height;
    self.cachedAspect = aspect;
    [self.engineBridge setCameraViewport:(int)sz.width height:(int)sz.height];
    [self.engineBridge setCameraProjection:macVerticalFOV() aspect:aspect near:0.1f far:1000.0f];

    __weak PragmataMacView *weakSelf = self;
    [self.engineBridge setOnInitialLoadComplete:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            PragmataMacView *s = weakSelf;
            if (!s) return;
            s.engineLoading = NO;
            s.mtkView.paused = NO;
            if (s.loadingProgressCallback) s.loadingProgressCallback(1.0f, @"Ready");
        });
    }];

    // Load all configs on main thread (Filament thread-safety requirement).
    NSString *cam = [[NSBundle mainBundle] pathForResource:@"cameras" ofType:@"ini"];
    if (cam) [self.engineBridge loadCameraConfig:cam];
    else APP_LOG("PragmataMacView", "⚠️ cameras.ini not found");

    NSString *sys = [[NSBundle mainBundle] pathForResource:@"system" ofType:@"ini" inDirectory:@"ControlsINI"];
    if (sys) [self.engineBridge loadSystemConfig:sys];
    else APP_LOG("PragmataMacView", "⚠️ system.ini not found");

    NSString *interior = [[NSBundle mainBundle] pathForResource:@"interior" ofType:@"ini" inDirectory:@"ControlsINI"];
    if (interior) [self.engineBridge loadInteriorConfig:interior];
    else APP_LOG("PragmataMacView", "⚠️ interior.ini not found");

    NSString *env = [[NSBundle mainBundle] pathForResource:@"environment" ofType:@"ini" inDirectory:@"ControlsINI"];
    if (env) [self.engineBridge loadEnvironmentConfig:env];
    else APP_LOG("PragmataMacView", "⚠️ environment.ini not found");

    // Start IBL loading NOW, before model load, so it's ready when rendering begins.
    [self.engineBridge setSceneEnvironment:@"Hangar"];

    if (self.loadingProgressCallback) self.loadingProgressCallback(0.1f, @"Initializing...");

    // Load model on background thread in parallel with IBL loading.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        self.initialLoadStartTime = CACurrentMediaTime();
        [self.engineBridge loadModel:@"PCraft400" preset:@"Front"];
    });
}

// MARK: - MTKViewDelegate

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    (void)view;
    if (self.engineSetupPending && size.width > 0 && size.height > 0) {
        self.engineSetupPending = NO;
        [self setupEngineWithSize:size];
        return;
    }
    if (!self.engineBridge) return;
    float aspect = size.width / size.height;
    self.cachedAspect = aspect;
    [self.engineBridge setCameraViewport:(int)size.width height:(int)size.height];
    [self.engineBridge setCameraProjection:macVerticalFOV() aspect:aspect near:0.1f far:1000.0f];
}

- (void)drawInMTKView:(nonnull MTKView *)view {
    (void)view;
    if (self.engineSetupPending && view.drawableSize.width > 0) [self setupEngineIfReady];
    if (!self.engineBridge) return;
    if (self.engineLoading) return;

    NSTimeInterval now = CACurrentMediaTime();
    float dt = self.lastFrameTime > 0 ? (float)(now - self.lastFrameTime) : (1.0f/60.0f);
    dt = fminf(dt, 1.0f/30.0f);
    self.lastFrameTime = now;

    [self.engineBridge update:dt];
    [self.engineBridge render];

    int fps = [self.engineBridge getTargetFPS];
    if (self.mtkView.preferredFramesPerSecond != fps) self.mtkView.preferredFramesPerSecond = fps;
}

// MARK: - First responder (required for scrollWheel: to fire)

- (BOOL)acceptsFirstResponder { return YES; }

- (void)mouseDown:(NSEvent *)event {
    [self.window makeFirstResponder:self];
}

// MARK: - Scroll wheel zoom

- (void)scrollWheel:(NSEvent *)event {
    if (!self.engineBridge || ![self.engineBridge isOrbitEnabled]) return;
    float delta = (float)event.scrollingDeltaY * 0.01f;
    [self.engineBridge applyOrbitZoom:delta];
    self.mtkView.paused = NO;
}

// MARK: - Gesture handlers

- (void)handleOrbitPan:(NSPanGestureRecognizer *)gesture {
    if (![self.engineBridge isOrbitEnabled]) return;
    CGPoint t = [gesture translationInView:self];
    const float sensitivity = 0.005f;
    [self.engineBridge applyOrbitRotationDeltaX:(float)t.x * sensitivity
                                         deltaY:-(float)t.y * sensitivity];
    [gesture setTranslation:CGPointZero inView:self];
    self.mtkView.paused = NO;
}

- (void)handleOrbitPinch:(NSMagnificationGestureRecognizer *)gesture {
    if (![self.engineBridge isOrbitEnabled]) return;
    float delta = (float)(1.0 - gesture.magnification) * 0.5f;
    [self.engineBridge applyOrbitZoom:delta];
    gesture.magnification = 0;
    self.mtkView.paused = NO;
}

// MARK: - Public API

- (void)setSignalCallback:(void (^)(NSString *, NSString *))callback {
    [self.engineBridge setSignalCallback:callback];
}

- (void)setOrbitEnabled:(BOOL)enabled {
    [self.engineBridge setOrbitEnabled:enabled];
}
- (BOOL)isOrbitEnabled { return [self.engineBridge isOrbitEnabled]; }
- (void)applyOrbitRotationDeltaX:(float)dx deltaY:(float)dy {
    [self.engineBridge applyOrbitRotationDeltaX:dx deltaY:dy];
    self.mtkView.paused = NO;
}
- (void)applyOrbitZoom:(float)delta {
    [self.engineBridge applyOrbitZoom:delta];
    self.mtkView.paused = NO;
}
- (float)getIPadZoomOffset { return [self.engineBridge getIPadZoomOffset]; }

- (void)applyHullColor:(NSString *)n      { [self.engineBridge applyHullColor:n]; }
- (void)applySeatColor:(NSString *)n      { [self.engineBridge applySeatColor:n]; }
- (void)applyDeckTexture:(NSString *)n    { [self.engineBridge applyDeckTexture:n]; }
- (void)applyWoodTexture:(NSString *)n    { [self.engineBridge applyWoodTexture:n]; }
- (void)applyEquipmentPackage:(NSString *)n { [self.engineBridge applyEquipmentPackage:n]; }
- (void)applyLeatherColor:(NSString *)n   { [self.engineBridge applyLeatherColor:n]; }
- (void)applyLivery:(NSInteger)i          { [self.engineBridge applyLivery:i]; }

- (void)setEnvironmentPreset:(NSString *)n  { [self.engineBridge setEnvironmentPreset:n]; }
- (void)setSceneEnvironment:(NSString *)n   { [self.engineBridge setSceneEnvironment:n]; }
- (void)switchSceneEnvironment:(NSString *)n { [self.engineBridge switchSceneEnvironment:n]; }
- (void)setShipState:(NSString *)s          { [self.engineBridge setShipState:s]; }
- (void)setInteriorMode:(BOOL)e             { [self.engineBridge setInteriorMode:e]; }
- (void)switchSceneMode:(NSString *)m       { [self.engineBridge switchSceneMode:m]; }

- (void)moveToPresetFront    { [self.engineBridge moveToCameraPreset:@"Front"]; }
- (void)moveToPresetTop      { [self.engineBridge moveToCameraPreset:@"Top"]; }
- (void)moveToPresetRear     { [self.engineBridge moveToCameraPreset:@"Rear"]; }
- (void)moveToPresetSide     { [self.engineBridge moveToCameraPreset:@"Side"]; }
- (void)moveToPresetInterior { [self.engineBridge moveToCameraPreset:@"Interior"]; }
- (void)moveToPreset:(NSString *)name { [self.engineBridge moveToCameraPreset:name]; }

- (NSInteger)getAnimationCount { return [self.engineBridge getAnimationCount]; }
- (NSString *)getAnimationNameAtIndex:(NSInteger)i { return [self.engineBridge getAnimationName:i]; }
- (void)playAnimationAtIndex:(NSInteger)i action:(NSString *)a partName:(NSString *)p {
    [self.engineBridge playAnimation:i action:a partName:p];
}
- (void)stopAnimationAtIndex:(NSInteger)i  { [self.engineBridge stopAnimation:i]; }
- (BOOL)isAnimationActiveAtIndex:(NSInteger)i { return [self.engineBridge isAnimationActive:i]; }

- (void)setNightMode:(BOOL)e              { [self.engineBridge setNightMode:e]; }
- (void)setBloomEnabled:(BOOL)e           { [self.engineBridge setBloomEnabled:e]; }
- (void)setBloomStrength:(float)s levels:(int)l quality:(int)q {
    [self.engineBridge setBloomStrength:s levels:l quality:q];
}
- (void)setAmbientOcclusionEnabled:(BOOL)e { [self.engineBridge setAmbientOcclusionEnabled:e]; }
- (BOOL)getAmbientOcclusionEnabled         { return [self.engineBridge getAmbientOcclusionEnabled]; }

- (void)setResolutionPreset:(ResolutionPreset)preset {
    float scale;
    switch (preset) {
        case ResolutionPresetNative: scale = 1.00f; break;
        case ResolutionPresetHigh:   scale = 0.70f; break;
        case ResolutionPresetHalf:   scale = 0.50f; break;
        default:                     scale = 0.33f; break;
    }
    [self.engineBridge setDynamicResolutionScale:scale];
}
- (float)getCurrentResolutionScale { return [self.engineBridge getCurrentResolutionScale]; }

- (void)setAntiAliasingFXAA:(BOOL)e                         { [self.engineBridge setFXAAEnabled:e]; }
- (void)setAntiAliasingMSAA:(BOOL)e sampleCount:(int)n       { [self.engineBridge setMSAAEnabled:e sampleCount:n]; }
- (NSInteger)getAntiAliasingType                             { return [self.engineBridge getAntiAliasingType]; }

- (void)setToneMapper:(NSInteger)t  { [self.engineBridge setToneMapper:t]; }
- (NSInteger)getToneMapper          { return [self.engineBridge getToneMapper]; }

- (void)setDebugAxisVisible:(BOOL)v { [self.engineBridge setDebugAxisVisible:v]; }
- (BOOL)isDebugAxisVisible          { return [self.engineBridge isDebugAxisVisible]; }

- (void)setSunLightIntensity:(float)v    { [self.engineBridge setSunLightIntensity:v]; }
- (float)getSunLightIntensity            { return [self.engineBridge getSunLightIntensity]; }
- (void)setAmbientLightIntensity:(float)v { [self.engineBridge setAmbientLightIntensity:v]; }
- (float)getAmbientLightIntensity        { return [self.engineBridge getAmbientLightIntensity]; }

- (void)playAnimationReverseAtIndex:(NSInteger)i action:(NSString *)a partName:(NSString *)p {
    [self.engineBridge playReverseAnimation:i action:a partName:p];
}

@end
