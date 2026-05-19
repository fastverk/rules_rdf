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

_SPARQL_ENGINE = "@rules_rdf//rdf:sparql_engine_toolchain_type"

def _sparql_query_test_impl(ctx):
    engine_info = ctx.toolchains[_SPARQL_ENGINE].sparql_engine_info
    engine = engine_info.binary
    dataset_info = ctx.attr.dataset[RdfDatasetInfo]
    dataset_files = dataset_info.files.to_list()

    # Concatenate the dataset files in lexicographic order — the
    # contract specifies it. Single-file datasets skip the cat.
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

    # Generate a runner that pipes the concatenated dataset into
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
    runfiles = ctx.runfiles(files = [engine, concat_input, ctx.file.query])
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
    toolchains = [_SPARQL_ENGINE],
    doc = "Run a SPARQL query against an RDF dataset; fail if the " +
          "result set is non-empty. The zero-row gate idiom.",
)
