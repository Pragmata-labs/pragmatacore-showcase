/**
 * @file PragmataCoreIOSBridge.mm
 * @brief iOS-to-SDK bridge for PragmataCore.
 *
 * Contains only generic SDK operations (pc_* calls).
 * All NauticaApp domain logic lives in ConfiguratorKit.
 */

#import "PragmataCoreIOSBridge.h"
#import "ConfiguratorKit.h"
#import "AppLog.h"
#include "pragmata/pragmatacore.h"

#import <MetalKit/MetalKit.h>
#include <dispatch/dispatch.h>
#include <string>

// ---------------------------------------------------------------------------
// Static C callbacks — platform implementations of pc_file_load_fn
// ---------------------------------------------------------------------------

static void PragmataFileLoad(const char* nameC,
                              pc_deliver_fn deliver,
                              void* deliver_ud,
                              void* /*userdata*/) {
    NSString* nsFileName = [NSString stringWithUTF8String:nameC];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSString* extension      = [nsFileName pathExtension];
        NSString* nameWithoutExt = [nsFileName stringByDeletingPathExtension];
        NSString* type = extension.length > 0 ? extension : @"glb";

        if ([nsFileName containsString:@"HDR_environment/"]) {
            NSString* hdrPath = [nsFileName
                stringByReplacingOccurrencesOfString:@"HDR_environment/"
                                          withString:@""];
            if ([hdrPath containsString:@"."]) {
                nameWithoutExt = [hdrPath stringByDeletingPathExtension];
                extension      = [hdrPath pathExtension];
                type           = extension;
            } else {
                nameWithoutExt = hdrPath;
            }
        }

        NSString* fullPath = nil;
        if ([nameWithoutExt containsString:@"/"]) {
            NSString* directory = [nameWithoutExt stringByDeletingLastPathComponent];
            NSString* filename  = [nameWithoutExt lastPathComponent];
            fullPath = [[NSBundle mainBundle] pathForResource:filename
                                                       ofType:type
                                                  inDirectory:directory];
            if (!fullPath)
                fullPath = [[NSBundle mainBundle] pathForResource:filename
                                                           ofType:type
                                                      inDirectory:nil];
        } else {
            fullPath = [[NSBundle mainBundle] pathForResource:nameWithoutExt ofType:type];
            if (!fullPath && [type isEqualToString:@"glb"])
                fullPath = [[NSBundle mainBundle] pathForResource:nameWithoutExt
                                                            ofType:type
                                                       inDirectory:@"3DAssets"];
            if (!fullPath && ([type isEqualToString:@"ktx"] || [type isEqualToString:@"txt"]))
                fullPath = [[NSBundle mainBundle] pathForResource:nameWithoutExt
                                                            ofType:type
                                                       inDirectory:@"HDR_environment"];
        }

        NSData* data = fullPath ? [NSData dataWithContentsOfFile:fullPath] : nil;
        if (!data || data.length == 0) {
            APP_LOG("PragmataCoreIOSBridge", "❌ Failed to load: %@", nsFileName);
            dispatch_async(dispatch_get_main_queue(), ^{ deliver(nullptr, 0, deliver_ud); });
            return;
        }

        __block NSData* blockData = [data copy];
        size_t dataSize = blockData.length;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!blockData || blockData.length != dataSize) { deliver(nullptr, 0, deliver_ud); return; }
            APP_LOG("PragmataCoreIOSBridge", "✅ File loaded: %@ (%lu bytes)",
                    nsFileName, (unsigned long)dataSize);
            deliver((const uint8_t*)blockData.bytes, dataSize, deliver_ud);
        });
    });
}

