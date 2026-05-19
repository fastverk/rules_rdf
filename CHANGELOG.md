# Changelog

All notable changes to rules_rdf. The format is loosely
[Keep a Changelog](https://keepachangelog.com/) — version headers
mirror the published bazel-registry entries.

## 0.1.0 — first usable surface

- Four `toolchain_type`s under `//rdf:`: `sparql_engine`,
  `rdf_validator`, `rdf_serializer`, `rdf_reasoner`.
- Toolchain registration rules + providers carrying both the
  plugin binary and its runfiles (so py_binary / java_binary
  plugins resolve in the sandbox).
- `rdf_dataset` + `RdfDatasetInfo` provider.
- `sparql_query_test` — zero-row SPARQL gate, the workhorse rule.
- `rdf_validate_test` — SHACL gate.
- `rdf_plugin_contract_test` rule + Python driver. Four scenarios:
  `valid_minimal`, `malformed_input`, `unknown_flag`,
  `determinism`.
- Plugin contract finalized at `rdf/plugin_contract.md` (v1).
- Stardoc reference for all six public-API .bzl files.
- End-to-end smoke (`examples/smoke/`) using a no-op Python SPARQL
  engine. Validates the contract pipeline without depending on a
  concrete RDF backend.

## 0.0.1 — scaffold

- Initial scaffold via `rels scaffold`. No public API yet.
