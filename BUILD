package(default_visibility = ["//visibility:public"])

licenses(["notice"])  # Apache 2.0

exports_files(["LICENSE"])

load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")

OBJC_COPTS = [
    "-Werror",
    "-Wextra",
    "-Wall",
    "-Wstrict-prototypes",
    "-Wdocumentation",
]

objc_library(
    name = "UIImage_FBLAdditions",
    srcs = glob([
        "Sources/UIImage+FBLAdditions/*.m",
    ]),
    hdrs = glob([
        "Sources/UIImage+FBLAdditions/include/*.h",
    ]) + [
        "UIImage+FBLAdditions.h",
    ],
    copts = OBJC_COPTS,
    includes = [
        "Sources/UIImage+FBLAdditions/include",
    ],
    module_map = "Sources/UIImage+FBLAdditions/include/module.modulemap",
)

objc_library(
    name = "UIImage_FBLAdditionsTestHelpers",
    testonly = 1,
    srcs = glob([
        "Sources/UIImage+FBLAdditionsTestHelpers/*.m",
    ]),
    hdrs = glob([
        "Sources/UIImage+FBLAdditionsTestHelpers/include/*.h",
    ]),
    copts = OBJC_COPTS,
    includes = [
        "Sources/UIImage+FBLAdditionsTestHelpers/include",
    ],
    module_map = "Sources/UIImage+FBLAdditionsTestHelpers/include/module.modulemap",
    deps = [
        ":UIImage_FBLAdditions",
    ],
)

ios_unit_test(
    name = "Tests",
    minimum_os_version = "9.0",
    test_host = "@build_bazel_rules_apple//apple/testing/default_host/ios",
    deps = [
        ":UIImage_FBLAdditionsTests",
    ],
)

objc_library(
    name = "UIImage_FBLAdditionsTests",
    testonly = 1,
    srcs = glob([
        "Tests/UIImage+FBLAdditionsTests/*.m",
    ]),
    copts = OBJC_COPTS,
    resources = glob([
        "Resources/UIImage+FBLAdditionsTests/*",
    ]),
    sdk_frameworks = [
        "CoreGraphics",
        "CoreImage",
        "UIKit",
    ],
    deps = [
        ":UIImage_FBLAdditions",
        ":UIImage_FBLAdditionsTestHelpers",
    ],
)
