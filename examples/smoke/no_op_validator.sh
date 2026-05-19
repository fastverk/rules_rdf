#!/usr/bin/env bash
# No-op SHACL validator for the rules_rdf smoke fixture. Validates
# the contract argv surface and stdin shape; emits a trivial
# sh:ValidationReport (Turtle) on success. Real validators
# (rules_jena's jena_shacl) replace it.

set -euo pipefail

KNOWN='--rule-name --in-format --shapes --severity'

for arg in "$@"; do
    case "$arg" in
        --*=*) ;;
        *)
            echo "no_op_validator: malformed flag $arg" >&2
            exit 2
            ;;
    esac
    key="${arg%%=*}"
    case " $KNOWN " in
        *" $key "*) ;;
        *)
            echo "no_op_validator: unknown flag $key" >&2
            exit 2
            ;;
    esac
done

stdin_bytes=$(cat)
if ! printf '%s' "$stdin_bytes" | grep -q '\.'; then
    echo "no_op_validator: malformed input" >&2
    exit 3
fi

printf '@prefix sh: <http://www.w3.org/ns/shacl#> .\n[] a sh:ValidationReport ; sh:conforms true .\n'
