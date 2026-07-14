import 'package:drift/native.dart';
import 'package:flutter_image_tools/app/database/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('数据库从版本二升级后删除日志和收藏模板表', () async {
    const previousSchemaVersion = 2;
    const removedTableNames = {'operation_logs', 'favorite_templates'};
    final executor = NativeDatabase.memory(
      setup: (database) {
        database.execute(
          'CREATE TABLE operation_logs '
          '(id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT)',
        );
        database.execute(
          'CREATE TABLE favorite_templates '
          '(id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT)',
        );
        database.execute('PRAGMA user_version = $previousSchemaVersion');
      },
    );
    final database = AppDatabase(executor);
    addTearDown(database.close);

    final rows = await database
        .customSelect(
          "SELECT name FROM sqlite_master "
          "WHERE type = 'table' "
          "AND name IN ('operation_logs', 'favorite_templates')",
        )
        .get();
    final remainingTableNames = rows
        .map((row) => row.read<String>('name'))
        .toSet();

    expect(database.schemaVersion, 3);
    expect(remainingTableNames.intersection(removedTableNames), isEmpty);
  });
}
