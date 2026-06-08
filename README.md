# PragmataCore Showcase

> Cross-platform real-time 3D configurator built on a proprietary C++ engine with Google Filament.
> iPadOS · tvOS · macOS · Android (in progress)

---

## Demo

<!-- Add demo video or GIF here -->
<!-- [![Demo](media/demo.gif)](media/demo.gif) -->

<!-- App Store links — uncomment when live -->
<!-- [Download on the App Store](https://apps.apple.com/...) -->

---

## What this is

A working sample application that runs on top of **PragmataCore** — a native real-time 3D runtime with:

- C++ core engine with ECS architecture
- Google Filament rendering backend (Metal on Apple platforms)
- C ABI public interface — platform-agnostic, zero C++ exposure
- Swift / Objective-C bridge for Apple platforms
- JNI bridge for Android (in progress)

The SDK source is private. This repository contains the sample UI source and a precompiled `PragmataCore.xcframework`.

---

## Architecture

```
SwiftUI / AppKit  (this repo)
       ↓
ObjC Bridge       (this repo — PragmataCoreIOSBridge.mm)
       ↓  pc_* C API
PragmataCore.xcframework  (precompiled binary)
       ↓
C++ Core · ECS · Fabric signal bus · Filament backend
       ↓
Google Filament → Metal (Apple) / Vulkan (Android)
```

---

## Platforms

| Platform | Status |
|---|---|
| macOS 15+ (Apple Silicon only) | ✅ |
| iPadOS 17+ | ✅ |
| tvOS 17+ | ✅ |
| Android | 🔄 In progress |

> **Intel Mac (x86\_64) is not supported.** The runtime has not been built or tested on Intel Macs and there are no plans to investigate or support it.

---

## Requirements

- Xcode 16+
- macOS 15 Sequoia or later
- Apple Silicon Mac (Intel not supported)

---

## Build

```bash
git clone https://github.com/Pragmata-labs/pragmatacore-showcase.git
cd pragmatacore-showcase
xcodegen generate
open PragmataCoreShowcase.xcodeproj
```

Select a scheme (`Showcase-macOS`, `Showcase-iPadOS`, `Showcase-tvOS`) and run.

The `PragmataCore.xcframework` is resolved automatically via Swift Package Manager on first build.

---

## Swift Package Manager

To use PragmataCore in your own project:

```
https://github.com/Pragmata-labs/pragmatacore-showcase
```

Add via **Xcode → File → Add Package Dependencies** and link `PragmataCore` to your target.

---

## SDK Public API (C ABI)

```c
// Create a rendering context
pc_context_t pc_context_create(const pc_context_desc_t* desc);

// Per-frame
pc_result_t pc_context_update(pc_context_t ctx, float dt);
pc_result_t pc_context_render(pc_context_t ctx);

// Load a 3D model
pc_result_t pc_scene_load_model(pc_context_t ctx, const char* name,
                                 const char* camera_preset, pc_scene_t* out);

// Camera
pc_result_t pc_camera_move_to_preset(pc_context_t ctx, const char* preset);
pc_result_t pc_camera_orbit_rotate(pc_context_t ctx, float dx, float dy);

// Materials
pc_result_t pc_material_set_base_color(pc_context_t ctx, const char* mesh,
                                        float r, float g, float b, float a);
```

Full API reference: headers are distributed inside `PragmataCore.xcframework` (resolved via SPM on first build).

---

## License

| Component | License |
|---|---|
| Sample UI source code | MIT — see [LICENSE](LICENSE) |
| PragmataCore.xcframework | Proprietary binary — see [LICENSE](LICENSE) notice |
| 3D models and assets | All Rights Reserved — see [ASSETS_LICENSE](ASSETS_LICENSE) |

3D assets (PCraft400 and related files) are proprietary IP. You may run the demo freely.
Any other use requires prior written agreement — contact markfuce@gmail.com.

---

*Built by [Marko Fucek](https://github.com/pannonianknight)*
