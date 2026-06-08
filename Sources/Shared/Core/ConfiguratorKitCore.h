// Created by Marko Fucek, Velika Gorica, markfuce@gmail.com, all rights reserved - 2026
/**
 * ConfiguratorKitCore — pure C++ domain logic, shared across all platforms.
 *
 * Thin platform wrappers:
 *   Apple  → ConfiguratorKit.mm   (ObjC, dispatches to main thread)
 *   Android → ConfiguratorKitJNI.cpp (JNI, dispatches to UI thread)
 */

#pragma once

#include "pragmata/handle.h"
#include <functional>
#include <string>

class Core3DEngine;
namespace core3d { class IniConfigManager; }

class ConfiguratorKitCore {
public:
    using SignalCallback = std::function<void(const std::string& type,
                                              const std::string& message)>;

    explicit ConfiguratorKitCore(pc_context_t ctx);

    // Ship state machine
    void setShipState(const std::string& state);
    void setInteriorMode(bool entering);
    void resendSignalModelLoad(const std::string& modelName);

    // Hull color — direct RGB signal path
    void applyHullColorRGB(float r, float g, float b);

    // Boat configurator (IniConfigManager)
    void applyHullColor(const std::string& colorName);
    void applySeatColor(const std::string& colorName);
    void applyDeckTexture(const std::string& styleName);
    void applyWoodTexture(const std::string& woodName);
    void applyEquipmentPackage(const std::string& packageName);
    void applyLeatherColor(const std::string& colorName);
    void applyLivery(int index);
    void inspectMaterials();

    // Fabric global callback — caller dispatches to its own UI thread
    void setSignalCallback(SignalCallback callback);

    // Misc
    void applyBackgroundColor();
    void setWaterWindSpeed(float v);
    void setWaterUvScale(float v);
    void setWaterWaveStrength(float v);
    void setWaterFresnelPower(float v);
    void setWaterFresnelMin(float v);
    void setWaterCenterOpacity(float v);

    // Raw Filament handles (escape hatches for platform Metal/GL integration)
    void* getEngine() const;
    void* getScene()  const;
    void* getCamera() const;

private:
    pc_context_t ctx_;

    Core3DEngine*             engine()        const;
    core3d::IniConfigManager* configManager() const;
};
