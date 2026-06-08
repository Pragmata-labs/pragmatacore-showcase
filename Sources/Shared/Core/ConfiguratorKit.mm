// Created by Marko Fucek, Velika Gorica, markfuce@gmail.com, all rights reserved - 2026

#import "ConfiguratorKit.h"
#import "ConfiguratorKitCore.h"
#import "AppLog.h"

#include <dispatch/dispatch.h>
#include <memory>

@implementation ConfiguratorKit {
    std::unique_ptr<ConfiguratorKitCore> _core;
    CKSignalCallback _signalCallback;
}

- (instancetype)initWithContext:(pc_context_t)ctx {
    self = [super init];
    if (self) _core = std::make_unique<ConfiguratorKitCore>(ctx);
    return self;
}

- (void)setShipState:(NSString *)state {
    if (state) _core->setShipState([state UTF8String]);
}

- (void)setInteriorMode:(BOOL)entering {
    _core->setInteriorMode(entering == YES);
}

- (void)resendSignalModelLoad:(NSString *)modelName {
    if (modelName) _core->resendSignalModelLoad([modelName UTF8String]);
}

- (void)applyHullColorRed:(float)r green:(float)g blue:(float)b {
    _core->applyHullColorRGB(r, g, b);
}

- (void)applyHullColor:(NSString *)colorName      { _core->applyHullColor([colorName UTF8String]); }
- (void)applySeatColor:(NSString *)colorName      { _core->applySeatColor([colorName UTF8String]); }
- (void)applyDeckTexture:(NSString *)styleName    { _core->applyDeckTexture([styleName UTF8String]); }
- (void)applyWoodTexture:(NSString *)woodName     { _core->applyWoodTexture([woodName UTF8String]); }
- (void)applyEquipmentPackage:(NSString *)name    { _core->applyEquipmentPackage([name UTF8String]); }
- (void)applyLeatherColor:(NSString *)colorName   { _core->applyLeatherColor([colorName UTF8String]); }
- (void)applyLivery:(NSInteger)index              { _core->applyLivery((int)index); }
- (void)inspectMaterials                          { _core->inspectMaterials(); }
- (void)applyBackgroundColor                      { _core->applyBackgroundColor(); }

- (void)setWaterWindSpeed:(float)v     { _core->setWaterWindSpeed(v); }
- (void)setWaterUvScale:(float)v       { _core->setWaterUvScale(v); }
- (void)setWaterWaveStrength:(float)v  { _core->setWaterWaveStrength(v); }
- (void)setWaterFresnelPower:(float)v  { _core->setWaterFresnelPower(v); }
- (void)setWaterFresnelMin:(float)v    { _core->setWaterFresnelMin(v); }
- (void)setWaterCenterOpacity:(float)v { _core->setWaterCenterOpacity(v); }

- (void *)getEngine { return _core->getEngine(); }
- (void *)getScene  { return _core->getScene(); }
- (void *)getCamera { return _core->getCamera(); }

- (void)setSignalCallback:(CKSignalCallback)callback {
    _signalCallback = callback;
    __weak ConfiguratorKit *weakSelf = self;
    _core->setSignalCallback([weakSelf](const std::string& type, const std::string& message) {
        ConfiguratorKit *strongSelf = weakSelf;
        if (!strongSelf) return;
        auto cb = strongSelf->_signalCallback;
        if (!cb) return;
        NSString *nsType    = [NSString stringWithUTF8String:type.c_str()];
        NSString *nsMessage = [NSString stringWithUTF8String:message.c_str()];
        dispatch_async(dispatch_get_main_queue(), ^{ cb(nsType, nsMessage); });
    });
    APP_LOG("ConfiguratorKit", "🔗 Fabric global callback connected");
}

@end
