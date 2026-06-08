/**
 * @file PragmataView.h
 * @brief Objective-C interface for the PragmataView renderer.
 *
 * This class provides a bridge for Swift to interact with the underlying
 * C++ Filament engine. It handles rendering, animation, camera controls,
 * and integration with the Fabric signaling system.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @struct FCameraPreset
 * @brief Defines a camera position and its look-at target.
 */
typedef struct {
  float posX, posY, posZ;          /** Pozicija kamere */
  float targetX, targetY, targetZ; /** Točka gdje kamera gleda */
} FCameraPreset;

/**
 * @interface PragmataView
 * @brief Main rendering view class that wraps the Filament engine.
 */
@interface PragmataView : UIView

/**
 * Initializes the view with the given frame.
 *
 * @param frame The initial frame rectangle for the view.
 * @return An initialized PragmataView instance.
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * Sets the background color of the Filament scene.
 *
 * @param red   Red component (0.0 - 1.0).
 * @param green Green component (0.0 - 1.0).
 * @param blue  Blue component (0.0 - 1.0).
 * @param alpha Alpha component (0.0 - 1.0).
 */
- (void)setBackgroundColorRed:(float)red
                        green:(float)green
                         blue:(float)blue
                        alpha:(float)alpha;

/** Moves the camera to the front preset position. */
- (void)moveToPresetFront;
/** Moves the camera to the top preset position. */
- (void)moveToPresetTop;
/** Moves the camera to the rear preset position. */
- (void)moveToPresetRear;
/** Moves the camera to the side preset position. */
- (void)moveToPresetSide;
/** Moves the camera to the interior preset position. */
- (void)moveToPresetInterior;

/**
 * Loads camera presets from an INI file.
 *
 * @param configPath Full path to the configuration file.
 */
- (void)loadCameraConfig:(NSString *)configPath;

/** Toggles the visibility of debug axes. */
- (void)toggleDebugAxis;
/** Sets the visibility of debug axes. @param visible BOOL flag. */
- (void)setDebugAxisVisible:(BOOL)visible;
/** @return BOOL indicating if debug axes are visible. */
- (BOOL)isDebugAxisVisible;

/** Water shader runtime (debug menu). */
- (void)setWaterWindSpeed:(float)v;
- (void)setWaterUvScale:(float)v;
- (void)setWaterWaveStrength:(float)v;
- (void)setWaterFresnelPower:(float)v;
- (void)setWaterFresnelMin:(float)v;
- (void)setWaterCenterOpacity:(float)v;

/** @return Total number of animations in the current model. */
- (NSInteger)getAnimationCount;

/**
 * Retrieves the name of an animation by its index.
 *
 * @param index Index of the animation.
 * @return The name of the animation, or nil if index is out of bounds.
 */
- (nullable NSString *)getAnimationNameAtIndex:(NSInteger)index
    NS_SWIFT_NAME(getAnimationName(at:));

/**
 * Plays an animation by its index.
 *
 * @param index    Index of the animation.
 * @param action   Action name for telemetry.
 * @param partName Name of the part being animated for telemetry.
 */
- (void)playAnimationAtIndex:(NSInteger)index
                      action:(NSString *)action
                    partName:(NSString *)partName
    NS_SWIFT_NAME(playAnimation(at:action:partName:));

/**
 * Plays an animation in reverse by its index.
 *
 * @param index    Index of the animation.
 * @param action   Action name for telemetry.
 * @param partName Name of the part being animated for telemetry.
 */
- (void)playAnimationReverseAtIndex:(NSInteger)index
                             action:(NSString *)action
                           partName:(NSString *)partName
    NS_SWIFT_NAME(playAnimationReverse(at:action:partName:));

- (void)stopAnimationAtIndex:(NSInteger)index
    NS_SWIFT_NAME(stopAnimation(at:));

/**
 * Checks if an animation is currently playing.
 *
 * @param index Index of the animation.
 * @return BOOL indicating if the animation is active.
 */
- (BOOL)isAnimationActiveAtIndex:(NSInteger)index
    NS_SWIFT_NAME(isAnimationActive(at:));

/**
 * Gets the total duration of an animation.
 *
 * @param index Index of the animation.
 * @return Duration in seconds.
 */
- (float)getAnimationDurationAtIndex:(NSInteger)index
    NS_SWIFT_NAME(getAnimationDuration(at:));

