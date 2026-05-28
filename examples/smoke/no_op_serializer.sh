#!/usr/bin/env bash
set -euo pipefail
KNOWN='--rule-name --in-format --out-format --input-file'
input_files=()
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
    if [[ "$key" == "--input-file" ]]; then
        input_files+=("${arg#*=}")
    fi
done
# Multi-file merge mode reads the named files; otherwise stdin. (A real
# serializer parses each file independently to scope blank nodes; the
# no-op just streams them — fine for the contract smoke fixture.)
if [[ ${#input_files[@]} -gt 0 ]]; then
    bytes=$(cat "${input_files[@]}")
else
    bytes=$(cat)
fi
if ! printf '%s' "$bytes" | grep -q '\.'; then
    echo "no_op_serializer: malformed input" >&2
    exit 3
fi
printf '# converted by no_op_serializer\n%s' "$bytes"
