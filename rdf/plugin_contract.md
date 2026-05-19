# rules_rdf plugin contract — v0.1 draft

> **Status:** draft. This document is the v0.1 deliverable; rules_rdf
> will refine it before tagging v0.1.0. Plugin authors targeting the
> contract should treat anything here as provisional until that tag.
>
> Authoritative specification for what an RDF toolchain plugin must
> do. Plugins are invoked by per-operation rules
> (`sparql_query_test`, `rdf_validate_test`, `rdf_transform`,
> `rdf_reason`, …) through registered toolchains.

## Process model

A plugin is any executable that conforms to:

```
INPUT
  stdin              the RDF document bytes — one or more graphs in a single
                     serialization, concatenated. Format declared via
                     --in-format. For multi-file datasets, the calling rule
                     concatenates the files in lexicographic order before
                     piping; plugins must not assume otherwise.
  argv               --key=value pairs, repeated

OUTPUT
  stdout             the generated output bytes (raw):
                       sparql_engine    → result set (SRX / JSON / TSV / CSV / Turtle for CONSTRUCT)
                       rdf_validator    → SHACL ValidationReport (Turtle)
                       rdf_serializer   → the dataset re-serialized in --out-format
                       rdf_reasoner     → the inferred-triples graph (Turtle, default)
  stderr             human-readable diagnostics

EXIT
  0                  success — stdout is the output
  non-zero           failure — stderr explains why
```

Plugins must not write anything to stdout other than the final output
bytes. Diagnostics go to stderr unconditionally.

A toolchain implementation may ship four separate binaries (one per
operation) or a single binary dispatched on a subcommand flag the
toolchain registration translates to. From the rule's point of view
each toolchain resolves to exactly one executable.

## Standard argv flags

The rule passes a fixed set of flags every plugin receives, regardless
of consumer wiring or which toolchain type:

| Flag | Meaning |
|---|---|
| `--rule-name=NAME` | Name of the Bazel target invoking the plugin. For error messages and provenance headers. |
| `--in-format=FORMAT` | Serialization of the dataset on stdin. One of `turtle`, `ntriples`, `nquads`, `trig`, `jsonld`, `rdfxml`. |

A plugin **must accept** these flags. It may treat them as no-ops if
they don't apply (e.g. `--in-format` for a plugin that auto-detects),
but the rule will always pass them.

## Consumer-supplied argv flags by toolchain

Each user-facing rule forwards its own additional flags. Unknown
flags must be rejected (exit non-zero) — silently ignoring them
would make a misconfigured query / shapes file / profile degrade
the build with no warning.

### `sparql_engine_toolchain_type`

| Flag | Set by | Meaning |
|---|---|---|
| `--query=PATH` | `sparql_query_test`, `sparql_query_run` | Path to the `.rq` SPARQL query file. |
| `--out-format=FORMAT` | rule | One of `srx`, `json`, `tsv`, `csv`, `turtle` (CONSTRUCT/DESCRIBE). |
| `--fail-on-nonempty` | `sparql_query_test` | If present, plugin exits non-zero when the result set has ≥ 1 row. The zero-row gate idiom. |

### `rdf_validator_toolchain_type`

| Flag | Set by | Meaning |
|---|---|---|
| `--shapes=PATH` | `rdf_validate_test` | Path to the SHACL shapes graph (Turtle). |
| `--severity=LEVEL` | rule | Minimum severity that fails the build: `violation` (default), `warning`, `info`. |

### `rdf_serializer_toolchain_type`

| Flag | Set by | Meaning |
|---|---|---|
| `--out-format=FORMAT` | `rdf_transform` | Output serialization, same vocabulary as `--in-format`. |

### `rdf_reasoner_toolchain_type`

| Flag | Set by | Meaning |
|---|---|---|
| `--profile=NAME` | `rdf_reason` | Reasoning profile: `rdfs`, `owl-rl`, `owl-mini`, `owl-micro`, `custom`. |
| `--rules=PATH` | `rdf_reason` | Path to a custom rule file, required iff `--profile=custom`. |
| `--include-base` | rule | If present, emit base + inferred triples. Default: inferred only. |

## Error reporting

Two distinct failure modes, identical to the jsonschema contract:

1. **Operation error** — input is well-formed but the plugin can't
   handle it (malformed query, unsatisfiable shape, unknown profile,
   unsupported serialization). Plugin writes a human-readable
   message to stderr and exits non-zero.

2. **Plugin bug** — process terminates abnormally (panic, JVM
   exception, segfault). Bazel surfaces the non-zero exit + stderr
   identically.

The exit code is the authoritative success signal. Stderr content
alone is not a failure; informational warnings on stderr during a
successful run are surfaced in Bazel's build log. Stdout must
contain *only* the final output bytes, never progress chatter.

