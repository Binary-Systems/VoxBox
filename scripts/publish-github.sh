#!/bin/bash
# Publish the current VoxBox tree to GitHub without the older Gitea history.
# The public commit's only parent is the previous public commit. Private
# submodule links are left out. This script does not push main or any tags.
set -euo pipefail

root=$(git rev-parse --show-toplevel)
cd "$root"
export GIT_HTTP_VERSION=HTTP/1.1
src=${1:-HEAD}
src=$(git rev-parse --verify "${src}^{commit}")
github_url="https://github.com/Binary-Systems/VoxBox.git"

git fetch origin main
if ! git merge-base --is-ancestor "$src" origin/main; then
  echo "Refusing: $src is not on origin/main." >&2
  exit 1
fi

if git ls-remote --exit-code origin refs/heads/github >/dev/null 2>&1; then
  git fetch origin github:refs/heads/github
fi

index=$(mktemp)
trap 'rm -f "$index"' EXIT
tree=$(
  GIT_INDEX_FILE=$index git read-tree "$src"
  for path in BSI-VoxBox Client-VoxBox .gitmodules .DS_Store branding/.DS_Store; do
    if GIT_INDEX_FILE=$index git ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
      GIT_INDEX_FILE=$index git update-index --force-remove -- "$path"
    fi
  done
  leftover=$(GIT_INDEX_FILE=$index git ls-files -- BSI-VoxBox Client-VoxBox .gitmodules .DS_Store branding/.DS_Store)
  if [ -n "$leftover" ]; then
    echo "Refusing: private paths are still in the public tree." >&2
    printf '%s\n' "$leftover" >&2
    exit 1
  fi
  GIT_INDEX_FILE=$index git write-tree
)

if git rev-parse --verify --quiet refs/heads/github >/dev/null; then
  parent=$(git rev-parse refs/heads/github)
  if [ "$(git rev-parse "${parent}^{tree}")" = "$tree" ]; then
    echo "Public branch already matches $(git rev-parse --short "$src")."
    commit=$parent
  else
    msg=$(mktemp)
    cat > "$msg" << EOF
Publish $(git rev-parse --short "$src").

The public tree matches that Gitea commit without the private submodule links.
EOF
    commit=$(git commit-tree "$tree" -p "$parent" -F "$msg")
    rm -f "$msg"
    git update-ref refs/heads/github "$commit"
  fi
else
  msg=$(mktemp)
  cat > "$msg" << EOF
Publish the current VoxBox tree.

This is the first public commit. Older history stays on Gitea. The private BSI-VoxBox and Client-VoxBox links are not included.
EOF
  commit=$(git commit-tree "$tree" -F "$msg")
  rm -f "$msg"
  git update-ref refs/heads/github "$commit"
fi

GIT_HTTP_VERSION=HTTP/1.1 git push origin refs/heads/github:refs/heads/github
git push "$github_url" refs/heads/github:refs/heads/main
echo "Published $(git rev-parse --short "$commit") to GitHub main."
