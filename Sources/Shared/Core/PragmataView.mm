/**
 * @file PragmataView.mm
 * @brief Implementation of the PragmataView UI component.
 *
 * This file handles iOS-specific view concerns, MTKView lifecycle,
 * gesture recognition for orbit controls, and bridges all rendering
 * calls to the PragmataCoreIOSBridge.
 *
 * REFACTORED: UI Event Handler - delegates to PragmataCoreIOSBridge
 */

#import "PragmataView.h"
#import "AppLog.h"
#import "PragmataCoreIOSBridge.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

// ============================================================================
// MARK: - Private Interface
// ============================================================================

/**
 * @brief Private properties and protocols for PragmataView.
 */
@interface PragmataView () <MTKViewDelegate, UIGestureRecognizerDelegate>

/** Bridge to the C++/Filament engine. */
@property(nonatomic, strong) PragmataCoreIOSBridge *engineBridge;

/** MetalKit view for hardware-accelerated rendering. */
@property(nonatomic, strong) MTKView *mtkView;

/** Timestamp of the last rendered frame for delta time calculation. */
@property(nonatomic) NSTimeInterval lastFrameTime;

/** @name Zoom Effect State */
/** @{ */
@property(nonatomic) BOOL isZooming;
@property(nonatomic) float zoomStartFOV;
@property(nonatomic) float zoomTargetFOV;
@property(nonatomic) NSTimeInterval zoomStartTime;
@property(nonatomic) float zoomDuration;
@property(nonatomic) float cachedAspect;
/** @} */

/** Timestamp of the last background color update to throttle CPU usage. */
@property(nonatomic) NSTimeInterval lastBackgroundColorUpdateTime;

/** @name Orbit Controls */
/** @{ */
@property(nonatomic, strong) UIPanGestureRecognizer *orbitPanGesture;
#if TARGET_OS_IOS
@property(nonatomic, strong) UIPinchGestureRecognizer *orbitPinchGesture;
#endif
/** Track if gestures are temporarily disabled (e.g. menu open). */
@property(nonatomic) BOOL orbitGesturesTemporarilyDisabled;
/** @} */

/** On tvOS, engine setup is deferred until MTKView has non-zero drawable size.
 */
@property(nonatomic) BOOL engineSetupPending;

/** When initial load started (for minimum 1s loading screen). */
@property(nonatomic) NSTimeInterval initialLoadStartTime;

@end

// ============================================================================
// MARK: - Constants
// ============================================================================

const float FOCAL_LENGTH_MM = 55.0f;
const float SENSOR_HEIGHT_MM = 24.0f;

/**
 * Calculates the vertical field of view in degrees.
 *
 * @param focalLengthMM  The focal length in millimeters.
 * @param sensorHeightMM The height of the sensor in millimeters.
 * @return The vertical FOV in degrees.
 */
inline float calculateVerticalFOV(float focalLengthMM, float sensorHeightMM) {
  float fovRadians = 2.0f * atanf(sensorHeightMM / (2.0f * focalLengthMM));
  return fovRadians * 180.0f / M_PI;
}

// ============================================================================
// MARK: - Implementation
// ============================================================================

@implementation PragmataView

// ============================================================================
// MARK: - Loading Progress
// ============================================================================

/**
 * Reports loading progress to the UI layer on the main thread.
 */
- (void)reportProgress:(float)progress stage:(NSString *)stage {
  if (!self.loadingProgressCallback)
    return;
  dispatch_async(dispatch_get_main_queue(), ^{
    if (self.loadingProgressCallback) {
      self.loadingProgressCallback(progress, stage);
    }
  });
}

// ============================================================================
// MARK: - User Input
// ============================================================================

- (void)notifyUserInput {
  [self.engineBridge notifyUserInput];
  self.mtkView.paused = NO;
}

// ============================================================================
// MARK: - Lifecycle
// ============================================================================

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    [self setup];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self.engineBridge cleanup];
}

// ============================================================================
// MARK: - Setup
// ============================================================================

