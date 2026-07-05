// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $OperationHistoryTable extends OperationHistory
    with TableInfo<$OperationHistoryTable, OperationHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OperationHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _featureNameMeta =
      const VerificationMeta('featureName');
  @override
  late final GeneratedColumn<String> featureName = GeneratedColumn<String>(
      'feature_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _inputPathMeta =
      const VerificationMeta('inputPath');
  @override
  late final GeneratedColumn<String> inputPath = GeneratedColumn<String>(
      'input_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _outputPathMeta =
      const VerificationMeta('outputPath');
  @override
  late final GeneratedColumn<String> outputPath = GeneratedColumn<String>(
      'output_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _parametersJsonMeta =
      const VerificationMeta('parametersJson');
  @override
  late final GeneratedColumn<String> parametersJson = GeneratedColumn<String>(
      'parameters_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _errorMessageMeta =
      const VerificationMeta('errorMessage');
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
      'error_message', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, DateTime> createdAt =
      GeneratedColumn<DateTime>('created_at', aliasedName, false,
              type: DriftSqlType.dateTime, requiredDuringInsert: true)
          .withConverter<DateTime>($OperationHistoryTable.$convertercreatedAt);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        featureName,
        inputPath,
        outputPath,
        parametersJson,
        status,
        errorMessage,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'operation_history';
  @override
  VerificationContext validateIntegrity(
      Insertable<OperationHistoryData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('feature_name')) {
      context.handle(
          _featureNameMeta,
          featureName.isAcceptableOrUnknown(
              data['feature_name']!, _featureNameMeta));
    } else if (isInserting) {
      context.missing(_featureNameMeta);
    }
    if (data.containsKey('input_path')) {
      context.handle(_inputPathMeta,
          inputPath.isAcceptableOrUnknown(data['input_path']!, _inputPathMeta));
    } else if (isInserting) {
      context.missing(_inputPathMeta);
    }
    if (data.containsKey('output_path')) {
      context.handle(
          _outputPathMeta,
          outputPath.isAcceptableOrUnknown(
              data['output_path']!, _outputPathMeta));
    }
    if (data.containsKey('parameters_json')) {
      context.handle(
          _parametersJsonMeta,
          parametersJson.isAcceptableOrUnknown(
              data['parameters_json']!, _parametersJsonMeta));
    } else if (isInserting) {
      context.missing(_parametersJsonMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('error_message')) {
      context.handle(
          _errorMessageMeta,
          errorMessage.isAcceptableOrUnknown(
              data['error_message']!, _errorMessageMeta));
    }
    context.handle(_createdAtMeta, const VerificationResult.success());
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OperationHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OperationHistoryData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      featureName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}feature_name'])!,
      inputPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}input_path'])!,
      outputPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}output_path']),
      parametersJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}parameters_json'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      errorMessage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}error_message']),
      createdAt: $OperationHistoryTable.$convertercreatedAt.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!),
    );
  }

  @override
  $OperationHistoryTable createAlias(String alias) {
    return $OperationHistoryTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, DateTime> $convertercreatedAt =
      const UtcDateTimeConverter();
}

