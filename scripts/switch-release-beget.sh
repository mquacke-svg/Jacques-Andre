#!/usr/bin/env bash
# Switch only after local/browser and server CGI rehearsal checks have passed.
set -euo pipefail
umask 077
site="$HOME/case-garage.fun"
release="$site/bakery-php-v1"
php="$site/bakery-php-runtime/bin/php"
shared="$site/bakery-app/.local"
backup="$HOME/.local/bakery-release-backups/before-php-v1-20261031"
stage="$site/public_html-php-v1-stage"
previous="$site/public_html-before-php-v1-20261031"
test ! -e "$backup"
test ! -e "$stage"
test ! -e "$previous"
grep -Fq "PassengerAppRoot $site/bakery-app-v11" "$site/public_html/.htaccess"
mkdir -p "$backup" "$stage"
cp -R "$release/public/." "$stage/"
mkdir -p "$stage/cgi-bin"
printf '#!/bin/sh\nexec "%s/bakery-php-runtime/bin/php-cgi" -c "%s/bakery-php-runtime/etc/php.ini"\n' "$site" "$site" > "$stage/cgi-bin/bakery-php.cgi"
chmod 755 "$stage/cgi-bin/bakery-php.cgi"
cat > "$stage/index.php" <<PHP
<?php
ini_set('error_log', '$release/.local/php-web.log');
header('X-Bakery-Release: php-v1');
require '$release/public/index.php';
PHP
cat > "$stage/.htaccess" <<'HT'
PassengerEnabled off
Options -Indexes -MultiViews +ExecCGI
DirectoryIndex index.php
AddHandler cgi-script .cgi
Action bakery-php /cgi-bin/bakery-php.cgi
<FilesMatch "\.php$">
    SetHandler bakery-php
</FilesMatch>
RewriteEngine On
RewriteCond %{HTTPS} !=on
RewriteCond %{REQUEST_URI} !^/\.well-known/acme-challenge/
RewriteRule ^ https://case-garage.fun%{REQUEST_URI} [R=301,L,NE]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^ index.php [L,QSA]
<FilesMatch "^\.">
    Require all denied
</FilesMatch>
HT
chmod g+rx "$stage" "$stage/cgi-bin"
chmod g+r "$stage/index.php" "$stage/.htaccess"
cp "$site/public_html/.htaccess" "$backup/htaccess"
cp "$site/bakery-app-v11/.env.local" "$backup/legacy.env.local"
cp "$release/.local/config.php" "$backup/rehearsal.config.php"
cat > "$site/public_html/.htaccess.maintenance" <<'HT'
PassengerEnabled off
RewriteEngine On
RewriteRule ^ - [R=503,L]
ErrorDocument 503 "Обновление сайта. Пожалуйста, повторите запрос через минуту."
HT
chmod g+r "$site/public_html/.htaccess.maintenance"
mv "$site/public_html/.htaccess.maintenance" "$site/public_html/.htaccess"
switched=0
rollback() {
    if test -d "$previous"; then
        if test -d "$site/public_html"; then mv "$site/public_html" "$site/public_html-php-v1-failed"; fi
        mv "$previous" "$site/public_html"
    fi
    cp "$backup/htaccess" "$site/public_html/.htaccess"
    chmod g+r "$site/public_html/.htaccess"
    echo 'PHP switch failed; previous application restored with current database' >&2
}
trap rollback ERR
sleep 2
"$php" "$release/scripts/data-audit.php" "$shared/bakery.sqlite" > "$backup/data-before.json"
"$php" "$release/scripts/snapshot.php" "$shared/bakery.sqlite" "$backup/bakery.sqlite"
if test -d "$shared/uploads"; then cp -R "$shared/uploads" "$backup/uploads"; else mkdir "$backup/uploads"; fi
sessions="/var/tmp/bakery-case-garage-php-$(openssl rand -hex 12)"
cat > "$release/.local/config.php" <<PHP
<?php return ['APP_URL'=>'https://case-garage.fun','DATABASE_PATH'=>'$shared/bakery.sqlite','UPLOADS_PATH'=>'$shared/uploads','SESSION_PATH'=>'$sessions','BACKUP_PATH'=>'$site/bakery-php-backups'];
PHP
chmod g+r "$release/.local/config.php"
getfacl -cp "$shared" | grep -q 'user:mquacker__casebgaragebfun__63:'
chmod g+rwx "$shared"
chmod g+rw "$shared/bakery.sqlite"
for suffix in -wal -shm; do if test -f "$shared/bakery.sqlite$suffix"; then chmod g+rw "$shared/bakery.sqlite$suffix"; fi; done
if test -d "$shared/uploads"; then find "$shared/uploads" -type d -exec chmod g+rwx '{}' \;; find "$shared/uploads" -type f -exec chmod g+rw '{}' \;; else mkdir "$shared/uploads"; chmod g+rwx "$shared/uploads"; fi
cd "$release"
"$php" scripts/setup.php
"$php" scripts/data-audit.php "$shared/bakery.sqlite" > "$backup/data-after.json"
"$php" -r '$a=json_decode(file_get_contents($argv[1]),true);$b=json_decode(file_get_contents($argv[2]),true);if($b["integrity"]!=="ok"||$b["foreignKeys"])exit(1);foreach($a["tables"] as $name=>$digest){if(($b["tables"][$name]??null)!==$digest){fwrite(STDERR,"Changed table: ".$name."\n");exit(1);}}echo "ALL_EXISTING_TABLES_UNCHANGED\n";' "$backup/data-before.json" "$backup/data-after.json"
mv "$site/public_html" "$previous"
mv "$stage" "$site/public_html"
switched=1
curl -fsS -D "$backup/live-headers.txt" https://case-garage.fun/ -o "$backup/live-home.html"
grep -qi 'X-Bakery-Release: php-v1' "$backup/live-headers.txt"
grep -q 'Маленькие радости' "$backup/live-home.html"
curl -fsS https://case-garage.fun/menu -o "$backup/live-menu.html"
grep -q 'data-catalog' "$backup/live-menu.html"
curl -fsS https://case-garage.fun/login -o "$backup/live-login.html"
grep -q 'name="csrf"' "$backup/live-login.html"
# Preserve the actual old config for a code-only rollback, not maintenance mode.
cp "$backup/htaccess" "$previous/.htaccess"
chmod g+r "$previous/.htaccess"
trap - ERR
echo PHP_RELEASE_LIVE_DATA_PRESERVED
