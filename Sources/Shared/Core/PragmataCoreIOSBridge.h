/**
 * @file PragmataCoreIOSBridge.h
 * @brief iOS-specific wrapper for Core3DEngine.
 *
 * This class translates between iOS types (NSString, MTKView, UIColor) and
 * C++ types. It acts as the primary interface for Swift code to interact
 * with the underlying Core3D C++ engine.
 */

#import <Foundation/Foundation.h>
#import <MetalKit/MetalKit.h>
#include <memory>

NS_ASSUME_NONNULL_BEGIN

/**
 * @typedef FabricSignalCallback
 * @brief Callback block for receiving signals from the Fabric system.
 * @param signalType The name/type of the signal (e.g., "AnimationPlay").
 * @param message The details of the signal (usually a string payload).
 */
typedef void (^FabricSignalCallback)(NSString *signalType, NSString *message);

/**
 * @class PragmataCoreIOSBridge
 * @brief Bridge between UIKit/Metal and the C++ Core3D engine.
 */
@interface PragmataCoreIOSBridge : NSObject

// ========================================
// Setup
// ========================================

/**
 * Initializes the engine and binds it to a MetalKit view.
 * @param mtkView MetalKit view used for rendering.
 * @return YES if the setup was successful.
 */
- (BOOL)setupWithMTKView:(MTKView *)mtkView;

/**
 * Releases all resources and destroys the C++ engine instance.
 */
- (void)cleanup;

// ========================================
// Asset Management
// ========================================

/**
 * Loads a 3D model (GLB) and moves the camera to an initial preset.
 * @param modelName Name of the glb file (without extension).
 * @param presetName Initial camera preset ("Front", "Top", "Rear").
 * @return YES if the model was loaded successfully.
 */
- (BOOL)loadModel:(NSString *)modelName preset:(NSString *)presetName;

/**
 * Block called when initial load (floor + boat) is complete. Set to dismiss
 * loading screen.
 */
- (void)setOnInitialLoadComplete:(void (^)(void))block;

/**
 * Loads a 3D debug axis (X=Red, Y=Green, Z=Blue).
 * @return YES if loaded successfully.
 */
- (BOOL)loadDebugAxis;

/**
 * Re-broadcasts the model load signal to refresh UI state.
 * @param modelName The name of the currently loaded model.
 */
- (void)resendSignal_ModelLoad:(NSString *)modelName;

// ========================================
// Animation
// ========================================

/**
 * Plays a specific animation by index.
 * @param index The animation index in the model.
 * @param action Human-readable action tag (e.g., "open").
 * @param partName Name of the car part (e.g., "door").
 */
- (void)playAnimation:(NSInteger)index
               action:(NSString *)action
             partName:(NSString *)partName;

/**
 * Plays a specific animation in reverse.
 * @param index The animation index in the model.
 * @param action Human-readable action tag (e.g., "close").
 * @param partName Name of the car part (e.g., "door").
 */
- (void)playReverseAnimation:(NSInteger)index
                      action:(NSString *)action
                    partName:(NSString *)partName;

/**
 * Immediately stops an animation.
 * @param index The animation index.
 */
- (void)stopAnimation:(NSInteger)index;

/**
 * Checks if a specific animation index is currently playing.
 * @param index The animation index.
 * @return YES if active.
 */
- (BOOL)isAnimationActive:(NSInteger)index;

/**
 * Returns the total number of animations supported by the loaded model.
 * @return Integer count of animations.
 */
- (NSInteger)getAnimationCount;

/**
 * Gets the internal name of an animation by index.
 * @param index The animation index.
 * @return The name string or nil.
 */
- (NSString *_Nullable)getAnimationName:(NSInteger)index;

// ========================================
// Camera
// ========================================

/**
 * Moves the camera to a predefined position and focus.
 * @param presetName "Front", "Top", "Rear", "Side", or "Interior".
 */
- (void)moveToCameraPreset:(NSString *)presetName;

