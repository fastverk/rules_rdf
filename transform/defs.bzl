"""User-facing format-conversion rule.

`rdf_transform` re-serializes an RDF dataset into a different
format via the registered `rdf_serializer` toolchain. The output
is a regular build artifact.

```python
load("@rules_rdf//rdf:dataset.bzl", "rdf_dataset")
load("@rules_rdf//transform:defs.bzl", "rdf_transform")

rdf_dataset(name = "src_turtle", srcs = ["data.ttl"], in_format = "turtle")

rdf_transform(
    name = "data_ntriples",
    dataset = ":src_turtle",
    out_format = "ntriples",
)
```

Output filename = `<name>.<ext>` where `<ext>` is the canonical
extension for `out_format` (`.ttl`, `.nt`, `.nq`, `.trig`,
`.jsonld`, `.rdf`).
"""

load("//rdf:providers.bzl", "RdfDatasetInfo")

_SERIALIZER = "@rules_rdf//rdf:rdf_serializer_toolchain_type"

_OUT_EXTENSIONS = {
    "turtle": "ttl",
    "ntriples": "nt",
    "nquads": "nq",
    "trig": "trig",
    "jsonld": "jsonld",
    "rdfxml": "rdf",
    # Apache Jena binary formats — useful as cached intermediate
    # forms (much faster to parse than Turtle for large datasets).
    # The corresponding consumer (e.g. Jena's RIOT) must
    # understand the binary format on the read side too.
    "rdfthrift": "rt",
    "rdfprotobuf": "rpb",
}

def _rdf_transform_impl(ctx):
    serializer_info = ctx.toolchains[_SERIALIZER].rdf_serializer_info
    serializer = serializer_info.binary
    dataset_info = ctx.attr.dataset[RdfDatasetInfo]
    dataset_files = sorted(
        dataset_info.files.to_list(),
        key = lambda f: f.short_path,
    )

    ext = _OUT_EXTENSIONS[ctx.attr.out_format]
    out = ctx.actions.declare_file(ctx.label.name + "." + ext)

    cmd = (
        "cat {datasets} | \"{serializer}\" " +
        "--rule-name=\"{rule_name}\" " +
        "--in-format=\"{in_format}\" " +
        "--out-format=\"{out_format}\" " +
        "> \"{out}\""
    ).format(
        datasets = " ".join([f.path for f in dataset_files]),
        serializer = serializer.path,
        rule_name = ctx.label.name,
        in_format = dataset_info.in_format,
        out_format = ctx.attr.out_format,
        out = out.path,
    )

    ctx.actions.run_shell(
        outputs = [out],
        inputs = depset(dataset_files),
        tools = depset(transitive = [
            depset([serializer]),
            serializer_info.runfiles.files,
        ]),
        command = cmd,
        mnemonic = "RdfTransform",
        progress_message = "rdf_transform %s → %s" % (ctx.label, ctx.attr.out_format),
    )

    return [
        DefaultInfo(files = depset([out])),
        RdfDatasetInfo(
            files = depset([out]),
            in_format = ctx.attr.out_format,
        ),
    ]

rdf_transform = rule(
    implementation = _rdf_transform_impl,
    attrs = {
        "dataset": attr.label(
            providers = [RdfDatasetInfo],
            mandatory = True,
            doc = "RDF dataset to convert.",
        ),
        "out_format": attr.string(
            mandatory = True,
            values = sorted(_OUT_EXTENSIONS.keys()),
            doc = "Target serialization.",
        ),
    },
    toolchains = [_SERIALIZER],
    provides = [RdfDatasetInfo],
    doc = "Convert an RDF dataset between serializations.",
)
