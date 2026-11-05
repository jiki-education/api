# GitHub Solution Syncing

**Status: Proposal (draft)**

This doc explores replicating Exercism's GitHub Solution Syncer in Jiki: an opt-in
feature that mirrors a user's exercise solutions to their own GitHub repository as
commits or pull requests.

## How Exercism does it

Exercism's website has two entirely separate GitHub subsystems:

1. **Content sync (read-only)** — pulls track/exercise content *from* exercism org
   repos into the database, driven by push webhooks. Nothing on the site ever opens
   PRs against exercism's own repos.
2. **Solution Syncer (write)** — pushes a user's own solutions *to their own* GitHub
   repo. This is the subsystem this doc is about.

### Setup and auth

- A dedicated GitHub App (separate from any org credentials) with `contents:
  read/write` and `pull_requests: write` permissions.
- The user installs the app on **exactly one** repo of theirs. The installation
  callback stores `installation_id` and `repo_full_name` on a
  `User::GithubSolutionSyncer` record.
- At runtime, a JWT is built from the app ID + private key and exchanged for a
  short-lived per-installation access token. All Octokit calls use that token.

### Per-user configuration

The syncer record holds:

- `enabled`
- `sync_on_iteration_creation` — sync automatically on each new iteration
- `processing_method` — enum: `commit` (straight to main) or `pull_request`
- `main_branch_name`
- `commit_message_template`
- `path_template` — default `solutions/$track_slug/$exercise_slug/$iteration_idx`

### Trigger

`Iteration::Create` checks for an enabled syncer and defers a `SyncIteration`
background job. That single hook is the entire integration with the submission flow.

### Write mechanics

Two strategies, chosen by `processing_method`:

- **Commit to main** — pure GitHub API, no local clone: `create_tree` against the
  base tree, `create_commit`, `update_ref`. No-ops if the tree is unchanged.
- **Pull request** — creates a throwaway branch (`exercism-sync/<hex>`), commits to
  it the same way, then `create_pull_request` with a generated title/body.

Bulk syncs ("sync everything" / "sync track") instead use a `--depth=1` local clone
into a tmpdir: write files, commit, push over
`https://x-access-token:<token>@github.com/...`, skipping repos over 10 MB.

Edge cases handled: empty repos are initialised and pushed a first branch; commits
are authored by a bot identity; the exercise's scaffold files can optionally be
included alongside the user's submitted files.

## Replicating it in Jiki

Jiki currently has no git/GitHub integration (no octokit in the Gemfile). But the
shape maps over cleanly, and in some ways more simply, since `ExerciseSubmission` is
already multi-file.

### 1. GitHub App

Register a "Jiki Solutions Syncer" GitHub App with `contents: read/write` and
`pull_requests: write`. Credentials go through the config gem —
`Jiki.secrets.github_syncer_app_id` and `Jiki.secrets.github_syncer_private_key` —
so a small PR to the config repo is part of the work. Add `octokit` (and `jwt`) to
the Gemfile.

### 2. Model

`User::GithubSyncer`, essentially Exercism's columns:

- `installation_id`, `repo_full_name`
- `enabled`, `sync_on_submission`
- `processing_method` (enum: `commit` / `pull_request`)
- `main_branch_name`, `commit_message_template`, `path_template`

Path template variables would be Jiki-shaped: `$course_slug/$level_slug/$lesson_slug`,
plus a variant for challenges — `ExerciseSubmission#context` is polymorphic
(`UserLesson` or `UserChallenge`), so the path builder needs a branch for each.

### 3. Commands

Under `app/commands/user/github_syncer/`, near-direct ports:

- `Create` / `Destroy` — installation callback handling, validating the installation
  covers exactly one repo.
- `GithubApp` — JWT → installation-token exchange.
- `SyncSubmission` — builds the file list from `submission.files` (filename +
  attached blob content), then delegates to `CreateCommit` or `CreatePullRequest`.
- `CreateCommit` / `CreatePullRequest` / `FindOrCreateBranch` — the Octokit
  tree/commit/ref dance, directly reusable from Exercism's implementation.
- Optionally `SyncEverything`, using the shallow-clone approach for backfills.

### 4. Trigger

One line in `ExerciseSubmission::Create`'s tap block:

```ruby
User::GithubSyncer::SyncSubmission.defer(submission)
```

when the user has an enabled syncer. The existing `MandateJob` + blanket `retry_on`
gives async execution and retries.

### 5. Controllers

- `Internal::GithubSyncerController` — settings CRUD plus manual sync endpoints.
- A callback endpoint for the GitHub App installation redirect. It carries an
  `installation_id` and must associate with the logged-in user, so it likely lives
  in `Internal::` with the frontend handling the redirect.

## Open design question: when to sync

Exercism syncs *iterations* — deliberate "I'm done, submit" moments. Jiki's
`ExerciseSubmission::Create` runs on every submit, and each submit is a whole new
record with no iteration numbering. If the frontend submits frequently (e.g. on
every run), commit-per-submission would be very noisy.

Options:

1. Trigger only on lesson/challenge completion (hook `UserLesson::Complete`
   instead), syncing the latest submission at that point. **Probably the right
   default.**
2. Debounce submission-triggered syncs.
3. Sync every submission and accept the noise (closest to Exercism's behaviour).

## Rough size

One migration, ~8 small commands, a controller, a config-gem PR, and the GitHub App
registration.