static void PragmataMaterialLoad(const char* idC,
                                  pc_deliver_fn deliver,
                                  void* deliver_ud,
                                  void* /*userdata*/) {
    @autoreleasepool {
        NSString* materialId = [NSString stringWithUTF8String:idC];
        NSString* fileName   = [NSString stringWithFormat:@"%@_metal", materialId];

#if TARGET_OS_OSX
        NSString* subdir = @"MaterialsDesktop";
#else
        NSString* subdir = [materialId isEqualToString:@"water"] ? @"WaterMaterial" : @"Materials";
#endif

        NSString* path = [[NSBundle mainBundle] pathForResource:fileName ofType:@"filamat" inDirectory:subdir];
        if (!path)
            path = [[NSBundle mainBundle] pathForResource:fileName ofType:@"filamat" inDirectory:@"Materials"];
        if (!path)
            path = [[NSBundle mainBundle] pathForResource:fileName ofType:@"filamat" inDirectory:nil];
        if (!path) { deliver(nullptr, 0, deliver_ud); return; }

        NSData* data = [NSData dataWithContentsOfFile:path];
        if (!data || data.length == 0) { deliver(nullptr, 0, deliver_ud); return; }

        deliver(static_cast<const uint8_t*>(data.bytes), data.length, deliver_ud);
    }
}

static void PragmataOnLoadComplete(void* userdata) {
    // Transfer ownership back from the retained block and invoke it.
    void(^block)(void) = (__bridge_transfer id)userdata;
    block();
}

@interface PragmataCoreIOSBridge () {
    pc_context_t _ctx;
    ConfiguratorKit  *_configuratorKit;
    void (^_onInitialLoadCompleteBlock)(void);
}
@end

@implementation PragmataCoreIOSBridge

- (instancetype)init {
    self = [super init];
    if (self) _ctx = PC_NULL_HANDLE;
    return self;
}

- (void)dealloc {
    [self cleanup];
}

// ---------------------------------------------------------------------------
// Setup
// ---------------------------------------------------------------------------

- (BOOL)setupWithMTKView:(MTKView *)mtkView {
    if (!mtkView) {
        APP_LOG("PragmataCoreIOSBridge", "⚠️ MTKView is nil");
        return NO;
    }

    CAMetalLayer *metalLayer = nil;
    if ([mtkView.layer isKindOfClass:[CAMetalLayer class]])
        metalLayer = (CAMetalLayer *)mtkView.layer;
    if (!metalLayer) {
        APP_LOG("PragmataCoreIOSBridge", "⚠️ No CAMetalLayer");
        return NO;
    }
    metalLayer.opaque = YES;

    __weak PragmataCoreIOSBridge* weakSelf = self;
    void(^completeBlock)(void) = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            PragmataCoreIOSBridge* s = weakSelf;
            if (!s) return;
            auto cb = s->_onInitialLoadCompleteBlock;
            if (cb) cb();
        });
    };

    pc_context_desc_t desc    = {};
    desc.native_window        = (__bridge void*)metalLayer;
    desc.width                = 0;
    desc.height               = 0;
    desc.file_load            = PragmataFileLoad;
    desc.file_load_ud         = nullptr;
    desc.material_load        = PragmataMaterialLoad;
    desc.material_load_ud     = nullptr;
    desc.on_load_complete     = PragmataOnLoadComplete;
    desc.on_load_complete_ud  = (__bridge_retained void*)completeBlock;

    _ctx = pc_context_create(&desc);
    if (_ctx == PC_NULL_HANDLE) {
        APP_LOG("PragmataCoreIOSBridge", "❌ Engine setup failed");
        return NO;
    }

    _configuratorKit = [[ConfiguratorKit alloc] initWithContext:_ctx];
    APP_LOG("PragmataCoreIOSBridge", "✅ Engine setup complete");
    return YES;
}

- (void)cleanup {
    if (_ctx) {
        pc_context_flush(_ctx);
        pc_context_destroy(_ctx);
        _ctx = PC_NULL_HANDLE;
    }
    _configuratorKit = nil;
}

// ---------------------------------------------------------------------------
// Scene / model
// ---------------------------------------------------------------------------

- (BOOL)loadModel:(NSString *)modelName preset:(NSString *)presetName {
    if (!_ctx || !modelName) return NO;
    std::string name   = [modelName UTF8String];
    std::string preset = presetName ? [presetName UTF8String] : "Front";
    return pc_scene_load_model(_ctx, name.c_str(), preset.c_str(), nullptr) == PC_OK;
}

- (void)setOnInitialLoadComplete:(void (^)(void))block {
    _onInitialLoadCompleteBlock = [block copy];
}

- (BOOL)loadDebugAxis {
    return pc_scene_load_debug_axis(_ctx) == PC_OK;
}

