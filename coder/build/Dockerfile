FROM codercom/enterprise-base:ubuntu

USER root

# ── System packages ────────────────────────────────────────────────────────────
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
      gnupg gosu curl ca-certificates zip unzip git supervisor sqlite3 \
      libcap2-bin libpng-dev python3 dnsutils librsvg2-bin fswatch ffmpeg nano \
      tmux && \
    rm -rf /var/lib/apt/lists/*

# ── PHP (ondrej/php PPA) ───────────────────────────────────────────────────────
RUN mkdir -p /etc/apt/keyrings && \
    curl -sS 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xb8dc7e53946656efbce4c1dd71daeaab4ad4cab6' \
      | gpg --dearmor | tee /etc/apt/keyrings/ppa_ondrej_php.gpg > /dev/null && \
    echo "deb [signed-by=/etc/apt/keyrings/ppa_ondrej_php.gpg] https://ppa.launchpadcontent.net/ondrej/php/ubuntu noble main" \
      > /etc/apt/sources.list.d/ppa_ondrej_php.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      libgd3 \
      php8.5-cli \
      php8.5-dev \
      php8.5-pgsql \
      php8.5-sqlite3 \
      php8.5-gd \
      php8.5-curl \
      php8.5-mongodb \
      php8.5-imap \
      php8.5-mysql \
      php8.5-mbstring \
      php8.5-xml \
      php8.5-zip \
      php8.5-bcmath \
      php8.5-soap \
      php8.5-intl \
      php8.5-readline \
      php8.5-ldap \
      php8.5-msgpack \
      php8.5-igbinary \
      php8.5-redis \
      php8.5-memcached \
      php8.5-pcov \
      php8.5-imagick \
      php8.5-xdebug && \
    setcap "cap_net_bind_service=+ep" /usr/bin/php8.5 && \
    rm -rf /var/lib/apt/lists/*

# ── Composer ───────────────────────────────────────────────────────────────────
RUN curl -sLS https://getcomposer.org/installer | php -- --install-dir=/usr/bin/ --filename=composer

# ── Node.js (via NodeSource) ───────────────────────────────────────────────────
ARG NODE_VERSION=24
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
      | gpg --dearmor | tee /etc/apt/keyrings/nodesource.gpg > /dev/null && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_VERSION}.x nodistro main" \
      > /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    apt-get install -y nodejs && \
    npm install -g npm pnpm bun && \
    corepack enable && \
    corepack prepare yarn@stable --activate && \
    npx playwright install-deps && \
    rm -rf /var/lib/apt/lists/*

# ── MySQL client ───────────────────────────────────────────────────────────────
RUN curl -sS https://www.postgresql.org/media/keys/ACCC4CF8.asc \
      | gpg --dearmor | tee /etc/apt/keyrings/pgdg.gpg > /dev/null && \
    echo "deb [signed-by=/etc/apt/keyrings/pgdg.gpg] http://apt.postgresql.org/pub/repos/apt noble-pgdg main" \
      > /etc/apt/sources.list.d/pgdg.list && \
    apt-get update && \
    apt-get install -y mysql-client && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

USER coder
