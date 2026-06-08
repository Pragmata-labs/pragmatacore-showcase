/**
 * ConfiguratorKit — NauticaApp domain plugin for PragmataCore SDK.
 *
 * Owns everything that is specific to the Nautica spaceship/boat configurator:
 * ship state machine, interior mode, boat configurator (IniConfigManager),
 * Fabric signal callback wiring, water shader parameters, and raw Filament
 * handle access.
 *
 * The bridge holds one ConfiguratorKit instance and delegates all domain calls here.
 * Generic SDK operations (camera, animation, render settings, environment)
 * remain in the bridge as pc_* calls.
 */

#pragma once

#import <Foundation/Foundation.h>
#include "pragmata/handle.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^CKSignalCallback)(NSString *signalType, NSString *message);

@interface ConfiguratorKit : NSObject

- (instancetype)initWithContext:(pc_context_t)ctx;

// ── Ship state ──────────────────────────────────────────────────────────────
// Publishes Signal_ActorState via Fabric; validates state vs current environment.
- (void)setShipState:(NSString *)state;

// Publishes Signal_InteriorMode via Fabric.
- (void)setInteriorMode:(BOOL)entering;

// Re-publishes Signal_ModelLoad (refreshes UI state after a model swap).
- (void)resendSignalModelLoad:(NSString *)modelName;

// ── Hull color (signal path) ─────────────────────────────────────────────────
// Publishes Signal_HullColor via Fabric.
- (void)applyHullColorRed:(float)r green:(float)g blue:(float)b;

// ── Boat configurator (IniConfigManager) ────────────────────────────────────
- (void)applyHullColor:(NSString *)colorName;
- (void)applySeatColor:(NSString *)colorName;
- (void)applyDeckTexture:(NSString *)styleName;
- (void)applyWoodTexture:(NSString *)woodName;
- (void)applyEquipmentPackage:(NSString *)packageName;
- (void)applyLeatherColor:(NSString *)colorName;
- (void)applyLivery:(NSInteger)index;
- (void)inspectMaterials;

// ── Fabric signal callback ───────────────────────────────────────────────────
// Wires a Swift-visible block to the Fabric global callback.
// Dispatches to main thread automatically.
- (void)setSignalCallback:(CKSignalCallback)callback;

// ── Background color (deferred apply) ───────────────────────────────────────
- (void)applyBackgroundColor;

// ── Water shader parameters ──────────────────────────────────────────────────
- (void)setWaterWindSpeed:(float)v;
- (void)setWaterUvScale:(float)v;
- (void)setWaterWaveStrength:(float)v;
- (void)setWaterFresnelPower:(float)v;
- (void)setWaterFresnelMin:(float)v;
- (void)setWaterCenterOpacity:(float)v;

// ── Raw Filament handles ─────────────────────────────────────────────────────
// Permanent escape hatches — needed by PragmataView for Filament Metal integration.
- (nullable void *)getEngine;
- (nullable void *)getScene;
- (nullable void *)getCamera;

@end

NS_ASSUME_NONNULL_END