// ---------------------------------------------------------------------------
// ConfiguratorKit domain delegation
// ---------------------------------------------------------------------------

- (void)resendSignal_ModelLoad:(NSString *)modelName {
    [_configuratorKit resendSignalModelLoad:modelName];
}

- (void)setShipState:(NSString *)state {
    [_configuratorKit setShipState:state];
}

- (void)setInteriorMode:(BOOL)entering {
    [_configuratorKit setInteriorMode:entering];
}

- (void)applyHullColorRed:(float)r green:(float)g blue:(float)b {
    [_configuratorKit applyHullColorRed:r green:g blue:b];
}

- (void)applyHullColor:(NSString *)colorName    { [_configuratorKit applyHullColor:colorName]; }
- (void)applySeatColor:(NSString *)colorName    { [_configuratorKit applySeatColor:colorName]; }
- (void)applyDeckTexture:(NSString *)styleName  { [_configuratorKit applyDeckTexture:styleName]; }
- (void)applyWoodTexture:(NSString *)woodName   { [_configuratorKit applyWoodTexture:woodName]; }
- (void)applyEquipmentPackage:(NSString *)name  { [_configuratorKit applyEquipmentPackage:name]; }
- (void)applyLeatherColor:(NSString *)colorName { [_configuratorKit applyLeatherColor:colorName]; }
- (void)applyLivery:(NSInteger)index            { [_configuratorKit applyLivery:index]; }
- (void)inspectMaterials                        { [_configuratorKit inspectMaterials]; }

- (void)setSignalCallback:(FabricSignalCallback)callback {
    [_configuratorKit setSignalCallback:callback];
}

- (void)applyBackgroundColor {
    [_configuratorKit applyBackgroundColor];
}

- (void)setWaterWindSpeed:(float)v     { [_configuratorKit setWaterWindSpeed:v]; }
- (void)setWaterUvScale:(float)v       { [_configuratorKit setWaterUvScale:v]; }
- (void)setWaterWaveStrength:(float)v  { [_configuratorKit setWaterWaveStrength:v]; }
- (void)setWaterFresnelPower:(float)v  { [_configuratorKit setWaterFresnelPower:v]; }
- (void)setWaterFresnelMin:(float)v    { [_configuratorKit setWaterFresnelMin:v]; }
- (void)setWaterCenterOpacity:(float)v { [_configuratorKit setWaterCenterOpacity:v]; }

- (void *)getEngine { return [_configuratorKit getEngine]; }
- (void *)getScene  { return [_configuratorKit getScene]; }
- (void *)getCamera { return [_configuratorKit getCamera]; }

// ---------------------------------------------------------------------------
// Animation
// ---------------------------------------------------------------------------

- (void)playAnimation:(NSInteger)index action:(NSString *)action partName:(NSString *)partName {
    pc_anim_play(_ctx, PC_NULL_HANDLE, (int)index);
}
- (void)playReverseAnimation:(NSInteger)index action:(NSString *)action partName:(NSString *)partName {
    pc_anim_play_reverse(_ctx, PC_NULL_HANDLE, (int)index);
}
- (void)stopAnimation:(NSInteger)index      { pc_anim_stop(_ctx, PC_NULL_HANDLE, (int)index); }
- (BOOL)isAnimationActive:(NSInteger)index  { return pc_anim_is_active(_ctx, PC_NULL_HANDLE, (int)index) != 0; }
- (NSInteger)getAnimationCount              { return (NSInteger)pc_anim_count(_ctx, PC_NULL_HANDLE); }
- (float)getAnimationDuration:(NSInteger)index { return pc_anim_duration(_ctx, PC_NULL_HANDLE, (int)index); }
- (NSString *_Nullable)getAnimationName:(NSInteger)index {
    char buf[256];
    if (pc_anim_name(_ctx, PC_NULL_HANDLE, (int)index, buf, sizeof(buf)) == PC_OK && buf[0])
        return [NSString stringWithUTF8String:buf];
    return nil;
}

// ---------------------------------------------------------------------------
// Camera
// ---------------------------------------------------------------------------

