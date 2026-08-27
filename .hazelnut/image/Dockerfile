FROM ghcr.io/balintbrews/hazelnut-foundation:1.0.0@sha256:82e435bd483925315d813924b66a1b8ee3967db1cba843605d2e8c8bcd5b5a67

USER root

ENV CANVAS_ENV_ROOT=${HAZELNUT_WORKSPACE_DIR}/drupal

# Drupal Canvas CI runs PHP 8.3, while Debian Trixie provides PHP 8.4.
RUN install -d -m 0755 /etc/apt/keyrings \
 && curl -fsSL https://packages.sury.org/php/apt.gpg \
    | gpg --dearmor -o /etc/apt/keyrings/deb.sury.org-php.gpg \
 && printf '%s\n' \
    'deb [signed-by=/etc/apt/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ trixie main' \
    >/etc/apt/sources.list.d/php.list \
 && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
 && printf '%s\n' \
    'deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_24.x nodistro main' \
    >/etc/apt/sources.list.d/nodesource.list \
 && apt-get update \
 && env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      build-essential \
      libasound2 \
      libgbm1 \
      libgtk-3-0 \
      libnotify4 \
      libnss3 \
      libxss1 \
      libxtst6 \
      mariadb-server \
      nodejs \
      patch \
      php8.3-cli \
      php8.3-curl \
      php8.3-gd \
      php8.3-intl \
      php8.3-mbstring \
      php8.3-mysql \
      php8.3-opcache \
      php8.3-readline \
      php8.3-xml \
      php8.3-zip \
      pkg-config \
      python3 \
      rsync \
      xauth \
      xvfb \
      zip \
 && rm -rf /var/lib/apt/lists/* \
 && npm install --global npm@11.18.0 \
 && corepack enable

# Install the current stable Composer 2 release and verify its installer.
RUN EXPECTED_CHECKSUM="$(curl -fsSL https://composer.github.io/installer.sig)" \
 && curl -fsSL https://getcomposer.org/installer -o /tmp/composer-setup.php \
 && ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', '/tmp/composer-setup.php');")" \
 && test "$EXPECTED_CHECKSUM" = "$ACTUAL_CHECKSUM" \
 && php /tmp/composer-setup.php --quiet --install-dir=/usr/local/bin --filename=composer \
 && rm /tmp/composer-setup.php

# Keep the local database private to the container and tune PHP for development.
RUN printf '%s\n' \
      '[mysqld]' \
      'bind-address = 127.0.0.1' \
    >/etc/mysql/mariadb.conf.d/99-canvas-env.cnf \
 && printf '%s\n' \
      'memory_limit = -1' \
      'opcache.enable_cli = 1' \
    >/etc/php/8.3/cli/conf.d/99-canvas-env.ini \
 && install -d -m 0755 "$CANVAS_ENV_ROOT/web/modules/contrib"

# The Drupal environment is baked into the image. Hazelnut clones Canvas into
# the session workspace, which is linked into Composer's expected module path.
COPY composer.json composer.lock ${CANVAS_ENV_ROOT}/
COPY recipes/ ${CANVAS_ENV_ROOT}/recipes/
COPY check-repo.sh ${CANVAS_ENV_ROOT}/scripts/check-repo.sh
COPY web/sites/default/settings.php ${CANVAS_ENV_ROOT}/web/sites/default/settings.php
COPY bin/ /usr/local/bin/

RUN jq '.scripts["pre-install-cmd"] = ["./scripts/check-repo.sh"]' \
      "$CANVAS_ENV_ROOT/composer.json" >/tmp/composer.json \
 && mv /tmp/composer.json "$CANVAS_ENV_ROOT/composer.json" \
 && chown -R "$USER:$USER" "$CANVAS_ENV_ROOT" "$HOME/.config" \
 && chmod 0755 "$CANVAS_ENV_ROOT/scripts/check-repo.sh" \
      /usr/local/bin/canvas-env-* /usr/local/bin/cypress \
      /usr/local/bin/n /usr/local/bin/phpcs /usr/local/bin/phpstan \
      /usr/local/bin/phpunit /usr/local/bin/playwright /usr/local/bin/site-install \
      /usr/local/bin/ui \
 && ln -s cypress /usr/local/bin/cy \
 && ln -s site-install /usr/local/bin/si

USER ${USER}

ENV COMPOSER_MEMORY_LIMIT=-1 \
    CYPRESS_CACHE_FOLDER=${CANVAS_ENV_ROOT}/.cache/cypress \
    DRUPAL_TEST_BASE_URL=http://127.0.0.1:8080 \
    DRUPAL_TEST_DB_URL=mysql://db:db@127.0.0.1:3306/db \
    DRUSH_OPTIONS_URI=http://127.0.0.1:8080 \
    NODE_OPTIONS=--max-old-space-size=4096 \
    npm_config_cache=${CANVAS_ENV_ROOT}/.cache/npm \
    SIMPLETEST_BASE_URL=http://127.0.0.1:8080 \
    SIMPLETEST_DB=mysql://db:db@127.0.0.1:3306/db \
    VITE_SERVER_ORIGIN=http://127.0.0.1:5173 \
    PATH=${CANVAS_ENV_ROOT}/vendor/bin:${PATH}

EXPOSE 8080 5173

WORKDIR ${CANVAS_ENV_ROOT}
