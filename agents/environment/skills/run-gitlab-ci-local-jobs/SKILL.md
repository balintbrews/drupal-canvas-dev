---
name: run-gitlab-ci-local-jobs
description:
  Run GitLab CI jobs locally with gitlab-ci-local in Drupal project repos that
  use Drupal.org's GitLab template. Use when the user asks to run a CI stage/job
  locally, reproduce CI failures, or inspect job output.
---

# Run GitLab CI jobs locally

Use this skill when a user asks to run a GitLab CI job or stage with
`gitlab-ci-local`.

## Scope

- Run from the repository containing `.gitlab-ci.yml`.
- For Drupal projects using `gitlab_templates`, always set:
  - `--remote-variables`
  - `_GITLAB_TEMPLATES_REPO=project/gitlab_templates`

## Standard commands

Run a stage:

```bash
npx gitlab-ci-local \
  --remote-variables git@git.drupal.org:project/gitlab_templates=includes/include.drupalci.variables.yml=main \
  --variable "_GITLAB_TEMPLATES_REPO=project/gitlab_templates" \
  --stage <stage-name>
```

Run one job:

```bash
npx gitlab-ci-local \
  --remote-variables git@git.drupal.org:project/gitlab_templates=includes/include.drupalci.variables.yml=main \
  --variable "_GITLAB_TEMPLATES_REPO=project/gitlab_templates" \
  "<job-name>"
```

List jobs:

```bash
npx gitlab-ci-local --list
```

## Output handling

- Capture and report:
  - first failing job name,
  - root error block,
  - whether failure is include/bootstrap vs actual job logic.
- If output is large, save and inspect relevant sections only.

## Cleanup (required)

`gitlab-ci-local` may modify tracked files and generate local artifacts. After
the run, clean up unless the user asks to keep them.

1. Check status:

```bash
git status --short
```

2. Restore tracked files changed by CI run:

```bash
git restore -- .gitattributes .gitignore composer.json build/main.min.css
```

3. Remove common generated files/directories if present:

```bash
rm -rf .gitlab-ci-local recipes web
rm -f build.env composer.lock composer.json.backup expand_composer_json.php get-file-via-curl.sh .editorconfig
```

4. Confirm only intentional changes remain:

```bash
git status --short
```

## Troubleshooting

- `gitlab-ci-local: command not found`:
  - use `npx gitlab-ci-local ...`
- include fetch errors with empty project namespace:
  - ensure `--remote-variables ...include.drupalci.variables.yml...`
  - ensure `--variable "_GITLAB_TEMPLATES_REPO=project/gitlab_templates"`
- next-major composer failures after template updates:
  - check whether `OPT_IN_TEST_NEXT_MAJOR: "1"` is enabled in `.gitlab-ci.yml`.
