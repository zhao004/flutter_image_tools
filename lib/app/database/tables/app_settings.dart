import 'package:drift/drift.dart';

import '../type/utc_date_time_converter.dart';

class AppSettings extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get settingKey => text().unique()();

  TextColumn get settingValue => text()();

  TextColumn get valueType => text()();

  DateTimeColumn get updatedAt =>
      dateTime().map(const UtcDateTimeConverter())();
}
