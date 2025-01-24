import Foundation

enum AppConfiguration {
    static let infoPlistSettings: [String: Any] = [
        "NSCameraUsageDescription": Bundle.cameraPermission,
        "NSPhotoLibraryUsageDescription": Bundle.photoLibraryPermission,
        "NSPhotoLibraryAddUsageDescription": Bundle.photoLibraryPermission,
        "CFBundleDevelopmentRegion": "$(DEVELOPMENT_LANGUAGE)",
        "CFBundleExecutable": "$(EXECUTABLE_NAME)",
        "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
        "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundleName": "$(PRODUCT_NAME)",
        "CFBundlePackageType": "$(PRODUCT_BUNDLE_PACKAGE_TYPE)",
        "CFBundleShortVersionString": "1.0",
        "CFBundleVersion": "1",
        "LSRequiresIPhoneOS": true,
        "UIApplicationSceneManifest": [
            "UIApplicationSupportsMultipleScenes": false
        ],
        "UILaunchScreen": [:],
        "UISupportedInterfaceOrientations": [
            "UIInterfaceOrientationPortrait",
            "UIInterfaceOrientationLandscapeLeft",
            "UIInterfaceOrientationLandscapeRight"
        ]
    ]
} 