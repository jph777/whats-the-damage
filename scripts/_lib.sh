# Shared helpers, sourced by the other scripts.
set -eu
cd "$(dirname "$0")"   # run from the repo regardless of caller cwd
COMMON=$(git rev-parse --path-format=absolute --git-common-dir)
LIVE=$(dirname "$COMMON")                          # the main worktree (what runs / is deployed)
WT_ROOT=${WORKFLOW_WORKTREES:-$(git config workflow.worktreeRoot || true)}
[ -n "$WT_ROOT" ] || WT_ROOT=$(dirname "$LIVE")/$(basename "$LIVE")-worktrees
DEV_WT=$WT_ROOT/dev
TEST_CMD=$(git config workflow.testCmd || true)    # run from a worktree root
UP_BRANCH=$(git config workflow.upstreamBranch || echo main)
die() { echo "error: $*" >&2; exit 1; }
run_tests() { [ -n "$TEST_CMD" ] || { echo "warning: workflow.testCmd not set; skipping tests" >&2; return 0; }; (cd "$1" && sh -c "$TEST_CMD"); }
