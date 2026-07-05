// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _settingKeyMeta =
      const VerificationMeta('settingKey');
  @override
  late final GeneratedColumn<String> settingKey = GeneratedColumn<String>(
      'setting_key', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _settingValueMeta =
      const VerificationMeta('settingValue');
  @override
  late final GeneratedColumn<String> settingValue = GeneratedColumn<String>(
      'setting_value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueTypeMeta =
      const VerificationMeta('valueType');
  @override
  late final GeneratedColumn<String> valueType = GeneratedColumn<String>(
      'value_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, DateTime> updatedAt =
      GeneratedColumn<DateTime>('updated_at', aliasedName, false,
              type: DriftSqlType.dateTime, requiredDuringInsert: true)
          .withConverter<DateTime>($AppSettingsTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns =>
      [id, settingKey, settingValue, valueType, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(Insertable<AppSetting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('setting_key')) {
      context.handle(
          _settingKeyMeta,
          settingKey.isAcceptableOrUnknown(
              data['setting_key']!, _settingKeyMeta));
    } else if (isInserting) {
      context.missing(_settingKeyMeta);
    }
    if (data.containsKey('setting_value')) {
      context.handle(
          _settingValueMeta,
          settingValue.isAcceptableOrUnknown(
              data['setting_value']!, _settingValueMeta));
    } else if (isInserting) {
      context.missing(_settingValueMeta);
    }
    if (data.containsKey('value_type')) {
      context.handle(_valueTypeMeta,
          valueType.isAcceptableOrUnknown(data['value_type']!, _valueTypeMeta));
    } else if (isInserting) {
      context.missing(_valueTypeMeta);
    }
    context.handle(_updatedAtMeta, const VerificationResult.success());
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      settingKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}setting_key'])!,
      settingValue: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}setting_value'])!,
      valueType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value_type'])!,
      updatedAt: $AppSettingsTable.$converterupdatedAt.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!),
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, DateTime> $converterupdatedAt =
      const UtcDateTimeConverter();
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final int id;
  final String settingKey;
  final String settingValue;
  final String valueType;
  final DateTime updatedAt;
  const AppSetting(
      {required this.id,
      required this.settingKey,
      required this.settingValue,
      required this.valueType,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['setting_key'] = Variable<String>(settingKey);
    map['setting_value'] = Variable<String>(settingValue);
    map['value_type'] = Variable<String>(valueType);
    {
      map['updated_at'] = Variable<DateTime>(
          $AppSettingsTable.$converterupdatedAt.toSql(updatedAt));
    }
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      id: Value(id),
      settingKey: Value(settingKey),
      settingValue: Value(settingValue),
      valueType: Value(valueType),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppSetting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      id: serializer.fromJson<int>(json['id']),
      settingKey: serializer.fromJson<String>(json['settingKey']),
      settingValue: serializer.fromJson<String>(json['settingValue']),
      valueType: serializer.fromJson<String>(json['valueType']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'settingKey': serializer.toJson<String>(settingKey),
      'settingValue': serializer.toJson<String>(settingValue),
      'valueType': serializer.toJson<String>(valueType),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AppSetting copyWith(
          {int? id,
          String? settingKey,
          String? settingValue,
          String? valueType,
          DateTime? updatedAt}) =>
      AppSetting(
        id: id ?? this.id,
        settingKey: settingKey ?? this.settingKey,
        settingValue: settingValue ?? this.settingValue,
        valueType: valueType ?? this.valueType,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      id: data.id.present ? data.id.value : this.id,
      settingKey:
          data.settingKey.present ? data.settingKey.value : this.settingKey,
      settingValue: data.settingValue.present
          ? data.settingValue.value
          : this.settingValue,
      valueType: data.valueType.present ? data.valueType.value : this.valueType,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('id: $id, ')
          ..write('settingKey: $settingKey, ')
          ..write('settingValue: $settingValue, ')
          ..write('valueType: $valueType, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, settingKey, settingValue, valueType, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.id == this.id &&
          other.settingKey == this.settingKey &&
          other.settingValue == this.settingValue &&
          other.valueType == this.valueType &&
          other.updatedAt == this.updatedAt);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<int> id;
  final Value<String> settingKey;
  final Value<String> settingValue;
  final Value<String> valueType;
  final Value<DateTime> updatedAt;
  const AppSettingsCompanion({
    this.id = const Value.absent(),
    this.settingKey = const Value.absent(),
    this.settingValue = const Value.absent(),
    this.valueType = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    this.id = const Value.absent(),
    required String settingKey,
    required String settingValue,
    required String valueType,
    required DateTime updatedAt,
  })  : settingKey = Value(settingKey),
        settingValue = Value(settingValue),
        valueType = Value(valueType),
        updatedAt = Value(updatedAt);
  static Insertable<AppSetting> custom({
    Expression<int>? id,
    Expression<String>? settingKey,
    Expression<String>? settingValue,
    Expression<String>? valueType,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (settingKey != null) 'setting_key': settingKey,
      if (settingValue != null) 'setting_value': settingValue,
      if (valueType != null) 'value_type': valueType,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AppSettingsCompanion copyWith(
      {Value<int>? id,
      Value<String>? settingKey,
      Value<String>? settingValue,
      Value<String>? valueType,
      Value<DateTime>? updatedAt}) {
    return AppSettingsCompanion(
      id: id ?? this.id,
      settingKey: settingKey ?? this.settingKey,
      settingValue: settingValue ?? this.settingValue,
      valueType: valueType ?? this.valueType,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (settingKey.present) {
      map['setting_key'] = Variable<String>(settingKey.value);
    }
    if (settingValue.present) {
      map['setting_value'] = Variable<String>(settingValue.value);
    }
    if (valueType.present) {
      map['value_type'] = Variable<String>(valueType.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(
          $AppSettingsTable.$converterupdatedAt.toSql(updatedAt.value));
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('id: $id, ')
          ..write('settingKey: $settingKey, ')
          ..write('settingValue: $settingValue, ')
          ..write('valueType: $valueType, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

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

class $FavoriteTemplatesTable extends FavoriteTemplates
    with TableInfo<$FavoriteTemplatesTable, FavoriteTemplate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoriteTemplatesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _templateNameMeta =
      const VerificationMeta('templateName');
  @override
  late final GeneratedColumn<String> templateName = GeneratedColumn<String>(
      'template_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _parametersJsonMeta =
      const VerificationMeta('parametersJson');
  @override
  late final GeneratedColumn<String> parametersJson = GeneratedColumn<String>(
      'parameters_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, DateTime> createdAt =
      GeneratedColumn<DateTime>('created_at', aliasedName, false,
              type: DriftSqlType.dateTime, requiredDuringInsert: true)
          .withConverter<DateTime>($FavoriteTemplatesTable.$convertercreatedAt);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, DateTime> updatedAt =
      GeneratedColumn<DateTime>('updated_at', aliasedName, false,
              type: DriftSqlType.dateTime, requiredDuringInsert: true)
          .withConverter<DateTime>($FavoriteTemplatesTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns =>
      [id, featureName, templateName, parametersJson, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorite_templates';
  @override
  VerificationContext validateIntegrity(Insertable<FavoriteTemplate> instance,
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
    if (data.containsKey('template_name')) {
      context.handle(
          _templateNameMeta,
          templateName.isAcceptableOrUnknown(
              data['template_name']!, _templateNameMeta));
    } else if (isInserting) {
      context.missing(_templateNameMeta);
    }
    if (data.containsKey('parameters_json')) {
      context.handle(
          _parametersJsonMeta,
          parametersJson.isAcceptableOrUnknown(
              data['parameters_json']!, _parametersJsonMeta));
    } else if (isInserting) {
      context.missing(_parametersJsonMeta);
    }
    context.handle(_createdAtMeta, const VerificationResult.success());
    context.handle(_updatedAtMeta, const VerificationResult.success());
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FavoriteTemplate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoriteTemplate(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      featureName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}feature_name'])!,
      templateName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}template_name'])!,
      parametersJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}parameters_json'])!,
      createdAt: $FavoriteTemplatesTable.$convertercreatedAt.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!),
      updatedAt: $FavoriteTemplatesTable.$converterupdatedAt.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!),
    );
  }

  @override
  $FavoriteTemplatesTable createAlias(String alias) {
    return $FavoriteTemplatesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, DateTime> $convertercreatedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime, DateTime> $converterupdatedAt =
      const UtcDateTimeConverter();
}

class FavoriteTemplate extends DataClass
    implements Insertable<FavoriteTemplate> {
  final int id;
  final String featureName;
  final String templateName;
  final String parametersJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  const FavoriteTemplate(
      {required this.id,
      required this.featureName,
      required this.templateName,
      required this.parametersJson,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['feature_name'] = Variable<String>(featureName);
    map['template_name'] = Variable<String>(templateName);
    map['parameters_json'] = Variable<String>(parametersJson);
    {
      map['created_at'] = Variable<DateTime>(
          $FavoriteTemplatesTable.$convertercreatedAt.toSql(createdAt));
    }
    {
      map['updated_at'] = Variable<DateTime>(
          $FavoriteTemplatesTable.$converterupdatedAt.toSql(updatedAt));
    }
    return map;
  }

  FavoriteTemplatesCompanion toCompanion(bool nullToAbsent) {
    return FavoriteTemplatesCompanion(
      id: Value(id),
      featureName: Value(featureName),
      templateName: Value(templateName),
      parametersJson: Value(parametersJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory FavoriteTemplate.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoriteTemplate(
      id: serializer.fromJson<int>(json['id']),
      featureName: serializer.fromJson<String>(json['featureName']),
      templateName: serializer.fromJson<String>(json['templateName']),
      parametersJson: serializer.fromJson<String>(json['parametersJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'featureName': serializer.toJson<String>(featureName),
      'templateName': serializer.toJson<String>(templateName),
      'parametersJson': serializer.toJson<String>(parametersJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  FavoriteTemplate copyWith(
          {int? id,
          String? featureName,
          String? templateName,
          String? parametersJson,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      FavoriteTemplate(
        id: id ?? this.id,
        featureName: featureName ?? this.featureName,
        templateName: templateName ?? this.templateName,
        parametersJson: parametersJson ?? this.parametersJson,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  FavoriteTemplate copyWithCompanion(FavoriteTemplatesCompanion data) {
    return FavoriteTemplate(
      id: data.id.present ? data.id.value : this.id,
      featureName:
          data.featureName.present ? data.featureName.value : this.featureName,
      templateName: data.templateName.present
          ? data.templateName.value
          : this.templateName,
      parametersJson: data.parametersJson.present
          ? data.parametersJson.value
          : this.parametersJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteTemplate(')
          ..write('id: $id, ')
          ..write('featureName: $featureName, ')
          ..write('templateName: $templateName, ')
          ..write('parametersJson: $parametersJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, featureName, templateName, parametersJson, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoriteTemplate &&
          other.id == this.id &&
          other.featureName == this.featureName &&
          other.templateName == this.templateName &&
          other.parametersJson == this.parametersJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class FavoriteTemplatesCompanion extends UpdateCompanion<FavoriteTemplate> {
  final Value<int> id;
  final Value<String> featureName;
  final Value<String> templateName;
  final Value<String> parametersJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const FavoriteTemplatesCompanion({
    this.id = const Value.absent(),
    this.featureName = const Value.absent(),
    this.templateName = const Value.absent(),
    this.parametersJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  FavoriteTemplatesCompanion.insert({
    this.id = const Value.absent(),
    required String featureName,
    required String templateName,
    required String parametersJson,
    required DateTime createdAt,
    required DateTime updatedAt,
  })  : featureName = Value(featureName),
        templateName = Value(templateName),
        parametersJson = Value(parametersJson),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<FavoriteTemplate> custom({
    Expression<int>? id,
    Expression<String>? featureName,
    Expression<String>? templateName,
    Expression<String>? parametersJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (featureName != null) 'feature_name': featureName,
      if (templateName != null) 'template_name': templateName,
      if (parametersJson != null) 'parameters_json': parametersJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  FavoriteTemplatesCompanion copyWith(
      {Value<int>? id,
      Value<String>? featureName,
      Value<String>? templateName,
      Value<String>? parametersJson,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt}) {
    return FavoriteTemplatesCompanion(
      id: id ?? this.id,
      featureName: featureName ?? this.featureName,
      templateName: templateName ?? this.templateName,
      parametersJson: parametersJson ?? this.parametersJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (templateName.present) {
      map['template_name'] = Variable<String>(templateName.value);
    }
    if (parametersJson.present) {
      map['parameters_json'] = Variable<String>(parametersJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(
          $FavoriteTemplatesTable.$convertercreatedAt.toSql(createdAt.value));
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(
          $FavoriteTemplatesTable.$converterupdatedAt.toSql(updatedAt.value));
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('featureName: $featureName, ')
          ..write('templateName: $templateName, ')
          ..write('parametersJson: $parametersJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $RecentFilesTable extends RecentFiles
    with TableInfo<$RecentFilesTable, RecentFile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecentFilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _fileNameMeta =
      const VerificationMeta('fileName');
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
      'file_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _mimeTypeMeta =
      const VerificationMeta('mimeType');
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
      'mime_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sizeBytesMeta =
      const VerificationMeta('sizeBytes');
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
      'size_bytes', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _lastUsedAtMeta =
      const VerificationMeta('lastUsedAt');
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, DateTime> lastUsedAt =
      GeneratedColumn<DateTime>('last_used_at', aliasedName, false,
              type: DriftSqlType.dateTime, requiredDuringInsert: true)
          .withConverter<DateTime>($RecentFilesTable.$converterlastUsedAt);
  @override
  List<GeneratedColumn> get $columns =>
      [id, filePath, fileName, mimeType, sizeBytes, lastUsedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recent_files';
  @override
  VerificationContext validateIntegrity(Insertable<RecentFile> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(_fileNameMeta,
          fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta));
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(_mimeTypeMeta,
          mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta));
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(_sizeBytesMeta,
          sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta));
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    context.handle(_lastUsedAtMeta, const VerificationResult.success());
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecentFile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecentFile(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path'])!,
      fileName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_name'])!,
      mimeType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mime_type'])!,
      sizeBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}size_bytes'])!,
      lastUsedAt: $RecentFilesTable.$converterlastUsedAt.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.dateTime, data['${effectivePrefix}last_used_at'])!),
    );
  }

  @override
  $RecentFilesTable createAlias(String alias) {
    return $RecentFilesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, DateTime> $converterlastUsedAt =
      const UtcDateTimeConverter();
}

class RecentFile extends DataClass implements Insertable<RecentFile> {
  final int id;
  final String filePath;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final DateTime lastUsedAt;
  const RecentFile(
      {required this.id,
      required this.filePath,
      required this.fileName,
      required this.mimeType,
      required this.sizeBytes,
      required this.lastUsedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['file_path'] = Variable<String>(filePath);
    map['file_name'] = Variable<String>(fileName);
    map['mime_type'] = Variable<String>(mimeType);
    map['size_bytes'] = Variable<int>(sizeBytes);
    {
      map['last_used_at'] = Variable<DateTime>(
          $RecentFilesTable.$converterlastUsedAt.toSql(lastUsedAt));
    }
    return map;
  }

  RecentFilesCompanion toCompanion(bool nullToAbsent) {
    return RecentFilesCompanion(
      id: Value(id),
      filePath: Value(filePath),
      fileName: Value(fileName),
      mimeType: Value(mimeType),
      sizeBytes: Value(sizeBytes),
      lastUsedAt: Value(lastUsedAt),
    );
  }

  factory RecentFile.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecentFile(
      id: serializer.fromJson<int>(json['id']),
      filePath: serializer.fromJson<String>(json['filePath']),
      fileName: serializer.fromJson<String>(json['fileName']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      lastUsedAt: serializer.fromJson<DateTime>(json['lastUsedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'filePath': serializer.toJson<String>(filePath),
      'fileName': serializer.toJson<String>(fileName),
      'mimeType': serializer.toJson<String>(mimeType),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'lastUsedAt': serializer.toJson<DateTime>(lastUsedAt),
    };
  }

  RecentFile copyWith(
          {int? id,
          String? filePath,
          String? fileName,
          String? mimeType,
          int? sizeBytes,
          DateTime? lastUsedAt}) =>
      RecentFile(
        id: id ?? this.id,
        filePath: filePath ?? this.filePath,
        fileName: fileName ?? this.fileName,
        mimeType: mimeType ?? this.mimeType,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      );
  RecentFile copyWithCompanion(RecentFilesCompanion data) {
    return RecentFile(
      id: data.id.present ? data.id.value : this.id,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      lastUsedAt:
          data.lastUsedAt.present ? data.lastUsedAt.value : this.lastUsedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecentFile(')
          ..write('id: $id, ')
          ..write('filePath: $filePath, ')
          ..write('fileName: $fileName, ')
          ..write('mimeType: $mimeType, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('lastUsedAt: $lastUsedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, filePath, fileName, mimeType, sizeBytes, lastUsedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecentFile &&
          other.id == this.id &&
          other.filePath == this.filePath &&
          other.fileName == this.fileName &&
          other.mimeType == this.mimeType &&
          other.sizeBytes == this.sizeBytes &&
          other.lastUsedAt == this.lastUsedAt);
}

class RecentFilesCompanion extends UpdateCompanion<RecentFile> {
  final Value<int> id;
  final Value<String> filePath;
  final Value<String> fileName;
  final Value<String> mimeType;
  final Value<int> sizeBytes;
  final Value<DateTime> lastUsedAt;
  const RecentFilesCompanion({
    this.id = const Value.absent(),
    this.filePath = const Value.absent(),
    this.fileName = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
  });
  RecentFilesCompanion.insert({
    this.id = const Value.absent(),
    required String filePath,
    required String fileName,
    required String mimeType,
    required int sizeBytes,
    required DateTime lastUsedAt,
  })  : filePath = Value(filePath),
        fileName = Value(fileName),
        mimeType = Value(mimeType),
        sizeBytes = Value(sizeBytes),
        lastUsedAt = Value(lastUsedAt);
  static Insertable<RecentFile> custom({
    Expression<int>? id,
    Expression<String>? filePath,
    Expression<String>? fileName,
    Expression<String>? mimeType,
    Expression<int>? sizeBytes,
    Expression<DateTime>? lastUsedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (filePath != null) 'file_path': filePath,
      if (fileName != null) 'file_name': fileName,
      if (mimeType != null) 'mime_type': mimeType,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (lastUsedAt != null) 'last_used_at': lastUsedAt,
    });
  }

  RecentFilesCompanion copyWith(
      {Value<int>? id,
      Value<String>? filePath,
      Value<String>? fileName,
      Value<String>? mimeType,
      Value<int>? sizeBytes,
      Value<DateTime>? lastUsedAt}) {
    return RecentFilesCompanion(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (lastUsedAt.present) {
      map['last_used_at'] = Variable<DateTime>(
          $RecentFilesTable.$converterlastUsedAt.toSql(lastUsedAt.value));
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecentFilesCompanion(')
          ..write('id: $id, ')
          ..write('filePath: $filePath, ')
          ..write('fileName: $fileName, ')
          ..write('mimeType: $mimeType, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('lastUsedAt: $lastUsedAt')
          ..write(')'))
        .toString();
  }
}

class $CacheRecordsTable extends CacheRecords
    with TableInfo<$CacheRecordsTable, CacheRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CacheRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _cacheKeyMeta =
      const VerificationMeta('cacheKey');
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
      'cache_key', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sizeBytesMeta =
      const VerificationMeta('sizeBytes');
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
      'size_bytes', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, DateTime> createdAt =
      GeneratedColumn<DateTime>('created_at', aliasedName, false,
              type: DriftSqlType.dateTime, requiredDuringInsert: true)
          .withConverter<DateTime>($CacheRecordsTable.$convertercreatedAt);
  static const VerificationMeta _expiresAtMeta =
      const VerificationMeta('expiresAt');
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, DateTime> expiresAt =
      GeneratedColumn<DateTime>('expires_at', aliasedName, true,
              type: DriftSqlType.dateTime, requiredDuringInsert: false)
          .withConverter<DateTime?>($CacheRecordsTable.$converterexpiresAtn);
  @override
  List<GeneratedColumn> get $columns =>
      [id, cacheKey, filePath, sizeBytes, createdAt, expiresAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_records';
  @override
  VerificationContext validateIntegrity(Insertable<CacheRecord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('cache_key')) {
      context.handle(_cacheKeyMeta,
          cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta));
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(_sizeBytesMeta,
          sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta));
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    context.handle(_createdAtMeta, const VerificationResult.success());
    context.handle(_expiresAtMeta, const VerificationResult.success());
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CacheRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheRecord(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      cacheKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cache_key'])!,
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path'])!,
      sizeBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}size_bytes'])!,
      createdAt: $CacheRecordsTable.$convertercreatedAt.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!),
      expiresAt: $CacheRecordsTable.$converterexpiresAtn.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.dateTime, data['${effectivePrefix}expires_at'])),
    );
  }

  @override
  $CacheRecordsTable createAlias(String alias) {
    return $CacheRecordsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, DateTime> $convertercreatedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime, DateTime> $converterexpiresAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime?, DateTime?> $converterexpiresAtn =
      NullAwareTypeConverter.wrap($converterexpiresAt);
}

class CacheRecord extends DataClass implements Insertable<CacheRecord> {
  final int id;
  final String cacheKey;
  final String filePath;
  final int sizeBytes;
  final DateTime createdAt;
  final DateTime? expiresAt;
  const CacheRecord(
      {required this.id,
      required this.cacheKey,
      required this.filePath,
      required this.sizeBytes,
      required this.createdAt,
      this.expiresAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['cache_key'] = Variable<String>(cacheKey);
    map['file_path'] = Variable<String>(filePath);
    map['size_bytes'] = Variable<int>(sizeBytes);
    {
      map['created_at'] = Variable<DateTime>(
          $CacheRecordsTable.$convertercreatedAt.toSql(createdAt));
    }
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<DateTime>(
          $CacheRecordsTable.$converterexpiresAtn.toSql(expiresAt));
    }
    return map;
  }

  CacheRecordsCompanion toCompanion(bool nullToAbsent) {
    return CacheRecordsCompanion(
      id: Value(id),
      cacheKey: Value(cacheKey),
      filePath: Value(filePath),
      sizeBytes: Value(sizeBytes),
      createdAt: Value(createdAt),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
    );
  }

  factory CacheRecord.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheRecord(
      id: serializer.fromJson<int>(json['id']),
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      filePath: serializer.fromJson<String>(json['filePath']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      expiresAt: serializer.fromJson<DateTime?>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'cacheKey': serializer.toJson<String>(cacheKey),
      'filePath': serializer.toJson<String>(filePath),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'expiresAt': serializer.toJson<DateTime?>(expiresAt),
    };
  }

  CacheRecord copyWith(
          {int? id,
          String? cacheKey,
          String? filePath,
          int? sizeBytes,
          DateTime? createdAt,
          Value<DateTime?> expiresAt = const Value.absent()}) =>
      CacheRecord(
        id: id ?? this.id,
        cacheKey: cacheKey ?? this.cacheKey,
        filePath: filePath ?? this.filePath,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        createdAt: createdAt ?? this.createdAt,
        expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
      );
  CacheRecord copyWithCompanion(CacheRecordsCompanion data) {
    return CacheRecord(
      id: data.id.present ? data.id.value : this.id,
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheRecord(')
          ..write('id: $id, ')
          ..write('cacheKey: $cacheKey, ')
          ..write('filePath: $filePath, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('createdAt: $createdAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, cacheKey, filePath, sizeBytes, createdAt, expiresAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheRecord &&
          other.id == this.id &&
          other.cacheKey == this.cacheKey &&
          other.filePath == this.filePath &&
          other.sizeBytes == this.sizeBytes &&
          other.createdAt == this.createdAt &&
          other.expiresAt == this.expiresAt);
}

class CacheRecordsCompanion extends UpdateCompanion<CacheRecord> {
  final Value<int> id;
  final Value<String> cacheKey;
  final Value<String> filePath;
  final Value<int> sizeBytes;
  final Value<DateTime> createdAt;
  final Value<DateTime?> expiresAt;
  const CacheRecordsCompanion({
    this.id = const Value.absent(),
    this.cacheKey = const Value.absent(),
    this.filePath = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
  });
  CacheRecordsCompanion.insert({
    this.id = const Value.absent(),
    required String cacheKey,
    required String filePath,
    required int sizeBytes,
    required DateTime createdAt,
    this.expiresAt = const Value.absent(),
  })  : cacheKey = Value(cacheKey),
        filePath = Value(filePath),
        sizeBytes = Value(sizeBytes),
        createdAt = Value(createdAt);
  static Insertable<CacheRecord> custom({
    Expression<int>? id,
    Expression<String>? cacheKey,
    Expression<String>? filePath,
    Expression<int>? sizeBytes,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? expiresAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cacheKey != null) 'cache_key': cacheKey,
      if (filePath != null) 'file_path': filePath,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (createdAt != null) 'created_at': createdAt,
      if (expiresAt != null) 'expires_at': expiresAt,
    });
  }

  CacheRecordsCompanion copyWith(
      {Value<int>? id,
      Value<String>? cacheKey,
      Value<String>? filePath,
      Value<int>? sizeBytes,
      Value<DateTime>? createdAt,
      Value<DateTime?>? expiresAt}) {
    return CacheRecordsCompanion(
      id: id ?? this.id,
      cacheKey: cacheKey ?? this.cacheKey,
      filePath: filePath ?? this.filePath,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(
          $CacheRecordsTable.$convertercreatedAt.toSql(createdAt.value));
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(
          $CacheRecordsTable.$converterexpiresAtn.toSql(expiresAt.value));
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheRecordsCompanion(')
          ..write('id: $id, ')
          ..write('cacheKey: $cacheKey, ')
          ..write('filePath: $filePath, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('createdAt: $createdAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $OperationHistoryTable operationHistory =
      $OperationHistoryTable(this);
  late final $OperationLogsTable operationLogs = $OperationLogsTable(this);
  late final $FavoriteTemplatesTable favoriteTemplates =
      $FavoriteTemplatesTable(this);
  late final $RecentFilesTable recentFiles = $RecentFilesTable(this);
  late final $CacheRecordsTable cacheRecords = $CacheRecordsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        appSettings,
        operationHistory,
        operationLogs,
        favoriteTemplates,
        recentFiles,
        cacheRecords
      ];
}

typedef $$AppSettingsTableCreateCompanionBuilder = AppSettingsCompanion
    Function({
  Value<int> id,
  required String settingKey,
  required String settingValue,
  required String valueType,
  required DateTime updatedAt,
});
typedef $$AppSettingsTableUpdateCompanionBuilder = AppSettingsCompanion
    Function({
  Value<int> id,
  Value<String> settingKey,
  Value<String> settingValue,
  Value<String> valueType,
  Value<DateTime> updatedAt,
});

class $$AppSettingsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get settingKey => $state.composableBuilder(
      column: $state.table.settingKey,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get settingValue => $state.composableBuilder(
      column: $state.table.settingValue,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get valueType => $state.composableBuilder(
      column: $state.table.valueType,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnWithTypeConverterFilters<DateTime, DateTime, DateTime> get updatedAt =>
      $state.composableBuilder(
          column: $state.table.updatedAt,
          builder: (column, joinBuilders) => ColumnWithTypeConverterFilters(
              column,
              joinBuilders: joinBuilders));
}

class $$AppSettingsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get settingKey => $state.composableBuilder(
      column: $state.table.settingKey,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get settingValue => $state.composableBuilder(
      column: $state.table.settingValue,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get valueType => $state.composableBuilder(
      column: $state.table.valueType,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

class $$AppSettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppSettingsTable,
    AppSetting,
    $$AppSettingsTableFilterComposer,
    $$AppSettingsTableOrderingComposer,
    $$AppSettingsTableCreateCompanionBuilder,
    $$AppSettingsTableUpdateCompanionBuilder,
    (AppSetting, BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>),
    AppSetting,
    PrefetchHooks Function()> {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$AppSettingsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$AppSettingsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> settingKey = const Value.absent(),
            Value<String> settingValue = const Value.absent(),
            Value<String> valueType = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              AppSettingsCompanion(
            id: id,
            settingKey: settingKey,
            settingValue: settingValue,
            valueType: valueType,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String settingKey,
            required String settingValue,
            required String valueType,
            required DateTime updatedAt,
          }) =>
              AppSettingsCompanion.insert(
            id: id,
            settingKey: settingKey,
            settingValue: settingValue,
            valueType: valueType,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppSettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AppSettingsTable,
    AppSetting,
    $$AppSettingsTableFilterComposer,
    $$AppSettingsTableOrderingComposer,
    $$AppSettingsTableCreateCompanionBuilder,
    $$AppSettingsTableUpdateCompanionBuilder,
    (AppSetting, BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>),
    AppSetting,
    PrefetchHooks Function()>;
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
typedef $$FavoriteTemplatesTableCreateCompanionBuilder
    = FavoriteTemplatesCompanion Function({
  Value<int> id,
  required String featureName,
  required String templateName,
  required String parametersJson,
  required DateTime createdAt,
  required DateTime updatedAt,
});
typedef $$FavoriteTemplatesTableUpdateCompanionBuilder
    = FavoriteTemplatesCompanion Function({
  Value<int> id,
  Value<String> featureName,
  Value<String> templateName,
  Value<String> parametersJson,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

class $$FavoriteTemplatesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $FavoriteTemplatesTable> {
  $$FavoriteTemplatesTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get featureName => $state.composableBuilder(
      column: $state.table.featureName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get templateName => $state.composableBuilder(
      column: $state.table.templateName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get parametersJson => $state.composableBuilder(
      column: $state.table.parametersJson,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnWithTypeConverterFilters<DateTime, DateTime, DateTime> get createdAt =>
      $state.composableBuilder(
          column: $state.table.createdAt,
          builder: (column, joinBuilders) => ColumnWithTypeConverterFilters(
              column,
              joinBuilders: joinBuilders));

  ColumnWithTypeConverterFilters<DateTime, DateTime, DateTime> get updatedAt =>
      $state.composableBuilder(
          column: $state.table.updatedAt,
          builder: (column, joinBuilders) => ColumnWithTypeConverterFilters(
              column,
              joinBuilders: joinBuilders));
}

class $$FavoriteTemplatesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $FavoriteTemplatesTable> {
  $$FavoriteTemplatesTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get featureName => $state.composableBuilder(
      column: $state.table.featureName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get templateName => $state.composableBuilder(
      column: $state.table.templateName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get parametersJson => $state.composableBuilder(
      column: $state.table.parametersJson,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

class $$FavoriteTemplatesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FavoriteTemplatesTable,
    FavoriteTemplate,
    $$FavoriteTemplatesTableFilterComposer,
    $$FavoriteTemplatesTableOrderingComposer,
    $$FavoriteTemplatesTableCreateCompanionBuilder,
    $$FavoriteTemplatesTableUpdateCompanionBuilder,
    (
      FavoriteTemplate,
      BaseReferences<_$AppDatabase, $FavoriteTemplatesTable, FavoriteTemplate>
    ),
    FavoriteTemplate,
    PrefetchHooks Function()> {
  $$FavoriteTemplatesTableTableManager(
      _$AppDatabase db, $FavoriteTemplatesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$FavoriteTemplatesTableFilterComposer(ComposerState(db, table)),
          orderingComposer: $$FavoriteTemplatesTableOrderingComposer(
              ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> featureName = const Value.absent(),
            Value<String> templateName = const Value.absent(),
            Value<String> parametersJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              FavoriteTemplatesCompanion(
            id: id,
            featureName: featureName,
            templateName: templateName,
            parametersJson: parametersJson,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String featureName,
            required String templateName,
            required String parametersJson,
            required DateTime createdAt,
            required DateTime updatedAt,
          }) =>
              FavoriteTemplatesCompanion.insert(
            id: id,
            featureName: featureName,
            templateName: templateName,
            parametersJson: parametersJson,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FavoriteTemplatesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FavoriteTemplatesTable,
    FavoriteTemplate,
    $$FavoriteTemplatesTableFilterComposer,
    $$FavoriteTemplatesTableOrderingComposer,
    $$FavoriteTemplatesTableCreateCompanionBuilder,
    $$FavoriteTemplatesTableUpdateCompanionBuilder,
    (
      FavoriteTemplate,
      BaseReferences<_$AppDatabase, $FavoriteTemplatesTable, FavoriteTemplate>
    ),
    FavoriteTemplate,
    PrefetchHooks Function()>;
typedef $$RecentFilesTableCreateCompanionBuilder = RecentFilesCompanion
    Function({
  Value<int> id,
  required String filePath,
  required String fileName,
  required String mimeType,
  required int sizeBytes,
  required DateTime lastUsedAt,
});
typedef $$RecentFilesTableUpdateCompanionBuilder = RecentFilesCompanion
    Function({
  Value<int> id,
  Value<String> filePath,
  Value<String> fileName,
  Value<String> mimeType,
  Value<int> sizeBytes,
  Value<DateTime> lastUsedAt,
});

class $$RecentFilesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $RecentFilesTable> {
  $$RecentFilesTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get filePath => $state.composableBuilder(
      column: $state.table.filePath,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get fileName => $state.composableBuilder(
      column: $state.table.fileName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get mimeType => $state.composableBuilder(
      column: $state.table.mimeType,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get sizeBytes => $state.composableBuilder(
      column: $state.table.sizeBytes,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnWithTypeConverterFilters<DateTime, DateTime, DateTime> get lastUsedAt =>
      $state.composableBuilder(
          column: $state.table.lastUsedAt,
          builder: (column, joinBuilders) => ColumnWithTypeConverterFilters(
              column,
              joinBuilders: joinBuilders));
}

class $$RecentFilesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $RecentFilesTable> {
  $$RecentFilesTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get filePath => $state.composableBuilder(
      column: $state.table.filePath,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get fileName => $state.composableBuilder(
      column: $state.table.fileName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get mimeType => $state.composableBuilder(
      column: $state.table.mimeType,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get sizeBytes => $state.composableBuilder(
      column: $state.table.sizeBytes,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get lastUsedAt => $state.composableBuilder(
      column: $state.table.lastUsedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

class $$RecentFilesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RecentFilesTable,
    RecentFile,
    $$RecentFilesTableFilterComposer,
    $$RecentFilesTableOrderingComposer,
    $$RecentFilesTableCreateCompanionBuilder,
    $$RecentFilesTableUpdateCompanionBuilder,
    (RecentFile, BaseReferences<_$AppDatabase, $RecentFilesTable, RecentFile>),
    RecentFile,
    PrefetchHooks Function()> {
  $$RecentFilesTableTableManager(_$AppDatabase db, $RecentFilesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$RecentFilesTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$RecentFilesTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> filePath = const Value.absent(),
            Value<String> fileName = const Value.absent(),
            Value<String> mimeType = const Value.absent(),
            Value<int> sizeBytes = const Value.absent(),
            Value<DateTime> lastUsedAt = const Value.absent(),
          }) =>
              RecentFilesCompanion(
            id: id,
            filePath: filePath,
            fileName: fileName,
            mimeType: mimeType,
            sizeBytes: sizeBytes,
            lastUsedAt: lastUsedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String filePath,
            required String fileName,
            required String mimeType,
            required int sizeBytes,
            required DateTime lastUsedAt,
          }) =>
              RecentFilesCompanion.insert(
            id: id,
            filePath: filePath,
            fileName: fileName,
            mimeType: mimeType,
            sizeBytes: sizeBytes,
            lastUsedAt: lastUsedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RecentFilesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RecentFilesTable,
    RecentFile,
    $$RecentFilesTableFilterComposer,
    $$RecentFilesTableOrderingComposer,
    $$RecentFilesTableCreateCompanionBuilder,
    $$RecentFilesTableUpdateCompanionBuilder,
    (RecentFile, BaseReferences<_$AppDatabase, $RecentFilesTable, RecentFile>),
    RecentFile,
    PrefetchHooks Function()>;
typedef $$CacheRecordsTableCreateCompanionBuilder = CacheRecordsCompanion
    Function({
  Value<int> id,
  required String cacheKey,
  required String filePath,
  required int sizeBytes,
  required DateTime createdAt,
  Value<DateTime?> expiresAt,
});
typedef $$CacheRecordsTableUpdateCompanionBuilder = CacheRecordsCompanion
    Function({
  Value<int> id,
  Value<String> cacheKey,
  Value<String> filePath,
  Value<int> sizeBytes,
  Value<DateTime> createdAt,
  Value<DateTime?> expiresAt,
});

class $$CacheRecordsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $CacheRecordsTable> {
  $$CacheRecordsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get cacheKey => $state.composableBuilder(
      column: $state.table.cacheKey,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get filePath => $state.composableBuilder(
      column: $state.table.filePath,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get sizeBytes => $state.composableBuilder(
      column: $state.table.sizeBytes,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnWithTypeConverterFilters<DateTime, DateTime, DateTime> get createdAt =>
      $state.composableBuilder(
          column: $state.table.createdAt,
          builder: (column, joinBuilders) => ColumnWithTypeConverterFilters(
              column,
              joinBuilders: joinBuilders));

  ColumnWithTypeConverterFilters<DateTime?, DateTime, DateTime> get expiresAt =>
      $state.composableBuilder(
          column: $state.table.expiresAt,
          builder: (column, joinBuilders) => ColumnWithTypeConverterFilters(
              column,
              joinBuilders: joinBuilders));
}

class $$CacheRecordsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $CacheRecordsTable> {
  $$CacheRecordsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get cacheKey => $state.composableBuilder(
      column: $state.table.cacheKey,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get filePath => $state.composableBuilder(
      column: $state.table.filePath,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get sizeBytes => $state.composableBuilder(
      column: $state.table.sizeBytes,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get expiresAt => $state.composableBuilder(
      column: $state.table.expiresAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

class $$CacheRecordsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CacheRecordsTable,
    CacheRecord,
    $$CacheRecordsTableFilterComposer,
    $$CacheRecordsTableOrderingComposer,
    $$CacheRecordsTableCreateCompanionBuilder,
    $$CacheRecordsTableUpdateCompanionBuilder,
    (
      CacheRecord,
      BaseReferences<_$AppDatabase, $CacheRecordsTable, CacheRecord>
    ),
    CacheRecord,
    PrefetchHooks Function()> {
  $$CacheRecordsTableTableManager(_$AppDatabase db, $CacheRecordsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$CacheRecordsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$CacheRecordsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> cacheKey = const Value.absent(),
            Value<String> filePath = const Value.absent(),
            Value<int> sizeBytes = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> expiresAt = const Value.absent(),
          }) =>
              CacheRecordsCompanion(
            id: id,
            cacheKey: cacheKey,
            filePath: filePath,
            sizeBytes: sizeBytes,
            createdAt: createdAt,
            expiresAt: expiresAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String cacheKey,
            required String filePath,
            required int sizeBytes,
            required DateTime createdAt,
            Value<DateTime?> expiresAt = const Value.absent(),
          }) =>
              CacheRecordsCompanion.insert(
            id: id,
            cacheKey: cacheKey,
            filePath: filePath,
            sizeBytes: sizeBytes,
            createdAt: createdAt,
            expiresAt: expiresAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CacheRecordsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CacheRecordsTable,
    CacheRecord,
    $$CacheRecordsTableFilterComposer,
    $$CacheRecordsTableOrderingComposer,
    $$CacheRecordsTableCreateCompanionBuilder,
    $$CacheRecordsTableUpdateCompanionBuilder,
    (
      CacheRecord,
      BaseReferences<_$AppDatabase, $CacheRecordsTable, CacheRecord>
    ),
    CacheRecord,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$OperationHistoryTableTableManager get operationHistory =>
      $$OperationHistoryTableTableManager(_db, _db.operationHistory);
  $$OperationLogsTableTableManager get operationLogs =>
      $$OperationLogsTableTableManager(_db, _db.operationLogs);
  $$FavoriteTemplatesTableTableManager get favoriteTemplates =>
      $$FavoriteTemplatesTableTableManager(_db, _db.favoriteTemplates);
  $$RecentFilesTableTableManager get recentFiles =>
      $$RecentFilesTableTableManager(_db, _db.recentFiles);
  $$CacheRecordsTableTableManager get cacheRecords =>
      $$CacheRecordsTableTableManager(_db, _db.cacheRecords);
}
