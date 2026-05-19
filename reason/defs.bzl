"""User-facing inference rules.

`rdf_reason` runs the registered `rdf_reasoner` toolchain over an
RDF dataset and emits the derived-triples graph (Turtle) as a
build artifact. Unlike `sparql_query_test` / `rdf_validate_test`,
this is a regular rule — its output is a file that downstream
rules can declare as a `src` or `data` dependency.

```python
load("@rules_rdf//rdf:dataset.bzl", "rdf_dataset")
load("@rules_rdf//reason:defs.bzl", "rdf_reason")

rdf_dataset(name = "ontology", srcs = glob(["*.ttl"]))

rdf_reason(
    name = "inferred",
    base = ":ontology",
    profile = "rdfs",
)
```

For custom rule sets (Jena RETE rules):

```python
rdf_reason(
    name = "inferred",
    base = ":ontology",
    profile = "custom",
    rules = "rules/transitive.rule",
)
```

The reasoner toolchain implementation decides which profiles are
supported; the abstract layer only validates that `profile =
"custom"` is paired with `rules` and vice versa.
"""

load("//rdf:providers.bzl", "RdfDatasetInfo")

_REASONER = "@rules_rdf//rdf:rdf_reasoner_toolchain_type"

_BUILTIN_PROFILES = ["rdfs", "owl-rl", "owl-mini", "owl-micro"]
_ALL_PROFILES = _BUILTIN_PROFILES + ["custom"]

def _rdf_reason_impl(ctx):
    if ctx.attr.profile == "custom" and ctx.file.rules == None:
        fail("rdf_reason: profile = 'custom' requires `rules`.")
    if ctx.attr.profile != "custom" and ctx.file.rules != None:
        fail(
            "rdf_reason: `rules` is only meaningful with " +
            "profile = 'custom' (got profile = '{}').".format(ctx.attr.profile),
        )

    reasoner_info = ctx.toolchains[_REASONER].rdf_reasoner_info
    reasoner = reasoner_info.binary
    dataset_info = ctx.attr.base[RdfDatasetInfo]
    dataset_files = sorted(
        dataset_info.files.to_list(),
        key = lambda f: f.short_path,
    )

    # Concatenate base graph files in lexicographic order, then pipe
    # to the reasoner.
    out = ctx.actions.declare_file(ctx.label.name + ".inferred.ttl")
    inputs = list(dataset_files)
    rules_flag = ""
    if ctx.file.rules != None:
        rules_flag = "--rules={} ".format(ctx.file.rules.path)
        inputs.append(ctx.file.rules)

    include_base_flag = "--include-base " if ctx.attr.include_base else ""

    cmd = (
        "cat {datasets} | \"{reasoner}\" " +
        "--rule-name=\"{rule_name}\" " +
        "--in-format=\"{in_format}\" " +
        "--profile=\"{profile}\" " +
        "{rules_flag}{include_base_flag}" +
        "> \"{out}\""
    ).format(
        datasets = " ".join([f.path for f in dataset_files]),
        reasoner = reasoner.path,
        rule_name = ctx.label.name,
        in_format = dataset_info.in_format,
        profile = ctx.attr.profile,
        rules_flag = rules_flag,
        include_base_flag = include_base_flag,
        out = out.path,
    )

    ctx.actions.run_shell(
        outputs = [out],
        inputs = depset(inputs),
        tools = depset(transitive = [
            depset([reasoner]),
            reasoner_info.runfiles.files,
        ]),
        command = cmd,
        mnemonic = "RdfReason",
        progress_message = "rdf_reason %s (profile=%s)" % (ctx.label, ctx.attr.profile),
    )

    # Emit a fresh RdfDatasetInfo over the derived-triples file so
    # downstream rules can chain (reason → validate → query).
    return [
        DefaultInfo(files = depset([out])),
        RdfDatasetInfo(
            files = depset([out]),
            in_format = "turtle",
        ),
    ]

rdf_reason = rule(
    implementation = _rdf_reason_impl,
    attrs = {
        "base": attr.label(
            providers = [RdfDatasetInfo],
            mandatory = True,
            doc = "RDF dataset to run inference over.",
        ),
        "profile": attr.string(
            default = "rdfs",
            values = _ALL_PROFILES,
            doc = "Reasoning profile. `custom` requires `rules`.",
        ),
        "rules": attr.label(
            allow_single_file = [".rule", ".txt"],
            doc = "Custom rule file (Jena RETE syntax). Required iff " +
                  "profile = 'custom'.",
        ),
        "include_base": attr.bool(
            default = False,
            doc = "If True, emit base + derived triples; otherwise " +
                  "only the derived (default).",
        ),
    },
    toolchains = [_REASONER],
    provides = [RdfDatasetInfo],
    doc = "Run inference over an RDF dataset; emit the " +
          "derived-triples graph (Turtle).",
)
