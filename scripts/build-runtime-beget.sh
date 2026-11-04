#!/usr/bin/env bash
set -euo pipefail
umask 022
base="$HOME/.local/bakery-php-runtime"
mkdir -p "$base/build"
cd "$base/build"
curl -fLsS --retry 2 https://www.php.net/distributions/php-8.3.36.tar.gz -o php-8.3.36.tar.gz
echo 'c93f3441f87f6ab156bef4432db215d7e61ca2c0183bb3a2aa28d9886ab59f53  php-8.3.36.tar.gz' | sha256sum -c -
tar -xzf php-8.3.36.tar.gz
cd php-8.3.36
./configure --prefix="$base/8.3.36" --with-config-file-path="$base/8.3.36/etc" --disable-all --enable-cli --enable-cgi --enable-session --enable-filter --enable-ctype --enable-pdo --with-pdo-sqlite --with-sqlite3 --enable-mbstring --disable-mbregex --enable-fileinfo --enable-intl --enable-gd --with-external-gd --with-iconv --with-openssl --with-zlib > "$base/configure.log" 2>&1
make -j2 > "$base/make.log" 2>&1
make install > "$base/install.log" 2>&1
cd "$base/build"
curl -fLsS --retry 2 https://pecl.php.net/get/scrypt-2.0.1.tgz -o scrypt-2.0.1.tgz
tar -xzf scrypt-2.0.1.tgz
cd scrypt-2.0.1
"$base/8.3.36/bin/phpize" > "$base/scrypt.log" 2>&1
./configure --with-php-config="$base/8.3.36/bin/php-config" >> "$base/scrypt.log" 2>&1
make -j2 >> "$base/scrypt.log" 2>&1
make install >> "$base/scrypt.log" 2>&1
mkdir -p "$base/8.3.36/etc"
cat > "$base/8.3.36/etc/php.ini" <<'INI'
extension=scrypt
date.timezone=Europe/Moscow
expose_php=Off
display_errors=Off
log_errors=On
memory_limit=192M
upload_max_filesize=5M
post_max_size=8M
max_execution_time=30
session.use_strict_mode=1
session.use_only_cookies=1
INI
"$base/8.3.36/bin/php" -v
"$base/8.3.36/bin/php" -m
touch "$base/READY"
