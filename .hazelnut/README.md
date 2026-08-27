# Drupal Canvas Hazelnut project definition

This directory is self-contained and can be moved to a separate
project-definition repository. The `image` directory is the complete Docker
build context; its Dockerfile does not copy files from outside that directory.

## GitLab credential

The `GITLAB_PAT` credential is a fine-grained Drupal GitLab personal access
token. Create it on the
[personal access tokens settings page](https://git.drupalcode.org/-/user_settings/personal_access_tokens?type=fine_grained).
Drupal issue forks are separate, dynamically created GitLab projects, so its
resource boundary is **All groups and projects that I'm a member of**.

Configure these resource permissions under **Group and project**:

- **Project Planning**
  - Work Item: Create
  - Work Item: Read
  - Work Item: Update
- **Projects**
  - Project: Fork
  - Project: Read
- **Repository**
  - Branch: Read
  - Code: Download
  - Code: Push
  - Code: Read
  - Merge Request: Create
  - Merge Request: Read
  - Merge Request: Update
- **CI/CD**
  - Job: Read
  - Job: Run
  - Job Artifact: Read
  - Pipeline: Read
  - Pipeline: Update

Configure these resource permissions under **User**:

- **Groups**
  - Namespace: Read
- **System Access**
  - User: Read

Do not grant any **Global** permissions. Pipeline creation is intentionally not
granted: pushes trigger pipelines, while Pipeline: Update permits pipeline
retries. Work Item permissions cover ordinary issue and merge request comments;
the separate Note resource is not required.

Store the generated token only in the ignored, mode-`0600` `secrets.env` file:

```dotenv
GITLAB_PAT=<token>
```

Build the image locally from this directory:

```bash
docker build --platform linux/amd64 -t canvas-env:local image
```

The image stores the Drupal environment at `$HAZELNUT_WORKSPACE_DIR/drupal`. At
runtime, `canvas-env-init` moves the Canvas checkout Hazelnut cloned to
`$HAZELNUT_WORKSPACE_DIR/$HAZELNUT_PROJECT_NAME` into Drupal's
`web/modules/contrib/canvas` path and leaves a symlink at the workspace path.
The checkout must physically live inside the Drupal tree because Canvas
tooling locates Drupal by walking up parent directories. `canvas-env-start` also runs a virtual
display with a VNC bridge; headed Cypress and Playwright sessions can be watched
at `http://localhost:6080/vnc.html`. The Cypress binary and the Playwright
Chromium browser are baked into the image; their versions are pinned as build
arguments in the Dockerfile and must be kept in sync with what the Canvas
repository resolves.

To test with a local Canvas checkout:

```bash
docker run -d \
  --name canvas-env-test \
  --platform linux/amd64 \
  -p 8080:8080 \
  -p 5173:5173 \
  -p 6080:6080 \
  -e HAZELNUT_PROJECT_NAME=canvas \
  -v "/path/to/canvas:/home/hazelnut/workspace/drupal/web/modules/contrib/canvas" \
  canvas-env:local \
  canvas-env-start sleep infinity

docker exec canvas-env-test composer install --no-interaction
docker exec canvas-env-test site-install --stark
docker exec -d canvas-env-test canvas-env-start
```

Mount a clean clone rather than a working checkout: `node_modules` installed on
the host contain platform-specific binaries that fail inside the container.

Open `http://localhost:8080` and sign in with `admin` as both the username and
password. Remove the container when finished:

```bash
docker rm -f canvas-env-test
```
