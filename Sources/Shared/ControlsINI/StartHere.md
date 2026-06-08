# ControlsINI — Configuration Files

All INI files that control runtime behaviour of the app are in this folder.
Edit values here and rebuild — no code change needed.
> **Note:** Since these files are copied into the app bundle at build time, you must **Build & Run** again for changes to take effect. Saving the file alone is not enough.

---

## cameras.ini
**Loaded by:** `PragmataView.mm` via `[[NSBundle mainBundle] pathForResource:@"cameras" ofType:@"ini" inDirectory:@"ControlsINI"]`
**Applied to:** `CameraController` (camera presets and zoom-punch timing)

Sections: `[Front]`, `[Side]`, `[Rear]`, `[Top]`, `[Interior]`, `[ZoomPunch]`
Each camera section sets `posX/Y/Z` (position) and `lookX/Y/Z` (look-at target).
`[ZoomPunch]` controls the animated zoom that fires on boat model swap.

---

## water.ini
**Loaded by:** `WaterFloorMaterial.cpp` and `WeatherManager.cpp` via `fileLoadCallback_("ControlsINI/water.ini", ...)`
**Applied to:** water surface shader material instance

Key params: `windDirX/Y`, `waveSpeed`, `uvScale`, `foamScale`, `foamAmount`,
`deepColorR/G/B`, `shallowColorR/G/B`, `baseOpacity`, `normalStrength`,
`roughness`, `reflectance`

---

## seafloor.ini
**Loaded by:** `WaterFloorMaterial.cpp` via `fileLoadCallback_("ControlsINI/seafloor.ini", ...)`
**Applied to:** sea floor (sand) shader material instance

Key params: `sandTilingX/Y`, `sandRoughness`, `causticGlobalSize`, `causticSpeed`,
`waterColorR/G/B`, `normalStrength`, `causticStrength`, `maskRadius`, `maskSoftness`

---

## xray.ini
**Loaded by:** `InteriorManager.cpp` via `fileLoadCallback_("ControlsINI/xray.ini", ...)`
**Applied to:** X-ray / interior view shader material instance
**Triggered:** when the Interior toggle is switched on

Key params: `mixFactor` (0.0–1.0 blend), `opacity`, `edgeColorR/G/B`

Presets (set manually in the file):
- Soft Ghost: `mixFactor=0.0, opacity=0.5`
- Blueprint/X-ray: `mixFactor=0.8, opacity=1.0`
- Hidden Part: `mixFactor=1.0, opacity=0.2`

---

## environment.ini
**Loaded by:** `Core3DEngine.cpp::loadEnvironmentConfig()` at startup via `fileLoadCallback_("ControlsINI/environment.ini", ...)`
**Applied to:** IBL indirect light + directional sun light when switching presets
**Triggered:** left sidebar buttons (sun.max = Sunny, sun.haze = Sunset)

Sections: `[Transition]`, `[Sunny]`, `[Sunset]`

`[Transition]`:
- `fadeSpeed` — IBL fade-out/fade-in speed in lux/sec (default 30000 ≈ 1.5 sec at 45000 lux)

Each preset section (`[Sunny]`, `[Sunset]`):
- `ktxFile` / `shFile` — IBL cubemap and spherical-harmonics file (relative to `HDR_environment/`)
- `iblIntensity` — indirect light intensity in lux (default 45000)
- `sunDirX/Y/Z` — directional light direction vector
- `sunColorR/G/B` — sun colour (linear, 0–1)
- `sunIntensity` — sun intensity in lux
- `color0..3R/G/B` — gradient skybox colors (4 steps)
- `stop0..3` — gradient stops (0.0 to 1.0)

> **Note:** ktxFile names are intentionally "swapped" (Sunny uses sunset_ibl.ktx and vice-versa)
> because the HDR files were generated from HDRs named the opposite way.
> Change the filenames here if you swap/regenerate the HDR assets.
