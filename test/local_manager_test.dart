import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:venera/foundation/local.dart';

/// Creates the schema used before the folder / display_order columns existed.
void createLegacySchema(Database db) {
  db.execute('''
    CREATE TABLE comics (
      id TEXT NOT NULL,
      title TEXT NOT NULL,
      subtitle TEXT NOT NULL,
      tags TEXT NOT NULL,
      directory TEXT NOT NULL,
      chapters TEXT NOT NULL,
      cover TEXT NOT NULL,
      comic_type INTEGER NOT NULL,
      downloadedChapters TEXT NOT NULL,
      created_at INTEGER,
      PRIMARY KEY (id, comic_type)
    );
  ''');
}

void insertLegacyComic(Database db, String id, int createdAt) {
  db.execute(
    'INSERT INTO comics VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
    [id, 'title-$id', '', '[]', 'dir-$id', 'null', 'cover.jpg', 0, '[]', createdAt],
  );
}

Set<String> comicColumns(Database db) => db
    .select('PRAGMA table_info(comics);')
    .map((row) => row['name'] as String)
    .toSet();

void main() {
  setUpAll(() {
    // The test host has no sqlite3.dll; use the one shipped with Windows.
    if (Platform.isWindows) {
      open.overrideFor(
        OperatingSystem.windows,
        () => DynamicLibrary.open('winsqlite3.dll'),
      );
    }
  });

  test('migration adds folder and display_order columns', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.dispose);
    createLegacySchema(db);
    insertLegacyComic(db, '1', 1000);

    expect(comicColumns(db).contains('folder'), false);

    LocalManager.migrateComicsTable(db);

    final columns = comicColumns(db);
    expect(columns.contains('folder'), true);
    expect(columns.contains('display_order'), true);

    final row = db.select('SELECT folder, display_order FROM comics;').first;
    expect(row['folder'], '');
    expect(row['display_order'], 1000);
  });

  test('migration is idempotent', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.dispose);
    createLegacySchema(db);
    insertLegacyComic(db, '1', 1000);

    LocalManager.migrateComicsTable(db);
    // Second run must not throw "duplicate column name".
    LocalManager.migrateComicsTable(db);

    expect(comicColumns(db).contains('folder'), true);
    // display_order must not be re-initialized on later runs.
    db.execute('UPDATE comics SET display_order = 5;');
    LocalManager.migrateComicsTable(db);
    final row = db.select('SELECT display_order FROM comics;').first;
    expect(row['display_order'], 5);
  });
}
