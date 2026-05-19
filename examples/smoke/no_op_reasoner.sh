#!/usr/bin/env bash
set -euo pipefail
KNOWN='--rule-name --in-format --profile --rules'
for arg in "$@"; do
    if [[ "$arg" == "--include-base" ]]; then continue; fi
    case "$arg" in
        --*=*) ;;
        *) echo "no_op_reasoner: malformed flag $arg" >&2; exit 2 ;;
    esac
    key="${arg%%=*}"
    case " $KNOWN " in
        *" $key "*) ;;
        *) echo "no_op_reasoner: unknown flag $key" >&2; exit 2 ;;
    esac
done
stdin_bytes=$(cat)
if ! printf '%s' "$stdin_bytes" | grep -q '\.'; then
    echo "no_op_reasoner: malformed input" >&2
    exit 3
fi
printf '# no_op_reasoner: zero inferred triples\n'
