import 'package:drift/drift.dart';

import '../type/utc_date_time_converter.dart';

class OperationHistory extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get featureName => text()();

  TextColumn get inputPath => text()();

  TextColumn get outputPath => text().nullable()();

  TextColumn get parametersJson => text()();

  TextColumn get status => text()();

  TextColumn get errorMessage => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().map(const UtcDateTimeConverter())();
}
