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
#
# `rdfthrift` and `rdfprotobuf` are Apache Jena's binary RDF
# serializations — significantly smaller and faster to parse than
# Turtle / N-Triples for large datasets. They make sense as
# `rdf_transform` outputs (cached intermediate forms) and as
# inputs where the producer is itself a Jena tool. Plugins that
# don't support them must reject them with a clear error per the
# contract's "rejects unknown flags" discipline.
RDF_FORMATS = [
    "turtle",
    "ntriples",
    "nquads",
    "trig",
    "jsonld",
    "rdfxml",
    "rdfthrift",
    "rdfprotobuf",
]

def _rdf_dataset_impl(ctx):
    own = depset(ctx.files.srcs)
    # Transitive closure: own files + every dep's closure. Models a
    # grounding ontology's linked vocabularies / module graph (e.g.
    # schema.org core → pending/auto/bib modules → SKOS, DC). Consumers
    # that reason or query over all linked triples use `transitive_files`.
    dep_closures = [d[RdfDatasetInfo].transitive_files for d in ctx.attr.deps]
    transitive = depset(ctx.files.srcs, transitive = dep_closures)
    return [
        DefaultInfo(files = transitive),
        RdfDatasetInfo(
            files = own,
            transitive_files = transitive,
            in_format = ctx.attr.in_format,
        ),
    ]

rdf_dataset = rule(
    implementation = _rdf_dataset_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [
                ".ttl", ".nt", ".nq", ".trig", ".jsonld",
                ".rdf", ".xml",
                ".rt",  # Apache Jena RDF Thrift binary
                ".rpb", ".bin",  # Apache Jena RDF Protobuf binary
            ],
            mandatory = True,
            doc = "RDF source files. Concatenated in lexicographic " +
                  "order by consuming rules before being piped to the " +
                  "plugin's stdin.",
        ),
        "deps": attr.label_list(
            providers = [RdfDatasetInfo],
            doc = "Other `rdf_dataset`s this graph links to (imported " +
                  "ontologies, vocabulary modules). Their files are folded " +
                  "into this dataset's `transitive_files` closure, so " +
                  "reasoning/query over the linked vocabularies resolves. " +
                  "Deps should share `in_format` (normalize otherwise).",
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
    doc = "A labeled collection of RDF source files + linked-graph deps.",
)
