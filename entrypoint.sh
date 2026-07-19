#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '%s\n' "$*"
}

error() {
  printf 'ERROR: %s\n' "$*" >&2
}

log "Event: ${GITHUB_EVENT_NAME}"

git_setup() {
  local target_url="${INPUT_TARGET_URL:-}"
  local target_username="${INPUT_TARGET_USERNAME:-}"
  local target_token="${INPUT_TARGET_TOKEN:-}"
  local target_host_path
  local cred_file

  if [ -z "$target_url" ]; then
    error "target URL is required."
    exit 1
  fi

  if [ -z "$target_username" ]; then
    error "target username is required."
    exit 1
  fi

  if [ -z "$target_token" ]; then
    error "target token is required."
    exit 1
  fi

  case "$target_url" in
    https://*)
      ;;
    *)
      error "only https:// target URLs are supported."
      exit 1
      ;;
  esac

  target_host_path="${target_url#https://}"
  cred_file="${RUNNER_TEMP:-/tmp}/git-credentials"

  # Mask secrets before anything can print them.
  echo "::add-mask::${target_token}"
  echo "::add-mask::${target_username}:${target_token}"
  echo "::add-mask::https://${target_username}:${target_token}@${target_host_path}"

  log "Configuring target remote..."

  # Add the remote without credentials, so .git/config does not store the token.
  git remote remove target 2>/dev/null || true
  git remote add target "$target_url"

  log "Configuring temporary Git credentials..."

  # Store credentials only in a temporary file for this job.
  printf 'https://%s:%s@%s\n' \
    "$target_username" \
    "$target_token" \
    "$target_host_path" > "$cred_file"

  chmod 0600 "$cred_file"

  git config --global credential.helper "store --file=$cred_file"

  export GIT_TERMINAL_PROMPT=0
}

retry() {
  local attempt=1
  local attempts=4
  local delay=5
  local output
  local status

  while :; do
    output=$(mktemp "${RUNNER_TEMP:-/tmp}/gitlab-sync.XXXXXX")

    if "$@" 2>&1 | tee "$output"; then
      rm -f "$output"
      return 0
    else
      status=${PIPESTATUS[0]}
    fi

    if (( attempt >= attempts )) || ! grep -Eqi \
      'GitLab: Internal API error \(5[0-9]{2}\)|requested URL returned error: 5[0-9]{2}|HTTP[^0-9]+5[0-9]{2}|5[0-9]{2} (Internal Server Error|Bad Gateway|Service Unavailable|Gateway Time-?out)' \
      "$output"; then
      rm -f "$output"
      return "$status"
    fi

    rm -f "$output"

    (( attempt++ ))

    log "Transient server error detected; retrying in ${delay} seconds (attempt ${attempt}/${attempts})..."
    sleep "$delay"

    (( delay *= 2 ))
  done
}

sync_refs() {
  log "Fetching refs..."
  retry git fetch --all --prune

  log "Pushing branches..."
  retry git push --force --prune target \
    'refs/heads/*:refs/heads/*'

  log "Pushing tags..."
  retry git push --force target \
    'refs/tags/*:refs/tags/*'
}

delete_ref() {
  local ref="${GITHUB_EVENT_REF:-}"
  local ref_type="${GITHUB_EVENT_REF_TYPE:-}"

  if [ -z "$ref" ]; then
    error "GITHUB_EVENT_REF is empty."
    exit 1
  fi

  case "$ref_type" in
    branch)
      ref="${ref#refs/heads/}"
      log "Deleting branch: ${ref}"
      retry git push target ":refs/heads/${ref}"
      ;;
    tag)
      ref="${ref#refs/tags/}"
      log "Deleting tag: ${ref}"
      retry git push target ":refs/tags/${ref}"
      ;;
    *)
      error "unsupported or empty GITHUB_EVENT_REF_TYPE: ${ref_type}"
      exit 1
      ;;
  esac
}

case "${GITHUB_EVENT_NAME}" in
  push|create|workflow_dispatch|workflow_run)
    git_setup
    sync_refs
    ;;

  delete)
    git_setup
    delete_ref
    ;;

  *)
    log "Nothing to sync for event: ${GITHUB_EVENT_NAME}"
    ;;
esac