/**
 * Loads camera presets from an INI file.
 * @param configPath Full path to the configuration file.
 */
- (void)loadCameraConfig:(NSString *)configPath;

// ========================================
// Environment Config
// ========================================

/**
 * Loads environment presets (e.g., Sunny, Sunset) from an INI file.
 * @param configPath Full path to the environment.ini file.
 */
- (void)loadEnvironmentConfig:(NSString *)configPath;

/**
 * Loads system.ini — render quality, platform tweaks (iPad zoom offset, bloom, shadows, AA...).
 * @param configPath Full path to the system.ini file.
 */
- (void)loadSystemConfig:(NSString *)configPath;

/** Loads interior.ini — skybox colour and leather presets for interior mode. */
- (void)loadInteriorConfig:(NSString *)configPath;

/** Returns the iPad initial zoom offset loaded from system.ini [iPad] defaultZoomOffset. */
- (float)getIPadZoomOffset;

/**
 * Sets the active environment preset (legacy direct call).
 * @param presetName The name of the preset to apply (e.g. "Seaside", "Space", "Hangar").
 */
- (void)setEnvironmentPreset:(NSString *)presetName;

/**
 * Publishes Signal_SceneEnvironment via Fabric — direct, no zoom, no ship state change.
 * Use for startup/initialization only.
 */
- (void)setSceneEnvironment:(NSString *)environment;

/**
 * Zoom-masked environment switch for UI buttons.
 * Triggers zoom-in, swaps HDR + sets fixed ship state at peak, then zooms out.
 * Fixed mapping: Hangar=Landed, Beach=Takeoff(VTOL), Space=Flight.
 */
- (void)switchSceneEnvironment:(NSString *)environment;

/**
 * Publishes Signal_ActorState via Fabric.
 * @param state @"Landed", @"Takeoff", or @"Flight"
 */
- (void)setShipState:(NSString *)state;

/**
 * Publishes Signal_InteriorMode via Fabric.
 * @param entering YES = ulaz u interior, NO = izlaz
 */
- (void)setInteriorMode:(BOOL)entering;

// ========================================
// Update & Render
// ========================================

/**
 * Advances the simulation time and updates engine state.
 * @param deltaTime Seconds elapsed since the last frame.
 */
- (void)update:(float)deltaTime;

/**
 * Triggers a frame render pass to the current Metal surface.
 */
- (void)render;

// ========================================
// Camera Viewport & Projection
// ========================================

/**
 * Updates the rendering viewport size.
 * @param width Pixels wide.
 * @param height Pixels high.
 */
- (void)setCameraViewport:(int)width height:(int)height;

/**
 * Configures the projection matrix.
 * @param fovDegrees Field of view angle.
 * @param aspect Width/Height ratio.
 * @param near Distance to near plane.
 * @param far Distance to far plane.
 */
- (void)setCameraProjection:(float)fovDegrees
                     aspect:(float)aspect
                       near:(float)near
                        far:(float)far;

/**
 * Enables or disables user-driven orbit controls.
 * @param enabled True to allow rotation/zoom.
 */
- (void)setOrbitEnabled:(BOOL)enabled;

/**
 * Queries the current orbit enablement state.
 * @return YES if enabled.
 */
- (BOOL)isOrbitEnabled;

/**
 * Apples a rotation delta to the orbit camera.
 * @param deltaX Horizontal rotation in radians.
 * @param deltaY Vertical rotation in radians.
 */
- (void)applyOrbitRotationDeltaX:(float)deltaX deltaY:(float)deltaY;

/**
 * Adjusts the orbit camera distance (zoom).
 * @param delta Relative zoom factor.
 */
- (void)applyOrbitZoom:(float)delta;

/**
 * Gets the total playback duration of an animation.
 * @param index The animation index.
 * @return Seconds.
 */
- (float)getAnimationDuration:(NSInteger)index;

// ========================================
// Getters (for PragmataView)
// ========================================

