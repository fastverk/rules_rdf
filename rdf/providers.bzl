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
        "files_to_run": "FilesToRunProvider: pass in an action's " +
                        "`tools=` so Bazel materializes the plugin's " +
                        "runfiles tree (java_binary / py_binary plugins " +
                        "fail to locate runfiles otherwise).",
    },
)

RdfValidatorToolchainInfo = provider(
    doc = "An RDF validator (SHACL today; ShEx in scope for v0.2). " +
          "Resolved by `rdf_validate_test`.",
    fields = {
        "binary": "File: an executable that validates an RDF " +
                  "dataset against a shapes graph per the contract.",
        "runfiles": "runfiles: the plugin binary's runfiles bundle.",
        "files_to_run": "FilesToRunProvider: pass in an action's " +
                        "`tools=` to materialize the plugin's runfiles tree.",
    },
)

RdfSerializerToolchainInfo = provider(
    doc = "An RDF format converter. Resolved by `rdf_transform`.",
    fields = {
        "binary": "File: an executable that converts between RDF " +
                  "serializations (Turtle / N-Triples / N-Quads / " +
                  "JSON-LD / RDF/XML / TriG).",
        "runfiles": "runfiles: the plugin binary's runfiles bundle.",
        "files_to_run": "FilesToRunProvider: pass in an action's " +
                        "`tools=` to materialize the plugin's runfiles tree.",
    },
)

RdfReasonerToolchainInfo = provider(
    doc = "An RDF inference engine. Resolved by `rdf_reason`.",
    fields = {
        "binary": "File: an executable that runs RDFS / OWL / " +
                  "custom-rule inference and emits derived triples.",
        "runfiles": "runfiles: the plugin binary's runfiles bundle.",
        "files_to_run": "FilesToRunProvider: pass in an action's " +
                        "`tools=` to materialize the plugin's runfiles tree.",
    },
)

RdfDatasetInfo = provider(
    doc = "A declared RDF dataset.",
    fields = {
        "files": "depset[File]: this dataset's own source files " +
                 "(excludes `deps`).",
        "transitive_files": "depset[File]: the full graph closure — " +
                            "this dataset's files plus the transitive " +
                            "closure of every `deps` dataset. Consumers " +
                            "needing all linked triples (sparql_query, " +
                            "rdf_reason, rdf_validate) operate over this; " +
                            "the subclass/import closure of a grounding " +
                            "ontology (schema.org + SKOS + DC + modules) " +
                            "is assembled here.",
        "in_format": "str: serialization of the dataset files. " +
                     "One of turtle, ntriples, nquads, trig, " +
                     "jsonld, rdfxml. The whole closure must share " +
                     "this format (normalize a differing dep with " +
                     "rdf_transform first).",
    },
)
