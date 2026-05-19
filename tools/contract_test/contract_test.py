#!/usr/bin/env python3
"""Conformance test driver for the rules_rdf plugin contract.

Invoked by the `rdf_plugin_contract_test` rule. Takes
`--plugin=<path>` and `--toolchain-type=<sparql_engine|rdf_validator|
rdf_serializer|rdf_reasoner>` and runs four scenarios in sequence.
Any failure exits non-zero with a human-readable diagnostic on
stderr; success exits 0.

The four scenarios mirror the contract's "Conformance testing"
section:

  1. valid_minimal     — plugin exits 0 + writes non-empty stdout
                         for a minimally well-formed input.
  2. malformed_input   — plugin exits non-zero on garbage stdin,
                         writes diagnostic to stderr, and emits
                         nothing on stdout.
  3. unknown_flag      — plugin rejects an unknown --key=value flag.
  4. determinism       — two identical invocations produce
                         byte-identical stdout.

Each toolchain type has its own "minimal valid input" because the
required argv flags differ. Definitions live in `_SCENARIOS` below.
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import tempfile
from pathlib import Path

# Minimal Turtle dataset used as stdin for valid_minimal +
# determinism. One triple, one prefix, deliberately trivial.
MINIMAL_TURTLE = b"""\
@prefix ex: <http://example.org/> .
ex:s ex:p ex:o .
"""

# Minimal SHACL shapes graph that the rdf_validator scenario
# pairs with the dataset above. The shape passes trivially —
# valid_minimal asserts the plugin works on a *conforming* graph,
# not that it catches violations.
MINIMAL_SHAPES = b"""\
@prefix sh: <http://www.w3.org/ns/shacl#> .
@prefix ex: <http://example.org/> .

ex:Shape a sh:NodeShape ;
    sh:targetNode ex:s ;
    sh:property [
        sh:path ex:p ;
        sh:minCount 1 ;
    ] .
