import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import 'tables/operation_history.dart';
import 'tables/operation_logs.dart';
import 'type/utc_date_time_converter.dart';

part 'database.g.dart';

@DriftDatabase(tables: [OperationHistory, OperationLogs])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<List<OperationHistoryData>> getRecentHistory({int limit = 50}) {
    if (limit <= 0) {
      return Future.value(const []);
    }
    return (select(operationHistory)
          ..orderBy([
            (table) => OrderingTerm.desc(table.createdAt),
          ])
          ..limit(limit))
        .get();
  }

  Future<int> createHistory(OperationHistoryCompanion history) =>
      into(operationHistory).insert(history);

  Future<int> createLog(OperationLogsCompanion log) =>
      into(operationLogs).insert(log);

  Future<int> clearHistory() => delete(operationHistory).go();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/app_database.sqlite');
    return NativeDatabase.createInBackground(file);
  });
}
