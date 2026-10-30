#!/usr/bin/env bash
# Run every case of a CFAST suite (or the listed subset) in parallel without stopping at the first failure.
# Usage: run_cfast_ci.sh <repo> <executable> <Verification|Validation> <results.tsv> [dir/case.in ...]
# Each results line is: case <TAB> exit code <TAB> first error line (empty on success) <TAB> seconds.
# CFAST_CI_PARALLEL sets the number of concurrent cases (default: nproc).
# CFAST_CI_SHARD=i/n keeps every n-th case starting at the i-th, to split a suite across jobs.
set -uo pipefail
export LC_ALL=C  # EPOCHREALTIME and printf %f need a dot as decimal separator
[[ $# -ge 4 ]] || { sed -n 2,6p "$0" >&2; exit 2; }
repo=$(cd "$1" && pwd); exe=$(readlink -f "$2"); suite=$3; results=$(readlink -m "$4"); shift 4
[[ -x $exe ]] || { echo "Executable not found: $exe" >&2; exit 2; }
shard=${CFAST_CI_SHARD:-1/1}; shard_index=${shard%/*}; shard_count=${shard#*/}
jobs=$(mktemp); trap 'rm -f "$jobs"' EXIT
export CFAST_CI_JOBS=$jobs CFAST_CI_SELECTED=" $* "

# The suite's case list calls $RUNCFAST -d dir case.in; record those calls instead of running them.
collect_case() {
   local dir=$2 input=$3
   [[ $CFAST_CI_SELECTED == "  " || $CFAST_CI_SELECTED == *" $dir/$input "* ]] || return 0
   printf '%s\t%s\n' "$dir" "$input" >> "$CFAST_CI_JOBS"
}
export -f collect_case
export RUNCFAST=collect_case
(cd "$repo/$suite" && bash scripts/CFAST_Cases.sh)
awk -v i="$shard_index" -v n="$shard_count" '(NR - i) % n == 0' "$jobs" > "$jobs.shard" && mv "$jobs.shard" "$jobs"
[[ -s $jobs ]] || { echo "No matching cases in $suite (shard $shard): $*" >&2; exit 2; }

run_case() {
   local dir=$1 input=$2 rc=0 base=${2%.*} error= start=$EPOCHREALTIME
   # Run CFAST directly, as qcfast.sh does locally, so older refs with other launcher defaults behave the same.
   # Each case writes only files named after its input, so cases in the same directory can run concurrently.
   (cd "$dir" && "$CFAST_CI_EXE" "$input" > "$base.log" 2> "$base.err") || rc=$?
   echo "$rc" > "$dir/$base.exit"
   if [[ $rc != 0 ]]; then
      error=$({ grep -ih 'error exit' "$dir/$base.err" "$dir/$base.log"; grep -ihE 'error|abort|stop' "$dir/$base.err" "$dir/$base.log"; } 2>/dev/null | head -1 | tr -s ' \t' ' ')
   fi
   printf '%s/%s\t%s\t%s\t%.1f\n' "$dir" "$input" "$rc" "$error" "$(awk -v a="$EPOCHREALTIME" -v b="$start" 'BEGIN {print a - b}')"
}
export -f run_case
export CFAST_CI_EXE=$exe
cd "$repo/$suite"
xargs -a "$jobs" -d '\n' -P "${CFAST_CI_PARALLEL:-$(nproc)}" -I{} bash -c 'IFS=$'"'"'\t'"'"' read -r d i <<< "$1"; run_case "$d" "$i"' _ {} \
   | sort > "$results"

total=$(wc -l < "$results"); failed=$(awk -F'\t' '$2 != 0' "$results" | wc -l)
awk -F'\t' '$2 != 0 {printf "FAIL (exit %s) %s: %s\n", $2, $1, $3}' "$results"
echo "Slowest cases:"; sort -t$'\t' -k4,4gr "$results" | head -3 | awk -F'\t' '{printf "  %6.1f s  %s\n", $4, $1}'
echo "$suite (shard $shard): $((total - failed))/$total cases passed with $exe"
[[ $failed == 0 ]]