/**
 * Orchestrates the initial setup of the view, MTKView, and engine bridge.
 */
- (void)setup {
  id<MTLDevice> device = MTLCreateSystemDefaultDevice();
  if (!device) {
    APP_LOG("PragmataView", "No Metal device. Simulator/GPU issue.");
    self.backgroundColor = [UIColor blackColor];
    return;
  }

  [self setupMTKViewWithDevice:device];
  [self setupAppearance];
  [self scheduleEngineSetup];
  [self setupLifecycleObservers];
}

- (void)setupLifecycleObservers {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc addObserver:self
         selector:@selector(appDidEnterBackground)
             name:UIApplicationDidEnterBackgroundNotification
           object:nil];
  [nc addObserver:self
         selector:@selector(appWillEnterForeground)
             name:UIApplicationWillEnterForegroundNotification
           object:nil];
}

- (void)appDidEnterBackground {
  self.mtkView.paused = YES;
  APP_LOG("PragmataView", "⏸️ Renderer paused (background)");
}

- (void)appWillEnterForeground {
  self.mtkView.paused = NO;
  APP_LOG("PragmataView", "▶️ Renderer resumed (foreground)");
}

/**
 * Configures the MTKView with the provided Metal device.
 */
- (void)setupMTKViewWithDevice:(id<MTLDevice>)device {
  self.mtkView = [[MTKView alloc] initWithFrame:self.bounds device:device];
  self.mtkView.delegate = self;
  self.mtkView.autoresizingMask =
      UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  self.mtkView.colorPixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;  // sRGB: correct gamma for Filament tonemapping
  self.mtkView.clearColor = MTLClearColorMake(0, 0, 0, 1);
  self.mtkView.preferredFramesPerSecond = 60;
  self.mtkView.paused = NO; // CRITICAL: Must be NO to enable rendering
  self.mtkView.enableSetNeedsDisplay = NO;

  APP_LOG("PragmataView", "🔧 MTKView paused=%d, preferredFPS=%ld",
          self.mtkView.paused, (long)self.mtkView.preferredFramesPerSecond);
  self.mtkView.framebufferOnly = YES;

  [self addSubview:self.mtkView];
  APP_LOG("PragmataView",
          "✅ MTKView created {{%.0f, %.0f}, {%.0f, %.0f}} "
         @"(native resolution)",
          self.bounds.origin.x, self.bounds.origin.y, self.bounds.size.width,
          self.bounds.size.height);
}

/**
 * Sets up basic UIView appearance and layout properties.
 */
- (void)setupAppearance {
  self.backgroundColor = [UIColor blackColor];
  self.clipsToBounds = YES;
  self.userInteractionEnabled = YES;

  // Setup orbit controls gesture recognizers
  [self setupOrbitGestures];
}

/**
 * Configures gesture recognizers for manual orbit camera control.
 */
- (void)setupOrbitGestures {
  // Pan gesture for rotation
  self.orbitPanGesture = [[UIPanGestureRecognizer alloc]
      initWithTarget:self
              action:@selector(handleOrbitPan:)];
#if TARGET_OS_IOS
  self.orbitPanGesture.minimumNumberOfTouches = 1;
  self.orbitPanGesture.maximumNumberOfTouches = 1;
#endif
  self.orbitPanGesture.enabled =
      NO; // Disabled by default, enabled when orbit is on
  self.orbitPanGesture.delegate = self;
  [self addGestureRecognizer:self.orbitPanGesture];

#if TARGET_OS_IOS
  // Pinch gesture for zoom
  self.orbitPinchGesture = [[UIPinchGestureRecognizer alloc]
      initWithTarget:self
              action:@selector(handleOrbitPinch:)];
  self.orbitPinchGesture.enabled =
      NO; // Disabled by default, enabled when orbit is on
  [self addGestureRecognizer:self.orbitPinchGesture];
#endif

  // Initialize temporary disable flag
  self.orbitGesturesTemporarilyDisabled = NO;
}

