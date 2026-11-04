#!/usr/bin/env bash
set -euo pipefail
source="$HOME/.local/bakery-php-runtime/8.3.36"
runtime="$HOME/case-garage.fun/bakery-php-runtime"
mkdir -p "$runtime/bin" "$runtime/etc" "$runtime/lib"
cp "$source/bin/php" "$runtime/bin/php-bin"
cp "$source/bin/php-cgi" "$runtime/bin/php-cgi"
cp "$source/lib/php/extensions/no-debug-non-zts-20230831/scrypt.so" "$runtime/lib/scrypt.so"
cp "$source/etc/php.ini" "$runtime/etc/php.ini"
printf '\nextension_dir="%s/lib"\n' "$runtime" >> "$runtime/etc/php.ini"
printf '#!/bin/sh\nexec "%s/bin/php-bin" -c "%s/etc/php.ini" "$@"\n' "$runtime" "$runtime" > "$runtime/bin/php"
chmod 755 "$runtime/bin/php" "$runtime/bin/php-bin" "$runtime/bin/php-cgi"
probe="$HOME/case-garage.fun/public_html/__bakery_php_probe_20261031"
printf '#!/bin/sh\nexec "%s/bin/php-cgi" -c "%s/etc/php.ini"\n' "$runtime" "$runtime" > "$probe/cgi-bin/php.cgi"
chmod 755 "$probe/cgi-bin/php.cgi"
"$runtime/bin/php" -v
curl -fsS 'https://case-garage.fun/__bakery_php_probe_20261031/'
