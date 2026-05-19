"""`rdf_plugin_contract_test(name, plugin, toolchain_type)` runs
the rules_rdf conformance test driver against any executable
claiming to implement the plugin contract for the named toolchain
type. See [`plugin_contract.md`](plugin_contract.md) for what the
driver asserts.

Plugin authors gate toolchain registration on it:

```python
load("@rules_rdf//rdf:contract_test.bzl", "rdf_plugin_contract_test")

rdf_plugin_contract_test(
    name = "jena_sparql_conforms",
    plugin = "//jena:jena_sparql",
    toolchain_type = "sparql_engine",
)
```

The four toolchain types each have their own minimum-valid input
inside the driver; pass the bare name (without the
`_toolchain_type` suffix or `@rules_rdf//rdf:` prefix).
"""

_TOOLCHAIN_TYPES = [
    "sparql_engine",
    "rdf_validator",
    "rdf_serializer",
    "rdf_reasoner",
]

def _impl(ctx):
    runner = ctx.actions.declare_file(ctx.label.name + ".sh")
    plugin_sp = ctx.executable.plugin.short_path
    driver_sp = ctx.executable._driver.short_path

    ctx.actions.write(
        output = runner,
        is_executable = True,
        content = """#!/usr/bin/env bash
set -euo pipefail
RUNFILES_DIR="${{RUNFILES_DIR:-$0.runfiles}}"
WS_NAME="{ws}"

resolve() {{
    local sp="$1"
    if [[ "$sp" == ../* ]]; then
        printf '%s' "$RUNFILES_DIR/${{sp#../}}"
    else
        printf '%s' "$RUNFILES_DIR/$WS_NAME/$sp"
    fi
}}

DRIVER="$(resolve "{driver_sp}")"
PLUGIN="$(resolve "{plugin_sp}")"

exec "$DRIVER" \\
    --plugin="$PLUGIN" \\
    --toolchain-type="{toolchain_type}"
""".format(
            ws = ctx.workspace_name,
            driver_sp = driver_sp,
            plugin_sp = plugin_sp,
            toolchain_type = ctx.attr.toolchain_type,
        ),
    )

    runfiles = ctx.runfiles(files = [
        ctx.executable._driver,
        ctx.executable.plugin,
    ])
    # Merge both transitive runfile bundles. py_binary plugins +
    # the py_binary driver both stage stage2 bootstrap files that
    # only resolve when their full default_runfiles is in scope.
    runfiles = runfiles.merge(ctx.attr._driver[DefaultInfo].default_runfiles)
    runfiles = runfiles.merge(ctx.attr.plugin[DefaultInfo].default_runfiles)
    return [DefaultInfo(executable = runner, runfiles = runfiles)]

rdf_plugin_contract_test = rule(
    implementation = _impl,
    test = True,
    attrs = {
        "plugin": attr.label(
            executable = True,
            cfg = "exec",
            mandatory = True,
            doc = "The plugin binary to test. Any executable that " +
                  "claims to implement the rules_rdf plugin contract.",
        ),
        "toolchain_type": attr.string(
            mandatory = True,
            values = _TOOLCHAIN_TYPES,
            doc = "Which toolchain type's scenarios to run: one of " +
                  ", ".join(_TOOLCHAIN_TYPES) + ".",
        ),
        "_driver": attr.label(
            executable = True,
            cfg = "exec",
            default = "@rules_rdf//tools/contract_test",
        ),
    },
    doc = "Run the rules_rdf conformance test driver against a " +
          "plugin binary. See plugin_contract.md.",
)
