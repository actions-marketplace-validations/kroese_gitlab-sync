#!/usr/bin/env bash
set -e

echo "${GITHUB_EVENT_NAME}"

function git-setup() {
  printf -v url "https://%s:%s@%s" \
    "${INPUT_TARGET_USERNAME}" \
    "${INPUT_TARGET_TOKEN}" \
    "${INPUT_TARGET_URL#https://}"
  echo "git remote add target ${url}"
  git remote add target "${url}"
  set -x
}

case "${GITHUB_EVENT_NAME}" in
push|create|pull_request|workflow_dispatch|workflow_run)
  git-setup
  git fetch --all
  git push -f --all target
  git push -f --prune target
  git push -f --tags target
    ;;
delete)
  git-setup
  git push -d target "${GITHUB_EVENT_REF}"
    ;;
*)
  #break
esac