/**
 * Applies a specific RGB color to the hull.
 *
 * @param r Red component (0.0 - 1.0).
 * @param g Green component (0.0 - 1.0).
 * @param b Blue component (0.0 - 1.0).
 */
- (void)applyHullColorRed:(float)r
                     green:(float)g
                      blue:(float)b
    NS_SWIFT_NAME(applyHullColor(r:g:b:));

// MARK: - Boat Configurator (new API)

/** Apply hull color by name from configuration. */
- (void)applyHullColor:(NSString *)colorName
    NS_SWIFT_NAME(applyHullColor(_:));

/** Apply seat color by name from configuration. */
- (void)applySeatColor:(NSString *)colorName
    NS_SWIFT_NAME(applySeatColor(_:));

/** Apply deck texture by style name from configuration. */
- (void)applyDeckTexture:(NSString *)styleName
    NS_SWIFT_NAME(applyDeckTexture(_:));

/** Apply wood texture by wood type from configuration. */
- (void)applyWoodTexture:(NSString *)woodName
    NS_SWIFT_NAME(applyWoodTexture(_:));

/** Apply equipment package from configuration. */
- (void)applyEquipmentPackage:(NSString *)packageName
    NS_SWIFT_NAME(applyEquipmentPackage(_:));

/** Apply livery preset (1–6). Reads livery.ini. */
- (void)applyLivery:(NSInteger)index
    NS_SWIFT_NAME(applyLivery(_:));

- (void)applyLeatherColor:(NSString *)colorName
    NS_SWIFT_NAME(applyLeatherColor(_:));

/** Utility to output material information to the console. */
- (void)inspectMaterials;

/** Sets the dynamic resolution scale. @param scale Factor (e.g., 0.5 for 50%).
 */
- (void)setDynamicResolutionScale:(float)scale;
/** @return Current resolution scale factor. */
- (float)getCurrentResolutionScale;

/**
 * @enum ResolutionPreset
 * @brief predefined resolution scaling levels.
 */
typedef NS_ENUM(NSInteger, ResolutionPreset) {
  ResolutionPresetNative = 0, /** 1.0× (100%) */
  ResolutionPresetHigh,       /** 0.7× (70%) */
  ResolutionPresetHalf,       /** 0.5× (50%) */
  ResolutionPresetThird       /** 0.33× (33%) */
};

/** Sets resolution based on a predefined preset. @param preset The preset to
 * apply. */
- (void)setResolutionPreset:(ResolutionPreset)preset;

/** Toggles FXAA anti-aliasing. @param enabled BOOL flag. */
- (void)setAntiAliasingFXAA:(BOOL)enabled;
/** Toggles MSAA anti-aliasing. @param enabled BOOL flag. @param sampleCount
 * Number of samples (e.g. 4). */
- (void)setAntiAliasingMSAA:(BOOL)enabled sampleCount:(int)sampleCount;
/** Current AA type: 0=NONE, 1=FXAA, 2=MSAA */
- (NSInteger)getAntiAliasingType;
/** Current MSAA sample count */
- (NSInteger)getMSAASampleCount;

/** Enables or disables bloom effect. @param enabled BOOL flag. */
- (void)setBloomEnabled:(BOOL)enabled;
/** @return YES if bloom is enabled. */
- (BOOL)isBloomEnabled;

/** Sets primary sun light intensity. @param intensity Value from 0.0 to
 * 200000.0. */
- (void)setSunLightIntensity:(float)intensity;
/** Sets ambient light intensity. @param intensity Value from 0.0 to 1.0. */
- (void)setAmbientLightIntensity:(float)intensity;
/** @return Current sun light intensity. */
- (float)getSunLightIntensity;
/** @return Current ambient light intensity. */
- (float)getAmbientLightIntensity;
/** Sets sun lighting preset with smooth transition. @param presetName "Sunny" or "Sunset". */
- (void)setSunLightingPreset:(NSString *)presetName
    NS_SWIFT_NAME(setSunLightingPreset(_:));

/** Enables or disables night mode (color grading). @param enabled BOOL flag. */
- (void)setNightMode:(BOOL)enabled;
/** @return BOOL indicating if night mode is enabled. */
- (BOOL)isNightModeEnabled;
/** Returns the iPad initial zoom offset from system.ini [iPad] defaultZoomOffset. */
- (float)getIPadZoomOffset;

