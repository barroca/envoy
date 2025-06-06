load("@bazel_skylib//lib:selects.bzl", "selects")
load("@envoy_api//bazel:api_build_system.bzl", "api_cc_py_proto_library")
load(
    "@envoy_build_config//:extensions_build_config.bzl",
    "CONTRIB_EXTENSION_PACKAGE_VISIBILITY",
    "EXTENSION_CONFIG_VISIBILITY",
)

# DO NOT LOAD THIS FILE. Load envoy_build_system.bzl instead.
# Envoy library targets
load(
    ":envoy_internal.bzl",
    "envoy_copts",
    "envoy_external_dep_path",
    "envoy_linkstatic",
    "repo_label",
)
load(":envoy_mobile_defines.bzl", "envoy_mobile_defines")
load(":envoy_pch.bzl", "envoy_pch_copts", "envoy_pch_deps")
load(":sanitizers.bzl", "sanitizer_deps")

# As above, but wrapped in list form for adding to dep lists. This smell seems needed as
# SelectorValue values have to match the attribute type. See
# https://github.com/bazelbuild/bazel/issues/2273.
def tcmalloc_external_deps(repository):
    _repo = repo_label(repository)
    return selects.with_or({
        _repo("//bazel:disable_tcmalloc"): [],
        (
            _repo("//bazel:debug_tcmalloc"),
            _repo("//bazel:gperftools_tcmalloc"),
        ): [_repo("//bazel/foreign_cc:gperftools")],
        "//conditions:default": [_repo("//bazel:tcmalloc_all_libs")],
    })

# Envoy C++ library targets that need no transformations or additional dependencies before being
# passed to cc_library should be specified with this function. Note: this exists to ensure that
# all envoy targets pass through an envoy-declared Starlark function where they can be modified
# before being passed to a native bazel function.
def envoy_basic_cc_library(name, deps = [], external_deps = [], **kargs):
    native.cc_library(
        name = name,
        deps = deps + [envoy_external_dep_path(dep) for dep in external_deps],
        **kargs
    )

def envoy_cc_extension(
        name,
        tags = [],
        extra_visibility = [],
        visibility = EXTENSION_CONFIG_VISIBILITY,
        alwayslink = 1,
        **kwargs):
    if "//visibility:public" not in visibility:
        visibility = visibility + extra_visibility

    ext_name = name + "_envoy_extension"
    envoy_cc_library(
        name = name,
        tags = tags,
        visibility = visibility,
        alwayslink = alwayslink,
        **kwargs
    )
    native.cc_library(
        name = ext_name,
        tags = tags,
        deps = select({
            ":is_enabled": [":" + name],
            "//conditions:default": [],
        }),
        visibility = visibility,
    )

def envoy_cc_contrib_extension(
        name,
        tags = [],
        extra_visibility = [],
        visibility = CONTRIB_EXTENSION_PACKAGE_VISIBILITY,
        alwayslink = 1,
        **kwargs):
    envoy_cc_extension(name, tags, extra_visibility, visibility, **kwargs)

# Envoy C++ library targets should be specified with this function.
def envoy_cc_library(
        name,
        srcs = [],
        hdrs = [],
        copts = [],
        visibility = None,
        rbe_pool = None,
        exec_properties = {},
        external_deps = [],
        tcmalloc_dep = None,
        repository = "",
        tags = [],
        deps = [],
        strip_include_prefix = None,
        include_prefix = None,
        textual_hdrs = None,
        alwayslink = None,
        defines = [],
        local_defines = [],
        linkopts = []):
    if tcmalloc_dep:
        deps += tcmalloc_external_deps(repository)
    exec_properties = exec_properties | select({
        repository + "//bazel:engflow_rbe_x86_64": {"Pool": rbe_pool} if rbe_pool else {},
        "//conditions:default": {},
    })

    # If alwayslink is not specified, allow turning it off via --define=library_autolink=disabled
    # alwayslink is defaulted on for envoy_cc_extensions to ensure the REGISTRY macros work.
    if alwayslink == None:
        alwayslink = select({
            repository + "//bazel:disable_library_autolink": 0,
            "//conditions:default": 1,
        })

    native.cc_library(
        name = name,
        srcs = srcs,
        hdrs = hdrs,
        copts = envoy_copts(repository) + envoy_pch_copts(repository, "//source/common/common:common_pch") + copts,
        linkopts = linkopts,
        visibility = visibility,
        tags = tags,
        textual_hdrs = textual_hdrs,
        deps = deps + [envoy_external_dep_path(dep) for dep in external_deps] +
               envoy_pch_deps(repository, "//source/common/common:common_pch") +
               sanitizer_deps(),
        exec_properties = exec_properties,
        alwayslink = alwayslink,
        linkstatic = envoy_linkstatic(),
        strip_include_prefix = strip_include_prefix,
        include_prefix = include_prefix,
        defines = envoy_mobile_defines(repository) + defines,
        local_defines = local_defines,
    )

    # Intended for usage by external consumers. This allows them to disambiguate
    # include paths via `external/envoy...`
    native.cc_library(
        name = name + "_with_external_headers",
        hdrs = hdrs,
        copts = envoy_copts(repository) + copts,
        visibility = visibility,
        tags = ["nocompdb"] + tags,
        deps = [":" + name],
        strip_include_prefix = strip_include_prefix,
        include_prefix = include_prefix,
    )

# Used to specify a library that only builds on POSIX
def envoy_cc_posix_library(name, srcs = [], hdrs = [], **kargs):
    envoy_cc_library(
        name = name + "_posix",
        srcs = select({
            "@envoy//bazel:windows_x86_64": [],
            "//conditions:default": srcs,
        }),
        hdrs = select({
            "@envoy//bazel:windows_x86_64": [],
            "//conditions:default": hdrs,
        }),
        **kargs
    )

# Used to specify a library that only builds on POSIX excluding Linux
def envoy_cc_posix_without_linux_library(name, srcs = [], hdrs = [], **kargs):
    envoy_cc_library(
        name = name + "_posix",
        srcs = select({
            "@envoy//bazel:windows_x86_64": [],
            "@envoy//bazel:linux": [],
            "//conditions:default": srcs,
        }),
        hdrs = select({
            "@envoy//bazel:windows_x86_64": [],
            "@envoy//bazel:linux": [],
            "//conditions:default": hdrs,
        }),
        **kargs
    )

# Used to specify a library that only builds on Linux
def envoy_cc_linux_library(name, srcs = [], hdrs = [], **kargs):
    envoy_cc_library(
        name = name + "_linux",
        srcs = select({
            "@envoy//bazel:linux": srcs,
            "//conditions:default": [],
        }),
        hdrs = select({
            "@envoy//bazel:linux": hdrs,
            "//conditions:default": [],
        }),
        **kargs
    )

# Used to specify a library that only builds on Windows
def envoy_cc_win32_library(name, srcs = [], hdrs = [], **kargs):
    envoy_cc_library(
        name = name + "_win32",
        srcs = select({
            "@envoy//bazel:windows_x86_64": srcs,
            "//conditions:default": [],
        }),
        hdrs = select({
            "@envoy//bazel:windows_x86_64": hdrs,
            "//conditions:default": [],
        }),
        **kargs
    )

# Envoy proto targets should be specified with this function.
def envoy_proto_library(name, visibility = ["//visibility:public"], **kwargs):
    api_cc_py_proto_library(
        name,
        # Avoid generating .so, we don't need it, can interfere with builds
        # such as OSS-Fuzz.
        linkstatic = 1,
        visibility = visibility,
        **kwargs
    )
