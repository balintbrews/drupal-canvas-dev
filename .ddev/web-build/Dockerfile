# The DDEV base image ships /usr/local/bin, /usr/sbin, and /usr/bin as
# world-writable (777). dpkg hard-codes those directories in the PATH it
# gives to postinst scripts, and the novnc postinst calls adduser which
# runs Perl in taint mode (-T). Perl rejects any world-writable directory
# in PATH, so the install fails. Temporarily tighten permissions, install
# novnc, then restore the original modes.
RUN chmod 755 /usr/local/bin /usr/sbin /usr/bin \
    && DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    --no-install-recommends --no-install-suggests novnc \
    && chmod 777 /usr/local/bin /usr/sbin /usr/bin