/** @return Raw pointer to Core3DEngine instance. */
- (void *)getEngine;
/** @return Raw pointer to Filament Scene. */
- (void *)getScene;
/** @return Raw pointer to Filament Camera. */
- (void *)getCamera;

// ========================================
// Material Operations
// ========================================

/**
 * Sets the hull color for the boat body.
 * @param r Red (0-1).
 * @param g Green (0-1).
 * @param b Blue (0-1).
 */
- (void)applyHullColorRed:(float)r green:(float)g blue:(float)b;

// ========================================
// Boat Configurator
// ========================================

/**
 * Apply hull color by name from configuration.
 * @param colorName Color name (e.g., "mint", "military", "antracite",
 * "fishermansBlue").
 */
- (void)applyHullColor:(NSString *)colorName;

/**
 * Apply seat color by name from configuration.
 * @param colorName Color name (e.g., "titanium", "mandarin", "jet", "sand").
 */
- (void)applySeatColor:(NSString *)colorName;

/**
 * Apply deck texture by style name from configuration.
 * @param styleName Style name (e.g., "eshtec", "teak", "udeck").
 */
- (void)applyDeckTexture:(NSString *)styleName;

/**
 * Apply wood texture by wood type from configuration.
 * @param woodName Wood type (e.g., "teak", "wood").
 */
- (void)applyWoodTexture:(NSString *)woodName;

/**
 * Apply equipment package from configuration.
 * @param packageName Package name (e.g., "base", "medium", "highEnd", "ultra").
 */
- (void)applyEquipmentPackage:(NSString *)packageName;

/**
 * Apply livery preset (1–6) — reads livery.ini, sets primary/secondary material params.
 * @param index 1=MILITECH, 2=EXPO, 3=ON BRAND, 4=GOLDEN, 5=DEEP PATROL, 6=CAMMO
 */
- (void)applyLivery:(NSInteger)index;

/**
 * Apply leather color preset to M_Leather material (exterior + interior assets).
 * @param colorName One of: "Beige", "Navy", "Teal", "Cognac", "Black", "Wine"
 */
- (void)applyLeatherColor:(NSString *)colorName;

/**
 * Debug: Print all material names in the boat asset to console.
 */
- (void)inspectMaterials;

// ========================================
// Background Color
// ========================================

/**
 * Sets the clear color of the renderer.
 * @param r Red (0-1).
 * @param g Green (0-1).
 * @param b Blue (0-1).
 * @param a Alpha (0-1).
 */
- (void)setBackgroundColorRed:(float)r
                        green:(float)g
                         blue:(float)b
                        alpha:(float)a;

/**
 * Commits the current background color to the Filament renderer.
 * Must be called during the update phase.
 */
- (void)applyBackgroundColor;

// ========================================
// Debug Axis
// ========================================

/** Toggles the visibility of the XYZ coordinate axes. */
- (void)toggleDebugAxis;
/** Sets debug axis visibility explicitly. */
- (void)setDebugAxisVisible:(BOOL)visible;
/** @return YES if axes are visible. */
- (BOOL)isDebugAxisVisible;

// ========================================
// Water Shader (runtime debug)
// ========================================

- (void)setWaterWindSpeed:(float)v;
- (void)setWaterUvScale:(float)v;
- (void)setWaterWaveStrength:(float)v;
- (void)setWaterFresnelPower:(float)v;
- (void)setWaterFresnelMin:(float)v;
- (void)setWaterCenterOpacity:(float)v;

// ========================================
// Lighting
// ========================================

/** Sets the intensity of the directional sun light. */
- (void)setSunLightIntensity:(float)intensity;
/** @return Current sun light intensity. */
- (float)getSunLightIntensity;
/** Sets the Global Illumination / IBL intensity. */
- (void)setAmbientLightIntensity:(float)intensity;
/** @return Current ambient intensity. */
- (float)getAmbientLightIntensity;
/** Sets sun lighting preset with smooth transition. */
- (void)setSunLightingPreset:(NSString *)presetName;