class OperationHistoryData extends DataClass
    implements Insertable<OperationHistoryData> {
  final int id;
  final String featureName;
  final String inputPath;
  final String? outputPath;
  final String parametersJson;
  final String status;
  final String? errorMessage;
  final DateTime createdAt;
  const OperationHistoryData(
      {required this.id,
      required this.featureName,
      required this.inputPath,
      this.outputPath,
      required this.parametersJson,
      required this.status,
      this.errorMessage,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['feature_name'] = Variable<String>(featureName);
    map['input_path'] = Variable<String>(inputPath);
    if (!nullToAbsent || outputPath != null) {
      map['output_path'] = Variable<String>(outputPath);
    }
    map['parameters_json'] = Variable<String>(parametersJson);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    {
      map['created_at'] = Variable<DateTime>(
          $OperationHistoryTable.$convertercreatedAt.toSql(createdAt));
    }
    return map;
  }

  OperationHistoryCompanion toCompanion(bool nullToAbsent) {
    return OperationHistoryCompanion(
      id: Value(id),
      featureName: Value(featureName),
      inputPath: Value(inputPath),
      outputPath: outputPath == null && nullToAbsent
          ? const Value.absent()
          : Value(outputPath),
      parametersJson: Value(parametersJson),
      status: Value(status),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      createdAt: Value(createdAt),
    );
  }

  factory OperationHistoryData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OperationHistoryData(
      id: serializer.fromJson<int>(json['id']),
      featureName: serializer.fromJson<String>(json['featureName']),
      inputPath: serializer.fromJson<String>(json['inputPath']),
      outputPath: serializer.fromJson<String?>(json['outputPath']),
      parametersJson: serializer.fromJson<String>(json['parametersJson']),
      status: serializer.fromJson<String>(json['status']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'featureName': serializer.toJson<String>(featureName),
      'inputPath': serializer.toJson<String>(inputPath),
      'outputPath': serializer.toJson<String?>(outputPath),
      'parametersJson': serializer.toJson<String>(parametersJson),
      'status': serializer.toJson<String>(status),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  OperationHistoryData copyWith(
          {int? id,
          String? featureName,
          String? inputPath,
          Value<String?> outputPath = const Value.absent(),
          String? parametersJson,
          String? status,
          Value<String?> errorMessage = const Value.absent(),
          DateTime? createdAt}) =>
      OperationHistoryData(
        id: id ?? this.id,
        featureName: featureName ?? this.featureName,
        inputPath: inputPath ?? this.inputPath,
        outputPath: outputPath.present ? outputPath.value : this.outputPath,
        parametersJson: parametersJson ?? this.parametersJson,
        status: status ?? this.status,
        errorMessage:
            errorMessage.present ? errorMessage.value : this.errorMessage,
        createdAt: createdAt ?? this.createdAt,
      );
  OperationHistoryData copyWithCompanion(OperationHistoryCompanion data) {
    return OperationHistoryData(
      id: data.id.present ? data.id.value : this.id,
      featureName:
          data.featureName.present ? data.featureName.value : this.featureName,
      inputPath: data.inputPath.present ? data.inputPath.value : this.inputPath,
      outputPath:
          data.outputPath.present ? data.outputPath.value : this.outputPath,
      parametersJson: data.parametersJson.present
          ? data.parametersJson.value
          : this.parametersJson,
      status: data.status.present ? data.status.value : this.status,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OperationHistoryData(')
          ..write('id: $id, ')
          ..write('featureName: $featureName, ')
          ..write('inputPath: $inputPath, ')
          ..write('outputPath: $outputPath, ')
          ..write('parametersJson: $parametersJson, ')
          ..write('status: $status, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, featureName, inputPath, outputPath,
      parametersJson, status, errorMessage, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OperationHistoryData &&
          other.id == this.id &&
          other.featureName == this.featureName &&
          other.inputPath == this.inputPath &&
          other.outputPath == this.outputPath &&
          other.parametersJson == this.parametersJson &&
          other.status == this.status &&
          other.errorMessage == this.errorMessage &&
          other.createdAt == this.createdAt);
}

class OperationHistoryCompanion extends UpdateCompanion<OperationHistoryData> {
  final Value<int> id;
  final Value<String> featureName;
  final Value<String> inputPath;
  final Value<String?> outputPath;
  final Value<String> parametersJson;
  final Value<String> status;
  final Value<String?> errorMessage;
  final Value<DateTime> createdAt;
  const OperationHistoryCompanion({
    this.id = const Value.absent(),
    this.featureName = const Value.absent(),
    this.inputPath = const Value.absent(),
    this.outputPath = const Value.absent(),
    this.parametersJson = const Value.absent(),
    this.status = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  OperationHistoryCompanion.insert({
    this.id = const Value.absent(),
    required String featureName,
    required String inputPath,
    this.outputPath = const Value.absent(),
    required String parametersJson,
    required String status,
    this.errorMessage = const Value.absent(),
    required DateTime createdAt,
  })  : featureName = Value(featureName),
        inputPath = Value(inputPath),
        parametersJson = Value(parametersJson),
        status = Value(status),
        createdAt = Value(createdAt);
  static Insertable<OperationHistoryData> custom({
    Expression<int>? id,
    Expression<String>? featureName,
    Expression<String>? inputPath,
    Expression<String>? outputPath,
    Expression<String>? parametersJson,
    Expression<String>? status,
    Expression<String>? errorMessage,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (featureName != null) 'feature_name': featureName,
      if (inputPath != null) 'input_path': inputPath,
      if (outputPath != null) 'output_path': outputPath,
      if (parametersJson != null) 'parameters_json': parametersJson,
      if (status != null) 'status': status,
      if (errorMessage != null) 'error_message': errorMessage,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  OperationHistoryCompanion copyWith(
      {Value<int>? id,
      Value<String>? featureName,
      Value<String>? inputPath,
      Value<String?>? outputPath,
      Value<String>? parametersJson,
      Value<String>? status,
      Value<String?>? errorMessage,
      Value<DateTime>? createdAt}) {
    return OperationHistoryCompanion(
      id: id ?? this.id,
      featureName: featureName ?? this.featureName,
      inputPath: inputPath ?? this.inputPath,
      outputPath: outputPath ?? this.outputPath,
      parametersJson: parametersJson ?? this.parametersJson,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (featureName.present) {
      map['feature_name'] = Variable<String>(featureName.value);
    }
    if (inputPath.present) {
      map['input_path'] = Variable<String>(inputPath.value);
    }
    if (outputPath.present) {
      map['output_path'] = Variable<String>(outputPath.value);
    }
    if (parametersJson.present) {
      map['parameters_json'] = Variable<String>(parametersJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(
          $OperationHistoryTable.$convertercreatedAt.toSql(createdAt.value));
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OperationHistoryCompanion(')
          ..write('id: $id, ')
          ..write('featureName: $featureName, ')
          ..write('inputPath: $inputPath, ')
          ..write('outputPath: $outputPath, ')
          ..write('parametersJson: $parametersJson, ')
          ..write('status: $status, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $OperationLogsTable extends OperationLogs
    with TableInfo<$OperationLogsTable, OperationLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OperationLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _featureNameMeta =
      const VerificationMeta('featureName');
  @override
  late final GeneratedColumn<String> featureName = GeneratedColumn<String>(
      'feature_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _inputPathMeta =
      const VerificationMeta('inputPath');
  @override
  late final GeneratedColumn<String> inputPath = GeneratedColumn<String>(
      'input_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _outputPathMeta =
      const VerificationMeta('outputPath');
  @override
  late final GeneratedColumn<String> outputPath = GeneratedColumn<String>(
      'output_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _parametersJsonMeta =
      const VerificationMeta('parametersJson');
  @override
  late final GeneratedColumn<String> parametersJson = GeneratedColumn<String>(
      'parameters_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, DateTime> startedAt =
      GeneratedColumn<DateTime>('started_at', aliasedName, false,
              type: DriftSqlType.dateTime, requiredDuringInsert: true)
          .withConverter<DateTime>($OperationLogsTable.$converterstartedAt);
  static const VerificationMeta _completedAtMeta =
      const VerificationMeta('completedAt');
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, DateTime> completedAt =
      GeneratedColumn<DateTime>('completed_at', aliasedName, true,
              type: DriftSqlType.dateTime, requiredDuringInsert: false)
          .withConverter<DateTime?>($OperationLogsTable.$convertercompletedAtn);
  static const VerificationMeta _durationMsMeta =
      const VerificationMeta('durationMs');
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
      'duration_ms', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _errorMessageMeta =
      const VerificationMeta('errorMessage');
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
      'error_message', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        featureName,
        inputPath,
        outputPath,
        parametersJson,
        startedAt,
        completedAt,
        durationMs,
        status,
        errorMessage
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'operation_logs';
  @override
  VerificationContext validateIntegrity(Insertable<OperationLog> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('feature_name')) {
      context.handle(
          _featureNameMeta,
          featureName.isAcceptableOrUnknown(
              data['feature_name']!, _featureNameMeta));
    } else if (isInserting) {
      context.missing(_featureNameMeta);
    }
    if (data.containsKey('input_path')) {
      context.handle(_inputPathMeta,
          inputPath.isAcceptableOrUnknown(data['input_path']!, _inputPathMeta));
    } else if (isInserting) {
      context.missing(_inputPathMeta);
    }
    if (data.containsKey('output_path')) {
      context.handle(
          _outputPathMeta,
          outputPath.isAcceptableOrUnknown(
              data['output_path']!, _outputPathMeta));
    }
    if (data.containsKey('parameters_json')) {
      context.handle(
          _parametersJsonMeta,
          parametersJson.isAcceptableOrUnknown(
              data['parameters_json']!, _parametersJsonMeta));
    } else if (isInserting) {
      context.missing(_parametersJsonMeta);
    }
    context.handle(_startedAtMeta, const VerificationResult.success());
    context.handle(_completedAtMeta, const VerificationResult.success());
    if (data.containsKey('duration_ms')) {
      context.handle(
          _durationMsMeta,
          durationMs.isAcceptableOrUnknown(
              data['duration_ms']!, _durationMsMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('error_message')) {
      context.handle(
          _errorMessageMeta,
          errorMessage.isAcceptableOrUnknown(
              data['error_message']!, _errorMessageMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OperationLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OperationLog(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      featureName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}feature_name'])!,
      inputPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}input_path'])!,
      outputPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}output_path']),
      parametersJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}parameters_json'])!,
      startedAt: $OperationLogsTable.$converterstartedAt.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.dateTime, data['${effectivePrefix}started_at'])!),
      completedAt: $OperationLogsTable.$convertercompletedAtn.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.dateTime, data['${effectivePrefix}completed_at'])),
      durationMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_ms']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      errorMessage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}error_message']),
    );
  }

  @override
  $OperationLogsTable createAlias(String alias) {
    return $OperationLogsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, DateTime> $converterstartedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime, DateTime> $convertercompletedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime?, DateTime?> $convertercompletedAtn =
      NullAwareTypeConverter.wrap($convertercompletedAt);
}

class OperationLog extends DataClass implements Insertable<OperationLog> {
  final int id;
  final String featureName;
  final String inputPath;
  final String? outputPath;
  final String parametersJson;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int? durationMs;
  final String status;
  final String? errorMessage;
  const OperationLog(
      {required this.id,
      required this.featureName,
      required this.inputPath,
      this.outputPath,
      required this.parametersJson,
      required this.startedAt,
      this.completedAt,
      this.durationMs,
      required this.status,
      this.errorMessage});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['feature_name'] = Variable<String>(featureName);
    map['input_path'] = Variable<String>(inputPath);
    if (!nullToAbsent || outputPath != null) {
      map['output_path'] = Variable<String>(outputPath);
    }
    map['parameters_json'] = Variable<String>(parametersJson);
    {
      map['started_at'] = Variable<DateTime>(
          $OperationLogsTable.$converterstartedAt.toSql(startedAt));
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(
          $OperationLogsTable.$convertercompletedAtn.toSql(completedAt));
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    return map;
  }

  OperationLogsCompanion toCompanion(bool nullToAbsent) {
    return OperationLogsCompanion(
      id: Value(id),
      featureName: Value(featureName),
      inputPath: Value(inputPath),
      outputPath: outputPath == null && nullToAbsent
          ? const Value.absent()
          : Value(outputPath),
      parametersJson: Value(parametersJson),
      startedAt: Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      status: Value(status),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
    );
  }

  factory OperationLog.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OperationLog(
      id: serializer.fromJson<int>(json['id']),
      featureName: serializer.fromJson<String>(json['featureName']),
      inputPath: serializer.fromJson<String>(json['inputPath']),
      outputPath: serializer.fromJson<String?>(json['outputPath']),
      parametersJson: serializer.fromJson<String>(json['parametersJson']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      status: serializer.fromJson<String>(json['status']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'featureName': serializer.toJson<String>(featureName),
      'inputPath': serializer.toJson<String>(inputPath),
      'outputPath': serializer.toJson<String?>(outputPath),
      'parametersJson': serializer.toJson<String>(parametersJson),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'durationMs': serializer.toJson<int?>(durationMs),
      'status': serializer.toJson<String>(status),
      'errorMessage': serializer.toJson<String?>(errorMessage),
    };
  }

  OperationLog copyWith(
          {int? id,
          String? featureName,
          String? inputPath,
          Value<String?> outputPath = const Value.absent(),
          String? parametersJson,
          DateTime? startedAt,
          Value<DateTime?> completedAt = const Value.absent(),
          Value<int?> durationMs = const Value.absent(),
          String? status,
          Value<String?> errorMessage = const Value.absent()}) =>
      OperationLog(
        id: id ?? this.id,
        featureName: featureName ?? this.featureName,
        inputPath: inputPath ?? this.inputPath,
        outputPath: outputPath.present ? outputPath.value : this.outputPath,
        parametersJson: parametersJson ?? this.parametersJson,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt.present ? completedAt.value : this.completedAt,
        durationMs: durationMs.present ? durationMs.value : this.durationMs,
        status: status ?? this.status,
        errorMessage:
            errorMessage.present ? errorMessage.value : this.errorMessage,
      );
  OperationLog copyWithCompanion(OperationLogsCompanion data) {
    return OperationLog(
      id: data.id.present ? data.id.value : this.id,
      featureName:
          data.featureName.present ? data.featureName.value : this.featureName,
      inputPath: data.inputPath.present ? data.inputPath.value : this.inputPath,
      outputPath:
          data.outputPath.present ? data.outputPath.value : this.outputPath,
      parametersJson: data.parametersJson.present
          ? data.parametersJson.value
          : this.parametersJson,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
      durationMs:
          data.durationMs.present ? data.durationMs.value : this.durationMs,
      status: data.status.present ? data.status.value : this.status,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OperationLog(')
          ..write('id: $id, ')
          ..write('featureName: $featureName, ')
          ..write('inputPath: $inputPath, ')
          ..write('outputPath: $outputPath, ')
          ..write('parametersJson: $parametersJson, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('status: $status, ')
          ..write('errorMessage: $errorMessage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, featureName, inputPath, outputPath,
      parametersJson, startedAt, completedAt, durationMs, status, errorMessage);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OperationLog &&
          other.id == this.id &&
          other.featureName == this.featureName &&
          other.inputPath == this.inputPath &&
          other.outputPath == this.outputPath &&
          other.parametersJson == this.parametersJson &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt &&
          other.durationMs == this.durationMs &&
          other.status == this.status &&
          other.errorMessage == this.errorMessage);
}

class OperationLogsCompanion extends UpdateCompanion<OperationLog> {
  final Value<int> id;
  final Value<String> featureName;
  final Value<String> inputPath;
  final Value<String?> outputPath;
  final Value<String> parametersJson;
  final Value<DateTime> startedAt;
  final Value<DateTime?> completedAt;
  final Value<int?> durationMs;
  final Value<String> status;
  final Value<String?> errorMessage;
  const OperationLogsCompanion({
    this.id = const Value.absent(),
    this.featureName = const Value.absent(),
    this.inputPath = const Value.absent(),
    this.outputPath = const Value.absent(),
    this.parametersJson = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.status = const Value.absent(),
    this.errorMessage = const Value.absent(),
  });
  OperationLogsCompanion.insert({
    this.id = const Value.absent(),
    required String featureName,
    required String inputPath,
    this.outputPath = const Value.absent(),
    required String parametersJson,
    required DateTime startedAt,
    this.completedAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    required String status,
    this.errorMessage = const Value.absent(),
  })  : featureName = Value(featureName),
        inputPath = Value(inputPath),
        parametersJson = Value(parametersJson),
        startedAt = Value(startedAt),
        status = Value(status);
  static Insertable<OperationLog> custom({
    Expression<int>? id,
    Expression<String>? featureName,
    Expression<String>? inputPath,
    Expression<String>? outputPath,
    Expression<String>? parametersJson,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? completedAt,
    Expression<int>? durationMs,
    Expression<String>? status,
    Expression<String>? errorMessage,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (featureName != null) 'feature_name': featureName,
      if (inputPath != null) 'input_path': inputPath,
      if (outputPath != null) 'output_path': outputPath,
      if (parametersJson != null) 'parameters_json': parametersJson,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (durationMs != null) 'duration_ms': durationMs,
      if (status != null) 'status': status,
      if (errorMessage != null) 'error_message': errorMessage,
    });
  }

  OperationLogsCompanion copyWith(
      {Value<int>? id,
      Value<String>? featureName,
      Value<String>? inputPath,
      Value<String?>? outputPath,
      Value<String>? parametersJson,
      Value<DateTime>? startedAt,
      Value<DateTime?>? completedAt,
      Value<int?>? durationMs,
      Value<String>? status,
      Value<String?>? errorMessage}) {
    return OperationLogsCompanion(
      id: id ?? this.id,
      featureName: featureName ?? this.featureName,
      inputPath: inputPath ?? this.inputPath,
      outputPath: outputPath ?? this.outputPath,
      parametersJson: parametersJson ?? this.parametersJson,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      durationMs: durationMs ?? this.durationMs,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (featureName.present) {
      map['feature_name'] = Variable<String>(featureName.value);
    }
    if (inputPath.present) {
      map['input_path'] = Variable<String>(inputPath.value);
    }
    if (outputPath.present) {
      map['output_path'] = Variable<String>(outputPath.value);
    }
    if (parametersJson.present) {
      map['parameters_json'] = Variable<String>(parametersJson.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(
          $OperationLogsTable.$converterstartedAt.toSql(startedAt.value));
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(
          $OperationLogsTable.$convertercompletedAtn.toSql(completedAt.value));
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OperationLogsCompanion(')
          ..write('id: $id, ')
          ..write('featureName: $featureName, ')
          ..write('inputPath: $inputPath, ')
          ..write('outputPath: $outputPath, ')
          ..write('parametersJson: $parametersJson, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('status: $status, ')
          ..write('errorMessage: $errorMessage')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $OperationHistoryTable operationHistory =
      $OperationHistoryTable(this);
  late final $OperationLogsTable operationLogs = $OperationLogsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [operationHistory, operationLogs];
}

typedef $$OperationHistoryTableCreateCompanionBuilder
    = OperationHistoryCompanion Function({
  Value<int> id,
  required String featureName,
  required String inputPath,
  Value<String?> outputPath,
  required String parametersJson,
  required String status,
  Value<String?> errorMessage,
  required DateTime createdAt,
});
typedef $$OperationHistoryTableUpdateCompanionBuilder
    = OperationHistoryCompanion Function({
  Value<int> id,
  Value<String> featureName,
  Value<String> inputPath,
  Value<String?> outputPath,
  Value<String> parametersJson,
  Value<String> status,
  Value<String?> errorMessage,
  Value<DateTime> createdAt,
});

class $$OperationHistoryTableFilterComposer
    extends FilterComposer<_$AppDatabase, $OperationHistoryTable> {
  $$OperationHistoryTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get featureName => $state.composableBuilder(
      column: $state.table.featureName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get inputPath => $state.composableBuilder(
      column: $state.table.inputPath,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get outputPath => $state.composableBuilder(
      column: $state.table.outputPath,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get parametersJson => $state.composableBuilder(
      column: $state.table.parametersJson,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get errorMessage => $state.composableBuilder(
      column: $state.table.errorMessage,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnWithTypeConverterFilters<DateTime, DateTime, DateTime> get createdAt =>
      $state.composableBuilder(
          column: $state.table.createdAt,
          builder: (column, joinBuilders) => ColumnWithTypeConverterFilters(
              column,
              joinBuilders: joinBuilders));
}

class $$OperationHistoryTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $OperationHistoryTable> {
  $$OperationHistoryTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get featureName => $state.composableBuilder(
      column: $state.table.featureName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get inputPath => $state.composableBuilder(
      column: $state.table.inputPath,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get outputPath => $state.composableBuilder(
      column: $state.table.outputPath,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get parametersJson => $state.composableBuilder(
      column: $state.table.parametersJson,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get errorMessage => $state.composableBuilder(
      column: $state.table.errorMessage,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

class $$OperationHistoryTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OperationHistoryTable,
    OperationHistoryData,
    $$OperationHistoryTableFilterComposer,
    $$OperationHistoryTableOrderingComposer,
    $$OperationHistoryTableCreateCompanionBuilder,
    $$OperationHistoryTableUpdateCompanionBuilder,
    (
      OperationHistoryData,
      BaseReferences<_$AppDatabase, $OperationHistoryTable,
          OperationHistoryData>
    ),
    OperationHistoryData,
    PrefetchHooks Function()> {
  $$OperationHistoryTableTableManager(
      _$AppDatabase db, $OperationHistoryTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$OperationHistoryTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$OperationHistoryTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> featureName = const Value.absent(),
            Value<String> inputPath = const Value.absent(),
            Value<String?> outputPath = const Value.absent(),
            Value<String> parametersJson = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> errorMessage = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              OperationHistoryCompanion(
            id: id,
            featureName: featureName,
            inputPath: inputPath,
            outputPath: outputPath,
            parametersJson: parametersJson,
            status: status,
            errorMessage: errorMessage,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String featureName,
            required String inputPath,
            Value<String?> outputPath = const Value.absent(),
            required String parametersJson,
            required String status,
            Value<String?> errorMessage = const Value.absent(),
            required DateTime createdAt,
          }) =>
              OperationHistoryCompanion.insert(
            id: id,
            featureName: featureName,
            inputPath: inputPath,
            outputPath: outputPath,
            parametersJson: parametersJson,
            status: status,
            errorMessage: errorMessage,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OperationHistoryTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OperationHistoryTable,
    OperationHistoryData,
    $$OperationHistoryTableFilterComposer,
    $$OperationHistoryTableOrderingComposer,
    $$OperationHistoryTableCreateCompanionBuilder,
    $$OperationHistoryTableUpdateCompanionBuilder,
    (
      OperationHistoryData,
      BaseReferences<_$AppDatabase, $OperationHistoryTable,
          OperationHistoryData>
    ),
    OperationHistoryData,
    PrefetchHooks Function()>;
typedef $$OperationLogsTableCreateCompanionBuilder = OperationLogsCompanion
    Function({
  Value<int> id,
  required String featureName,
  required String inputPath,
  Value<String?> outputPath,
  required String parametersJson,
  required DateTime startedAt,
  Value<DateTime?> completedAt,
  Value<int?> durationMs,
  required String status,
  Value<String?> errorMessage,
});
typedef $$OperationLogsTableUpdateCompanionBuilder = OperationLogsCompanion
    Function({
  Value<int> id,
  Value<String> featureName,
  Value<String> inputPath,
  Value<String?> outputPath,
  Value<String> parametersJson,
  Value<DateTime> startedAt,
  Value<DateTime?> completedAt,
  Value<int?> durationMs,
  Value<String> status,
  Value<String?> errorMessage,
});

class $$OperationLogsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $OperationLogsTable> {
  $$OperationLogsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get featureName => $state.composableBuilder(
      column: $state.table.featureName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get inputPath => $state.composableBuilder(
      column: $state.table.inputPath,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get outputPath => $state.composableBuilder(
      column: $state.table.outputPath,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get parametersJson => $state.composableBuilder(
      column: $state.table.parametersJson,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnWithTypeConverterFilters<DateTime, DateTime, DateTime> get startedAt =>
      $state.composableBuilder(
          column: $state.table.startedAt,
          builder: (column, joinBuilders) => ColumnWithTypeConverterFilters(
              column,
              joinBuilders: joinBuilders));

  ColumnWithTypeConverterFilters<DateTime?, DateTime, DateTime>
      get completedAt => $state.composableBuilder(
          column: $state.table.completedAt,
          builder: (column, joinBuilders) => ColumnWithTypeConverterFilters(
              column,
              joinBuilders: joinBuilders));

  ColumnFilters<int> get durationMs => $state.composableBuilder(
      column: $state.table.durationMs,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get errorMessage => $state.composableBuilder(
      column: $state.table.errorMessage,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$OperationLogsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $OperationLogsTable> {
  $$OperationLogsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get featureName => $state.composableBuilder(
      column: $state.table.featureName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get inputPath => $state.composableBuilder(
      column: $state.table.inputPath,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get outputPath => $state.composableBuilder(
      column: $state.table.outputPath,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get parametersJson => $state.composableBuilder(
      column: $state.table.parametersJson,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get startedAt => $state.composableBuilder(
      column: $state.table.startedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get completedAt => $state.composableBuilder(
      column: $state.table.completedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get durationMs => $state.composableBuilder(
      column: $state.table.durationMs,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get errorMessage => $state.composableBuilder(
      column: $state.table.errorMessage,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

class $$OperationLogsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OperationLogsTable,
    OperationLog,
    $$OperationLogsTableFilterComposer,
    $$OperationLogsTableOrderingComposer,
    $$OperationLogsTableCreateCompanionBuilder,
    $$OperationLogsTableUpdateCompanionBuilder,
    (
      OperationLog,
      BaseReferences<_$AppDatabase, $OperationLogsTable, OperationLog>
    ),
    OperationLog,
    PrefetchHooks Function()> {
  $$OperationLogsTableTableManager(_$AppDatabase db, $OperationLogsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$OperationLogsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$OperationLogsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> featureName = const Value.absent(),
            Value<String> inputPath = const Value.absent(),
            Value<String?> outputPath = const Value.absent(),
            Value<String> parametersJson = const Value.absent(),
            Value<DateTime> startedAt = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
            Value<int?> durationMs = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> errorMessage = const Value.absent(),
          }) =>
              OperationLogsCompanion(
            id: id,
            featureName: featureName,
            inputPath: inputPath,
            outputPath: outputPath,
            parametersJson: parametersJson,
            startedAt: startedAt,
            completedAt: completedAt,
            durationMs: durationMs,
            status: status,
            errorMessage: errorMessage,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String featureName,
            required String inputPath,
            Value<String?> outputPath = const Value.absent(),
            required String parametersJson,
            required DateTime startedAt,
            Value<DateTime?> completedAt = const Value.absent(),
            Value<int?> durationMs = const Value.absent(),
            required String status,
            Value<String?> errorMessage = const Value.absent(),
          }) =>
              OperationLogsCompanion.insert(
            id: id,
            featureName: featureName,
            inputPath: inputPath,
            outputPath: outputPath,
            parametersJson: parametersJson,
            startedAt: startedAt,
            completedAt: completedAt,
            durationMs: durationMs,
            status: status,
            errorMessage: errorMessage,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OperationLogsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OperationLogsTable,
    OperationLog,
    $$OperationLogsTableFilterComposer,
    $$OperationLogsTableOrderingComposer,
    $$OperationLogsTableCreateCompanionBuilder,
    $$OperationLogsTableUpdateCompanionBuilder,
    (
      OperationLog,
      BaseReferences<_$AppDatabase, $OperationLogsTable, OperationLog>
    ),
    OperationLog,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$OperationHistoryTableTableManager get operationHistory =>
      $$OperationHistoryTableTableManager(_db, _db.operationHistory);
  $$OperationLogsTableTableManager get operationLogs =>
      $$OperationLogsTableTableManager(_db, _db.operationLogs);
}
