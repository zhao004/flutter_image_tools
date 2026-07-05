import 'package:drift/drift.dart';

import '../type/utc_date_time_converter.dart';

class RecentFiles extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get filePath => text().unique()();

  TextColumn get fileName => text()();

  TextColumn get mimeType => text()();

  IntColumn get sizeBytes => integer()();

  DateTimeColumn get lastUsedAt =>
      dateTime().map(const UtcDateTimeConverter())();
}