For `sparql_query_test` with `--fail-on-nonempty`: a non-empty result
set is **not** a plugin error — the plugin successfully ran the
query and **chose** to exit non-zero per the flag. Stderr should
include the offending rows in a human-readable form to make the
gate failure actionable.

## Output stability

Plugins should produce **deterministic output** for the same input.
RDF makes this non-trivial because the underlying graph is unordered;
the discipline is:

- **Turtle / N-Triples / N-Quads output**: sort triples
  lexicographically (subject, predicate, object). Blank node labels
  must be assigned in a canonical, content-derived order (e.g.
  Hogan's RDF canonicalisation, or a stable hash-based labelling) —
  never auto-incremented from JVM identity hash codes or process-
  local counters.
- **JSON-LD output**: emit in expanded form, sort keys
  lexicographically, sort array contents where order is not
  semantically meaningful.
- **SPARQL result sets**: include an explicit `ORDER BY` in the
  query when emitting TSV/CSV/JSON. The plugin must not reorder
  rows; if the query lacks `ORDER BY`, output ordering is
  implementation-defined and consumers should treat the result as
  unordered.
- **Validation reports**: order `sh:ValidationResult` entries by
  `sh:focusNode` then `sh:sourceShape`.
- Don't embed timestamps, hostnames, JVM versions, or build IDs in
  the output. A `# generated by <plugin-name>` preamble is fine; a
  `# generated at 2026-05-19T12:34:56Z` preamble is not.

A typical Turtle preamble:

```
# @generated by <plugin-name>. DO NOT EDIT.
#
# Source: <value of --rule-name>
```

## Multi-file output

A plugin emits **exactly one file's content** on stdout. Multi-file
output kinds (e.g. query results + execution plan, validation report
+ trace) are expressed as separate rule invocations against separate
plugins — not as one plugin returning multiple files.

If a future plugin genuinely needs to emit many files at once, it
should be wrapped in a rule using `ctx.actions.declare_directory`,
matching the jsonschema escape hatch. The single-file constraint
is the default and what every v0.1 rule expects.

## Concrete plugin skeleton

A 25-line Python plugin is a real plugin. Example: a SPARQL engine
backed by `rdflib`:

```python
import sys
from rdflib import Graph

def parse_flag(name):
    for arg in sys.argv[1:]:
        if arg.startswith(f"--{name}="):
            return arg.split("=", 1)[1]
    return None

in_format = parse_flag("in-format") or "turtle"
query_path = parse_flag("query")
fail_on_nonempty = "--fail-on-nonempty" in sys.argv

g = Graph()
g.parse(data=sys.stdin.buffer.read(), format=in_format)
with open(query_path) as f:
    results = list(g.query(f.read()))

# Emit TSV.
for row in results:
    sys.stdout.write("\t".join(str(c) for c in row) + "\n")

if fail_on_nonempty and results:
    sys.stderr.write(f"{len(results)} row(s) violated gate\n")
    sys.exit(1)
```

A real production plugin (e.g. `rules_jena`'s `jena_sparql`) is a
java_binary wrapping `org.apache.jena.query.QueryExecutionFactory`
— the shape is the same.

## Conformance testing

The `rdf_plugin_contract_test` rule runs a contract driver against
any plugin executable. The driver is parameterised by toolchain type
because each type has a different "minimal valid input" — see the
table — but the four scenarios are constant:

| Scenario | Asserts |
|---|---|
| `valid_minimal` | Plugin exits 0 + writes non-empty stdout for a well-formed minimal input (a 1-triple Turtle graph + the appropriate query / shapes / profile). |
| `malformed_input` | Plugin exits non-zero, writes to stderr, and **does not write to stdout** on garbage stdin. |
| `unknown_flag` | Plugin rejects an unknown `--key=value` flag (exit non-zero). |
| `determinism` | Two identical invocations produce byte-identical stdout. |

Plugin authors gate their toolchain registration with it:

```python
load("@rules_rdf//rdf:contract_test.bzl", "rdf_plugin_contract_test")

rdf_plugin_contract_test(
    name = "jena_sparql_conforms",
    plugin = "//jena:jena_sparql",
    toolchain_type = "sparql_engine",
)
```

The four default `_no_op` plugins shipped with rules_rdf in v0.1
each have a `*_conforms` test target as the canary that the driver
itself works against a known-passing implementation.

## Versioning

Contract changes follow the same rules as rules_jsonschema:

- **Adding a standard argv flag** is breaking — plugins reject
  unknown flags. Coordinate across all known plugins before adding.
- **Adding a new toolchain type** is additive (existing plugins
  ignore it).
- **Per-toolchain consumer-supplied flags** are owned by the rule
  that forwards them; changing those is the rule author's concern,
  not a contract issue.
- **Changing stdin/stdout semantics** is breaking.

The contract version is currently **v0.1 (draft)**. Once rules_rdf
tags v0.1.0, this document becomes the **v1** stable contract.
Future versions will be declared here and plugins are expected to
support the latest.
