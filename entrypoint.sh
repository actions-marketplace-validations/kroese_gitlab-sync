#!/usr/bin/env bash
set -e

echo "${GITHUB_EVENT_NAME}"

git_setup() {
  local target_url="${INPUT_TARGET_URL#https://}"
  local clean_url="https://${target_url}"
  local cred_file="${RUNNER_TEMP:-/tmp}/git-credentials"

  # Mask secrets in logs as early as possible
  echo "::add-mask::${INPUT_TARGET_TOKEN}"
  echo "::add-mask::${INPUT_TARGET_USERNAME}:${INPUT_TARGET_TOKEN}"
  echo "::add-mask::https://${INPUT_TARGET_USERNAME}:${INPUT_TARGET_TOKEN}@${target_url}"

  # Add the remote without credentials, so .git/config does not contain the token
  git remote remove target 2>/dev/null || true
  git remote add target "${clean_url}"

  # Store credentials in a temporary credential file
  printf 'https://%s:%s@%s\n' \
    "${INPUT_TARGET_USERNAME}" \
    "${INPUT_TARGET_TOKEN}" \
    "${target_url}" > "$cred_file"

  chmod 0600 "$cred_file"

  git config --global credential.helper "store --file=$cred_file"

  # Never allow Git to prompt interactively in CI
  export GIT_TERMINAL_PROMPT=0
}

case "${GITHUB_EVENT_NAME}" in
  push|create|pull_request|workflow_dispatch|workflow_run)
    git_setup
    git fetch --all --prune

    # Mirror only branches.
    git push --force --prune target 'refs/heads/*:refs/heads/*'

    # Mirror only tags.
    git push --force target 'refs/tags/*:refs/tags/*'
    ;;

  delete)
    git_setup

    case "${GITHUB_EVENT_REF_TYPE}" in
      branch)
        git push target ":refs/heads/${GITHUB_EVENT_REF}"
        ;;
      tag)
        git push target ":refs/tags/${GITHUB_EVENT_REF}"
        ;;
    esac
    ;;

  *)
    :
    ;;
esac
