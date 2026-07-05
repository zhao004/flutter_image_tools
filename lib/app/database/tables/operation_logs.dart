import 'package:drift/drift.dart';

import '../type/utc_date_time_converter.dart';

class OperationLogs extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get featureName => text()();

  TextColumn get inputPath => text()();

  TextColumn get outputPath => text().nullable()();

  TextColumn get parametersJson => text()();

  DateTimeColumn get startedAt =>
      dateTime().map(const UtcDateTimeConverter())();

  DateTimeColumn get completedAt =>
      dateTime().map(const UtcDateTimeConverter()).nullable()();

  IntColumn get durationMs => integer().nullable()();

  TextColumn get status => text()();

  TextColumn get errorMessage => text().nullable()();
}
