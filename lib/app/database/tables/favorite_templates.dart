import 'package:drift/drift.dart';

import '../type/utc_date_time_converter.dart';

class FavoriteTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get featureName => text()();

  TextColumn get templateName => text()();

  TextColumn get parametersJson => text()();

  DateTimeColumn get createdAt =>
      dateTime().map(const UtcDateTimeConverter())();

  DateTimeColumn get updatedAt =>
      dateTime().map(const UtcDateTimeConverter())();
}
