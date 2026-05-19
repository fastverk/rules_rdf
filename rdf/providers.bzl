"""Providers for the four rules_rdf toolchain types.

Each provider wraps both the executable and the runfiles needed
to invoke it. Carrying runfiles in the provider matters for
plugin implementations that aren't a single self-contained binary
— py_binary, java_binary, sh_binary all stage helper files via
runfiles. Consuming rules merge the provider's `runfiles` into
their own to make the plugin actually executable inside a Bazel
sandbox.
"""

SparqlEngineToolchainInfo = provider(
    doc = "A SPARQL query engine. Resolved by `sparql_query_test` " +
          "and `sparql_query_run`.",
    fields = {
        "binary": "File: an executable that runs SPARQL queries " +
                  "per the rules_rdf plugin contract.",
        "runfiles": "runfiles: the plugin binary's runfiles bundle.",
    },
)

RdfValidatorToolchainInfo = provider(
    doc = "An RDF validator (SHACL today; ShEx in scope for v0.2). " +
          "Resolved by `rdf_validate_test`.",
    fields = {
        "binary": "File: an executable that validates an RDF " +
                  "dataset against a shapes graph per the contract.",
        "runfiles": "runfiles: the plugin binary's runfiles bundle.",
    },
)

RdfSerializerToolchainInfo = provider(
    doc = "An RDF format converter. Resolved by `rdf_transform`.",
    fields = {
        "binary": "File: an executable that converts between RDF " +
                  "serializations (Turtle / N-Triples / N-Quads / " +
                  "JSON-LD / RDF/XML / TriG).",
        "runfiles": "runfiles: the plugin binary's runfiles bundle.",
    },
)

RdfReasonerToolchainInfo = provider(
    doc = "An RDF inference engine. Resolved by `rdf_reason`.",
    fields = {
        "binary": "File: an executable that runs RDFS / OWL / " +
                  "custom-rule inference and emits derived triples.",
        "runfiles": "runfiles: the plugin binary's runfiles bundle.",
    },
)

RdfDatasetInfo = provider(
    doc = "A declared RDF dataset.",
    fields = {
        "files": "depset[File]: source files in the dataset.",
        "in_format": "str: serialization of the dataset files. " +
                     "One of turtle, ntriples, nquads, trig, " +
                     "jsonld, rdfxml.",
    },
)
