---
name: canvas-gitlab-cli
description:
  Use glab with Drupal Canvas on Drupal's GitLab instance. Use when Codex needs
  to inspect or act on Canvas GitLab issues, merge requests, branches, diffs,
  project metadata, authentication state, or repository cloning for
  git.drupalcode.org/project/canvas.
---

# Canvas GitLab CLI

Use this skill for Drupal Canvas GitLab operations through `glab`.

## Constants

- Web/API host: `git.drupalcode.org`
- Repo for `glab --repo`: `https://git.drupalcode.org/project/canvas.git`
- Project path: `project/canvas`
- Default branch: `1.x`
- SSH Git remote: `git@git.drupal.org:project/canvas.git`

Keep the Web/API host and SSH host distinct. Do not rewrite
`git.drupalcode.org` to `git.drupal.org` except for SSH Git remotes.

## Authentication

Before using authenticated operations, check:

```sh
glab auth status --hostname git.drupalcode.org
```

If auth is missing, ask the user to authenticate. Do not request, print, store,
or commit tokens. The expected setup is keyring-backed auth with HTTPS API calls
and SSH Git operations:

```sh
glab auth login \
  --hostname git.drupalcode.org \
  --api-protocol https \
  --git-protocol ssh \
  --ssh-hostname git.drupal.org \
  --use-keyring
```

## Repository access

When outside a Canvas checkout, always pass the full repo URL:

```sh
glab issue list --repo https://git.drupalcode.org/project/canvas.git
glab mr list --repo https://git.drupalcode.org/project/canvas.git
```

Prefer the full URL in scripts and agent commands even when the current
checkout could infer the repository. It avoids ambiguity with the custom Drupal
GitLab host.

To clone Canvas, use the default branch explicitly:

```sh
glab repo clone https://git.drupalcode.org/project/canvas.git canvas -- --branch 1.x
```

## Common workflows

Only run commands that mutate GitLab state, such as posting notes or creating
merge requests, when the user has asked for that action.

Inspect project metadata:

```sh
glab repo view https://git.drupalcode.org/project/canvas.git --output json
```

Inspect an issue:

```sh
glab issue view <issue-id> --repo https://git.drupalcode.org/project/canvas.git
glab issue note <issue-id> --repo https://git.drupalcode.org/project/canvas.git --message '<message>'
```

Inspect a merge request:

```sh
glab mr view <mr-id> --repo https://git.drupalcode.org/project/canvas.git
glab mr diff <mr-id> --repo https://git.drupalcode.org/project/canvas.git
glab mr checkout <mr-id> --repo https://git.drupalcode.org/project/canvas.git
```

Create a merge request:

```sh
glab mr create \
  --repo https://git.drupalcode.org/project/canvas.git \
  --target-branch 1.x \
  --source-branch <branch-name> \
  --title '<title>' \
  --description '<description>'
```

Before starting work from an issue or merge request, gather context with the
issue or MR view command, then check related MRs, branches, and diffs as needed.
Use `1.x` as the target branch unless the user or issue explicitly says
otherwise. Never compare, diff, or validate work against `7.x-1.x`.