- (void)moveToCameraPreset:(NSString *)presetName {
    if (presetName) pc_camera_move_to_preset(_ctx, [presetName UTF8String]);
}
- (void)loadCameraConfig:(NSString *)configPath {
    if (!configPath) return;
    NSData *data = [NSData dataWithContentsOfFile:configPath];
    if (data && data.length > 0)
        pc_camera_load_config(_ctx, static_cast<const uint8_t*>(data.bytes), data.length);
}
- (void)setCameraViewport:(int)width height:(int)height { pc_camera_set_viewport(_ctx, width, height); }
- (void)setCameraProjection:(float)fov aspect:(float)aspect near:(float)near far:(float)far {
    pc_camera_set_projection(_ctx, fov, aspect, near, far);
}
- (void)setOrbitEnabled:(BOOL)enabled       { pc_camera_set_orbit(_ctx, enabled ? 1 : 0); }
- (BOOL)isOrbitEnabled                      { return pc_camera_is_orbit(_ctx) != 0; }
- (void)applyOrbitRotationDeltaX:(float)dx deltaY:(float)dy { pc_camera_orbit_rotate(_ctx, dx, dy); }
- (void)applyOrbitZoom:(float)delta         { pc_camera_orbit_zoom(_ctx, delta); }
- (float)getIPadZoomOffset                  { return pc_camera_ipad_zoom_offset(_ctx); }

// ---------------------------------------------------------------------------
// Environment
// ---------------------------------------------------------------------------

- (void)loadEnvironmentConfig:(NSString *)path {
    if (!path) return;
    NSData *d = [NSData dataWithContentsOfFile:path];
    if (d && d.length) pc_env_load_config(_ctx, PC_CONFIG_ENVIRONMENT,
                                           static_cast<const uint8_t*>(d.bytes), d.length);
}
- (void)loadSystemConfig:(NSString *)path {
    if (!path) return;
    NSData *d = [NSData dataWithContentsOfFile:path];
    if (d && d.length) pc_env_load_config(_ctx, PC_CONFIG_SYSTEM,
                                           static_cast<const uint8_t*>(d.bytes), d.length);
}
- (void)loadInteriorConfig:(NSString *)path {
    if (!path) return;
    NSData *d = [NSData dataWithContentsOfFile:path];
    if (d && d.length) pc_env_load_config(_ctx, PC_CONFIG_INTERIOR,
                                           static_cast<const uint8_t*>(d.bytes), d.length);
}

- (void)setEnvironmentPreset:(NSString *)name {
    if (name) pc_env_set_preset(_ctx, [name UTF8String]);
}
- (void)setSceneEnvironment:(NSString *)environment {
    if (!environment) return;
    int id = PC_ENV_SEASIDE;
    if ([environment isEqualToString:@"Hangar"]) id = PC_ENV_HANGAR;
    else if ([environment isEqualToString:@"Space"]) id = PC_ENV_SPACE;
    pc_env_set_environment(_ctx, id);
}
- (void)switchSceneEnvironment:(NSString *)environment {
    if (!environment) return;
    int id = PC_ENV_SEASIDE;
    if ([environment isEqualToString:@"Hangar"]) id = PC_ENV_HANGAR;
    else if ([environment isEqualToString:@"Space"]) id = PC_ENV_SPACE;
    pc_env_switch_environment(_ctx, id);
}
- (void)switchSceneMode:(NSString *)mode {
    pc_env_set_scene_mode(_ctx, mode ? [mode UTF8String] : "exterior");
#if TARGET_OS_OSX
    pc_camera_set_orbit(_ctx, 1);
#else
    bool isIPad = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
    if (isIPad) pc_camera_set_orbit(_ctx, 1);
#endif
}

// ---------------------------------------------------------------------------
// Render / Lighting
// ---------------------------------------------------------------------------

- (void)update:(float)dt  { pc_context_update(_ctx, dt); }
- (void)render            { pc_context_render(_ctx); }

- (void)setBackgroundColorRed:(float)r green:(float)g blue:(float)b alpha:(float)a {
    pc_render_set_background(_ctx, r, g, b, a);
}
- (void)toggleDebugAxis               { pc_render_set_debug_axis(_ctx, !pc_render_get_debug_axis(_ctx)); }
- (void)setDebugAxisVisible:(BOOL)v   { pc_render_set_debug_axis(_ctx, v ? 1 : 0); }
- (BOOL)isDebugAxisVisible            { return pc_render_get_debug_axis(_ctx) != 0; }

