#!/usr/bin/env bash
set -euo pipefail
KNOWN='--rule-name --in-format --out-format'
for arg in "$@"; do
    case "$arg" in
        --*=*) ;;
        *) echo "no_op_serializer: malformed flag $arg" >&2; exit 2 ;;
    esac
    key="${arg%%=*}"
    case " $KNOWN " in
        *" $key "*) ;;
        *) echo "no_op_serializer: unknown flag $key" >&2; exit 2 ;;
    esac
done
stdin_bytes=$(cat)
if ! printf '%s' "$stdin_bytes" | grep -q '\.'; then
    echo "no_op_serializer: malformed input" >&2
    exit 3
fi
printf '# converted by no_op_serializer\n%s' "$stdin_bytes"