// MARK: - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
  // If this is orbit pan gesture, check if it started in swipe zone
  if (gestureRecognizer == self.orbitPanGesture) {
    CGPoint location = [gestureRecognizer locationInView:self];
    CGFloat screenWidth = self.bounds.size.width;
    const CGFloat swipeZoneWidth =
        50.0f; // Same as in ViewController (right 50pt)

    // Don't begin orbit pan if gesture started in swipe zone
    if (location.x > screenWidth - swipeZoneWidth) {
      return NO; // Let swipe gesture handle it
    }
  }
  return YES;
}

/**
 * Schedules the engine bridge setup on the next run loop cycle.
 */
- (void)scheduleEngineSetup {
  self.engineSetupPending = YES;
  dispatch_async(dispatch_get_main_queue(), ^{
    [self setupEngineIfReady];
  });
}

/**
 * Calls setupEngine only when MTKView has a valid drawable size.
 * Used to defer setup on tvOS where size can be zero at init.
 */
- (void)setupEngineIfReady {
  if (!self.mtkView || !self.engineSetupPending) {
    return;
  }
  CGSize drawableSize = self.mtkView.drawableSize;
  if (drawableSize.width == 0 || drawableSize.height == 0) {
    drawableSize = self.mtkView.bounds.size;
  }
  if (drawableSize.width == 0 || drawableSize.height == 0) {
#if TARGET_OS_TV
    APP_LOG("PragmataView",
            "tvOS: deferring engine setup until drawable size is "
           @"non-zero");
#endif
    return;
  }
  self.engineSetupPending = NO;
  [self setupEngineWithDrawableSize:drawableSize];
}

/**
 * Initializes the C++/Filament engine bridge and loads initial assets.
 * Requires non-zero drawableSize (call from setupEngineIfReady or
 * drawableSizeWillChange).
 */
