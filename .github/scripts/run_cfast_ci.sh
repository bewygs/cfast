#!/usr/bin/env bash
# Run every case of a CFAST suite (or the listed subset) in parallel without stopping at the first failure.
# Usage: run_cfast_ci.sh <repo> <executable> <Verification|Validation> <results.tsv> [dir/case.in ...]
# Each results line is: case <TAB> exit code <TAB> first error line (empty on success).
set -uo pipefail
[[ $# -ge 4 ]] || { sed -n 2,4p "$0" >&2; exit 2; }
# Absolute paths without GNU readlink, so the script also runs on macOS.
repo=$(cd "$1" && pwd); exe=$(cd "$(dirname "$2")" && pwd)/$(basename "$2")
suite=$3; results=$(cd "$(dirname "$4")" && pwd)/$(basename "$4"); shift 4
[[ -x $exe ]] || { echo "Executable not found: $exe" >&2; exit 2; }
jobs=$(mktemp); trap 'rm -f "$jobs"' EXIT
export CFAST_CI_JOBS=$jobs CFAST_CI_SELECTED=" $* "

# The suite's case list calls $RUNCFAST -d dir case.in; record those calls instead of running them.
collect_case() {
   local dir=$2 input=$3
   [[ $CFAST_CI_SELECTED == "  " || $CFAST_CI_SELECTED == *" $dir/$input "* ]] || return 0
   printf '%s/%s\n' "$dir" "$input" >> "$CFAST_CI_JOBS"
}
export -f collect_case
export RUNCFAST=collect_case
(cd "$repo/$suite" && bash scripts/CFAST_Cases.sh)
[[ -s $jobs ]] || { echo "No matching cases in $suite: $*" >&2; exit 2; }

run_case() {
   local dir=${1%/*} input=${1##*/} rc=0 base error=
   base=${input%.*}
   # Run CFAST directly, as qcfast.sh does locally, so older refs with other launcher defaults behave the same.
   # Each case writes only files named after its input, so cases in the same directory can run concurrently.
   (cd "$dir" && "$CFAST_CI_EXE" "$input" > "$base.log" 2> "$base.err") || rc=$?
   echo "$rc" > "$dir/$base.exit"
   if [[ $rc != 0 ]]; then
      error=$({ grep -ih 'error exit' "$dir/$base.err" "$dir/$base.log"; grep -ihE 'error|abort|stop' "$dir/$base.err" "$dir/$base.log"; } 2>/dev/null | head -1 | tr -s ' \t' ' ')
   fi
   printf '%s/%s\t%s\t%s\n' "$dir" "$input" "$rc" "$error"
}
export -f run_case
export CFAST_CI_EXE=$exe
cd "$repo/$suite"
tr '\n' '\0' < "$jobs" | xargs -0 -n 1 -P "$(getconf _NPROCESSORS_ONLN)" bash -c 'run_case "$1"' _ \
   | sort > "$results"

total=$(awk 'END {print NR}' "$results"); failed=$(awk -F'\t' '$2 != 0 {n++} END {print n + 0}' "$results")
awk -F'\t' '$2 != 0 {printf "FAIL (exit %s) %s: %s\n", $2, $1, $3}' "$results"
echo "$suite: $((total - failed))/$total cases passed with $exe"
(( failed == 0 ))
