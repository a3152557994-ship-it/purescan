#!/usr/bin/env python3
"""Generate deterministic PureScan.xcodeproj with 3 targets:
- PureScan (iOS 18.0+ App)
- PureScanWidgets (Home Screen WidgetKit Extension)
- PureScanTests (XCTest Unit Test Bundle)
"""
from __future__ import annotations

import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROJ_DIR = ROOT / "PureScan.xcodeproj"
PROJ_DIR.mkdir(parents=True, exist_ok=True)


def uid(tag: str) -> str:
    return hashlib.md5(f"purescan::{tag}".encode("utf-8")).hexdigest()[:24].upper()


def rel_sources(subdir: str, ext: str = ".swift") -> list[str]:
    base = ROOT / subdir
    if not base.exists():
        return []
    return sorted([p.relative_to(ROOT).as_posix() for p in base.rglob(f"*{ext}")])


def main() -> None:
    app_sources = rel_sources("Sources", ".swift")
    widget_sources = rel_sources("Widgets", ".swift")
    test_sources = rel_sources("Tests", ".swift")

    asset_catalog = "Resources/Assets.xcassets"
    privacy_manifest = "Resources/PrivacyInfo.xcprivacy"
    app_info_plist = "Config/Info.plist"
    widget_info_plist = "Config/Widget-Info.plist"
    app_entitlements = "Config/PureScan.entitlements"
    widget_entitlements = "Config/PureScanWidgets.entitlements"
    storekit_config = "Config/PureScan.storekit"

    file_refs: dict[str, tuple[str, str, str, str]] = {}
    build_files: dict[str, tuple[str, str, str | None]] = {}

    def add_file(rel_path: str, file_type: str, name: str | None = None, path_attr: str | None = None) -> str:
        if rel_path in file_refs:
            return file_refs[rel_path][0]
        fid = uid(f"fileref::{rel_path}")
        file_refs[rel_path] = (fid, file_type, name or Path(rel_path).name, path_attr or rel_path)
        return fid

    for s in app_sources:
        fid = add_file(s, "sourcecode.swift")
        build_files[f"app_src::{s}"] = (uid(f"bf_app::{s}"), fid, None)

    for s in widget_sources:
        fid = add_file(s, "sourcecode.swift")
        build_files[f"widget_src::{s}"] = (uid(f"bf_widget::{s}"), fid, None)

    for s in test_sources:
        fid = add_file(s, "sourcecode.swift")
        build_files[f"test_src::{s}"] = (uid(f"bf_test::{s}"), fid, None)

    zh_strings_fid = add_file(
        "Resources/zh-Hans.lproj/InfoPlist.strings",
        "text.plist.strings",
        name="zh-Hans",
        path_attr="Resources/zh-Hans.lproj/InfoPlist.strings",
    )
    en_strings_fid = add_file(
        "Resources/en.lproj/InfoPlist.strings",
        "text.plist.strings",
        name="en",
        path_attr="Resources/en.lproj/InfoPlist.strings",
    )
    strings_vg_id = uid("variantgroup::InfoPlist.strings")
    build_files["app_res::InfoPlist.strings"] = (uid("bf_app_res::InfoPlist.strings"), strings_vg_id, None)

    assets_fid = add_file(asset_catalog, "folder.assetcatalog")
    build_files["app_res::Assets.xcassets"] = (uid("bf_app_res::Assets.xcassets"), assets_fid, None)

    privacy_fid = add_file(privacy_manifest, "text.xml")
    build_files["app_res::PrivacyInfo.xcprivacy"] = (uid("bf_app_res::PrivacyInfo.xcprivacy"), privacy_fid, None)
    build_files["widget_res::PrivacyInfo.xcprivacy"] = (uid("bf_widget_res::PrivacyInfo.xcprivacy"), privacy_fid, None)

    storekit_fid = add_file(storekit_config, "text.json")
    build_files["test_res::PureScan.storekit"] = (uid("bf_test_res::PureScan.storekit"), storekit_fid, None)

    for cfg_file, ftype in [
        (app_info_plist, "text.plist.xml"),
        (widget_info_plist, "text.plist.xml"),
        (app_entitlements, "text.plist.entitlements"),
        (widget_entitlements, "text.plist.entitlements"),
    ]:
        add_file(cfg_file, ftype)

    # Product refs
    app_prod_id = uid("product::PureScan.app")
    widget_prod_id = uid("product::PureScanWidgets.appex")
    test_prod_id = uid("product::PureScanTests.xctest")

    embed_widget_bf = uid("bf_embed::PureScanWidgets.appex")

    # Target & phase IDs
    project_id = uid("project")
    main_group_id = uid("group::main")
    products_group_id = uid("group::Products")
    sources_group_id = uid("group::Sources")
    widgets_group_id = uid("group::Widgets")
    tests_group_id = uid("group::Tests")
    resources_group_id = uid("group::Resources")
    config_group_id = uid("group::Config")

    app_target_id = uid("target::PureScan")
    widget_target_id = uid("target::PureScanWidgets")
    test_target_id = uid("target::PureScanTests")

    app_sources_phase = uid("phase::app_sources")
    app_frameworks_phase = uid("phase::app_frameworks")
    app_resources_phase = uid("phase::app_resources")
    app_embed_ext_phase = uid("phase::app_embed_ext")

    widget_sources_phase = uid("phase::widget_sources")
    widget_frameworks_phase = uid("phase::widget_frameworks")
    widget_resources_phase = uid("phase::widget_resources")

    test_sources_phase = uid("phase::test_sources")
    test_frameworks_phase = uid("phase::test_frameworks")
    test_resources_phase = uid("phase::test_resources")

    dep_widget_proxy = uid("proxy::widget")
    dep_widget_id = uid("dep::app_widget")
    dep_app_proxy = uid("proxy::app")
    dep_test_app_id = uid("dep::test_app")

    # Build config IDs
    proj_debug_cfg = uid("cfg::proj_debug")
    proj_release_cfg = uid("cfg::proj_release")
    proj_cfg_list = uid("cfglist::proj")

    app_debug_cfg = uid("cfg::app_debug")
    app_release_cfg = uid("cfg::app_release")
    app_cfg_list = uid("cfglist::app")

    widget_debug_cfg = uid("cfg::widget_debug")
    widget_release_cfg = uid("cfg::widget_release")
    widget_cfg_list = uid("cfglist::widget")

    test_debug_cfg = uid("cfg::test_debug")
    test_release_cfg = uid("cfg::test_release")
    test_cfg_list = uid("cfglist::test")

    lines: list[str] = []
    w = lines.append

    w("// !$*UTF8*$!")
    w("{")
    w("\tarchiveVersion = 1;")
    w("\tclasses = {")
    w("\t};")
    w("\tobjectVersion = 56;")
    w("\tobjects = {")
    w("")

    # PBXBuildFile
    w("/* Begin PBXBuildFile section */")
    for key, (bfid, fref, settings) in sorted(build_files.items()):
        extra = f" settings = {{{settings}}};" if settings else ""
        w(f"\t\t{bfid} /* {key} */ = {{isa = PBXBuildFile; fileRef = {fref};{extra} }};")
    w(f"\t\t{embed_widget_bf} /* PureScanWidgets.appex in Embed Foundation Extensions */ = {{isa = PBXBuildFile; fileRef = {widget_prod_id}; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};")
    w("/* End PBXBuildFile section */")
    w("")

    # PBXContainerItemProxy
    w("/* Begin PBXContainerItemProxy section */")
    w(f"\t\t{dep_widget_proxy} /* PBXContainerItemProxy */ = {{")
    w("\t\t\tisa = PBXContainerItemProxy;")
    w(f"\t\t\tcontainerPortal = {project_id} /* Project object */;")
    w("\t\t\tproxyType = 1;")
    w(f"\t\t\tremoteGlobalIDString = {widget_target_id};")
    w("\t\t\tremoteInfo = PureScanWidgets;")
    w("\t\t};")
    w(f"\t\t{dep_app_proxy} /* PBXContainerItemProxy */ = {{")
    w("\t\t\tisa = PBXContainerItemProxy;")
    w(f"\t\t\tcontainerPortal = {project_id} /* Project object */;")
    w("\t\t\tproxyType = 1;")
    w(f"\t\t\tremoteGlobalIDString = {app_target_id};")
    w("\t\t\tremoteInfo = PureScan;")
    w("\t\t};")
    w("/* End PBXContainerItemProxy section */")
    w("")

    # PBXCopyFilesBuildPhase
    w("/* Begin PBXCopyFilesBuildPhase section */")
    w(f"\t\t{app_embed_ext_phase} /* Embed Foundation Extensions */ = {{")
    w("\t\t\tisa = PBXCopyFilesBuildPhase;")
    w("\t\t\tbuildActionMask = 2147483647;")
    w('\t\t\tdstPath = "";')
    w("\t\t\tdstSubfolderSpec = 13;")
    w("\t\t\tfiles = (")
    w(f"\t\t\t\t{embed_widget_bf} /* PureScanWidgets.appex in Embed Foundation Extensions */,")
    w("\t\t\t);")
    w('\t\t\tname = "Embed Foundation Extensions";')
    w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w("\t\t};")
    w("/* End PBXCopyFilesBuildPhase section */")
    w("")

    # PBXFileReference
    w("/* Begin PBXFileReference section */")
    for rel_path, (fid, ftype, name, path_attr) in sorted(file_refs.items()):
        w(f'\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; name = "{name}"; path = "{path_attr}"; sourceTree = "<group>"; }};')
    w(f'\t\t{app_prod_id} /* PureScan.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = PureScan.app; sourceTree = BUILT_PRODUCTS_DIR; }};')
    w(f'\t\t{widget_prod_id} /* PureScanWidgets.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = PureScanWidgets.appex; sourceTree = BUILT_PRODUCTS_DIR; }};')
    w(f'\t\t{test_prod_id} /* PureScanTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = PureScanTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};')
    w("/* End PBXFileReference section */")
    w("")

    # PBXFrameworksBuildPhase
    w("/* Begin PBXFrameworksBuildPhase section */")
    for pid, label in [
        (app_frameworks_phase, "PureScan"),
        (widget_frameworks_phase, "PureScanWidgets"),
        (test_frameworks_phase, "PureScanTests"),
    ]:
        w(f"\t\t{pid} /* Frameworks ({label}) */ = {{")
        w("\t\t\tisa = PBXFrameworksBuildPhase;")
        w("\t\t\tbuildActionMask = 2147483647;")
        w("\t\t\tfiles = (")
        w("\t\t\t);")
        w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
        w("\t\t};")
    w("/* End PBXFrameworksBuildPhase section */")
    w("")

    # PBXGroup
    w("/* Begin PBXGroup section */")
    w(f"\t\t{main_group_id} = {{")
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    w(f"\t\t\t\t{sources_group_id} /* Sources */,")
    w(f"\t\t\t\t{widgets_group_id} /* Widgets */,")
    w(f"\t\t\t\t{tests_group_id} /* Tests */,")
    w(f"\t\t\t\t{resources_group_id} /* Resources */,")
    w(f"\t\t\t\t{config_group_id} /* Config */,")
    w(f"\t\t\t\t{products_group_id} /* Products */,")
    w("\t\t\t);")
    w('\t\t\tsourceTree = "<group>";')
    w("\t\t};")

    def emit_group(gid: str, name: str, child_ids: list[str]) -> None:
        w(f"\t\t{gid} /* {name} */ = {{")
        w("\t\t\tisa = PBXGroup;")
        w("\t\t\tchildren = (")
        for cid in child_ids:
            w(f"\t\t\t\t{cid},")
        w("\t\t\t);")
        w(f"\t\t\tname = {name};")
        w('\t\t\tsourceTree = "<group>";')
        w("\t\t};")

    emit_group(sources_group_id, "Sources", [file_refs[s][0] for s in app_sources])
    emit_group(widgets_group_id, "Widgets", [file_refs[s][0] for s in widget_sources])
    emit_group(tests_group_id, "Tests", [file_refs[s][0] for s in test_sources])
    emit_group(resources_group_id, "Resources", [assets_fid, privacy_fid, strings_vg_id])
    emit_group(config_group_id, "Config", [file_refs[p][0] for p in [app_info_plist, widget_info_plist, app_entitlements, widget_entitlements, storekit_config]])
    emit_group(products_group_id, "Products", [app_prod_id, widget_prod_id, test_prod_id])
    w("/* End PBXGroup section */")
    w("")

    # PBXNativeTarget
    w("/* Begin PBXNativeTarget section */")
    w(f"\t\t{app_target_id} /* PureScan */ = {{")
    w("\t\t\tisa = PBXNativeTarget;")
    w(f"\t\t\tbuildConfigurationList = {app_cfg_list};")
    w("\t\t\tbuildPhases = (")
    w(f"\t\t\t\t{app_sources_phase} /* Sources */,")
    w(f"\t\t\t\t{app_frameworks_phase} /* Frameworks */,")
    w(f"\t\t\t\t{app_resources_phase} /* Resources */,")
    w(f"\t\t\t\t{app_embed_ext_phase} /* Embed Foundation Extensions */,")
    w("\t\t\t);")
    w("\t\t\tbuildRules = ();")
    w("\t\t\tdependencies = (")
    w(f"\t\t\t\t{dep_widget_id} /* PBXTargetDependency */,")
    w("\t\t\t);")
    w("\t\t\tname = PureScan;")
    w("\t\t\tproductName = PureScan;")
    w(f"\t\t\tproductReference = {app_prod_id};")
    w('\t\t\tproductType = "com.apple.product-type.application";')
    w("\t\t};")

    w(f"\t\t{widget_target_id} /* PureScanWidgets */ = {{")
    w("\t\t\tisa = PBXNativeTarget;")
    w(f"\t\t\tbuildConfigurationList = {widget_cfg_list};")
    w("\t\t\tbuildPhases = (")
    w(f"\t\t\t\t{widget_sources_phase} /* Sources */,")
    w(f"\t\t\t\t{widget_frameworks_phase} /* Frameworks */,")
    w(f"\t\t\t\t{widget_resources_phase} /* Resources */,")
    w("\t\t\t);")
    w("\t\t\tbuildRules = ();")
    w("\t\t\tdependencies = ();")
    w("\t\t\tname = PureScanWidgets;")
    w("\t\t\tproductName = PureScanWidgets;")
    w(f"\t\t\tproductReference = {widget_prod_id};")
    w('\t\t\tproductType = "com.apple.product-type.app-extension";')
    w("\t\t};")

    w(f"\t\t{test_target_id} /* PureScanTests */ = {{")
    w("\t\t\tisa = PBXNativeTarget;")
    w(f"\t\t\tbuildConfigurationList = {test_cfg_list};")
    w("\t\t\tbuildPhases = (")
    w(f"\t\t\t\t{test_sources_phase} /* Sources */,")
    w(f"\t\t\t\t{test_frameworks_phase} /* Frameworks */,")
    w(f"\t\t\t\t{test_resources_phase} /* Resources */,")
    w("\t\t\t);")
    w("\t\t\tbuildRules = ();")
    w("\t\t\tdependencies = (")
    w(f"\t\t\t\t{dep_test_app_id} /* PBXTargetDependency */,")
    w("\t\t\t);")
    w("\t\t\tname = PureScanTests;")
    w("\t\t\tproductName = PureScanTests;")
    w(f"\t\t\tproductReference = {test_prod_id};")
    w('\t\t\tproductType = "com.apple.product-type.bundle.unit-test";')
    w("\t\t};")
    w("/* End PBXNativeTarget section */")
    w("")

    # PBXProject
    w("/* Begin PBXProject section */")
    w(f"\t\t{project_id} /* Project object */ = {{")
    w("\t\t\tisa = PBXProject;")
    w("\t\t\tattributes = {")
    w("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    w("\t\t\t\tLastSwiftUpdateCheck = 2720;")
    w("\t\t\t\tLastUpgradeCheck = 2720;")
    w("\t\t\t\tTargetAttributes = {")
    w(f"\t\t\t\t\t{app_target_id} = {{ DevelopmentTeam = KU364788TC; ProvisioningStyle = Automatic; }};")
    w(f"\t\t\t\t\t{widget_target_id} = {{ DevelopmentTeam = KU364788TC; ProvisioningStyle = Automatic; }};")
    w(f"\t\t\t\t\t{test_target_id} = {{ DevelopmentTeam = KU364788TC; TestTargetID = {app_target_id}; }};")
    w("\t\t\t\t};")
    w("\t\t\t};")
    w(f"\t\t\tbuildConfigurationList = {proj_cfg_list};")
    w('\t\t\tcompatibilityVersion = "Xcode 14.0";')
    w('\t\t\tdevelopmentRegion = "zh-Hans";')
    w("\t\t\thasScannedForEncodings = 0;")
    w('\t\t\tknownRegions = (en, "zh-Hans", Base);')
    w(f"\t\t\tmainGroup = {main_group_id};")
    w(f"\t\t\tproductRefGroup = {products_group_id};")
    w('\t\t\tprojectDirPath = "";')
    w('\t\t\tprojectRoot = "";')
    w("\t\t\ttargets = (")
    w(f"\t\t\t\t{app_target_id} /* PureScan */,")
    w(f"\t\t\t\t{widget_target_id} /* PureScanWidgets */,")
    w(f"\t\t\t\t{test_target_id} /* PureScanTests */,")
    w("\t\t\t);")
    w("\t\t};")
    w("/* End PBXProject section */")
    w("")

    # PBXResourcesBuildPhase
    w("/* Begin PBXResourcesBuildPhase section */")
    for pid, keys in [
        (app_resources_phase, ["app_res::Assets.xcassets", "app_res::PrivacyInfo.xcprivacy", "app_res::InfoPlist.strings"]),
        (widget_resources_phase, ["widget_res::PrivacyInfo.xcprivacy"]),
        (test_resources_phase, ["test_res::PureScan.storekit"]),
    ]:
        w(f"\t\t{pid} = {{")
        w("\t\t\tisa = PBXResourcesBuildPhase;")
        w("\t\t\tbuildActionMask = 2147483647;")
        w("\t\t\tfiles = (")
        for k in keys:
            w(f"\t\t\t\t{build_files[k][0]} /* {k} */,")
        w("\t\t\t);")
        w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
        w("\t\t};")
    w("/* End PBXResourcesBuildPhase section */")
    w("")

    # PBXSourcesBuildPhase
    w("/* Begin PBXSourcesBuildPhase section */")
    for pid, prefix, items in [
        (app_sources_phase, "app_src", app_sources),
        (widget_sources_phase, "widget_src", widget_sources),
        (test_sources_phase, "test_src", test_sources),
    ]:
        w(f"\t\t{pid} = {{")
        w("\t\t\tisa = PBXSourcesBuildPhase;")
        w("\t\t\tbuildActionMask = 2147483647;")
        w("\t\t\tfiles = (")
        for s in items:
            w(f"\t\t\t\t{build_files[f'{prefix}::{s}'][0]} /* {s} */,")
        w("\t\t\t);")
        w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
        w("\t\t};")
    w("/* End PBXSourcesBuildPhase section */")
    w("")

    # PBXTargetDependency
    w("/* Begin PBXTargetDependency section */")
    w(f"\t\t{dep_widget_id} = {{isa = PBXTargetDependency; target = {widget_target_id}; targetProxy = {dep_widget_proxy}; }};")
    w(f"\t\t{dep_test_app_id} = {{isa = PBXTargetDependency; target = {app_target_id}; targetProxy = {dep_app_proxy}; }};")
    w("/* End PBXTargetDependency section */")
    w("")

    # PBXVariantGroup
    w("/* Begin PBXVariantGroup section */")
    w(f"\t\t{strings_vg_id} /* InfoPlist.strings */ = {{")
    w("\t\t\tisa = PBXVariantGroup;")
    w("\t\t\tchildren = (")
    w(f"\t\t\t\t{zh_strings_fid} /* zh-Hans */,")
    w(f"\t\t\t\t{en_strings_fid} /* en */,")
    w("\t\t\t);")
    w("\t\t\tname = InfoPlist.strings;")
    w('\t\t\tsourceTree = "<group>";')
    w("\t\t};")
    w("/* End PBXVariantGroup section */")
    w("")

    # XCBuildConfiguration
    w("/* Begin XCBuildConfiguration section */")
    common_proj = [
        "ALWAYS_SEARCH_USER_PATHS = NO",
        "CLANG_ENABLE_MODULES = YES",
        "CLANG_ENABLE_OBJC_ARC = YES",
        "CODE_SIGN_STYLE = Automatic",
        "DEVELOPMENT_TEAM = KU364788TC",
        "ENABLE_USER_SCRIPT_SANDBOXING = YES",
        "IPHONEOS_DEPLOYMENT_TARGET = 18.0",
        "MARKETING_VERSION = 1.0.0",
        "CURRENT_PROJECT_VERSION = 1",
        "SDKROOT = iphoneos",
        'SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"',
        "SWIFT_VERSION = 5.0",
        'TARGETED_DEVICE_FAMILY = "1,2"',
    ]

    def emit_cfg(cid: str, name: str, settings: list[str]) -> None:
        w(f"\t\t{cid} /* {name} */ = {{")
        w("\t\t\tisa = XCBuildConfiguration;")
        w("\t\t\tbuildSettings = {")
        for line in settings:
            w(f"\t\t\t\t{line};")
        w("\t\t\t};")
        w(f"\t\t\tname = {name};")
        w("\t\t};")

    emit_cfg(proj_debug_cfg, "Debug", common_proj + [
        "DEBUG_INFORMATION_FORMAT = dwarf",
        "ENABLE_TESTABILITY = YES",
        "GCC_OPTIMIZATION_LEVEL = 0",
        "ONLY_ACTIVE_ARCH = YES",
        'SWIFT_OPTIMIZATION_LEVEL = "-Onone"',
        'SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG"',
    ])
    emit_cfg(proj_release_cfg, "Release", common_proj + [
        'DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"',
        "ENABLE_NS_ASSERTIONS = NO",
        'SWIFT_OPTIMIZATION_LEVEL = "-O"',
        "VALIDATE_PRODUCT = YES",
    ])

    app_common = [
        "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor",
        'CODE_SIGN_ENTITLEMENTS = "Config/PureScan.entitlements"',
        "GENERATE_INFOPLIST_FILE = NO",
        'INFOPLIST_FILE = "Config/Info.plist"',
        'LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks"',
        "PRODUCT_BUNDLE_IDENTIFIER = com.yanghe.purescan",
        "PRODUCT_NAME = PureScan",
        "SWIFT_EMIT_LOC_STRINGS = YES",
    ]
    emit_cfg(app_debug_cfg, "Debug", app_common + ['CODE_SIGN_IDENTITY = "Apple Development"'])
    emit_cfg(app_release_cfg, "Release", app_common + [
        "CODE_SIGN_STYLE = Manual",
        'CODE_SIGN_IDENTITY = "Apple Distribution"',
        'PROVISIONING_PROFILE_SPECIFIER = "PureScan AppStore Dist"',
    ])

    widget_common = [
        "APPLICATION_EXTENSION_API_ONLY = YES",
        'CODE_SIGN_ENTITLEMENTS = "Config/PureScanWidgets.entitlements"',
        "GENERATE_INFOPLIST_FILE = NO",
        'INFOPLIST_FILE = "Config/Widget-Info.plist"',
        'LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks"',
        "PRODUCT_BUNDLE_IDENTIFIER = com.yanghe.purescan.widgets",
        'PRODUCT_NAME = "$(TARGET_NAME)"',
        "SKIP_INSTALL = YES",
        "SWIFT_EMIT_LOC_STRINGS = YES",
    ]
    emit_cfg(widget_debug_cfg, "Debug", widget_common + ['CODE_SIGN_IDENTITY = "Apple Development"'])
    emit_cfg(widget_release_cfg, "Release", widget_common + [
        "CODE_SIGN_STYLE = Manual",
        'CODE_SIGN_IDENTITY = "Apple Distribution"',
        'PROVISIONING_PROFILE_SPECIFIER = "PureScan Widgets AppStore Dist"',
    ])

    test_common = [
        'BUNDLE_LOADER = "$(TEST_HOST)"',
        "GENERATE_INFOPLIST_FILE = YES",
        'LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks @loader_path/Frameworks"',
        "PRODUCT_BUNDLE_IDENTIFIER = com.yanghe.purescan.tests",
        'PRODUCT_NAME = "$(TARGET_NAME)"',
        'TEST_HOST = "$(BUILT_PRODUCTS_DIR)/PureScan.app/PureScan"',
    ]
    emit_cfg(test_debug_cfg, "Debug", test_common)
    emit_cfg(test_release_cfg, "Release", test_common)
    w("/* End XCBuildConfiguration section */")
    w("")

    # XCConfigurationList
    w("/* Begin XCConfigurationList section */")
    for list_id, label, d_id, r_id in [
        (proj_cfg_list, "PBXProject PureScan", proj_debug_cfg, proj_release_cfg),
        (app_cfg_list, "PBXNativeTarget PureScan", app_debug_cfg, app_release_cfg),
        (widget_cfg_list, "PBXNativeTarget PureScanWidgets", widget_debug_cfg, widget_release_cfg),
        (test_cfg_list, "PBXNativeTarget PureScanTests", test_debug_cfg, test_release_cfg),
    ]:
        w(f"\t\t{list_id} /* Build configuration list for {label} */ = {{")
        w("\t\t\tisa = XCConfigurationList;")
        w("\t\t\tbuildConfigurations = (")
        w(f"\t\t\t\t{d_id} /* Debug */,")
        w(f"\t\t\t\t{r_id} /* Release */,")
        w("\t\t\t);")
        w("\t\t\tdefaultConfigurationIsVisible = 0;")
        w("\t\t\tdefaultConfigurationName = Release;")
        w("\t\t};")
    w("/* End XCConfigurationList section */")
    w("\t};")
    w(f"\trootObject = {project_id} /* Project object */;")
    w("}")

    (PROJ_DIR / "project.pbxproj").write_text("\n".join(lines) + "\n", encoding="utf-8")

    schemes_dir = PROJ_DIR / "xcshareddata" / "xcschemes"
    schemes_dir.mkdir(parents=True, exist_ok=True)
    scheme_xml = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "2720"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{app_target_id}"
               BuildableName = "PureScan.app"
               BlueprintName = "PureScan"
               ReferencedContainer = "container:PureScan.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{widget_target_id}"
               BuildableName = "PureScanWidgets.appex"
               BlueprintName = "PureScanWidgets"
               ReferencedContainer = "container:PureScan.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{test_target_id}"
               BuildableName = "PureScanTests.xctest"
               BlueprintName = "PureScanTests"
               ReferencedContainer = "container:PureScan.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{app_target_id}"
            BuildableName = "PureScan.app"
            BlueprintName = "PureScan"
            ReferencedContainer = "container:PureScan.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
      <StoreKitConfigurationFileReference
         identifier = "../../Config/PureScan.storekit">
      </StoreKitConfigurationFileReference>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{app_target_id}"
            BuildableName = "PureScan.app"
            BlueprintName = "PureScan"
            ReferencedContainer = "container:PureScan.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug" />
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES" />
</Scheme>
"""
    (schemes_dir / "PureScan.xcscheme").write_text(scheme_xml, encoding="utf-8")
    print(f"Generated {PROJ_DIR} ({len(app_sources)} app files, {len(widget_sources)} widget files, {len(test_sources)} test files)")


if __name__ == "__main__":
    main()
