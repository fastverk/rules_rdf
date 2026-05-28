"""User-facing SPARQL rules.

`sparql_query_test` is the zero-row gate idiom: declare an
invariant as a SPARQL query whose result set is empty when the
graph satisfies the invariant. CI runs it as a Bazel test; any
non-empty row triggers a failure.

It's the rules_rdf analog of the production `GateZeroRows.java`
pattern in the Aion RFC repo's `kg/java/`. v0.1 wires the rule
through `sparql_engine_toolchain_type`; the actual SPARQL
execution comes from whichever concrete toolchain the consumer
registered (rules_jena, a future rules_rdflib, etc.).

```python
load("@rules_rdf//rdf:dataset.bzl", "rdf_dataset")
load("@rules_rdf//sparql:defs.bzl", "sparql_query_test")

rdf_dataset(name = "corpus", srcs = glob(["*.ttl"]))

sparql_query_test(
    name = "no_dangling_refs",
    dataset = ":corpus",
    query = "queries/dangling.rq",
)
```
"""

load("//rdf:providers.bzl", "RdfDatasetInfo")
load("//rdf:merge.bzl", "SERIALIZER_TOOLCHAIN", "merged_dataset_input")

_SPARQL_ENGINE = "@rules_rdf//rdf:sparql_engine_toolchain_type"

# SELECT/ASK tabular result formats → just a data file.
_SELECT_OUT = {"tsv": "tsv", "csv": "csv", "json": "json", "xml": "srx"}

# CONSTRUCT/DESCRIBE graph results → also an rdf_dataset (chainable into
# rdf_reason / further sparql_query).
_GRAPH_OUT = {
    "turtle": "ttl",
    "ntriples": "nt",
    "nquads": "nq",
    "trig": "trig",
    "jsonld": "jsonld",
    "rdfxml": "rdf",
}

def _sparql_query_test_impl(ctx):
    engine_info = ctx.toolchains[_SPARQL_ENGINE].sparql_engine_info
    engine = engine_info.binary
    dataset_info = ctx.attr.dataset[RdfDatasetInfo]
    # Query the full linked-graph closure (own files + deps), merged
    # blank-node-safely via the serializer toolchain (not byte-concat).
    concat_input, dataset_runfiles = merged_dataset_input(
        ctx,
        dataset_info,
        ctx.label.name + ".merged.rdf",
    )

    # Generate a runner that pipes the merged dataset into
    # the engine. Test passes iff exit 0 (per --fail-on-nonempty
    # semantics in the contract).
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

ENGINE="$(resolve "{engine_sp}")"
DATASET="$(resolve "{dataset_sp}")"
QUERY="$(resolve "{query_sp}")"

exec "$ENGINE" \\
    --rule-name="{rule_name}" \\
    --in-format="{in_format}" \\
    --query="$QUERY" \\
    --out-format="tsv" \\
    --fail-on-nonempty \\
    < "$DATASET"
""".format(
            ws = ctx.workspace_name,
            engine_sp = engine.short_path,
            dataset_sp = concat_input.short_path,
            query_sp = ctx.file.query.short_path,
            rule_name = ctx.label.name,
            in_format = dataset_info.in_format,
        ),
    )

    # Merge the engine's own runfiles bundle so py_binary /
    # java_binary plugins find their bootstrap files.
    runfiles = ctx.runfiles(files = [engine, ctx.file.query])
    runfiles = runfiles.merge(dataset_runfiles)
    runfiles = runfiles.merge(engine_info.runfiles)
    return [DefaultInfo(executable = runner, runfiles = runfiles)]

sparql_query_test = rule(
    implementation = _sparql_query_test_impl,
    test = True,
    attrs = {
        "dataset": attr.label(
            providers = [RdfDatasetInfo],
            mandatory = True,
            doc = "An `rdf_dataset` whose triples the query runs against.",
        ),
        "query": attr.label(
            allow_single_file = [".rq", ".sparql"],
            mandatory = True,
            doc = "The SPARQL query file. Result set must be empty " +
                  "for the test to pass (per `--fail-on-nonempty`).",
        ),
    },
    toolchains = [_SPARQL_ENGINE, SERIALIZER_TOOLCHAIN],
    doc = "Run a SPARQL query against an RDF dataset; fail if the " +
          "result set is non-empty. The zero-row gate idiom.",
)

def _sparql_query_impl(ctx):
    engine_info = ctx.toolchains[_SPARQL_ENGINE].sparql_engine_info
    engine = engine_info.binary
    dataset_info = ctx.attr.dataset[RdfDatasetInfo]
    # Query the full linked-graph closure (own files + deps).
    dataset_files = sorted(
        dataset_info.transitive_files.to_list(),
        key = lambda f: f.short_path,
    )

    is_graph = ctx.attr.out_format in _GRAPH_OUT
    ext = _GRAPH_OUT[ctx.attr.out_format] if is_graph else _SELECT_OUT[ctx.attr.out_format]
    out = ctx.actions.declare_file(ctx.label.name + "." + ext)

    cmd = (
        "cat {datasets} | \"{engine}\" " +
        "--rule-name=\"{rule_name}\" " +
        "--in-format=\"{in_format}\" " +
        "--query=\"{query}\" " +
        "--out-format=\"{out_format}\" " +
        "> \"{out}\""
    ).format(
        datasets = " ".join([f.path for f in dataset_files]),
        engine = engine.path,
        rule_name = ctx.label.name,
        in_format = dataset_info.in_format,
        query = ctx.file.query.path,
        out_format = ctx.attr.out_format,
        out = out.path,
    )

    ctx.actions.run_shell(
        outputs = [out],
        inputs = depset(dataset_files + [ctx.file.query]),
        tools = [engine_info.files_to_run],
        command = cmd,
        mnemonic = "SparqlQuery",
        progress_message = "sparql_query %s → %s" % (ctx.label, ctx.attr.out_format),
    )

    providers = [DefaultInfo(files = depset([out]))]
    # CONSTRUCT/DESCRIBE results are themselves a graph — expose an
    # rdf_dataset so the result chains into rdf_reason / sparql_query.
    if is_graph:
        providers.append(RdfDatasetInfo(
            files = depset([out]),
            transitive_files = depset([out]),
            in_format = ctx.attr.out_format,
        ))
    return providers

sparql_query = rule(
    implementation = _sparql_query_impl,
    attrs = {
        "dataset": attr.label(
            providers = [RdfDatasetInfo],
            mandatory = True,
            doc = "The `rdf_dataset` (closure) to query.",
        ),
        "query": attr.label(
            allow_single_file = [".rq", ".sparql"],
            mandatory = True,
            doc = "The SPARQL query file (SELECT/ASK → tabular; " +
                  "CONSTRUCT/DESCRIBE → graph).",
        ),
        "out_format": attr.string(
            mandatory = True,
            values = sorted(_SELECT_OUT.keys()) + sorted(_GRAPH_OUT.keys()),
            doc = "Result serialization. Tabular (tsv/csv/json/xml) for " +
                  "SELECT/ASK; RDF (turtle/ntriples/…) for " +
                  "CONSTRUCT/DESCRIBE (also yields an rdf_dataset).",
        ),
    },
    toolchains = [_SPARQL_ENGINE],
    doc = "Run a SPARQL query and emit the results as a build artifact " +
          "(the producer counterpart to sparql_query_test's gate). Turns " +
          "a reasoned graph into queryable, downstream-consumable data " +
          "— e.g. grounding tuples for training-data generation.",
)
