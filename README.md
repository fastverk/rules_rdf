# rules_rdf

Bazel rules for RDF — toolchain types for SPARQL, SHACL validation, format conversion, and reasoning. Concrete implementations live in sibling repos like rules_jena.

## Status: v0.0.1 — scaffold

No public surface yet. See `CHANGELOG.md` for what has shipped.

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
