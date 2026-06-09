# Changelog

All notable changes to PragmataCore Configurator are documented here.

---

## [Unreleased]

---

## [v0.1.1] — 2026-06-08

### Fixed
- `Package.swift` swift-tools-version bumped to 6.0 (required for `.macOS(.v15)` platform constraint)
- SPM binary target tag alignment — showcase resolves `PragmataCore.xcframework` correctly on first build

---

## [v0.1.0] — 2026-06-08

### Added
- Initial public release
- iPadOS 17+, tvOS 17+, macOS 15+ (Apple Silicon) support
- Real-time 3D configurator built on PragmataCore (C++ / Filament / Metal)
- Hull colour, livery, and equipment package selection via INI-driven UI
- Interior / exterior scene mode switching
- IBL environment presets (Space, Hangar, Sunrise, Sunset)
- Siri Remote support on tvOS (touch orbit, ring zoom, center click select)
- `PragmataCore.xcframework` distributed via Swift Package Manager (binary target)