"""

# Minimal SPARQL query for valid_minimal.
MINIMAL_QUERY = b"""\
PREFIX ex: <http://example.org/>
SELECT ?s WHERE { ?s ex:p ex:o . }
"""

# Toolchain-type-specific scenarios. Each entry maps to a function
# producing (argv_extra, stdin_bytes, with_files) where with_files
# is a dict[str, bytes] of temp files the plugin needs paths to.
_SCENARIOS: dict[str, dict[str, tuple]] = {
    "sparql_engine": {
        "valid_minimal": (["--query=__QUERY__"], MINIMAL_TURTLE,
                          {"__QUERY__": MINIMAL_QUERY}),
        "malformed_input": (["--query=__QUERY__"], b"this is not turtle <<<",
                            {"__QUERY__": MINIMAL_QUERY}),
        "unknown_flag": (["--query=__QUERY__", "--bogus-flag=yes"],
                         MINIMAL_TURTLE, {"__QUERY__": MINIMAL_QUERY}),
    },
    "rdf_validator": {
        "valid_minimal": (["--shapes=__SHAPES__"], MINIMAL_TURTLE,
                          {"__SHAPES__": MINIMAL_SHAPES}),
        "malformed_input": (["--shapes=__SHAPES__"], b"this is not turtle <<<",
                            {"__SHAPES__": MINIMAL_SHAPES}),
        "unknown_flag": (["--shapes=__SHAPES__", "--bogus-flag=yes"],
                         MINIMAL_TURTLE, {"__SHAPES__": MINIMAL_SHAPES}),
    },
    "rdf_serializer": {
        "valid_minimal": (["--out-format=ntriples"], MINIMAL_TURTLE, {}),
        "malformed_input": (["--out-format=ntriples"],
                            b"this is not turtle <<<", {}),
        "unknown_flag": (["--out-format=ntriples", "--bogus-flag=yes"],
                         MINIMAL_TURTLE, {}),
    },
    "rdf_reasoner": {
        "valid_minimal": (["--profile=rdfs"], MINIMAL_TURTLE, {}),
        "malformed_input": (["--profile=rdfs"],
                            b"this is not turtle <<<", {}),
        "unknown_flag": (["--profile=rdfs", "--bogus-flag=yes"],
                         MINIMAL_TURTLE, {}),
    },
}

STANDARD_ARGV = ["--rule-name=contract_test", "--in-format=turtle"]


class Failure(Exception):
    """A single conformance check failed. Message is the diagnostic."""


def run_scenario(
    plugin: str,
    argv_extra: list[str],
    stdin_bytes: bytes,
    tmpdir: Path,
    files: dict[str, bytes],
) -> subprocess.CompletedProcess[bytes]:
    """Materialize files in tmpdir, substitute placeholders into
    argv_extra, and run the plugin once."""
    resolved_extra: list[str] = []
    for arg in argv_extra:
        for placeholder, content in files.items():
            if placeholder in arg:
                target = tmpdir / placeholder.strip("_").lower()
                target.write_bytes(content)
                arg = arg.replace(placeholder, str(target))
        resolved_extra.append(arg)

    return subprocess.run(
        [plugin, *STANDARD_ARGV, *resolved_extra],
        input=stdin_bytes,
        capture_output=True,
        timeout=30,
    )


def assert_valid_minimal(plugin: str, scenarios: dict[str, tuple], tmpdir: Path) -> None:
    argv, stdin_b, files = scenarios["valid_minimal"]
    result = run_scenario(plugin, argv, stdin_b, tmpdir, files)
    if result.returncode != 0:
        raise Failure(
            f"valid_minimal: expected exit 0, got {result.returncode}\n"
            f"  stderr: {result.stderr.decode(errors='replace')[:500]}"
        )
    if not result.stdout:
        raise Failure("valid_minimal: stdout was empty (contract requires non-empty)")


def assert_malformed_input(plugin: str, scenarios: dict[str, tuple], tmpdir: Path) -> None:
    argv, stdin_b, files = scenarios["malformed_input"]
    result = run_scenario(plugin, argv, stdin_b, tmpdir, files)
    if result.returncode == 0:
        raise Failure(
            "malformed_input: expected non-zero exit, got 0\n"
            "  Plugin accepted garbage stdin as valid RDF."
        )
    if result.stdout:
        raise Failure(
            "malformed_input: stdout was non-empty on failure.\n"
            "  Contract requires stdout-only-on-success.\n"
            f"  Got {len(result.stdout)} bytes of stdout."
        )
    if not result.stderr:
        raise Failure(
            "malformed_input: stderr was empty on failure.\n"
            "  Contract requires a human-readable diagnostic on stderr."
        )


def assert_unknown_flag(plugin: str, scenarios: dict[str, tuple], tmpdir: Path) -> None:
    argv, stdin_b, files = scenarios["unknown_flag"]
    result = run_scenario(plugin, argv, stdin_b, tmpdir, files)
    if result.returncode == 0:
        raise Failure(
            "unknown_flag: expected non-zero exit, got 0\n"
            "  Plugin silently accepted --bogus-flag. The contract\n"
            "  requires rejecting unknown flags so misconfigured\n"
            "  options don't silently degrade output."
        )


def assert_determinism(plugin: str, scenarios: dict[str, tuple], tmpdir: Path) -> None:
    argv, stdin_b, files = scenarios["valid_minimal"]
    r1 = run_scenario(plugin, argv, stdin_b, tmpdir, files)
    r2 = run_scenario(plugin, argv, stdin_b, tmpdir, files)
    if r1.returncode != 0 or r2.returncode != 0:
        raise Failure(
            "determinism: one of the two runs failed before comparison "
            "(see valid_minimal output above)"
        )
    if r1.stdout != r2.stdout:
        raise Failure(
            "determinism: two identical invocations produced different stdout.\n"
            f"  Run 1: {len(r1.stdout)} bytes\n"
            f"  Run 2: {len(r2.stdout)} bytes"
        )


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--plugin", required=True, help="Path to the plugin executable.")
    p.add_argument(
        "--toolchain-type",
        required=True,
        choices=sorted(_SCENARIOS.keys()),
        help="Which toolchain type's scenarios to run.",
    )
    args = p.parse_args()

    scenarios = _SCENARIOS[args.toolchain_type]
    checks = [
        ("valid_minimal", assert_valid_minimal),
        ("malformed_input", assert_malformed_input),
        ("unknown_flag", assert_unknown_flag),
        ("determinism", assert_determinism),
    ]

    failures: list[str] = []
    with tempfile.TemporaryDirectory() as tmpdir_str:
        tmpdir = Path(tmpdir_str)
        for name, fn in checks:
            try:
                fn(args.plugin, scenarios, tmpdir)
                print(f"  {name}: pass", file=sys.stderr)
            except Failure as e:
                print(f"  {name}: FAIL", file=sys.stderr)
                failures.append(f"{name}: {e}")
            except Exception as e:  # noqa: BLE001
                print(f"  {name}: ERROR ({e!r})", file=sys.stderr)
                failures.append(f"{name}: unexpected error: {e!r}")

    if failures:
        print("\nrdf_plugin_contract_test: FAIL", file=sys.stderr)
        for f in failures:
            print(f"  - {f}", file=sys.stderr)
        return 1

    print("rdf_plugin_contract_test: pass", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
