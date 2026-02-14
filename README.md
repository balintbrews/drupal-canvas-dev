# `drupal-canvas-dev`

An opinionated development environment for brewing
[Drupal Canvas](https://www.drupal.org/project/canvas), built with
[DDEV](https://ddev.com/). I maintain this project to use for my day-to-day
development work, with workflows and tools I prefer.

## Setup

1. Clone the repository
2. Copy `.ddev/.env.example` to `.ddev/.env`
   1. Add your [OpenAI API key](https://platform.openai.com) to be used by the
      Canvas AI module
3. Run:
   ```
   ddev start \
     && ddev clone-repo \
     && ddev clone-repo-mercury \
     && ddev composer install \
     && ddev site-install \
     && ddev launch \
     && ddev ui --install
   ```

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
| `playwright`            | Run Playwright in UI mode.<br>(Accessible via VNC at `https://canvas.ddev.site:6081/vnc.html`)<br><br>`--spec <path-to-spec>`: runs a spec in headless mode                                                                                                                                                   |
| `cy`,<br>`cypress`      | Run the Cypress UI in end-to-end testing mode<br>(Accessible via VNC at `https://canvas.ddev.site:6081/vnc.html`)<br><br>`--spec <path-to-spec>`: runs a spec in headless mode<br>`--component` `-c`: use component testing mode                                                                              |
| `phpunit [path]`        | Run PHPUnit tests in the module's codebase<br><br>`[path]`: narrows to the path, relative to the module directory                                                                                                                                                                                             |
| `phpcs [path]`          | Run PHP Code Beautifier and Fixer in the module's codebase<br><br>`[path]`: narrows to the path, relative to the module directory                                                                                                                                                                             |
| `phpstan`               | Run PHPStan in the module's codebase                                                                                                                                                                                                                                                                          |
| `si`,<br>`site-install` | Install Drupal site, install and configure modules: Canvas, Canvas AI, Canvas OAuth.<br><br>`--ui`: also installs Canvas Vite for UI development<br>`--mercury` `-m`: applies the Mercury recipe instead of the Stark and Humanify recipes<br>`--stark`: skips the Humanify recipe, and creates an empty page |
| `clone-repo`            | Clone the Canvas module's repository, add local nested-repo excludes for `AGENTS.md` and `.agents/`, and set symlinks for `AGENTS.md` and `.agents/skills`. (Runs on the host.)                                                                                                                               |
| `clone-repo-mercury`    | Clone the Mercury theme's repository. (Runs on the host.)                                                                                                                                                                                                                                                     |

See the [list of commands](https://docs.ddev.com/en/stable/users/usage/cli/)
provided by DDEV out-of-the box.

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