- (void)setupEngineWithDrawableSize:(CGSize)drawableSize {
  if (!self.mtkView) {
    APP_LOG("PragmataView", "❌ MTKView not available");
    return;
  }

  self.engineBridge = [[PragmataCoreIOSBridge alloc] init];
  if (![self.engineBridge setupWithMTKView:self.mtkView]) {
    APP_LOG("PragmataView", "❌ Engine setup failed");
    self.engineSetupPending = YES;
    return;
  }

  float aspect = drawableSize.width / drawableSize.height;
  self.cachedAspect = aspect;

  [self.engineBridge setCameraViewport:(int)drawableSize.width
                                height:(int)drawableSize.height];

  float verticalFOV = calculateVerticalFOV(FOCAL_LENGTH_MM, SENSOR_HEIGHT_MM);
  [self.engineBridge setCameraProjection:verticalFOV
                                  aspect:aspect
                                    near:0.1f
                                     far:1000.0f];

  APP_LOG("PragmataView", "📷 Viewport set: %dx%d, FOV: %.2f°, aspect: %.4f",
          (int)drawableSize.width, (int)drawableSize.height, verticalFOV,
          aspect);

  __weak PragmataView *weakSelf = self;
  [self.engineBridge setOnInitialLoadComplete:^{
    PragmataView *strongSelf = weakSelf;
    if (!strongSelf)
      return;
    NSTimeInterval elapsed =
        CACurrentMediaTime() - strongSelf.initialLoadStartTime;
    NSTimeInterval delay = (elapsed < 1.0) ? (1.0 - elapsed) : 0;

    // Re-capture from weakSelf in nested block to avoid use-after-free
    void (^reportReady)(void) = ^{
      PragmataView *strongSelf2 = weakSelf;
      if (!strongSelf2) return;
      [strongSelf2 reportProgress:1.0f stage:@"Ready"];
    };

    if (delay > 0) {
      dispatch_after(
          dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
          dispatch_get_main_queue(), reportReady);
    } else {
      reportReady();
    }
  }];

  [self reportProgress:0.1f stage:@"Initializing engine..."];

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    self.initialLoadStartTime = CACurrentMediaTime();
    [self reportProgress:0.3f stage:@"Loading environment..."];
    NSString *cameraConfigPath =
        [[NSBundle mainBundle] pathForResource:@"cameras" ofType:@"ini"];
    if (cameraConfigPath) {
      [self.engineBridge loadCameraConfig:cameraConfigPath];
      APP_LOG("PragmataView", "📷 Loaded camera config: %@", cameraConfigPath);
    } else {
      APP_LOG("PragmataView", "⚠️ cameras.ini not found in bundle");
    }

    NSString *sysConfigPath =
        [[NSBundle mainBundle] pathForResource:@"system" ofType:@"ini" inDirectory:@"ControlsINI"];
    if (sysConfigPath) {
      [self.engineBridge loadSystemConfig:sysConfigPath];
    } else {
      APP_LOG("PragmataView", "⚠️ system.ini not found in bundle");
    }

    NSString *interiorConfigPath =
        [[NSBundle mainBundle] pathForResource:@"interior" ofType:@"ini" inDirectory:@"ControlsINI"];
    if (interiorConfigPath) {
      [self.engineBridge loadInteriorConfig:interiorConfigPath];
    } else {
      APP_LOG("PragmataView", "⚠️ interior.ini not found in bundle");
    }

    NSString *envConfigPath =
        [[NSBundle mainBundle] pathForResource:@"environment" ofType:@"ini" inDirectory:@"ControlsINI"];
    if (envConfigPath) {
      // Must run on main thread — loadEnvironmentConfig calls setEnvironmentPreset which
      // creates Filament ColorGrading objects; those require a Filament-adopted thread.
      dispatch_async(dispatch_get_main_queue(), ^{
        [self.engineBridge loadEnvironmentConfig:envConfigPath];
      });
    } else {
      APP_LOG("PragmataView", "⚠️ environment.ini not found in bundle");
    }

    [self reportProgress:0.6f stage:@"Loading boat..."];
    [self.engineBridge loadModel:@"PCraft400"
                          preset:@"Front"];

    // Apply initial environment (Hangar) so Platform.glb loads
    // and EEnvironment is set before any UI interaction.
    // Must run on main thread — Fabric publish is not thread-safe from bg.
    dispatch_async(dispatch_get_main_queue(), ^{
      [weakSelf.engineBridge setSceneEnvironment:@"Hangar"];
    });
  });

  // Default to 1080p on high-res displays (scale 0.5 → 1920×1080 from 4K)
  if (drawableSize.width > 1920) {
    [self setResolutionPreset:ResolutionPresetHalf];
  }
}

// ============================================================================
// MARK: - MTKViewDelegate
// ============================================================================

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
  (void)view;

  // On tvOS, first valid size often arrives here; run deferred engine setup
  if (self.engineSetupPending && size.width > 0 && size.height > 0) {
    self.engineSetupPending = NO;
    [self setupEngineWithDrawableSize:size];
    return;
  }

  if (!self.engineBridge) {
    return;
  }

  float aspect = size.width / size.height;
  self.cachedAspect = aspect;
  [self.engineBridge setCameraViewport:(int)size.width height:(int)size.height];
  float verticalFOV = calculateVerticalFOV(FOCAL_LENGTH_MM, SENSOR_HEIGHT_MM);
  [self.engineBridge setCameraProjection:verticalFOV
                                  aspect:aspect
                                    near:0.1f
                                     far:1000.0f];
}

- (void)drawInMTKView:(nonnull MTKView *)view {
  (void)view;
  // Try deferred setup on first draw (e.g. if drawableSizeWillChange wasn't
  // called)
  if (self.engineSetupPending && view.drawableSize.width > 0 &&
      view.drawableSize.height > 0) {
    [self setupEngineIfReady];
  }
  if (!self.engineBridge) {
    return;
  }
  [self renderFrame];
}

// ============================================================================
// MARK: - Rendering Loop
// ============================================================================

/**
 * The main rendering entry point, called for every frame.
 * Responsible for delta time calculation, UI effect updates, and engine render
 * calls.
 */
