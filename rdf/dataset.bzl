"""`rdf_dataset(name, srcs, in_format)` — declare a labeled
collection of RDF files.

This is the single source of "what triples are in this graph?"
that every other rule consumes. Carrying both the file depset and
the format string up-front lets sparql_query_test / rdf_validate_test /
… avoid sniffing extensions at action time and lets consumers
mix datasets with declared formats in one BUILD target without
ambiguity.

Multi-file datasets are concatenated by the consuming rule in
**lexicographic order** before being piped to the plugin's stdin
(see `rdf/plugin_contract.md`). Consumers that care about ordering
should name files to sort accordingly.
"""

load(":providers.bzl", "RdfDatasetInfo")

# Vocabulary lives here so the rules + the plugin contract stay
# in sync; if you add a format, add it everywhere.
RDF_FORMATS = [
    "turtle",
    "ntriples",
    "nquads",
    "trig",
    "jsonld",
    "rdfxml",
]

def _rdf_dataset_impl(ctx):
    return [
        DefaultInfo(files = depset(ctx.files.srcs)),
        RdfDatasetInfo(
            files = depset(ctx.files.srcs),
            in_format = ctx.attr.in_format,
        ),
    ]

rdf_dataset = rule(
    implementation = _rdf_dataset_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".ttl", ".nt", ".nq", ".trig", ".jsonld", ".rdf", ".xml"],
            mandatory = True,
            doc = "RDF source files. Concatenated in lexicographic " +
                  "order by consuming rules before being piped to the " +
                  "plugin's stdin.",
        ),
        "in_format": attr.string(
            default = "turtle",
            values = RDF_FORMATS,
            doc = "Serialization of every file in `srcs`. " +
                  "Mixed-format datasets aren't supported in v0.1 — " +
                  "use rdf_transform first.",
        ),
    },
    provides = [RdfDatasetInfo],
    doc = "A labeled collection of RDF source files.",
)