- (void)setSunLightIntensity:(float)v    { pc_light_set_sun(_ctx, v); }
- (float)getSunLightIntensity            { return pc_light_get_sun(_ctx); }
- (void)setAmbientLightIntensity:(float)v{ pc_light_set_ambient(_ctx, v); }
- (float)getAmbientLightIntensity        { return pc_light_get_ambient(_ctx); }
- (void)setSunLightingPreset:(NSString *)n { if (n) pc_light_set_sun_preset(_ctx, [n UTF8String]); }

- (void)setDynamicResolutionScale:(float)s { pc_render_set_dyn_res(_ctx, s); }
- (float)getCurrentResolutionScale         { return pc_render_get_dyn_res(_ctx); }
- (void)setFXAAEnabled:(BOOL)v             { pc_render_set_fxaa(_ctx, v ? 1 : 0); }
- (void)setMSAAEnabled:(BOOL)v sampleCount:(int)s { pc_render_set_msaa(_ctx, v ? 1 : 0, s); }
- (int)getAntiAliasingType                 { return pc_render_get_aa_type(_ctx); }
- (int)getMSAASampleCount                  { return pc_render_get_msaa_samples(_ctx); }
- (void)setBloomEnabled:(BOOL)v            { pc_render_set_bloom(_ctx, v ? 1 : 0); }
- (BOOL)isBloomEnabled                     { return pc_render_get_bloom(_ctx) != 0; }
- (void)setBloomStrength:(float)s levels:(int)l quality:(int)q {
    pc_render_set_bloom_options(_ctx, s, l, q);
}
- (void)setNightMode:(BOOL)v               { pc_render_set_night_mode(_ctx, v ? 1 : 0); }
- (BOOL)isNightModeEnabled                 { return pc_render_get_night_mode(_ctx) != 0; }
- (void)setAmbientOcclusionEnabled:(BOOL)v { pc_render_set_ao(_ctx, v ? 1 : 0); }
- (BOOL)getAmbientOcclusionEnabled         { return pc_render_get_ao(_ctx) != 0; }
- (void)setToneMapper:(NSInteger)t         { pc_render_set_tone_mapper(_ctx, (int)t); }
- (NSInteger)getToneMapper                 { return (NSInteger)pc_render_get_tone_mapper(_ctx); }
- (void)setVignetteEnabled:(BOOL)v         { pc_render_set_vignette(_ctx, v ? 1 : 0); }
- (BOOL)getVignetteEnabled                 { return pc_render_get_vignette(_ctx) != 0; }
- (void)setSSREnabled:(BOOL)v              { pc_render_set_ssr(_ctx, v ? 1 : 0); }
- (BOOL)getSSREnabled                      { return pc_render_get_ssr(_ctx) != 0; }
- (void)setSSRQualityLevel:(NSInteger)l    { pc_render_set_ssr_quality(_ctx, (int)l); }
- (NSInteger)getSSRQualityLevel            { return (NSInteger)pc_render_get_ssr_quality(_ctx); }

// ---------------------------------------------------------------------------
// Weather / Wave
// ---------------------------------------------------------------------------

- (void)startRain                        { pc_weather_set_rain(_ctx, 1, 1.0f); }
- (void)stopRain                         { pc_weather_set_rain(_ctx, 0, 0.0f); }
- (void)setRainIntensity:(float)v        { pc_weather_set_rain(_ctx, 1, v); }
- (void)setPactorWaveEnabled:(BOOL)v     { pc_scene_set_wave(_ctx, v ? 1 : 0); }
- (BOOL)isPactorWaveEnabled              { return pc_scene_get_wave(_ctx) != 0; }

// ---------------------------------------------------------------------------
// Frame rate
// ---------------------------------------------------------------------------

- (int)getTargetFPS      { return pc_render_get_target_fps(_ctx); }
- (void)notifyUserInput  { pc_camera_notify_input(_ctx); }

@end