- (void)renderFrame {
  if (!self.engineBridge) {
    return;
  }

  // Calculate deltaTime
  NSTimeInterval currentTime = CACurrentMediaTime();
  float deltaTime = self.lastFrameTime > 0
                        ? (float)(currentTime - self.lastFrameTime)
                        : (1.0f / 60.0f);
  deltaTime = fminf(deltaTime, 1.0f / 30.0f);
  self.lastFrameTime = currentTime;

  // Update zoom effect (iOS-specific UI effect)
  [self updateZoomWithDeltaTime:deltaTime];

  [self.engineBridge update:deltaTime];
  [self.engineBridge render];

  // Adaptive frame rate: read target FPS from engine and apply to MTKView
  int targetFPS = [self.engineBridge getTargetFPS];
  if (self.mtkView.preferredFramesPerSecond != targetFPS) {
    self.mtkView.preferredFramesPerSecond = targetFPS;
  }
}

// ============================================================================
// MARK: - iOS-Specific UI Effects
// ============================================================================

/**
 * Updates the camera FOV animation logic.
 */
- (void)updateZoomWithDeltaTime:(float)deltaTime {
  (void)deltaTime; // Suppress unused parameter warning - using
                   // CACurrentMediaTime() instead

  if (!self.isZooming) {
    return;
  }

  NSTimeInterval elapsed = CACurrentMediaTime() - self.zoomStartTime;
  float progress = (float)(elapsed / self.zoomDuration);

  if (progress >= 1.0f) {
    // Zoom finished
    self.isZooming = NO;
    // Apply final FOV via bridge
    float aspect = self.cachedAspect > 0 ? self.cachedAspect : 0.75f;
    [self.engineBridge setCameraProjection:self.zoomTargetFOV
                                    aspect:aspect
                                      near:0.1f
                                       far:1000.0f];
  } else {
    // Interpolate FOV
    float currentFOV =
        self.zoomStartFOV + (self.zoomTargetFOV - self.zoomStartFOV) * progress;
    // Apply FOV via bridge
    float aspect = self.cachedAspect > 0 ? self.cachedAspect : 0.75f;
    [self.engineBridge setCameraProjection:currentFOV
                                    aspect:aspect
                                      near:0.1f
                                       far:1000.0f];
  }
}

/**
 * Throttles and applies background color updates to correctly match UI and
 * skybox.
 */
- (void)updateBackgroundColorInterpolationWithDeltaTime:(float)deltaTime {
  if (!self.engineBridge) {
    return;
  }

  // Throttle background color updates to every 2 frames
  NSTimeInterval currentTime = CACurrentMediaTime();
  if (currentTime - self.lastBackgroundColorUpdateTime < (1.0 / 30.0)) {
    return;
  }
  self.lastBackgroundColorUpdateTime = currentTime;

  [self.engineBridge applyBackgroundColor];
}

// ============================================================================
// MARK: - Public API (delegates to bridge)
// ============================================================================

- (void)loadModelNamed:(NSString *)modelName
            withPreset:(nullable NSString *)presetName {
  [self.engineBridge loadModel:modelName preset:presetName ?: @"Front"];
}

- (void)resendSignal_ModelLoad:(NSString *)modelName {
  [self.engineBridge resendSignal_ModelLoad:modelName];
}

- (void)switchSceneMode:(NSString *)mode {
  [self.engineBridge switchSceneMode:mode];
}

- (void)setSignalCallback:(void (^)(NSString *signalType,
                                    NSString *message))callback {
  if (self.engineBridge) {
    [self.engineBridge setSignalCallback:callback];
    APP_LOG("PragmataView", "✅ Signal callback set");
  } else {
    APP_LOG("PragmataView", "⚠️ Engine bridge not ready, callback not set");
  }
}

- (void)moveToPresetFront {
  [self.engineBridge moveToCameraPreset:@"Front"];
}

- (void)moveToPresetTop {
  [self.engineBridge moveToCameraPreset:@"Top"];
}

- (void)moveToPresetRear {
  [self.engineBridge moveToCameraPreset:@"Rear"];
}

