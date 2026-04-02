#!/usr/bin/env bash
# Create empty GitHub repo via API, then push branch main (or current branch as main).
# Requires PAT: classic with "repo", or fine-grained with Contents read/write on this repo.
#
#   export GITHUB_TOKEN='ghp_xxxx'
#   ./scripts/github_create_repo_and_push.sh
#
# Optional: GITHUB_USER=jkrescue GITHUB_REPO=nimtest
set -euo pipefail

TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
USER="${GITHUB_USER:-jkrescue}"
REPO="${GITHUB_REPO:-nimtest}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -z "$TOKEN" ]]; then
  echo "ERROR: set GITHUB_TOKEN (or GH_TOKEN)." >&2
  echo "Create token: https://github.com/settings/tokens" >&2
  exit 1
fi

BRANCH="$(git branch --show-current)"
if [[ -z "$BRANCH" ]]; then
  echo "ERROR: not on a git branch" >&2
  exit 1
fi

echo "POST user/repos -> ${USER}/${REPO} ..."
code="$(curl -sS -o /tmp/gh_create_repo.json -w '%{http_code}' \
  -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/user/repos" \
  -d "{\"name\":\"${REPO}\",\"private\":false,\"auto_init\":false}")"

if [[ "$code" != "201" && "$code" != "422" ]]; then
  echo "GitHub API HTTP $code" >&2
  cat /tmp/gh_create_repo.json >&2 || true
  exit 1
fi
[[ "$code" == "422" ]] && echo "Repo may already exist (422). Pushing anyway."

git remote remove origin 2>/dev/null || true
git remote add origin "https://github.com/${USER}/${REPO}.git"

# Authenticated push; then strip token from remote URL
export GIT_TERMINAL_PROMPT=0
if [[ "$BRANCH" == "main" ]]; then
  git push -u "https://oauth2:${TOKEN}@github.com/${USER}/${REPO}.git" main
else
  echo "Current branch is '${BRANCH}', pushing to origin main ..."
  git push -u "https://oauth2:${TOKEN}@github.com/${USER}/${REPO}.git" "${BRANCH}:main"
fi

git remote set-url origin "https://github.com/${USER}/${REPO}.git"
git fetch origin main 2>/dev/null || true
git branch -u origin/main main 2>/dev/null || true

echo "Done: https://github.com/${USER}/${REPO}"