// ========================================
// Render Settings
// ========================================

/**
 * Scaled the rendering resolution (e.g. 0.5 for half-res).
 */
- (void)setDynamicResolutionScale:(float)scale;
/** @return Current resolution scale factor. */
- (float)getCurrentResolutionScale;
/** Enables or disables FXAA post-processing. */
- (void)setFXAAEnabled:(BOOL)enabled;
/** Configures MSAA anti-aliasing. */
- (void)setMSAAEnabled:(BOOL)enabled sampleCount:(int)sampleCount;
/** Current AA type: 0=NONE, 1=FXAA, 2=MSAA */
- (int)getAntiAliasingType;
/** Current MSAA sample count (e.g. 2). */
- (int)getMSAASampleCount;
/** Enables or disables bloom effect. */
- (void)setBloomEnabled:(BOOL)enabled;
/** @return YES if bloom is enabled. */
- (BOOL)isBloomEnabled;
/** strength 0-1, levels 1-8 (lower = smaller kernel), quality 0=LOW 1=MED 2=HIGH */
- (void)setBloomStrength:(float)strength levels:(int)levels quality:(int)quality;
/** Toggles night-time lighting mode. */
- (void)setNightMode:(BOOL)enabled;
/** @return YES if night mode is active. */
- (BOOL)isNightModeEnabled;
/** Enables or disables ambient occlusion. */
- (void)setAmbientOcclusionEnabled:(BOOL)enabled;
/** @return YES if ambient occlusion is enabled. */
- (BOOL)getAmbientOcclusionEnabled;
/** Sets tone mapper: 0=Linear, 1=ACES, 2=Filmic. */
- (void)setToneMapper:(NSInteger)type;
/** @return Current tone mapper index (0/1/2). */
- (NSInteger)getToneMapper;
/** Enables or disables vignette. */
- (void)setVignetteEnabled:(BOOL)enabled;
/** @return YES if vignette is enabled. */
- (BOOL)getVignetteEnabled;
/** Enables or disables screen-space reflections (SSR). */
- (void)setSSREnabled:(BOOL)enabled;
/** @return YES if SSR is enabled. */
- (BOOL)getSSREnabled;
/** Sets SSR quality: 0=Low, 1=Medium, 2=High. */
- (void)setSSRQualityLevel:(NSInteger)level;
/** @return Current SSR quality (0/1/2). */
- (NSInteger)getSSRQualityLevel;

// ========================================
// Scene Mode Switch (Interior / Exterior)
// ========================================

/**
 * Switches the scene between exterior (boat + water) and interior mode.
 * Triggers a camera zoom punch; at peak assets swap, then camera animates to
 * new preset.
 * @param mode "interior" or "exterior"
 */
- (void)switchSceneMode:(NSString *)mode;

// ========================================
// Weather Effects
// ========================================

/** Starts the rain simulation and particle effect. */
- (void)startRain;
/** Stops the rain effect. */
- (void)stopRain;
/** Sets precipitation density (0.0 to 1.0). */
- (void)setRainIntensity:(float)intensity;

/** Enables or disables pactor wave (buoyancy) animation. Exposed for toggle /
 * future sync with water shader. */
- (void)setPactorWaveEnabled:(BOOL)enabled;
/** @return BOOL indicating if pactor wave animation is enabled. */
- (BOOL)isPactorWaveEnabled;

// ========================================
// Frame Rate Management
// ========================================

/** Target FPS from the adaptive frame rate manager. */
- (int)getTargetFPS;
/** Notify activity from platform input (e.g. CoreWindow). */
- (void)notifyUserInput;

// ========================================
// Fabric Signal Callback
// ========================================

/**
 * Registers a block to be executed whenever a Fabric signal is emitted.
 */
- (void)setSignalCallback:(FabricSignalCallback)callback;

@end

NS_ASSUME_NONNULL_END
