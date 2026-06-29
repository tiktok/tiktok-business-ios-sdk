// swift-tools-version:5.4
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "TikTokBusinessSDK",
    platforms: [
        .iOS(.v12),
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "TikTokBusinessSDK",
            targets: ["TikTokBusinessSDK", "TikTokBusinessSDKCore"]),
    ],
    dependencies: [
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "TikTokBusinessSDKCore",
            dependencies: [],
            path: "TikTokBusinessSDK/Core",
            publicHeadersPath: "Public",
            cSettings: [
                .define("TikTokBusinessSDK_SPM"),
                .headerSearchPath("./"),
                .headerSearchPath("AppEvents"),
                .headerSearchPath("TiktokSKAdNetwork"),
                .headerSearchPath("TikTokAdditions"),
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
                .headerSearchPath("TTSDKEncrypt"),
                .headerSearchPath("Storage"),
            ],
            linkerSettings: [
                .linkedLibrary("c++"),
                .linkedFramework("UIKit"),
                .linkedFramework("CoreTelephony"),
                .linkedFramework("AdSupport"),
                .linkedFramework("AppTrackingTransparency"),
                .linkedFramework("WebKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("StoreKit")
            ]
        ),
        .target(
            name: "TikTokBusinessSDK",
            dependencies: ["TikTokBusinessSDKCore"],
            path: "TikTokBusinessSDK/Swift",
            swiftSettings: [.define("TikTokBusinessSDK_SPM")]
        ),
        .testTarget(
            name: "TikTokBusinessSDKTestsAppEvents",
            dependencies: ["TikTokBusinessSDKCore", "TikTokBusinessSDK"],
            path: "TikTokBusinessSDKTests/AppEvents"
        ),
        .testTarget(
            name: "TikTokBusinessSDKTestsIAP",
            dependencies: ["TikTokBusinessSDKCore", "TikTokBusinessSDK"],
            path: "TikTokBusinessSDKTests/IAP"
        ),
    ]
)
