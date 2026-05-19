#!/usr/bin/env bash
# No-op SPARQL engine. See no_op_validator.sh for the pattern.
set -euo pipefail

KNOWN='--rule-name --in-format --query --out-format'
fail_on_nonempty=0
for arg in "$@"; do
    if [[ "$arg" == "--fail-on-nonempty" ]]; then
        fail_on_nonempty=1
        continue
    fi
    case "$arg" in
        --*=*) ;;
        *) echo "no_op_sparql: malformed flag $arg" >&2; exit 2 ;;
    esac
    key="${arg%%=*}"
    case " $KNOWN " in
        *" $key "*) ;;
        *) echo "no_op_sparql: unknown flag $key" >&2; exit 2 ;;
    esac
done
stdin_bytes=$(cat)
if ! printf '%s' "$stdin_bytes" | grep -q '\.'; then
    echo "no_op_sparql: malformed input" >&2
    exit 3
fi
printf '# no_op_sparql: zero-row result set\n'
