# rules_rdf

Bazel rules for RDF. Defines abstract toolchain types for the four
operations that show up in every production RDF/knowledge-graph
pipeline — SPARQL query execution, SHACL validation, format
conversion, and reasoning — and leaves the engine choice to a
concrete toolchain registered by the consumer. The host repo only
registers toolchains; the rules themselves are engine-agnostic.

## Status: v0.0.1 — scaffold

Nothing ships yet. This release is the module skeleton + design docs.
The first usable surface (toolchain type definitions, `_no_op`
default rules, plugin contract test driver) lands in v0.1.0. See
[`docs/ROADMAP.md`](docs/ROADMAP.md).

## Architecture

Plugins implement a minimal stdin/argv/stdout contract; per-operation
Bazel rules wrap them. Concrete RDF engines (Apache Jena, RDF4J,
Oxigraph, …) live in sibling repos and register toolchains against
the abstract types defined here.

```
//rdf:                        operation-neutral core
  - toolchain_type definitions per RDF operation
  - provider definitions (RdfDatasetInfo, …)
  - rdf_*_toolchain rules (register a plugin)
  - rdf_plugin_contract_test rule (verify a plugin conforms)
  - plugin_contract.md (authoritative spec)

//sparql:                     SPARQL query rules
  - sparql_query_test, sparql_query_run

//shacl:                      SHACL validation rules
  - rdf_validate_test

//convert:                    format conversion rules
  - rdf_transform

//reason:                     inference rules
  - rdf_reason
```

Adding a new RDF engine is:

1. Write four plugin binaries (one per toolchain type) — or a single
   multi-tool binary dispatched on a subcommand flag. Each conforms
   to the plugin contract.
2. Register one `rdf_*_toolchain` per operation pointing at the
   appropriate plugin.
3. Gate registration with `rdf_plugin_contract_test`.

## Planned toolchain types

| Type | Operation | Inputs | Output |
|---|---|---|---|
| `sparql_engine_toolchain_type` | Run a SPARQL query against an RDF dataset | dataset (one or more graph files) + `.rq` query file | query results (SRX / JSON / TSV / CSV / Turtle for CONSTRUCT) |
| `rdf_validator_toolchain_type` | Validate a dataset against a SHACL shapes graph | dataset + `shapes.ttl` | validation report (Turtle, `sh:ValidationReport`) |
| `rdf_serializer_toolchain_type` | Convert RDF between serializations | dataset in format A | same graph in format B (Turtle ↔ N-Triples ↔ JSON-LD ↔ RDF/XML ↔ TriG ↔ N-Quads) |
| `rdf_reasoner_toolchain_type` | Materialise inferred triples | dataset + reasoning profile (`rdfs`, `owl-rl`, custom rules) | derived-triples graph (Turtle) |

Each type resolves a single plugin executable per consumer; an engine
ships up to four plugins (or one binary with four subcommands) and
registers each independently so a consumer can mix-and-match — e.g.
Jena for SPARQL and Oxigraph for reasoning — without rebuilding the
toolchain.

## Planned user-facing rules

| Rule | Toolchain | Purpose |
|---|---|---|
| `rdf_dataset` | (none) | Bundle one or more graph files + format hints into an `RdfDatasetInfo` provider consumed by every downstream rule. |
| `sparql_query_test` | `sparql_engine_toolchain_type` | Zero-row gate — run a `.rq` query and fail the build if the result set is non-empty. The canonical SPARQL gate idiom. |
| `sparql_query_run` | `sparql_engine_toolchain_type` | Run a query and emit the result set as a build artifact. |
| `rdf_validate_test` | `rdf_validator_toolchain_type` | Run SHACL validation; fail the build on any `sh:Violation`. |
| `rdf_transform` | `rdf_serializer_toolchain_type` | Convert a dataset between serializations. Idempotent on the same format. |
| `rdf_reason` | `rdf_reasoner_toolchain_type` | Emit the inferred triples for a dataset under a reasoning profile. |

`sparql_query_test` is the workhorse — the production graph at
`kg/java/` uses the same "non-empty result set means violation"
idiom for every PR gate, and rules_rdf lifts that idiom into a
first-class Bazel rule.

## The plugin contract

A plugin is any executable that conforms to:

```
INPUT
  stdin              the RDF document bytes (concatenated dataset, format declared via --in-format)
  argv               --key=value pairs

OUTPUT
  stdout             the generated output (query results, validation report, converted graph, inferred triples)
  stderr             diagnostics

EXIT
  0                  success
  non-zero           failure
```

Standard argv flags every plugin receives: `--rule-name=NAME` and
`--in-format=FORMAT`. Per-toolchain flags (`--query=PATH`,
`--shapes=PATH`, `--out-format=FORMAT`, `--profile=NAME`) are passed
through by the calling rule. See
[`rdf/plugin_contract.md`](rdf/plugin_contract.md) for the
authoritative spec (currently v0.1 draft).

## Concrete implementations

- **[fastverk/rules_jena](https://github.com/fastverk/rules_jena)** —
  Apache Jena backend. Ships plugins for all four toolchain types
  (`jena_sparql`, `jena_shacl`, `jena_riot`, `jena_reasoner`) and a
  Maven-pinned `JENA_DEPS` set so consumers don't re-declare it.

Others (RDF4J, Oxigraph) are not blocked by anything in this repo —
the contract is the integration point. PRs to list third-party
implementations here are welcome.

## Install

`.bazelrc`:

```
common --registry=https://raw.githubusercontent.com/fastverk/bazel-registry/main/
common --registry=https://bcr.bazel.build/
```

`MODULE.bazel`:

```python
bazel_dep(name = "rules_rdf", version = "0.0.1")
```

No toolchains are registered by default — pull in a concrete
implementation (e.g. `rules_jena`) and register its toolchains in
your `MODULE.bazel`.

## Compatibility

- **Bazel**: 7.4+, bzlmod required (tested on 9.1).

## License

MIT.
