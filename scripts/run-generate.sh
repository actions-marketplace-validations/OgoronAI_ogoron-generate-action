#!/usr/bin/env bash
set -euo pipefail

git config user.name "${INPUT_AUTHOR_NAME:-ogoron-bot}"
git config user.email "${INPUT_AUTHOR_EMAIL:-agents@ogoron.com}"

commit_if_changes() {
  local message="$1"
  if [[ -z "$(git status --porcelain)" ]]; then
    return 1
  fi

  git add -A
  git commit -m "${message}" >/dev/null
  return 0
}

resolve_git_scope() {
  local raw="${INPUT_SCOPE:-}"
  if [[ -n "${raw}" ]]; then
    printf '%s\n' "${raw}"
    return 0
  fi

  local branch_name="${GITHUB_HEAD_REF:-${GITHUB_REF_NAME:-}}"
  if [[ -z "${branch_name}" ]]; then
    branch_name="$(git rev-parse --abbrev-ref HEAD)"
  fi
  printf 'branch:%s\n' "${branch_name}"
}

git_scope="$(resolve_git_scope)"
debug_flag=()
if [[ "${INPUT_DEBUG:-false}" == "true" ]]; then
  debug_flag+=(--debug)
fi

selected=0
if [[ "${INPUT_UNIT:-false}" == "true" ]]; then
  selected=1
fi
if [[ "${INPUT_API:-false}" == "true" ]]; then
  selected=1
fi
if [[ "${INPUT_UI:-false}" == "true" ]]; then
  selected=1
fi

if [[ "${selected}" -ne 1 ]]; then
  echo "At least one of unit/api/ui must be true." >&2
  exit 2
fi

runtime_dir="$(dirname "${OGORON_BIN}")"
export PATH="${runtime_dir}:${PATH}"

if [[ "${INPUT_UNIT:-false}" == "true" ]]; then
  ogoron generate unit-tests --from-diff --git-scope "${git_scope}" "${debug_flag[@]}"
fi

if [[ "${INPUT_API:-false}" == "true" ]]; then
  api_entry="Changed API surface from git scope ${git_scope}"
  api_description="Study the repository changes in git scope ${git_scope}. Infer the API entrypoints and behaviors affected by those changes. Generate API tests only for the changed API surface, prioritizing request/response contracts, authentication, authorization, validation, and backward-compatibility risks."
  ogoron generate api-tests --entry "${api_entry}" --description "${api_description}" "${debug_flag[@]}"
fi

if [[ "${INPUT_UI:-false}" == "true" ]]; then
  ogoron generate test-cases --git-scope "${git_scope}" "${debug_flag[@]}"
  ogoron generate autotests "${debug_flag[@]}"
fi

changes_detected="false"
if commit_if_changes "Generate Ogoron test artifacts"; then
  changes_detected="true"
elif [[ -n "$(git status --porcelain)" ]]; then
  changes_detected="true"
fi

pr_body_path="${RUNNER_TEMP:-/tmp}/ogoron-generate-pr-body.md"
cat > "${pr_body_path}" <<EOF
## What Ogoron generated

This PR contains repository changes produced by the \`generate\` action.

## Requested generation scope

- git scope: \`${git_scope}\`
- unit: \`${INPUT_UNIT:-false}\`
- api: \`${INPUT_API:-false}\`
- ui: \`${INPUT_UI:-false}\`

## Commands used

$(if [[ "${INPUT_UNIT:-false}" == "true" ]]; then echo "- \`ogoron generate unit-tests --from-diff --git-scope ${git_scope}\`"; fi)
$(if [[ "${INPUT_API:-false}" == "true" ]]; then echo "- \`ogoron generate api-tests\` with a git-scope-driven prompt"; fi)
$(if [[ "${INPUT_UI:-false}" == "true" ]]; then echo "- \`ogoron generate test-cases --git-scope ${git_scope}\`"; fi)
$(if [[ "${INPUT_UI:-false}" == "true" ]]; then echo "- \`ogoron generate autotests\`"; fi)

## Review notes

- Review generated tests before merge.
- Prefer merging narrow, feature-scoped changes.
- If generation touched unexpected areas, refine the git scope and rerun the action.
EOF

{
  echo "git-scope=${git_scope}"
  echo "changes-detected=${changes_detected}"
  echo "pr-body-path=${pr_body_path}"
} >> "${GITHUB_OUTPUT}"
