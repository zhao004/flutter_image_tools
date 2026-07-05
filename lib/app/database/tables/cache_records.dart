import 'package:drift/drift.dart';

import '../type/utc_date_time_converter.dart';

class CacheRecords extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get cacheKey => text().unique()();

  TextColumn get filePath => text()();

  IntColumn get sizeBytes => integer()();

  DateTimeColumn get createdAt =>
      dateTime().map(const UtcDateTimeConverter())();

  DateTimeColumn get expiresAt =>
      dateTime().map(const UtcDateTimeConverter()).nullable()();
}
