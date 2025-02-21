// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "TikTokBusinessSDK",
    platforms: [
        .iOS(.v9),
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "TikTokBusinessSDK",
            targets: ["TikTokBusinessSDK"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "TikTokBusinessSDK",
            dependencies: [],
            path: "TikTokBusinessSDK",
            publicHeadersPath: "Public",
            cSettings: [
                .headerSearchPath("./"),
                .headerSearchPath("AppEvents"),
                .headerSearchPath("TiktokSKAdNetwork"),
                .headerSearchPath("TTSDKCrash/TTSDKCrashReportingCore/include"),
                .headerSearchPath("TTSDKCrash/TTSDKCrashCore/include"),
                .headerSearchPath("TTSDKCrash/TTSDKCrashRecordingCore/include"),
                .headerSearchPath("TTSDKCrash/TTSDKCrashSinks/include"),
                .headerSearchPath("TTSDKCrash/TTSDKCrashRecording"),
                .headerSearchPath("TTSDKCrash/TTSDKCrashRecording/include"),
                .headerSearchPath("TTSDKCrash/TTSDKCrashBootTimeMonitor/include"),
                .headerSearchPath("TTSDKCrash/TTSDKCrashDiscSpaceMonitor/include"),
                .headerSearchPath("TTSDKCrash/TTSDKCrashInstallations/include"),
                .headerSearchPath("TTSDKCrash/TTSDKCrashFilters/include"),
                .headerSearchPath("TTSDKCrash/TTSDKCrashRecording/Monitors"),
                .headerSearchPath("TTSDKAddress"),
                .headerSearchPath("TikTokAdditions"),
            ],
            linkerSettings: [
                .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS])),
            ]
        ),
        .testTarget(
            name: "TikTokBusinessSDKTests",
            dependencies: ["TikTokBusinessSDK"],
            path: "TikTokBusinessSDKTests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