- (void)moveToPresetSide {
  [self.engineBridge moveToCameraPreset:@"Side"];
}

- (void)moveToPresetInterior {
  [self.engineBridge moveToCameraPreset:@"Interior"];
}

- (void)loadCameraConfig:(NSString *)configPath {
  if (self.engineBridge) {
    [self.engineBridge loadCameraConfig:configPath];
  }
}

- (void)playAnimationAtIndex:(NSInteger)index
                      action:(NSString *)action
                    partName:(NSString *)partName {
  if (!self.engineBridge) {
    return;
  }
  [self.engineBridge playAnimation:index action:action partName:partName];
}

- (void)playAnimationReverseAtIndex:(NSInteger)index
                             action:(NSString *)action
                           partName:(NSString *)partName {
  if (!self.engineBridge) {
    return;
  }
  [self.engineBridge playReverseAnimation:index
                                   action:action
                                 partName:partName];
}

- (void)stopAnimationAtIndex:(NSInteger)index {
  if (!self.engineBridge) return;
  [self.engineBridge stopAnimation:index];
}

- (BOOL)isAnimationActiveAtIndex:(NSInteger)index {
  if (!self.engineBridge) {
    return NO;
  }
  return [self.engineBridge isAnimationActive:index];
}

- (NSInteger)getAnimationCount {
  if (!self.engineBridge) {
    return 0;
  }
  return [self.engineBridge getAnimationCount];
}

- (NSString *)getAnimationNameAtIndex:(NSInteger)index {
  if (!self.engineBridge) {
    return nil;
  }
  return [self.engineBridge getAnimationName:index];
}

- (float)getAnimationDurationAtIndex:(NSInteger)index {
  if (!self.engineBridge) {
    return 0.0f;
  }
  return [self.engineBridge getAnimationDuration:index];
}

- (void)setBackgroundColorRed:(float)red
                        green:(float)green
                         blue:(float)blue
                        alpha:(float)alpha {
  [self.engineBridge setBackgroundColorRed:red
                                     green:green
                                      blue:blue
                                     alpha:alpha];
}

- (void)toggleDebugAxis {
  [self.engineBridge toggleDebugAxis];
}

- (void)setDebugAxisVisible:(BOOL)visible {
  [self.engineBridge setDebugAxisVisible:visible];
}

- (BOOL)isDebugAxisVisible {
  return [self.engineBridge isDebugAxisVisible];
}

- (void)setWaterWindSpeed:(float)v {
  [self.engineBridge setWaterWindSpeed:v];
}
- (void)setWaterUvScale:(float)v {
  [self.engineBridge setWaterUvScale:v];
}
- (void)setWaterWaveStrength:(float)v {
  [self.engineBridge setWaterWaveStrength:v];
}
- (void)setWaterFresnelPower:(float)v {
  [self.engineBridge setWaterFresnelPower:v];
}
- (void)setWaterFresnelMin:(float)v {
  [self.engineBridge setWaterFresnelMin:v];
}
- (void)setWaterCenterOpacity:(float)v {
  [self.engineBridge setWaterCenterOpacity:v];
}

- (void)applyHullColorRed:(float)r green:(float)g blue:(float)b {
  [self.engineBridge applyHullColorRed:r green:g blue:b];
}

// MARK: - Boat Configurator (new API)

- (void)applyHullColor:(NSString *)colorName {
  [self.engineBridge applyHullColor:colorName];
}

- (void)applySeatColor:(NSString *)colorName {
  [self.engineBridge applySeatColor:colorName];
}

- (void)applyDeckTexture:(NSString *)styleName {
  [self.engineBridge applyDeckTexture:styleName];
}

- (void)applyWoodTexture:(NSString *)woodName {
  [self.engineBridge applyWoodTexture:woodName];
}

- (void)applyEquipmentPackage:(NSString *)packageName {
  [self.engineBridge applyEquipmentPackage:packageName];
}

- (void)applyLivery:(NSInteger)index {
  [self.engineBridge applyLivery:index];
}

