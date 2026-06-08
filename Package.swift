// swift-tools-version: 5.9
import PackageDescription

// ─────────────────────────────────────────────────────────────────────────────
// After cutting a release:
//   1. Upload dist/PragmataCore.xcframework.zip to GitHub Releases
//   2. Copy the download URL into `releaseUrl` below
//   3. Paste the checksum printed by build-xcframework.sh into `checksum`
// ─────────────────────────────────────────────────────────────────────────────

let releaseUrl = "https://github.com/Pragmata-labs/pragmatacore-showcase/releases/download/v0.1.0/PragmataCore.xcframework.zip"
let checksum   = "REPLACE_WITH_CHECKSUM_FROM_BUILD_SCRIPT"

let package = Package(
    name: "PragmataCore",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "PragmataCore",
            targets: ["PragmataCore"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "PragmataCore",
            url: releaseUrl,
            checksum: checksum
        ),
    ]
)
