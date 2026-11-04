#!/usr/bin/env bash
set -euo pipefail
site="$HOME/case-garage.fun"
probe="$site/public_html/__bakery_php_probe_20261031"
runtime="$HOME/.local/bakery-php-runtime/8.3.36"
test -f "$HOME/.local/bakery-php-runtime/READY"
mkdir -p "$probe/cgi-bin"
cat > "$probe/.htaccess" <<'HT'
PassengerEnabled off
Options -Indexes +ExecCGI
AddHandler cgi-script .cgi
Action bakery-php /__bakery_php_probe_20261031/cgi-bin/php.cgi
AddHandler bakery-php .php
<FilesMatch "\.php$">
SetHandler bakery-php
</FilesMatch>
DirectoryIndex index.php
HT
printf '#!/bin/sh\nexec "%s/bin/php-cgi"\n' "$runtime" > "$probe/cgi-bin/php.cgi"
chmod 755 "$probe/cgi-bin/php.cgi"
cat > "$probe/cgi-bin/hello.cgi" <<'CGI'
#!/bin/sh
printf 'Content-Type: text/plain\n\nCGI_OK\n'
id
CGI
chmod 755 "$probe/cgi-bin/hello.cgi"
cat > "$probe/index.php" <<'PHP'
<?php
header('Content-Type: application/json');
header('X-Robots-Tag: noindex, nofollow');
echo json_encode(['php'=>PHP_VERSION,'sapi'=>PHP_SAPI,'pdo'=>PDO::getAvailableDrivers(),'intl'=>class_exists('Normalizer'),'mbstring'=>extension_loaded('mbstring'),'scrypt'=>function_exists('scrypt') && strlen(scrypt('probe','00000000000000000000000000000000',16384,16,1,64,false))===128,'webp'=>gd_info()['WebP Support']]);
PHP
curl -fsS "https://case-garage.fun/__bakery_php_probe_20261031/cgi-bin/hello.cgi"
curl -fsS "https://case-garage.fun/__bakery_php_probe_20261031/"