- (void)applyLeatherColor:(NSString *)colorName {
  [self.engineBridge applyLeatherColor:colorName];
}

- (void)inspectMaterials {
  [self.engineBridge inspectMaterials];
}

- (void)setDynamicResolutionScale:(float)scale {
  [self.engineBridge setDynamicResolutionScale:scale];
}

- (float)getCurrentResolutionScale {
  return [self.engineBridge getCurrentResolutionScale];
}

- (void)setResolutionPreset:(ResolutionPreset)preset {
  float scale = 0.7f;
  switch (preset) {
  case ResolutionPresetNative:
    scale = 1.0f;
    break;
  case ResolutionPresetHigh:
    scale = 0.7f;
    break;
  case ResolutionPresetHalf:
    scale = 0.5f;
    break;
  case ResolutionPresetThird:
    scale = 0.33f;
    break;
  }
  [self.engineBridge setDynamicResolutionScale:scale];
}

- (void)setAntiAliasingFXAA:(BOOL)enabled {
  [self.engineBridge setFXAAEnabled:enabled];
}

- (void)setAntiAliasingMSAA:(BOOL)enabled sampleCount:(int)sampleCount {
  [self.engineBridge setMSAAEnabled:enabled sampleCount:sampleCount];
}

- (NSInteger)getAntiAliasingType {
  return [self.engineBridge getAntiAliasingType];
}

- (NSInteger)getMSAASampleCount {
  return [self.engineBridge getMSAASampleCount];
}

- (void)setBloomEnabled:(BOOL)enabled {
  [self.engineBridge setBloomEnabled:enabled];
}

- (BOOL)isBloomEnabled {
  return [self.engineBridge isBloomEnabled];
}

- (void)setSunLightIntensity:(float)intensity {
  [self.engineBridge setSunLightIntensity:intensity];
}

- (void)setAmbientLightIntensity:(float)intensity {
  [self.engineBridge setAmbientLightIntensity:intensity];
}

- (float)getSunLightIntensity {
  return [self.engineBridge getSunLightIntensity];
}

- (float)getAmbientLightIntensity {
  return [self.engineBridge getAmbientLightIntensity];
}

- (void)setSunLightingPreset:(NSString *)presetName {
  [self.engineBridge setSunLightingPreset:presetName];
}

- (void)setNightMode:(BOOL)enabled {
  [self.engineBridge setNightMode:enabled];
}

- (float)getIPadZoomOffset {
  return [self.engineBridge getIPadZoomOffset];
}

- (void)setEnvironmentPreset:(NSString *)presetName {
  [self.engineBridge setEnvironmentPreset:presetName];
}

- (void)setSceneEnvironment:(NSString *)environment {
  [self.engineBridge setSceneEnvironment:environment];
}

- (void)switchSceneEnvironment:(NSString *)environment {
  [self.engineBridge switchSceneEnvironment:environment];
}

- (void)setShipState:(NSString *)state {
  [self.engineBridge setShipState:state];
}

- (void)setInteriorMode:(BOOL)entering {
  [self.engineBridge setInteriorMode:entering];
}

- (BOOL)isNightModeEnabled {
  return [self.engineBridge isNightModeEnabled];
}

- (void)setAmbientOcclusionEnabled:(BOOL)enabled {
  [self.engineBridge setAmbientOcclusionEnabled:enabled];
}

- (BOOL)getAmbientOcclusionEnabled {
  return [self.engineBridge getAmbientOcclusionEnabled];
}

- (void)setToneMapper:(NSInteger)type {
  [self.engineBridge setToneMapper:type];
}

- (NSInteger)getToneMapper {
  return [self.engineBridge getToneMapper];
}

- (void)setVignetteEnabled:(BOOL)enabled {
  [self.engineBridge setVignetteEnabled:enabled];
}

- (BOOL)getVignetteEnabled {
  return [self.engineBridge getVignetteEnabled];
}

- (void)setSSREnabled:(BOOL)enabled {
  [self.engineBridge setSSREnabled:enabled];
}

