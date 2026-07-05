import 'package:drift/drift.dart';

import '../type/utc_date_time_converter.dart';

class Todos extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text()();

  TextColumn get description => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().map(const UtcDateTimeConverter())();
}
