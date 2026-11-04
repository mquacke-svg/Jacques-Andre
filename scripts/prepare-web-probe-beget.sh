#!/usr/bin/env bash
set -euo pipefail
site="$HOME/case-garage.fun"
release="$site/bakery-php-v1"
php="$site/bakery-php-runtime/bin/php"
probe="$site/public_html/__bakery_php_probe_20261031"
sessions="/var/tmp/bakery-php-e2e-$(openssl rand -hex 12)"
cd "$release"
chmod g+rx "$release"
# The test fixture removes customer records ONLY from the separate e2e snapshot.
"$php" -r 'echo json_encode(["adminPassword"=>bin2hex(random_bytes(24))]);' | "$php" tests/e2e-fixture.php init > .local/server-fixture.json
cat > .local/config.php <<PHP
<?php return ['APP_URL'=>'https://case-garage.fun','DATABASE_PATH'=>'$release/.local/e2e.sqlite','UPLOADS_PATH'=>'$release/.local/e2e-uploads','SESSION_PATH'=>'$sessions'];
PHP
# Beget assigns per-site ACL entries automatically. Enable their existing mask only.
getfacl -cp .local | grep -q 'user:mquacker__casebgaragebfun__63:'
chmod g+rwx .local .local/e2e-sessions .local/e2e-uploads
chmod g+rw .local/e2e.sqlite
chmod g+r .local/config.php
for suffix in -wal -shm; do if test -f ".local/e2e.sqlite$suffix"; then chmod g+rw ".local/e2e.sqlite$suffix"; fi; done
cat > "$probe/app.php" <<PHP
<?php
ini_set('error_log', '$release/.local/php-web.log');
\$_SERVER['REQUEST_URI'] = substr(\$_SERVER['REQUEST_URI'], strlen('/__bakery_php_probe_20261031/app')) ?: '/';
require '$release/public/index.php';
PHP
cat >> "$probe/.htaccess" <<'HT'
RewriteEngine On
RewriteRule ^app(?:/.*)?$ app.php [L,QSA]
HT
curl -fsS 'https://case-garage.fun/__bakery_php_probe_20261031/app/' -o "$release/.local/server-home.html"
grep -q 'Маленькие радости' "$release/.local/server-home.html"
echo CGI_DATABASE_SESSIONS_OK