- (BOOL)getSSREnabled {
  return [self.engineBridge getSSREnabled];
}

- (void)setSSRQualityLevel:(NSInteger)level {
  [self.engineBridge setSSRQualityLevel:level];
}

- (NSInteger)getSSRQualityLevel {
  return [self.engineBridge getSSRQualityLevel];
}

- (void)setOrbitEnabled:(BOOL)enabled {
  [self.engineBridge setOrbitEnabled:enabled];

  if (enabled && !self.orbitGesturesTemporarilyDisabled) {
    self.orbitPanGesture.enabled = YES;
#if TARGET_OS_IOS
    self.orbitPinchGesture.enabled = YES;
#endif
  } else {
    self.orbitPanGesture.enabled = NO;
#if TARGET_OS_IOS
    self.orbitPinchGesture.enabled = NO;
#endif
  }

  APP_LOG("PragmataView", "🔧 Orbit controls %@, gestures %@",
          enabled ? @"enabled" : @"disabled",
          self.orbitPanGesture.enabled ? @"enabled" : @"disabled");
}

- (void)setOrbitGesturesEnabled:(BOOL)enabled {
  self.orbitGesturesTemporarilyDisabled = !enabled;

  if ([self isOrbitEnabled] && enabled) {
    self.orbitPanGesture.enabled = YES;
#if TARGET_OS_IOS
    self.orbitPinchGesture.enabled = YES;
#endif
  } else {
    self.orbitPanGesture.enabled = NO;
#if TARGET_OS_IOS
    self.orbitPinchGesture.enabled = NO;
#endif
  }
}

- (BOOL)isOrbitEnabled {
  return [self.engineBridge isOrbitEnabled];
}

- (void)applyOrbitRotationDeltaX:(float)deltaX deltaY:(float)deltaY {
  [self.engineBridge applyOrbitRotationDeltaX:deltaX deltaY:deltaY];
}

- (void)applyOrbitZoom:(float)delta {
  [self.engineBridge applyOrbitZoom:delta];
}

// ========================================
// MARK: - Orbit Gesture Handlers
// ========================================

/**
 * Handles the pan gesture for rotating the orbit camera.
 *
 * @param gesture The UIPanGestureRecognizer instance.
 */
- (void)handleOrbitPan:(UIPanGestureRecognizer *)gesture {
  if (![self isOrbitEnabled]) {
    return;
  }

  CGPoint location = [gesture locationInView:self];
  CGFloat screenWidth = self.bounds.size.width;
  const CGFloat swipeZoneWidth = 50.0f;

  if (location.x > screenWidth - swipeZoneWidth) {
    return;
  }

  CGPoint translation = [gesture translationInView:self];
  const float sensitivity = 0.005f;
  float deltaX = translation.x * sensitivity;
  float deltaY = -translation.y * sensitivity;

  [self applyOrbitRotationDeltaX:deltaX deltaY:deltaY];
  [gesture setTranslation:CGPointZero inView:self];
}

/**
 * Handles the pinch gesture for zooming the orbit camera.
 *
 * @param gesture The UIPinchGestureRecognizer instance.
 */
#if TARGET_OS_IOS
- (void)handleOrbitPinch:(UIPinchGestureRecognizer *)gesture {
  if (![self isOrbitEnabled]) {
    return;
  }

  const float sensitivity = 0.5f;
  float scale = gesture.scale;
  float delta = (1.0f - scale) * sensitivity;

  [self applyOrbitZoom:delta];
  gesture.scale = 1.0f;
}
#endif

// ========================================
// Weather Effects
// ========================================

- (void)startRain {
  if (!self.engineBridge) {
    return;
  }
  [self.engineBridge startRain];
}

- (void)stopRain {
  if (!self.engineBridge) {
    return;
  }
  [self.engineBridge stopRain];
}

- (void)setPactorWaveEnabled:(BOOL)enabled {
  [self.engineBridge setPactorWaveEnabled:enabled];
}

- (BOOL)isPactorWaveEnabled {
  return [self.engineBridge isPactorWaveEnabled];
}

@end
