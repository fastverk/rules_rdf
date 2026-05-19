#!/usr/bin/env python3
"""No-op SPARQL engine for the rules_rdf smoke test.

Exists only to validate the end-to-end wiring: rdf_dataset →
sparql_query_test → toolchain resolution → plugin invocation.
A real SPARQL engine (rules_jena's `jena_sparql`, eventually)
replaces this; the no-op deliberately doesn't link against an
RDF parser.

Contract surface implemented:
  - Accepts --rule-name, --in-format, --query, --out-format,
    --fail-on-nonempty
  - Rejects unknown flags (non-zero exit)
  - Detects malformed Turtle by a trivial syntactic sniff
    (presence of '.' on at least one line)
  - With --fail-on-nonempty: always reports 0 rows (the no-op
    "doesn't run any query") so sparql_query_test passes
"""

from __future__ import annotations

import sys

KNOWN_FLAGS = {
    "--rule-name", "--in-format", "--query", "--out-format",
    "--fail-on-nonempty", "--shapes", "--severity",
    "--profile", "--rules", "--include-base",
}


def parse_args():
    fail_on_nonempty = False
    for arg in sys.argv[1:]:
        if arg == "--fail-on-nonempty":
            fail_on_nonempty = True
            continue
        if "=" not in arg:
            sys.stderr.write(f"no_op_sparql: malformed flag {arg!r}\n")
            sys.exit(2)
        key, _ = arg.split("=", 1)
        if key not in KNOWN_FLAGS:
            sys.stderr.write(f"no_op_sparql: unknown flag {key!r}\n")
            sys.exit(2)
    return fail_on_nonempty


def main():
    fail_on_nonempty = parse_args()
    stdin_bytes = sys.stdin.buffer.read()

    # Trivial well-formedness sniff: any Turtle document has at
    # least one '.' terminator. Garbage stdin fails fast.
    if not stdin_bytes.strip() or b"." not in stdin_bytes:
        sys.stderr.write("no_op_sparql: malformed input — no '.' terminator found\n")
        sys.exit(3)

    # Emit a TSV result set with zero rows. The header line keeps
    # stdout non-empty (the contract requires non-empty stdout on
    # successful runs).
    sys.stdout.write("# no_op_sparql: zero-row result set\n")

    # zero rows + --fail-on-nonempty → exit 0
    if fail_on_nonempty:
        sys.exit(0)


if __name__ == "__main__":
    main()
