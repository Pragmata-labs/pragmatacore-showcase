#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PragmataMacView : NSView

@property (nonatomic, copy, nullable) void (^loadingProgressCallback)(float progress, NSString *stage);
@property (nonatomic, copy, nullable) void (^sceneFadeCallback)(BOOL isTransitioning);

- (void)setSignalCallback:(void (^)(NSString *signalType, NSString *message))callback;

- (void)applyHullColor:(NSString *)colorName;
- (void)applySeatColor:(NSString *)colorName;
- (void)applyDeckTexture:(NSString *)styleName;
- (void)applyWoodTexture:(NSString *)woodName;
- (void)applyEquipmentPackage:(NSString *)packageName;
- (void)applyLeatherColor:(NSString *)colorName;
- (void)applyLivery:(NSInteger)index;

- (void)setEnvironmentPreset:(NSString *)presetName;
- (void)setSceneEnvironment:(NSString *)environment;
- (void)switchSceneEnvironment:(NSString *)environment;
- (void)setShipState:(NSString *)state;
- (void)setInteriorMode:(BOOL)entering;
- (void)switchSceneMode:(NSString *)mode;

- (void)moveToPresetFront;
- (void)moveToPresetTop;
- (void)moveToPresetRear;
- (void)moveToPresetSide;
- (void)moveToPresetInterior;
- (void)moveToPreset:(NSString *)name;

- (void)setOrbitEnabled:(BOOL)enabled;
- (BOOL)isOrbitEnabled;
- (void)applyOrbitRotationDeltaX:(float)dx deltaY:(float)dy;
- (void)applyOrbitZoom:(float)delta;
- (float)getIPadZoomOffset;

- (NSInteger)getAnimationCount;
- (nullable NSString *)getAnimationNameAtIndex:(NSInteger)index;
- (void)playAnimationAtIndex:(NSInteger)index action:(NSString *)action partName:(NSString *)partName;
- (void)stopAnimationAtIndex:(NSInteger)index;
- (BOOL)isAnimationActiveAtIndex:(NSInteger)index;

- (void)setNightMode:(BOOL)enabled;
- (void)setBloomEnabled:(BOOL)enabled;
- (void)setBloomStrength:(float)strength levels:(int)levels quality:(int)quality;
- (void)setAmbientOcclusionEnabled:(BOOL)enabled;
- (BOOL)getAmbientOcclusionEnabled;

// Resolution
typedef NS_ENUM(NSInteger, ResolutionPreset) {
    ResolutionPresetNative = 0,
    ResolutionPresetHigh,
    ResolutionPresetHalf,
    ResolutionPresetThird
};
- (void)setResolutionPreset:(ResolutionPreset)preset;
- (float)getCurrentResolutionScale;

// Anti-Aliasing
- (void)setAntiAliasingFXAA:(BOOL)enabled;
- (void)setAntiAliasingMSAA:(BOOL)enabled sampleCount:(int)sampleCount;
- (NSInteger)getAntiAliasingType;

// Tone Mapper
- (void)setToneMapper:(NSInteger)type;
- (NSInteger)getToneMapper;

// Debug Axis
- (void)setDebugAxisVisible:(BOOL)visible;
- (BOOL)isDebugAxisVisible;

// Lighting
- (void)setSunLightIntensity:(float)intensity;
- (float)getSunLightIntensity;
- (void)setAmbientLightIntensity:(float)intensity;
- (float)getAmbientLightIntensity;

// Animation reverse
- (void)playAnimationReverseAtIndex:(NSInteger)index action:(NSString *)action partName:(NSString *)partName
    NS_SWIFT_NAME(playAnimationReverse(at:action:partName:));

@end

NS_ASSUME_NONNULL_END
