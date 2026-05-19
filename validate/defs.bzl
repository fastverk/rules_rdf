"""User-facing RDF validation rules.

`rdf_validate_test` runs a SHACL shapes graph against an RDF
dataset and fails the build if any violations are reported.
Resolves through `rdf_validator_toolchain_type` so the actual
SHACL engine is pluggable (rules_jena's
`org.apache.jena.shacl.ShaclValidator`, a future
`rules_pyshacl`, …).

```python
load("@rules_rdf//rdf:dataset.bzl", "rdf_dataset")
load("@rules_rdf//validate:defs.bzl", "rdf_validate_test")

rdf_dataset(name = "ontology", srcs = glob(["ontology/*.ttl"]))

rdf_validate_test(
    name = "ontology_conforms",
    dataset = ":ontology",
    shapes = "shapes.ttl",
)
```

ShEx support is in scope for v0.2 (the toolchain contract leaves
room for it via the `--shapes-language` arg, but for v0.1 the
shapes file is assumed Turtle-encoded SHACL).
"""

load("//rdf:providers.bzl", "RdfDatasetInfo")

_VALIDATOR = "@rules_rdf//rdf:rdf_validator_toolchain_type"

def _rdf_validate_test_impl(ctx):
    validator_info = ctx.toolchains[_VALIDATOR].rdf_validator_info
    validator = validator_info.binary
    dataset_info = ctx.attr.dataset[RdfDatasetInfo]
    dataset_files = dataset_info.files.to_list()

    if len(dataset_files) == 1:
        concat_input = dataset_files[0]
    else:
        concat_input = ctx.actions.declare_file(ctx.label.name + ".concat.rdf")
        sorted_files = sorted(dataset_files, key = lambda f: f.short_path)
        ctx.actions.run_shell(
            outputs = [concat_input],
            inputs = sorted_files,
            command = "cat {} > {}".format(
                " ".join([f.path for f in sorted_files]),
                concat_input.path,
            ),
            mnemonic = "RdfConcat",
            progress_message = "concat %d RDF files for %s" % (
                len(sorted_files),
                ctx.label,
            ),
        )

    runner = ctx.actions.declare_file(ctx.label.name + ".sh")
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

VALIDATOR="$(resolve "{validator_sp}")"
DATASET="$(resolve "{dataset_sp}")"
SHAPES="$(resolve "{shapes_sp}")"

# The validator must exit non-zero on `--severity`-or-above
# violations per the contract. Stdout carries the SHACL
# ValidationReport (Turtle) on both success and failure; we
# stream it for debuggability.
exec "$VALIDATOR" \\
    --rule-name="{rule_name}" \\
    --in-format="{in_format}" \\
    --shapes="$SHAPES" \\
    --severity="{severity}" \\
    < "$DATASET"
""".format(
            ws = ctx.workspace_name,
            validator_sp = validator.short_path,
            dataset_sp = concat_input.short_path,
            shapes_sp = ctx.file.shapes.short_path,
            rule_name = ctx.label.name,
            in_format = dataset_info.in_format,
            severity = ctx.attr.severity,
        ),
    )

    runfiles = ctx.runfiles(files = [validator, concat_input, ctx.file.shapes])
    runfiles = runfiles.merge(validator_info.runfiles)
    return [DefaultInfo(executable = runner, runfiles = runfiles)]

rdf_validate_test = rule(
    implementation = _rdf_validate_test_impl,
    test = True,
    attrs = {
        "dataset": attr.label(
            providers = [RdfDatasetInfo],
            mandatory = True,
            doc = "An `rdf_dataset` to validate.",
        ),
        "shapes": attr.label(
            allow_single_file = [".ttl"],
            mandatory = True,
            doc = "SHACL shapes graph (Turtle).",
        ),
        "severity": attr.string(
            default = "violation",
            values = ["violation", "warning", "info"],
            doc = "Minimum severity that fails the build.",
        ),
    },
    toolchains = [_VALIDATOR],
    doc = "Validate an RDF dataset against a SHACL shapes graph.",
)
