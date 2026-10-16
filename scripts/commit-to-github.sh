#!/bin/sh
# Commits FILES, as they are here, to the default branch of this GitHub repository through the API, so GitHub
# signs the commit, and prints the new commit. For the workflows: needs gh, jq and GITHUB_REPOSITORY.
#
# Usage: scripts/commit-to-github.sh MESSAGE FILE...
set -eu

cd "$(dirname "$0")/.."

MESSAGE="$1"
shift
BRANCH="$(gh api "repos/$GITHUB_REPOSITORY" --jq .default_branch)"
HEAD="$(gh api "repos/$GITHUB_REPOSITORY/commits/$BRANCH" --jq .sha)"
ADDITIONS="$(for file in "$@"; do
    jq -n --arg path "$file" --arg contents "$(base64 < "$file" | tr -d '\n')" '{path: $path, contents: $contents}'
done | jq -s .)"
jq -n --arg repository "$GITHUB_REPOSITORY" --arg branch "$BRANCH" --arg head "$HEAD" --arg message "$MESSAGE" \
    --argjson additions "$ADDITIONS" '{
        query: "mutation($input: CreateCommitOnBranchInput!) { createCommitOnBranch(input: $input) { commit { oid } } }",
        variables: {input: {
            branch: {repositoryNameWithOwner: $repository, branchName: $branch},
            expectedHeadOid: $head,
            message: {headline: $message},
            fileChanges: {additions: $additions}
        }}
    }' | gh api graphql --input - --jq .data.createCommitOnBranch.commit.oid
