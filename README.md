# Ogoron Generate Action

Generate unit, API, and UI test artifacts with Ogoron on Linux runners.

Current scope:
- `ubuntu-*` runners only
- Linux release assets only

## Required environment

Provide secrets via workflow `env`, not action inputs.

- `OGORON_REPO_TOKEN`
- `OGORON_LLM_API_KEY` when BYOK access is required

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `unit` | no | `false` | Generate unit tests from git diff. |
| `api` | no | `false` | Generate API tests using a git-scope-driven prompt workaround. |
| `ui` | no | `false` | Generate UI test cases from git diff and then generate autotests. |
| `scope` | no | current branch | Git scope, for example `commit:abc123`, `branch:feature/new-auth`, `date:2024-01-01`, `since:HEAD~5`. |
| `working-directory` | no | `.` | Repository directory where commands should run. |
| `cli-version` | no | `5.2.0` | Ogoron CLI release version to download. Versions older than `5.2.0` are rejected. |
| `download-url` | no |  | Explicit Linux bundle URL override. |
| `debug` | no | `false` | Pass `--debug` to Ogoron generation commands. |
| `create-pr` | no | `false` | Create or update a pull request when generation changes repository files. |
| `pr-branch` | no | `ogoron/generate` | Branch used for generated artifact changes. |
| `pr-title` | no | `Generate Ogoron test artifacts` | Pull request title. |
| `commit-message` | no | `Generate Ogoron test artifacts` | Commit message used for generated artifacts. |
| `author-name` | no | `ogoron-bot` | Git author name for the generated commit. |
| `author-email` | no | `agents@ogoron.com` | Git author email for the generated commit. |

## Outputs

| Output | Description |
| --- | --- |
| `ogoron-bin` | Absolute path to the downloaded Ogoron executable. |
| `git-scope` | Resolved git scope used by the action. |
| `changes-detected` | Whether generation changed repository files. |
| `pull-request-url` | URL of the created or updated pull request, if any. |
| `branch-name` | Branch name used for generated artifacts. |

## Notes

- At least one of `unit`, `api`, or `ui` must be `true`.
- `ui=true` runs two commands:
  - `ogoron generate test-cases --git-scope <scope>`
  - `ogoron generate autotests`
- `api=true` is a temporary workaround. The current CLI does not expose a first-class diff-based API generation command, so this action feeds a structured English prompt derived from `scope` into `ogoron generate api-tests`.
- When `create-pr=true`, the action commits generated changes locally and then opens or updates a pull request through `peter-evans/create-pull-request`.
