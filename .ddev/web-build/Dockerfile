# The DDEV base image ships /usr/local/bin, /usr/sbin, and /usr/bin as
# world-writable (777). dpkg hard-codes those directories in the PATH it
# gives to postinst scripts, and the novnc postinst calls adduser which
# runs Perl in taint mode (-T). Perl rejects any world-writable directory
# in PATH, so the install fails. Temporarily tighten permissions, install
# novnc, then restore the original modes.
RUN chmod 755 /usr/local/bin /usr/sbin /usr/bin \
    && find /etc/apt/trusted.gpg.d /usr/share/keyrings -type f \( -iname '*sury*' -o -iname '*php*' \) -delete \
    && curl -fsSL https://packages.sury.org/php/apt.gpg -o /usr/share/keyrings/deb.sury.org-php.gpg \
    && cp /usr/share/keyrings/deb.sury.org-php.gpg /etc/apt/trusted.gpg.d/deb.sury.org-php.gpg \
    && DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    --no-install-recommends --no-install-suggests novnc \
    && chmod 777 /usr/local/bin /usr/sbin /usr/bin
