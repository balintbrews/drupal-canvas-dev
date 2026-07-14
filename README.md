# `drupal-canvas-dev`

An opinionated development environment for brewing
[Drupal Canvas](https://www.drupal.org/project/canvas), built with
[DDEV](https://ddev.com/). I maintain this project to use for my day-to-day
development work, with workflows and tools I prefer.

## Setup

1. Clone the repository
2. Run:
   ```
   ddev start \
     && ddev clone-repo \
     && ddev clone-repo-mercury \
     && ddev composer install \
     && ddev site-install \
     && ddev launch \
     && ddev ui --install
   ```

## Canvas worktree setup

Use `scripts/create-worktree.sh` to work on a Canvas branch from
`web/modules/contrib/canvas` as a standalone project. Pass a branch name, and
the script derives everything else:

```bash
scripts/create-worktree.sh 880922-my-branch
```

This creates the branch from `origin/1.x` and a worktree at
`../canvas-worktrees/880922-my-branch/canvas` when they do not exist yet, and
reuses them when they do. The same command works for creating, resuming, and
repairing a setup. When the branch already exists locally or is checked out in
another worktree, the script uses it as is.

The default Canvas starting point is `origin/1.x`. Pass `--base-ref=<ref>` to
use another ref. The base ref can be a remote branch, local branch, tag, or
commit SHA. Pass `--worktrees-root=<path>` to change where derived worktrees
are created. Run the script with `--help` for the full list of options.

The script also accepts a Drupal.org merge request URL:

```bash
scripts/create-worktree.sh https://git.drupalcode.org/project/canvas/-/merge_requests/1353
```

This resolves the merge request to its issue-fork branch, adds the fork as a
Git remote named `canvas-<issue-id>` when needed, and creates the branch
tracking it. When the branch already exists locally, it is reused as is.

By default, the script also runs the DDEV setup:

```bash
ddev start
ddev composer install
ddev site-install
```

Pass `--ui` to run `ddev site-install --ui` instead, which also builds the UI.
Note that `ddev site-install` reinstalls the Drupal site.

When a coding tool creates the Canvas worktree, use the same script with
`--canvas-worktree` in the tool setup hook, replacing `SOURCE_TREE_PATH` and
`WORKTREE_PATH` with the environment variables provided by the tool:

```bash
set -euo pipefail

SOURCE_ENV="$(cd "$SOURCE_TREE_PATH/../../../.." && pwd)"

"$SOURCE_ENV/scripts/create-worktree.sh" \
  --canvas-worktree="$WORKTREE_PATH"
```

After the Canvas worktree exists, the script creates an environment
wrapper next to it, writes a unique ignored DDEV project name, mounts the
Canvas worktree into DDEV at `web/modules/contrib/canvas`, and creates
`.ddev-env` inside the Canvas worktree as a symlink back to the environment
wrapper.

To create and wrap the worktree without running DDEV setup, pass
`--skip-ddev`.

After setup, the environment wrapper is available from the Canvas worktree:

```bash
cd .ddev-env
```

When done with a branch, use `scripts/destroy-worktree.sh` to tear the
setup down. This deletes the DDEV project including its containers and
database, then removes the environment wrapper, the Mercury worktree, and the
Canvas worktree. The branch is kept by default; pass `--delete-branch` to
delete it as well:

```bash
scripts/destroy-worktree.sh 880922-my-branch
```

## DDEV project name

The DDEV project name is derived from the checkout directory because
`.ddev/config.yaml` does not set `name`. This keeps Git worktrees independent: a
checkout in `canvas-env` uses `https://canvas-env.ddev.site`, and a worktree in
`canvas-env-issue-123` uses `https://canvas-env-issue-123.ddev.site`.

Use ignored local overrides in `.ddev/config.local.yaml` only when a checkout
needs a specific project name.

## Agent setup

This project uses two agent configuration scopes:

- Environment scope for root-level tooling and infrastructure tasks.
- Canvas scope for module code work in `web/modules/contrib/canvas`.

For details on workspace entrypoints and skill locations, see
`agents/README.md`.

Running `ddev clone-repo` also wires the Canvas agent files in the nested
repository by creating symlinks for `AGENTS.md` and `.agents/skills`, and by
adding local-only nested-repo excludes for `AGENTS.md` and `.agents/` in
`.git/info/exclude`.

## Commands

| Command                 | Description                                                                                                                                                                                                                                                                                                   |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `n`                     | Run `npm` inside the UI directory.<br><br>`--canvas-dir=<directory>`: runs `npm` inside specified directory<br>(`root`, `ui`, `astro`, `cli`, or `docs`)                                                                                                                                                      |
| `ui`                    | Build the UI code and start the dev server.<br><br>`--install` `-i`: runs `npm install` before<br>`--skip-build` `-s`: skips the build step                                                                                                                                                                   |
| `playwright`            | Run Playwright in UI mode.<br>(Accessible via VNC at `https://<project-name>.ddev.site:6081/vnc.html`)<br><br>`--spec <path-to-spec>`: runs a spec in headless mode                                                                                                                                           |
| `cy`,<br>`cypress`      | Run the Cypress UI in end-to-end testing mode<br>(Accessible via VNC at `https://<project-name>.ddev.site:6081/vnc.html`)<br><br>`--spec <path-to-spec>`: runs a spec in headless mode<br>`--component` `-c`: use component testing mode                                                                      |
| `phpunit [path]`        | Run PHPUnit tests in the module's codebase<br><br>`[path]`: narrows to the path, relative to the module directory                                                                                                                                                                                             |
| `phpcs [path]`          | Run PHP Code Beautifier and Fixer in the module's codebase<br><br>`[path]`: narrows to the path, relative to the module directory                                                                                                                                                                             |
| `phpstan`               | Run PHPStan in the module's codebase                                                                                                                                                                                                                                                                          |
| `si`,<br>`site-install` | Install Drupal site, install and configure modules: Canvas and Canvas OAuth.<br><br>`--ui`: also installs Canvas Vite for UI development<br>`--mercury` `-m`: applies the Mercury recipe instead of the Stark and Humanify recipes<br>`--stark`: skips the Humanify recipe, and creates an empty page |
| `clone-repo`            | Clone the Canvas module's repository, add local nested-repo excludes for `AGENTS.md` and `.agents/`, and set symlinks for `AGENTS.md` and `.agents/skills`. (Runs on the host.)                                                                                                                               |
| `clone-repo-mercury`    | Clone the Mercury theme's repository. (Runs on the host.)                                                                                                                                                                                                                                                     |

See the [list of commands](https://docs.ddev.com/en/stable/users/usage/cli/)
provided by DDEV out-of-the box.

## Scripts

| Script                               | Description                                                                               |
| ------------------------------------ | ----------------------------------------------------------------------------------------- |
| `scripts/create-worktree.sh`   | Create or set up a Canvas worktree with an environment wrapper and DDEV bind mount.       |
| `scripts/destroy-worktree.sh` | Tear down a Canvas worktree setup, including its DDEV project, containers, and database.  |
| `scripts/wrap-canvas-worktree.sh`    | Wrap an existing Canvas worktree with a sibling environment worktree and DDEV bind mount. |
| `scripts/wire-canvas-agents.sh`      | Wire local Canvas `AGENTS.md` and `.agents/skills` into a Canvas checkout or worktree.    |
| `scripts/install-canvas-packages.sh` | Build and install local Canvas package tarballs into a target project.                    |

## Export with Default Content

Use `ddev drush dcer` to export specific entities to recipe content folders.

Export a `canvas_page` entity:

```bash
ddev drush dcer canvas_page 1 --folder=../recipes/canvas_dev_humanify/content
```

Export a `menu_link_content` entity:

```bash
ddev drush dcer menu_link_content 1 --folder=../../recipes/canvas_dev_humanify/content
```

## Credits

My work on Drupal Canvas is made possible by [Acquia](https://www.acquia.com).