/** Applies a named environment preset (e.g. "Seaside", "Space", "Hangar"). */
- (void)setEnvironmentPreset:(NSString *)presetName;
/** Publishes Signal_SceneEnvironment directly — no zoom, no state change. Startup use only. */
- (void)setSceneEnvironment:(NSString *)environment;
/** Zoom-masked env switch for UI buttons. Sets fixed ship state per env at peak zoom. */
- (void)switchSceneEnvironment:(NSString *)environment;
/** Publishes Signal_ActorState (@"Landed", @"Takeoff", @"Flight"). */
- (void)setShipState:(NSString *)state;
/** Publishes Signal_InteriorMode. */
- (void)setInteriorMode:(BOOL)entering;

/** Enables or disables ambient occlusion. */
- (void)setAmbientOcclusionEnabled:(BOOL)enabled;
/** @return BOOL indicating if ambient occlusion is enabled. */
- (BOOL)getAmbientOcclusionEnabled;
/** Sets tone mapper: 0=Linear, 1=ACES, 2=Filmic. */
- (void)setToneMapper:(NSInteger)type;
/** @return Current tone mapper index (0/1/2). */
- (NSInteger)getToneMapper;
/** Enables or disables vignette. */
- (void)setVignetteEnabled:(BOOL)enabled;
/** @return BOOL indicating if vignette is enabled. */
- (BOOL)getVignetteEnabled;
- (void)setSSREnabled:(BOOL)enabled;
- (BOOL)getSSREnabled;
- (void)setSSRQualityLevel:(NSInteger)level;
- (NSInteger)getSSRQualityLevel;

/** Enables or disables camera orbit controls. @param enabled BOOL flag. */
- (void)setOrbitEnabled:(BOOL)enabled;
/** @return BOOL indicating if orbit controls are enabled. */
- (BOOL)isOrbitEnabled;
/** Applies manual rotation delta to the orbit camera. @param deltaX Horizontal
 * rotation. @param deltaY Vertical rotation. */
- (void)applyOrbitRotationDeltaX:(float)deltaX deltaY:(float)deltaY;
/** Applies zoom delta to the orbit camera. @param delta Zoom change amount. */
- (void)applyOrbitZoom:(float)delta;
/** Temporarily disables gesture detection for orbit controls. @param enabled
 * BOOL flag. */
- (void)setOrbitGesturesEnabled:(BOOL)enabled;

/** Starts the rain weather effect. */
- (void)startRain;
/** Stops the rain weather effect. */
- (void)stopRain;
/** Enables or disables pactor wave (buoyancy) animation. For toggle / future sync with water shader. */
- (void)setPactorWaveEnabled:(BOOL)enabled;
/** @return BOOL indicating if pactor wave animation is enabled. */
- (BOOL)isPactorWaveEnabled;

/**
 * Loads a 3D model by its name and optionally applies a camera preset.
 *
 * @param modelName  Name of the model asset to load.
 * @param presetName Optional name of the camera preset to apply after loading.
 */
- (void)loadModelNamed:(NSString *)modelName
            withPreset:(nullable NSString *)presetName
    NS_SWIFT_NAME(loadModel(named:withPreset:));

/** Manually triggers a model load telemetry signal. @param modelName Name of
 * the model. */
- (void)resendSignal_ModelLoad:(NSString *)modelName;

/**
 * Switches the scene between "exterior" and "interior" modes.
 * Triggers a camera zoom punch; at peak assets swap, then camera animates to new preset.
 */
- (void)switchSceneMode:(NSString *)mode
    NS_SWIFT_NAME(switchSceneMode(_:));

/**
 * Sets a callback block to receive Fabric signals from the rendering engine.
 *
 * @param callback Block taking signalType and message strings.
 */
- (void)setSignalCallback:(void (^)(NSString *signalType,
                                    NSString *message))callback;

/**
 * Callback for loading progress updates.
 * Called on the main thread with progress (0.0-1.0) and a stage description.
 */
@property (nonatomic, copy, nullable) void (^loadingProgressCallback)(float progress, NSString *stage);

/**
 * Callback for scene fade transitions triggered by Fabric signals.
 * isTransitioning=YES when SceneFadeOut fires, NO when SceneFadeIn fires.
 * Called on the main thread.
 */
@property (nonatomic, copy, nullable) void (^sceneFadeCallback)(BOOL isTransitioning);

/** Notify engine of user input (called from CoreWindow for global input detection). */
- (void)notifyUserInput;

@end

NS_ASSUME_NONNULL_END
