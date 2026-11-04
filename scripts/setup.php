<?php
// Создаёт базу с каталогом только при первом запуске; существующую не заменяет.
require dirname(__DIR__) . '/lib/bootstrap.php';
if (PHP_SAPI !== 'cli') exit(1);
$path = getenv('DATABASE_PATH') ?: ($GLOBALS['config']['DATABASE_PATH'] ?? ROOT . '/.local/bakery.sqlite');
if (!is_file($path)) {
    $directory = dirname($path);
    if (!is_dir($directory) && !mkdir($directory, 0700, true) && !is_dir($directory)) throw new RuntimeException('Не удалось создать каталог базы данных');
    $source = fopen(ROOT . '/data/catalog.sqlite', 'rb');
    if (!$source) throw new RuntimeException('Не найден исходный каталог');
    $destination = @fopen($path, 'xb');
    if (!$destination) {
        fclose($source);
        throw new RuntimeException('Не удалось создать базу; проверьте путь и права доступа');
    }
    $bytes = stream_copy_to_stream($source, $destination);
    $expected = filesize(ROOT . '/data/catalog.sqlite');
    fclose($source);
    fclose($destination);
    if ($bytes === false || $bytes !== $expected) {
        unlink($path);
        throw new RuntimeException('Не удалось скопировать каталог');
    }
    echo "Создана новая база с каталогом.\n";
}
if (db()->query('PRAGMA integrity_check')->fetchColumn() !== 'ok') throw new RuntimeException('SQLite повреждена');
db()->exec('CREATE TABLE IF NOT EXISTS auth_rate_limit (key TEXT PRIMARY KEY, count INTEGER NOT NULL, expires_at INTEGER NOT NULL)');
foreach (['uploads', 'sessions', 'backups'] as $folder) {
    if (!is_dir(ROOT . '/.local/' . $folder)) mkdir(ROOT . '/.local/' . $folder, 0700, true);
}
echo "База проверена. Служебная таблица готова. Каталог и аккаунты сохранены.\n";
