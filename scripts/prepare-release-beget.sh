#!/usr/bin/env bash
set -euo pipefail
umask 077
site="$HOME/case-garage.fun"
release="$site/bakery-php-v1"
php="$site/bakery-php-runtime/bin/php"
test ! -e "$release"
mkdir "$release"
tar -xzf "$HOME/.local/bakery-php-v1.tar.gz" -C "$release"
mkdir "$release/.local"
"$php" "$release/scripts/snapshot.php" "$site/bakery-app/.local/bakery.sqlite" "$release/.local/bakery.sqlite"
if test -d "$site/bakery-app/.local/uploads"; then cp -R "$site/bakery-app/.local/uploads" "$release/.local/uploads"; else mkdir "$release/.local/uploads"; fi
cat > "$release/.local/config.php" <<PHP
<?php return ['APP_URL'=>'https://case-garage.fun','DATABASE_PATH'=>'$release/.local/bakery.sqlite','UPLOADS_PATH'=>'$release/.local/uploads','SESSION_PATH'=>'$release/.local/sessions','BACKUP_PATH'=>'$release/.local/backups'];
PHP
cd "$release"
"$php" scripts/setup.php
"$php" scripts/check-env.php
"$php" tests/shop-test.php
"$php" tests/auth-test.php
"$php" tests/backup-test.php
find lib views public scripts tests -name '*.php' -exec "$php" -l '{}' \; > .local/php-lint.log
"$php" scripts/data-audit.php .local/bakery.sqlite > .local/rehearsal-audit.json
echo SERVER_RELEASE_CHECKS_PASSED
