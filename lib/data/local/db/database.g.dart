// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $AccountsTable extends Accounts
    with TableInfo<$AccountsTable, AccountRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ProviderType, int> provider =
      GeneratedColumn<int>(
        'provider',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<ProviderType>($AccountsTable.$converterprovider);
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AccountStatus, int> status =
      GeneratedColumn<int>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      ).withConverter<AccountStatus>($AccountsTable.$converterstatus);
  static const VerificationMeta _configJsonMeta = const VerificationMeta(
    'configJson',
  );
  @override
  late final GeneratedColumn<String> configJson = GeneratedColumn<String>(
    'config_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _refreshJsonMeta = const VerificationMeta(
    'refreshJson',
  );
  @override
  late final GeneratedColumn<String> refreshJson = GeneratedColumn<String>(
    'refresh_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _lastSyncUtcMeta = const VerificationMeta(
    'lastSyncUtc',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncUtc = GeneratedColumn<DateTime>(
    'last_sync_utc',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    provider,
    displayName,
    email,
    status,
    configJson,
    refreshJson,
    lastSyncUtc,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<AccountRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('config_json')) {
      context.handle(
        _configJsonMeta,
        configJson.isAcceptableOrUnknown(data['config_json']!, _configJsonMeta),
      );
    }
    if (data.containsKey('refresh_json')) {
      context.handle(
        _refreshJsonMeta,
        refreshJson.isAcceptableOrUnknown(
          data['refresh_json']!,
          _refreshJsonMeta,
        ),
      );
    }
    if (data.containsKey('last_sync_utc')) {
      context.handle(
        _lastSyncUtcMeta,
        lastSyncUtc.isAcceptableOrUnknown(
          data['last_sync_utc']!,
          _lastSyncUtcMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AccountRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AccountRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      provider: $AccountsTable.$converterprovider.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}provider'],
        )!,
      ),
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      status: $AccountsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}status'],
        )!,
      ),
      configJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}config_json'],
      )!,
      refreshJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}refresh_json'],
      )!,
      lastSyncUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_sync_utc'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ProviderType, int, int> $converterprovider =
      const EnumIndexConverter<ProviderType>(ProviderType.values);
  static JsonTypeConverter2<AccountStatus, int, int> $converterstatus =
      const EnumIndexConverter<AccountStatus>(AccountStatus.values);
}

class AccountRow extends DataClass implements Insertable<AccountRow> {
  final String id;
  final ProviderType provider;
  final String displayName;
  final String email;
  final AccountStatus status;

  /// Сериализованный AccountConfig (JSON).
  final String configJson;

  /// Политика обновления (JSON).
  final String refreshJson;

  /// Время последнего УСПЕШНОГО синка и текст последней ошибки (для плашки).
  final DateTime? lastSyncUtc;
  final String? lastError;
  const AccountRow({
    required this.id,
    required this.provider,
    required this.displayName,
    required this.email,
    required this.status,
    required this.configJson,
    required this.refreshJson,
    this.lastSyncUtc,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['provider'] = Variable<int>(
        $AccountsTable.$converterprovider.toSql(provider),
      );
    }
    map['display_name'] = Variable<String>(displayName);
    map['email'] = Variable<String>(email);
    {
      map['status'] = Variable<int>(
        $AccountsTable.$converterstatus.toSql(status),
      );
    }
    map['config_json'] = Variable<String>(configJson);
    map['refresh_json'] = Variable<String>(refreshJson);
    if (!nullToAbsent || lastSyncUtc != null) {
      map['last_sync_utc'] = Variable<DateTime>(lastSyncUtc);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      provider: Value(provider),
      displayName: Value(displayName),
      email: Value(email),
      status: Value(status),
      configJson: Value(configJson),
      refreshJson: Value(refreshJson),
      lastSyncUtc: lastSyncUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncUtc),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory AccountRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AccountRow(
      id: serializer.fromJson<String>(json['id']),
      provider: $AccountsTable.$converterprovider.fromJson(
        serializer.fromJson<int>(json['provider']),
      ),
      displayName: serializer.fromJson<String>(json['displayName']),
      email: serializer.fromJson<String>(json['email']),
      status: $AccountsTable.$converterstatus.fromJson(
        serializer.fromJson<int>(json['status']),
      ),
      configJson: serializer.fromJson<String>(json['configJson']),
      refreshJson: serializer.fromJson<String>(json['refreshJson']),
      lastSyncUtc: serializer.fromJson<DateTime?>(json['lastSyncUtc']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'provider': serializer.toJson<int>(
        $AccountsTable.$converterprovider.toJson(provider),
      ),
      'displayName': serializer.toJson<String>(displayName),
      'email': serializer.toJson<String>(email),
      'status': serializer.toJson<int>(
        $AccountsTable.$converterstatus.toJson(status),
      ),
      'configJson': serializer.toJson<String>(configJson),
      'refreshJson': serializer.toJson<String>(refreshJson),
      'lastSyncUtc': serializer.toJson<DateTime?>(lastSyncUtc),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  AccountRow copyWith({
    String? id,
    ProviderType? provider,
    String? displayName,
    String? email,
    AccountStatus? status,
    String? configJson,
    String? refreshJson,
    Value<DateTime?> lastSyncUtc = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
  }) => AccountRow(
    id: id ?? this.id,
    provider: provider ?? this.provider,
    displayName: displayName ?? this.displayName,
    email: email ?? this.email,
    status: status ?? this.status,
    configJson: configJson ?? this.configJson,
    refreshJson: refreshJson ?? this.refreshJson,
    lastSyncUtc: lastSyncUtc.present ? lastSyncUtc.value : this.lastSyncUtc,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  AccountRow copyWithCompanion(AccountsCompanion data) {
    return AccountRow(
      id: data.id.present ? data.id.value : this.id,
      provider: data.provider.present ? data.provider.value : this.provider,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      email: data.email.present ? data.email.value : this.email,
      status: data.status.present ? data.status.value : this.status,
      configJson: data.configJson.present
          ? data.configJson.value
          : this.configJson,
      refreshJson: data.refreshJson.present
          ? data.refreshJson.value
          : this.refreshJson,
      lastSyncUtc: data.lastSyncUtc.present
          ? data.lastSyncUtc.value
          : this.lastSyncUtc,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AccountRow(')
          ..write('id: $id, ')
          ..write('provider: $provider, ')
          ..write('displayName: $displayName, ')
          ..write('email: $email, ')
          ..write('status: $status, ')
          ..write('configJson: $configJson, ')
          ..write('refreshJson: $refreshJson, ')
          ..write('lastSyncUtc: $lastSyncUtc, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    provider,
    displayName,
    email,
    status,
    configJson,
    refreshJson,
    lastSyncUtc,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccountRow &&
          other.id == this.id &&
          other.provider == this.provider &&
          other.displayName == this.displayName &&
          other.email == this.email &&
          other.status == this.status &&
          other.configJson == this.configJson &&
          other.refreshJson == this.refreshJson &&
          other.lastSyncUtc == this.lastSyncUtc &&
          other.lastError == this.lastError);
}

class AccountsCompanion extends UpdateCompanion<AccountRow> {
  final Value<String> id;
  final Value<ProviderType> provider;
  final Value<String> displayName;
  final Value<String> email;
  final Value<AccountStatus> status;
  final Value<String> configJson;
  final Value<String> refreshJson;
  final Value<DateTime?> lastSyncUtc;
  final Value<String?> lastError;
  final Value<int> rowid;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.provider = const Value.absent(),
    this.displayName = const Value.absent(),
    this.email = const Value.absent(),
    this.status = const Value.absent(),
    this.configJson = const Value.absent(),
    this.refreshJson = const Value.absent(),
    this.lastSyncUtc = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountsCompanion.insert({
    required String id,
    required ProviderType provider,
    required String displayName,
    required String email,
    this.status = const Value.absent(),
    this.configJson = const Value.absent(),
    this.refreshJson = const Value.absent(),
    this.lastSyncUtc = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       provider = Value(provider),
       displayName = Value(displayName),
       email = Value(email);
  static Insertable<AccountRow> custom({
    Expression<String>? id,
    Expression<int>? provider,
    Expression<String>? displayName,
    Expression<String>? email,
    Expression<int>? status,
    Expression<String>? configJson,
    Expression<String>? refreshJson,
    Expression<DateTime>? lastSyncUtc,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (provider != null) 'provider': provider,
      if (displayName != null) 'display_name': displayName,
      if (email != null) 'email': email,
      if (status != null) 'status': status,
      if (configJson != null) 'config_json': configJson,
      if (refreshJson != null) 'refresh_json': refreshJson,
      if (lastSyncUtc != null) 'last_sync_utc': lastSyncUtc,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountsCompanion copyWith({
    Value<String>? id,
    Value<ProviderType>? provider,
    Value<String>? displayName,
    Value<String>? email,
    Value<AccountStatus>? status,
    Value<String>? configJson,
    Value<String>? refreshJson,
    Value<DateTime?>? lastSyncUtc,
    Value<String?>? lastError,
    Value<int>? rowid,
  }) {
    return AccountsCompanion(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      status: status ?? this.status,
      configJson: configJson ?? this.configJson,
      refreshJson: refreshJson ?? this.refreshJson,
      lastSyncUtc: lastSyncUtc ?? this.lastSyncUtc,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (provider.present) {
      map['provider'] = Variable<int>(
        $AccountsTable.$converterprovider.toSql(provider.value),
      );
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(
        $AccountsTable.$converterstatus.toSql(status.value),
      );
    }
    if (configJson.present) {
      map['config_json'] = Variable<String>(configJson.value);
    }
    if (refreshJson.present) {
      map['refresh_json'] = Variable<String>(refreshJson.value);
    }
    if (lastSyncUtc.present) {
      map['last_sync_utc'] = Variable<DateTime>(lastSyncUtc.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('provider: $provider, ')
          ..write('displayName: $displayName, ')
          ..write('email: $email, ')
          ..write('status: $status, ')
          ..write('configJson: $configJson, ')
          ..write('refreshJson: $refreshJson, ')
          ..write('lastSyncUtc: $lastSyncUtc, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CalendarsTable extends Calendars
    with TableInfo<$CalendarsTable, CalendarRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalendarsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameOverrideMeta = const VerificationMeta(
    'nameOverride',
  );
  @override
  late final GeneratedColumn<String> nameOverride = GeneratedColumn<String>(
    'name_override',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorOverrideMeta = const VerificationMeta(
    'colorOverride',
  );
  @override
  late final GeneratedColumn<int> colorOverride = GeneratedColumn<int>(
    'color_override',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _defaultReminderMinutesMeta =
      const VerificationMeta('defaultReminderMinutes');
  @override
  late final GeneratedColumn<int> defaultReminderMinutes = GeneratedColumn<int>(
    'default_reminder_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _visibleMeta = const VerificationMeta(
    'visible',
  );
  @override
  late final GeneratedColumn<bool> visible = GeneratedColumn<bool>(
    'visible',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("visible" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPrimaryMeta = const VerificationMeta(
    'isPrimary',
  );
  @override
  late final GeneratedColumn<bool> isPrimary = GeneratedColumn<bool>(
    'is_primary',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_primary" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _readOnlyMeta = const VerificationMeta(
    'readOnly',
  );
  @override
  late final GeneratedColumn<bool> readOnly = GeneratedColumn<bool>(
    'read_only',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("read_only" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    name,
    nameOverride,
    color,
    colorOverride,
    defaultReminderMinutes,
    visible,
    syncState,
    isPrimary,
    readOnly,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calendars';
  @override
  VerificationContext validateIntegrity(
    Insertable<CalendarRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('name_override')) {
      context.handle(
        _nameOverrideMeta,
        nameOverride.isAcceptableOrUnknown(
          data['name_override']!,
          _nameOverrideMeta,
        ),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('color_override')) {
      context.handle(
        _colorOverrideMeta,
        colorOverride.isAcceptableOrUnknown(
          data['color_override']!,
          _colorOverrideMeta,
        ),
      );
    }
    if (data.containsKey('default_reminder_minutes')) {
      context.handle(
        _defaultReminderMinutesMeta,
        defaultReminderMinutes.isAcceptableOrUnknown(
          data['default_reminder_minutes']!,
          _defaultReminderMinutesMeta,
        ),
      );
    }
    if (data.containsKey('visible')) {
      context.handle(
        _visibleMeta,
        visible.isAcceptableOrUnknown(data['visible']!, _visibleMeta),
      );
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('is_primary')) {
      context.handle(
        _isPrimaryMeta,
        isPrimary.isAcceptableOrUnknown(data['is_primary']!, _isPrimaryMeta),
      );
    }
    if (data.containsKey('read_only')) {
      context.handle(
        _readOnlyMeta,
        readOnly.isAcceptableOrUnknown(data['read_only']!, _readOnlyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CalendarRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalendarRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      nameOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_override'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      )!,
      colorOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_override'],
      ),
      defaultReminderMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}default_reminder_minutes'],
      ),
      visible: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}visible'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      ),
      isPrimary: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_primary'],
      )!,
      readOnly: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}read_only'],
      )!,
    );
  }

  @override
  $CalendarsTable createAlias(String alias) {
    return $CalendarsTable(attachedDatabase, alias);
  }
}

class CalendarRow extends DataClass implements Insertable<CalendarRow> {
  final String id;
  final String accountId;
  final String name;

  /// Пользовательское имя (переименование). Синк не трогает; null → берём [name].
  final String? nameOverride;

  /// Цвет из источника (перезаписывается синком).
  final int color;

  /// Пользовательский цвет (FR-A9). Синк его не трогает; null → берём [color].
  final int? colorOverride;

  /// Дефолтное напоминание календаря (минут до начала; 0 = в момент начала;
  /// null = без напоминания). Пользовательская настройка, синк не трогает (FR-N).
  final int? defaultReminderMinutes;
  final bool visible;
  final String? syncState;
  final bool isPrimary;
  final bool readOnly;
  const CalendarRow({
    required this.id,
    required this.accountId,
    required this.name,
    this.nameOverride,
    required this.color,
    this.colorOverride,
    this.defaultReminderMinutes,
    required this.visible,
    this.syncState,
    required this.isPrimary,
    required this.readOnly,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || nameOverride != null) {
      map['name_override'] = Variable<String>(nameOverride);
    }
    map['color'] = Variable<int>(color);
    if (!nullToAbsent || colorOverride != null) {
      map['color_override'] = Variable<int>(colorOverride);
    }
    if (!nullToAbsent || defaultReminderMinutes != null) {
      map['default_reminder_minutes'] = Variable<int>(defaultReminderMinutes);
    }
    map['visible'] = Variable<bool>(visible);
    if (!nullToAbsent || syncState != null) {
      map['sync_state'] = Variable<String>(syncState);
    }
    map['is_primary'] = Variable<bool>(isPrimary);
    map['read_only'] = Variable<bool>(readOnly);
    return map;
  }

  CalendarsCompanion toCompanion(bool nullToAbsent) {
    return CalendarsCompanion(
      id: Value(id),
      accountId: Value(accountId),
      name: Value(name),
      nameOverride: nameOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(nameOverride),
      color: Value(color),
      colorOverride: colorOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(colorOverride),
      defaultReminderMinutes: defaultReminderMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultReminderMinutes),
      visible: Value(visible),
      syncState: syncState == null && nullToAbsent
          ? const Value.absent()
          : Value(syncState),
      isPrimary: Value(isPrimary),
      readOnly: Value(readOnly),
    );
  }

  factory CalendarRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalendarRow(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      name: serializer.fromJson<String>(json['name']),
      nameOverride: serializer.fromJson<String?>(json['nameOverride']),
      color: serializer.fromJson<int>(json['color']),
      colorOverride: serializer.fromJson<int?>(json['colorOverride']),
      defaultReminderMinutes: serializer.fromJson<int?>(
        json['defaultReminderMinutes'],
      ),
      visible: serializer.fromJson<bool>(json['visible']),
      syncState: serializer.fromJson<String?>(json['syncState']),
      isPrimary: serializer.fromJson<bool>(json['isPrimary']),
      readOnly: serializer.fromJson<bool>(json['readOnly']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'name': serializer.toJson<String>(name),
      'nameOverride': serializer.toJson<String?>(nameOverride),
      'color': serializer.toJson<int>(color),
      'colorOverride': serializer.toJson<int?>(colorOverride),
      'defaultReminderMinutes': serializer.toJson<int?>(defaultReminderMinutes),
      'visible': serializer.toJson<bool>(visible),
      'syncState': serializer.toJson<String?>(syncState),
      'isPrimary': serializer.toJson<bool>(isPrimary),
      'readOnly': serializer.toJson<bool>(readOnly),
    };
  }

  CalendarRow copyWith({
    String? id,
    String? accountId,
    String? name,
    Value<String?> nameOverride = const Value.absent(),
    int? color,
    Value<int?> colorOverride = const Value.absent(),
    Value<int?> defaultReminderMinutes = const Value.absent(),
    bool? visible,
    Value<String?> syncState = const Value.absent(),
    bool? isPrimary,
    bool? readOnly,
  }) => CalendarRow(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    name: name ?? this.name,
    nameOverride: nameOverride.present ? nameOverride.value : this.nameOverride,
    color: color ?? this.color,
    colorOverride: colorOverride.present
        ? colorOverride.value
        : this.colorOverride,
    defaultReminderMinutes: defaultReminderMinutes.present
        ? defaultReminderMinutes.value
        : this.defaultReminderMinutes,
    visible: visible ?? this.visible,
    syncState: syncState.present ? syncState.value : this.syncState,
    isPrimary: isPrimary ?? this.isPrimary,
    readOnly: readOnly ?? this.readOnly,
  );
  CalendarRow copyWithCompanion(CalendarsCompanion data) {
    return CalendarRow(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      name: data.name.present ? data.name.value : this.name,
      nameOverride: data.nameOverride.present
          ? data.nameOverride.value
          : this.nameOverride,
      color: data.color.present ? data.color.value : this.color,
      colorOverride: data.colorOverride.present
          ? data.colorOverride.value
          : this.colorOverride,
      defaultReminderMinutes: data.defaultReminderMinutes.present
          ? data.defaultReminderMinutes.value
          : this.defaultReminderMinutes,
      visible: data.visible.present ? data.visible.value : this.visible,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      isPrimary: data.isPrimary.present ? data.isPrimary.value : this.isPrimary,
      readOnly: data.readOnly.present ? data.readOnly.value : this.readOnly,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalendarRow(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('name: $name, ')
          ..write('nameOverride: $nameOverride, ')
          ..write('color: $color, ')
          ..write('colorOverride: $colorOverride, ')
          ..write('defaultReminderMinutes: $defaultReminderMinutes, ')
          ..write('visible: $visible, ')
          ..write('syncState: $syncState, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('readOnly: $readOnly')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    name,
    nameOverride,
    color,
    colorOverride,
    defaultReminderMinutes,
    visible,
    syncState,
    isPrimary,
    readOnly,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalendarRow &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.name == this.name &&
          other.nameOverride == this.nameOverride &&
          other.color == this.color &&
          other.colorOverride == this.colorOverride &&
          other.defaultReminderMinutes == this.defaultReminderMinutes &&
          other.visible == this.visible &&
          other.syncState == this.syncState &&
          other.isPrimary == this.isPrimary &&
          other.readOnly == this.readOnly);
}

class CalendarsCompanion extends UpdateCompanion<CalendarRow> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<String> name;
  final Value<String?> nameOverride;
  final Value<int> color;
  final Value<int?> colorOverride;
  final Value<int?> defaultReminderMinutes;
  final Value<bool> visible;
  final Value<String?> syncState;
  final Value<bool> isPrimary;
  final Value<bool> readOnly;
  final Value<int> rowid;
  const CalendarsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.name = const Value.absent(),
    this.nameOverride = const Value.absent(),
    this.color = const Value.absent(),
    this.colorOverride = const Value.absent(),
    this.defaultReminderMinutes = const Value.absent(),
    this.visible = const Value.absent(),
    this.syncState = const Value.absent(),
    this.isPrimary = const Value.absent(),
    this.readOnly = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CalendarsCompanion.insert({
    required String id,
    required String accountId,
    required String name,
    this.nameOverride = const Value.absent(),
    required int color,
    this.colorOverride = const Value.absent(),
    this.defaultReminderMinutes = const Value.absent(),
    this.visible = const Value.absent(),
    this.syncState = const Value.absent(),
    this.isPrimary = const Value.absent(),
    this.readOnly = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       name = Value(name),
       color = Value(color);
  static Insertable<CalendarRow> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? name,
    Expression<String>? nameOverride,
    Expression<int>? color,
    Expression<int>? colorOverride,
    Expression<int>? defaultReminderMinutes,
    Expression<bool>? visible,
    Expression<String>? syncState,
    Expression<bool>? isPrimary,
    Expression<bool>? readOnly,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (name != null) 'name': name,
      if (nameOverride != null) 'name_override': nameOverride,
      if (color != null) 'color': color,
      if (colorOverride != null) 'color_override': colorOverride,
      if (defaultReminderMinutes != null)
        'default_reminder_minutes': defaultReminderMinutes,
      if (visible != null) 'visible': visible,
      if (syncState != null) 'sync_state': syncState,
      if (isPrimary != null) 'is_primary': isPrimary,
      if (readOnly != null) 'read_only': readOnly,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CalendarsCompanion copyWith({
    Value<String>? id,
    Value<String>? accountId,
    Value<String>? name,
    Value<String?>? nameOverride,
    Value<int>? color,
    Value<int?>? colorOverride,
    Value<int?>? defaultReminderMinutes,
    Value<bool>? visible,
    Value<String?>? syncState,
    Value<bool>? isPrimary,
    Value<bool>? readOnly,
    Value<int>? rowid,
  }) {
    return CalendarsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      name: name ?? this.name,
      nameOverride: nameOverride ?? this.nameOverride,
      color: color ?? this.color,
      colorOverride: colorOverride ?? this.colorOverride,
      defaultReminderMinutes:
          defaultReminderMinutes ?? this.defaultReminderMinutes,
      visible: visible ?? this.visible,
      syncState: syncState ?? this.syncState,
      isPrimary: isPrimary ?? this.isPrimary,
      readOnly: readOnly ?? this.readOnly,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (nameOverride.present) {
      map['name_override'] = Variable<String>(nameOverride.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (colorOverride.present) {
      map['color_override'] = Variable<int>(colorOverride.value);
    }
    if (defaultReminderMinutes.present) {
      map['default_reminder_minutes'] = Variable<int>(
        defaultReminderMinutes.value,
      );
    }
    if (visible.present) {
      map['visible'] = Variable<bool>(visible.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (isPrimary.present) {
      map['is_primary'] = Variable<bool>(isPrimary.value);
    }
    if (readOnly.present) {
      map['read_only'] = Variable<bool>(readOnly.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalendarsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('name: $name, ')
          ..write('nameOverride: $nameOverride, ')
          ..write('color: $color, ')
          ..write('colorOverride: $colorOverride, ')
          ..write('defaultReminderMinutes: $defaultReminderMinutes, ')
          ..write('visible: $visible, ')
          ..write('syncState: $syncState, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('readOnly: $readOnly, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EventsTable extends Events with TableInfo<$EventsTable, Event> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _calendarIdMeta = const VerificationMeta(
    'calendarId',
  );
  @override
  late final GeneratedColumn<String> calendarId = GeneratedColumn<String>(
    'calendar_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES calendars (id)',
    ),
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerEventIdMeta = const VerificationMeta(
    'providerEventId',
  );
  @override
  late final GeneratedColumn<String> providerEventId = GeneratedColumn<String>(
    'provider_event_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startUtcMeta = const VerificationMeta(
    'startUtc',
  );
  @override
  late final GeneratedColumn<DateTime> startUtc = GeneratedColumn<DateTime>(
    'start_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endUtcMeta = const VerificationMeta('endUtc');
  @override
  late final GeneratedColumn<DateTime> endUtc = GeneratedColumn<DateTime>(
    'end_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeZoneIdMeta = const VerificationMeta(
    'timeZoneId',
  );
  @override
  late final GeneratedColumn<String> timeZoneId = GeneratedColumn<String>(
    'time_zone_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('UTC'),
  );
  static const VerificationMeta _allDayMeta = const VerificationMeta('allDay');
  @override
  late final GeneratedColumn<bool> allDay = GeneratedColumn<bool>(
    'all_day',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("all_day" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recurrenceRuleMeta = const VerificationMeta(
    'recurrenceRule',
  );
  @override
  late final GeneratedColumn<String> recurrenceRule = GeneratedColumn<String>(
    'recurrence_rule',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recurrenceIdMeta = const VerificationMeta(
    'recurrenceId',
  );
  @override
  late final GeneratedColumn<String> recurrenceId = GeneratedColumn<String>(
    'recurrence_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ResponseStatus, int> myResponse =
      GeneratedColumn<int>(
        'my_response',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(4),
      ).withConverter<ResponseStatus>($EventsTable.$convertermyResponse);
  @override
  late final GeneratedColumnWithTypeConverter<ShowAs, int> showAs =
      GeneratedColumn<int>(
        'show_as',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      ).withConverter<ShowAs>($EventsTable.$convertershowAs);
  @override
  late final GeneratedColumnWithTypeConverter<EventVisibility, int> visibility =
      GeneratedColumn<int>(
        'visibility',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      ).withConverter<EventVisibility>($EventsTable.$convertervisibility);
  @override
  late final GeneratedColumnWithTypeConverter<EventStatus, int> status =
      GeneratedColumn<int>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      ).withConverter<EventStatus>($EventsTable.$converterstatus);
  static const VerificationMeta _deletedRemotelyMeta = const VerificationMeta(
    'deletedRemotely',
  );
  @override
  late final GeneratedColumn<bool> deletedRemotely = GeneratedColumn<bool>(
    'deleted_remotely',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted_remotely" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _colorOverrideMeta = const VerificationMeta(
    'colorOverride',
  );
  @override
  late final GeneratedColumn<int> colorOverride = GeneratedColumn<int>(
    'color_override',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mergedGroupIdMeta = const VerificationMeta(
    'mergedGroupId',
  );
  @override
  late final GeneratedColumn<String> mergedGroupId = GeneratedColumn<String>(
    'merged_group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _webUrlMeta = const VerificationMeta('webUrl');
  @override
  late final GeneratedColumn<String> webUrl = GeneratedColumn<String>(
    'web_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _conferenceJsonMeta = const VerificationMeta(
    'conferenceJson',
  );
  @override
  late final GeneratedColumn<String> conferenceJson = GeneratedColumn<String>(
    'conference_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attendeesJsonMeta = const VerificationMeta(
    'attendeesJson',
  );
  @override
  late final GeneratedColumn<String> attendeesJson = GeneratedColumn<String>(
    'attendees_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remindersJsonMeta = const VerificationMeta(
    'remindersJson',
  );
  @override
  late final GeneratedColumn<String> remindersJson = GeneratedColumn<String>(
    'reminders_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attachmentsJsonMeta = const VerificationMeta(
    'attachmentsJson',
  );
  @override
  late final GeneratedColumn<String> attachmentsJson = GeneratedColumn<String>(
    'attachments_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    calendarId,
    accountId,
    providerEventId,
    etag,
    title,
    startUtc,
    endUtc,
    timeZoneId,
    allDay,
    location,
    description,
    recurrenceRule,
    recurrenceId,
    myResponse,
    showAs,
    visibility,
    status,
    deletedRemotely,
    colorOverride,
    mergedGroupId,
    webUrl,
    conferenceJson,
    attendeesJson,
    remindersJson,
    attachmentsJson,
    dirty,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'events';
  @override
  VerificationContext validateIntegrity(
    Insertable<Event> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('calendar_id')) {
      context.handle(
        _calendarIdMeta,
        calendarId.isAcceptableOrUnknown(data['calendar_id']!, _calendarIdMeta),
      );
    } else if (isInserting) {
      context.missing(_calendarIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('provider_event_id')) {
      context.handle(
        _providerEventIdMeta,
        providerEventId.isAcceptableOrUnknown(
          data['provider_event_id']!,
          _providerEventIdMeta,
        ),
      );
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('start_utc')) {
      context.handle(
        _startUtcMeta,
        startUtc.isAcceptableOrUnknown(data['start_utc']!, _startUtcMeta),
      );
    } else if (isInserting) {
      context.missing(_startUtcMeta);
    }
    if (data.containsKey('end_utc')) {
      context.handle(
        _endUtcMeta,
        endUtc.isAcceptableOrUnknown(data['end_utc']!, _endUtcMeta),
      );
    } else if (isInserting) {
      context.missing(_endUtcMeta);
    }
    if (data.containsKey('time_zone_id')) {
      context.handle(
        _timeZoneIdMeta,
        timeZoneId.isAcceptableOrUnknown(
          data['time_zone_id']!,
          _timeZoneIdMeta,
        ),
      );
    }
    if (data.containsKey('all_day')) {
      context.handle(
        _allDayMeta,
        allDay.isAcceptableOrUnknown(data['all_day']!, _allDayMeta),
      );
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_rule')) {
      context.handle(
        _recurrenceRuleMeta,
        recurrenceRule.isAcceptableOrUnknown(
          data['recurrence_rule']!,
          _recurrenceRuleMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_id')) {
      context.handle(
        _recurrenceIdMeta,
        recurrenceId.isAcceptableOrUnknown(
          data['recurrence_id']!,
          _recurrenceIdMeta,
        ),
      );
    }
    if (data.containsKey('deleted_remotely')) {
      context.handle(
        _deletedRemotelyMeta,
        deletedRemotely.isAcceptableOrUnknown(
          data['deleted_remotely']!,
          _deletedRemotelyMeta,
        ),
      );
    }
    if (data.containsKey('color_override')) {
      context.handle(
        _colorOverrideMeta,
        colorOverride.isAcceptableOrUnknown(
          data['color_override']!,
          _colorOverrideMeta,
        ),
      );
    }
    if (data.containsKey('merged_group_id')) {
      context.handle(
        _mergedGroupIdMeta,
        mergedGroupId.isAcceptableOrUnknown(
          data['merged_group_id']!,
          _mergedGroupIdMeta,
        ),
      );
    }
    if (data.containsKey('web_url')) {
      context.handle(
        _webUrlMeta,
        webUrl.isAcceptableOrUnknown(data['web_url']!, _webUrlMeta),
      );
    }
    if (data.containsKey('conference_json')) {
      context.handle(
        _conferenceJsonMeta,
        conferenceJson.isAcceptableOrUnknown(
          data['conference_json']!,
          _conferenceJsonMeta,
        ),
      );
    }
    if (data.containsKey('attendees_json')) {
      context.handle(
        _attendeesJsonMeta,
        attendeesJson.isAcceptableOrUnknown(
          data['attendees_json']!,
          _attendeesJsonMeta,
        ),
      );
    }
    if (data.containsKey('reminders_json')) {
      context.handle(
        _remindersJsonMeta,
        remindersJson.isAcceptableOrUnknown(
          data['reminders_json']!,
          _remindersJsonMeta,
        ),
      );
    }
    if (data.containsKey('attachments_json')) {
      context.handle(
        _attachmentsJsonMeta,
        attachmentsJson.isAcceptableOrUnknown(
          data['attachments_json']!,
          _attachmentsJsonMeta,
        ),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Event map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Event(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      calendarId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calendar_id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      providerEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_event_id'],
      ),
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      startUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_utc'],
      )!,
      endUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_utc'],
      )!,
      timeZoneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_zone_id'],
      )!,
      allDay: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}all_day'],
      )!,
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      recurrenceRule: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_rule'],
      ),
      recurrenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_id'],
      ),
      myResponse: $EventsTable.$convertermyResponse.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}my_response'],
        )!,
      ),
      showAs: $EventsTable.$convertershowAs.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}show_as'],
        )!,
      ),
      visibility: $EventsTable.$convertervisibility.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}visibility'],
        )!,
      ),
      status: $EventsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}status'],
        )!,
      ),
      deletedRemotely: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted_remotely'],
      )!,
      colorOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_override'],
      ),
      mergedGroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merged_group_id'],
      ),
      webUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}web_url'],
      ),
      conferenceJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conference_json'],
      ),
      attendeesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attendees_json'],
      ),
      remindersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminders_json'],
      ),
      attachmentsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachments_json'],
      ),
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
    );
  }

  @override
  $EventsTable createAlias(String alias) {
    return $EventsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ResponseStatus, int, int> $convertermyResponse =
      const EnumIndexConverter<ResponseStatus>(ResponseStatus.values);
  static JsonTypeConverter2<ShowAs, int, int> $convertershowAs =
      const EnumIndexConverter<ShowAs>(ShowAs.values);
  static JsonTypeConverter2<EventVisibility, int, int> $convertervisibility =
      const EnumIndexConverter<EventVisibility>(EventVisibility.values);
  static JsonTypeConverter2<EventStatus, int, int> $converterstatus =
      const EnumIndexConverter<EventStatus>(EventStatus.values);
}

class Event extends DataClass implements Insertable<Event> {
  final String id;
  final String calendarId;
  final String accountId;

  /// Id события в источнике (для CRUD и как сигнал дедупа — UID).
  final String? providerEventId;
  final String? etag;
  final String title;
  final DateTime startUtc;
  final DateTime endUtc;
  final String timeZoneId;
  final bool allDay;
  final String? location;
  final String? description;
  final String? recurrenceRule;
  final String? recurrenceId;
  final ResponseStatus myResponse;
  final ShowAs showAs;
  final EventVisibility visibility;
  final EventStatus status;
  final bool deletedRemotely;
  final int? colorOverride;
  final String? mergedGroupId;

  /// Готовая web-ссылка на событие в облаке (для карточки).
  final String? webUrl;

  /// Видеоконференция (JSON) и участники (JSON) — денормализованно для MVP.
  final String? conferenceJson;
  final String? attendeesJson;
  final String? remindersJson;

  /// Вложения события (ATTACH / attachments) — JSON-список ссылок с подписями.
  final String? attachmentsJson;

  /// Признак «есть несинхронизированные локальные правки» (для Outbox-логики).
  final bool dirty;
  const Event({
    required this.id,
    required this.calendarId,
    required this.accountId,
    this.providerEventId,
    this.etag,
    required this.title,
    required this.startUtc,
    required this.endUtc,
    required this.timeZoneId,
    required this.allDay,
    this.location,
    this.description,
    this.recurrenceRule,
    this.recurrenceId,
    required this.myResponse,
    required this.showAs,
    required this.visibility,
    required this.status,
    required this.deletedRemotely,
    this.colorOverride,
    this.mergedGroupId,
    this.webUrl,
    this.conferenceJson,
    this.attendeesJson,
    this.remindersJson,
    this.attachmentsJson,
    required this.dirty,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['calendar_id'] = Variable<String>(calendarId);
    map['account_id'] = Variable<String>(accountId);
    if (!nullToAbsent || providerEventId != null) {
      map['provider_event_id'] = Variable<String>(providerEventId);
    }
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    map['title'] = Variable<String>(title);
    map['start_utc'] = Variable<DateTime>(startUtc);
    map['end_utc'] = Variable<DateTime>(endUtc);
    map['time_zone_id'] = Variable<String>(timeZoneId);
    map['all_day'] = Variable<bool>(allDay);
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || recurrenceRule != null) {
      map['recurrence_rule'] = Variable<String>(recurrenceRule);
    }
    if (!nullToAbsent || recurrenceId != null) {
      map['recurrence_id'] = Variable<String>(recurrenceId);
    }
    {
      map['my_response'] = Variable<int>(
        $EventsTable.$convertermyResponse.toSql(myResponse),
      );
    }
    {
      map['show_as'] = Variable<int>(
        $EventsTable.$convertershowAs.toSql(showAs),
      );
    }
    {
      map['visibility'] = Variable<int>(
        $EventsTable.$convertervisibility.toSql(visibility),
      );
    }
    {
      map['status'] = Variable<int>(
        $EventsTable.$converterstatus.toSql(status),
      );
    }
    map['deleted_remotely'] = Variable<bool>(deletedRemotely);
    if (!nullToAbsent || colorOverride != null) {
      map['color_override'] = Variable<int>(colorOverride);
    }
    if (!nullToAbsent || mergedGroupId != null) {
      map['merged_group_id'] = Variable<String>(mergedGroupId);
    }
    if (!nullToAbsent || webUrl != null) {
      map['web_url'] = Variable<String>(webUrl);
    }
    if (!nullToAbsent || conferenceJson != null) {
      map['conference_json'] = Variable<String>(conferenceJson);
    }
    if (!nullToAbsent || attendeesJson != null) {
      map['attendees_json'] = Variable<String>(attendeesJson);
    }
    if (!nullToAbsent || remindersJson != null) {
      map['reminders_json'] = Variable<String>(remindersJson);
    }
    if (!nullToAbsent || attachmentsJson != null) {
      map['attachments_json'] = Variable<String>(attachmentsJson);
    }
    map['dirty'] = Variable<bool>(dirty);
    return map;
  }

  EventsCompanion toCompanion(bool nullToAbsent) {
    return EventsCompanion(
      id: Value(id),
      calendarId: Value(calendarId),
      accountId: Value(accountId),
      providerEventId: providerEventId == null && nullToAbsent
          ? const Value.absent()
          : Value(providerEventId),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      title: Value(title),
      startUtc: Value(startUtc),
      endUtc: Value(endUtc),
      timeZoneId: Value(timeZoneId),
      allDay: Value(allDay),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      recurrenceRule: recurrenceRule == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceRule),
      recurrenceId: recurrenceId == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceId),
      myResponse: Value(myResponse),
      showAs: Value(showAs),
      visibility: Value(visibility),
      status: Value(status),
      deletedRemotely: Value(deletedRemotely),
      colorOverride: colorOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(colorOverride),
      mergedGroupId: mergedGroupId == null && nullToAbsent
          ? const Value.absent()
          : Value(mergedGroupId),
      webUrl: webUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(webUrl),
      conferenceJson: conferenceJson == null && nullToAbsent
          ? const Value.absent()
          : Value(conferenceJson),
      attendeesJson: attendeesJson == null && nullToAbsent
          ? const Value.absent()
          : Value(attendeesJson),
      remindersJson: remindersJson == null && nullToAbsent
          ? const Value.absent()
          : Value(remindersJson),
      attachmentsJson: attachmentsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentsJson),
      dirty: Value(dirty),
    );
  }

  factory Event.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Event(
      id: serializer.fromJson<String>(json['id']),
      calendarId: serializer.fromJson<String>(json['calendarId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      providerEventId: serializer.fromJson<String?>(json['providerEventId']),
      etag: serializer.fromJson<String?>(json['etag']),
      title: serializer.fromJson<String>(json['title']),
      startUtc: serializer.fromJson<DateTime>(json['startUtc']),
      endUtc: serializer.fromJson<DateTime>(json['endUtc']),
      timeZoneId: serializer.fromJson<String>(json['timeZoneId']),
      allDay: serializer.fromJson<bool>(json['allDay']),
      location: serializer.fromJson<String?>(json['location']),
      description: serializer.fromJson<String?>(json['description']),
      recurrenceRule: serializer.fromJson<String?>(json['recurrenceRule']),
      recurrenceId: serializer.fromJson<String?>(json['recurrenceId']),
      myResponse: $EventsTable.$convertermyResponse.fromJson(
        serializer.fromJson<int>(json['myResponse']),
      ),
      showAs: $EventsTable.$convertershowAs.fromJson(
        serializer.fromJson<int>(json['showAs']),
      ),
      visibility: $EventsTable.$convertervisibility.fromJson(
        serializer.fromJson<int>(json['visibility']),
      ),
      status: $EventsTable.$converterstatus.fromJson(
        serializer.fromJson<int>(json['status']),
      ),
      deletedRemotely: serializer.fromJson<bool>(json['deletedRemotely']),
      colorOverride: serializer.fromJson<int?>(json['colorOverride']),
      mergedGroupId: serializer.fromJson<String?>(json['mergedGroupId']),
      webUrl: serializer.fromJson<String?>(json['webUrl']),
      conferenceJson: serializer.fromJson<String?>(json['conferenceJson']),
      attendeesJson: serializer.fromJson<String?>(json['attendeesJson']),
      remindersJson: serializer.fromJson<String?>(json['remindersJson']),
      attachmentsJson: serializer.fromJson<String?>(json['attachmentsJson']),
      dirty: serializer.fromJson<bool>(json['dirty']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'calendarId': serializer.toJson<String>(calendarId),
      'accountId': serializer.toJson<String>(accountId),
      'providerEventId': serializer.toJson<String?>(providerEventId),
      'etag': serializer.toJson<String?>(etag),
      'title': serializer.toJson<String>(title),
      'startUtc': serializer.toJson<DateTime>(startUtc),
      'endUtc': serializer.toJson<DateTime>(endUtc),
      'timeZoneId': serializer.toJson<String>(timeZoneId),
      'allDay': serializer.toJson<bool>(allDay),
      'location': serializer.toJson<String?>(location),
      'description': serializer.toJson<String?>(description),
      'recurrenceRule': serializer.toJson<String?>(recurrenceRule),
      'recurrenceId': serializer.toJson<String?>(recurrenceId),
      'myResponse': serializer.toJson<int>(
        $EventsTable.$convertermyResponse.toJson(myResponse),
      ),
      'showAs': serializer.toJson<int>(
        $EventsTable.$convertershowAs.toJson(showAs),
      ),
      'visibility': serializer.toJson<int>(
        $EventsTable.$convertervisibility.toJson(visibility),
      ),
      'status': serializer.toJson<int>(
        $EventsTable.$converterstatus.toJson(status),
      ),
      'deletedRemotely': serializer.toJson<bool>(deletedRemotely),
      'colorOverride': serializer.toJson<int?>(colorOverride),
      'mergedGroupId': serializer.toJson<String?>(mergedGroupId),
      'webUrl': serializer.toJson<String?>(webUrl),
      'conferenceJson': serializer.toJson<String?>(conferenceJson),
      'attendeesJson': serializer.toJson<String?>(attendeesJson),
      'remindersJson': serializer.toJson<String?>(remindersJson),
      'attachmentsJson': serializer.toJson<String?>(attachmentsJson),
      'dirty': serializer.toJson<bool>(dirty),
    };
  }

  Event copyWith({
    String? id,
    String? calendarId,
    String? accountId,
    Value<String?> providerEventId = const Value.absent(),
    Value<String?> etag = const Value.absent(),
    String? title,
    DateTime? startUtc,
    DateTime? endUtc,
    String? timeZoneId,
    bool? allDay,
    Value<String?> location = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> recurrenceRule = const Value.absent(),
    Value<String?> recurrenceId = const Value.absent(),
    ResponseStatus? myResponse,
    ShowAs? showAs,
    EventVisibility? visibility,
    EventStatus? status,
    bool? deletedRemotely,
    Value<int?> colorOverride = const Value.absent(),
    Value<String?> mergedGroupId = const Value.absent(),
    Value<String?> webUrl = const Value.absent(),
    Value<String?> conferenceJson = const Value.absent(),
    Value<String?> attendeesJson = const Value.absent(),
    Value<String?> remindersJson = const Value.absent(),
    Value<String?> attachmentsJson = const Value.absent(),
    bool? dirty,
  }) => Event(
    id: id ?? this.id,
    calendarId: calendarId ?? this.calendarId,
    accountId: accountId ?? this.accountId,
    providerEventId: providerEventId.present
        ? providerEventId.value
        : this.providerEventId,
    etag: etag.present ? etag.value : this.etag,
    title: title ?? this.title,
    startUtc: startUtc ?? this.startUtc,
    endUtc: endUtc ?? this.endUtc,
    timeZoneId: timeZoneId ?? this.timeZoneId,
    allDay: allDay ?? this.allDay,
    location: location.present ? location.value : this.location,
    description: description.present ? description.value : this.description,
    recurrenceRule: recurrenceRule.present
        ? recurrenceRule.value
        : this.recurrenceRule,
    recurrenceId: recurrenceId.present ? recurrenceId.value : this.recurrenceId,
    myResponse: myResponse ?? this.myResponse,
    showAs: showAs ?? this.showAs,
    visibility: visibility ?? this.visibility,
    status: status ?? this.status,
    deletedRemotely: deletedRemotely ?? this.deletedRemotely,
    colorOverride: colorOverride.present
        ? colorOverride.value
        : this.colorOverride,
    mergedGroupId: mergedGroupId.present
        ? mergedGroupId.value
        : this.mergedGroupId,
    webUrl: webUrl.present ? webUrl.value : this.webUrl,
    conferenceJson: conferenceJson.present
        ? conferenceJson.value
        : this.conferenceJson,
    attendeesJson: attendeesJson.present
        ? attendeesJson.value
        : this.attendeesJson,
    remindersJson: remindersJson.present
        ? remindersJson.value
        : this.remindersJson,
    attachmentsJson: attachmentsJson.present
        ? attachmentsJson.value
        : this.attachmentsJson,
    dirty: dirty ?? this.dirty,
  );
  Event copyWithCompanion(EventsCompanion data) {
    return Event(
      id: data.id.present ? data.id.value : this.id,
      calendarId: data.calendarId.present
          ? data.calendarId.value
          : this.calendarId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      providerEventId: data.providerEventId.present
          ? data.providerEventId.value
          : this.providerEventId,
      etag: data.etag.present ? data.etag.value : this.etag,
      title: data.title.present ? data.title.value : this.title,
      startUtc: data.startUtc.present ? data.startUtc.value : this.startUtc,
      endUtc: data.endUtc.present ? data.endUtc.value : this.endUtc,
      timeZoneId: data.timeZoneId.present
          ? data.timeZoneId.value
          : this.timeZoneId,
      allDay: data.allDay.present ? data.allDay.value : this.allDay,
      location: data.location.present ? data.location.value : this.location,
      description: data.description.present
          ? data.description.value
          : this.description,
      recurrenceRule: data.recurrenceRule.present
          ? data.recurrenceRule.value
          : this.recurrenceRule,
      recurrenceId: data.recurrenceId.present
          ? data.recurrenceId.value
          : this.recurrenceId,
      myResponse: data.myResponse.present
          ? data.myResponse.value
          : this.myResponse,
      showAs: data.showAs.present ? data.showAs.value : this.showAs,
      visibility: data.visibility.present
          ? data.visibility.value
          : this.visibility,
      status: data.status.present ? data.status.value : this.status,
      deletedRemotely: data.deletedRemotely.present
          ? data.deletedRemotely.value
          : this.deletedRemotely,
      colorOverride: data.colorOverride.present
          ? data.colorOverride.value
          : this.colorOverride,
      mergedGroupId: data.mergedGroupId.present
          ? data.mergedGroupId.value
          : this.mergedGroupId,
      webUrl: data.webUrl.present ? data.webUrl.value : this.webUrl,
      conferenceJson: data.conferenceJson.present
          ? data.conferenceJson.value
          : this.conferenceJson,
      attendeesJson: data.attendeesJson.present
          ? data.attendeesJson.value
          : this.attendeesJson,
      remindersJson: data.remindersJson.present
          ? data.remindersJson.value
          : this.remindersJson,
      attachmentsJson: data.attachmentsJson.present
          ? data.attachmentsJson.value
          : this.attachmentsJson,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Event(')
          ..write('id: $id, ')
          ..write('calendarId: $calendarId, ')
          ..write('accountId: $accountId, ')
          ..write('providerEventId: $providerEventId, ')
          ..write('etag: $etag, ')
          ..write('title: $title, ')
          ..write('startUtc: $startUtc, ')
          ..write('endUtc: $endUtc, ')
          ..write('timeZoneId: $timeZoneId, ')
          ..write('allDay: $allDay, ')
          ..write('location: $location, ')
          ..write('description: $description, ')
          ..write('recurrenceRule: $recurrenceRule, ')
          ..write('recurrenceId: $recurrenceId, ')
          ..write('myResponse: $myResponse, ')
          ..write('showAs: $showAs, ')
          ..write('visibility: $visibility, ')
          ..write('status: $status, ')
          ..write('deletedRemotely: $deletedRemotely, ')
          ..write('colorOverride: $colorOverride, ')
          ..write('mergedGroupId: $mergedGroupId, ')
          ..write('webUrl: $webUrl, ')
          ..write('conferenceJson: $conferenceJson, ')
          ..write('attendeesJson: $attendeesJson, ')
          ..write('remindersJson: $remindersJson, ')
          ..write('attachmentsJson: $attachmentsJson, ')
          ..write('dirty: $dirty')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    calendarId,
    accountId,
    providerEventId,
    etag,
    title,
    startUtc,
    endUtc,
    timeZoneId,
    allDay,
    location,
    description,
    recurrenceRule,
    recurrenceId,
    myResponse,
    showAs,
    visibility,
    status,
    deletedRemotely,
    colorOverride,
    mergedGroupId,
    webUrl,
    conferenceJson,
    attendeesJson,
    remindersJson,
    attachmentsJson,
    dirty,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Event &&
          other.id == this.id &&
          other.calendarId == this.calendarId &&
          other.accountId == this.accountId &&
          other.providerEventId == this.providerEventId &&
          other.etag == this.etag &&
          other.title == this.title &&
          other.startUtc == this.startUtc &&
          other.endUtc == this.endUtc &&
          other.timeZoneId == this.timeZoneId &&
          other.allDay == this.allDay &&
          other.location == this.location &&
          other.description == this.description &&
          other.recurrenceRule == this.recurrenceRule &&
          other.recurrenceId == this.recurrenceId &&
          other.myResponse == this.myResponse &&
          other.showAs == this.showAs &&
          other.visibility == this.visibility &&
          other.status == this.status &&
          other.deletedRemotely == this.deletedRemotely &&
          other.colorOverride == this.colorOverride &&
          other.mergedGroupId == this.mergedGroupId &&
          other.webUrl == this.webUrl &&
          other.conferenceJson == this.conferenceJson &&
          other.attendeesJson == this.attendeesJson &&
          other.remindersJson == this.remindersJson &&
          other.attachmentsJson == this.attachmentsJson &&
          other.dirty == this.dirty);
}

class EventsCompanion extends UpdateCompanion<Event> {
  final Value<String> id;
  final Value<String> calendarId;
  final Value<String> accountId;
  final Value<String?> providerEventId;
  final Value<String?> etag;
  final Value<String> title;
  final Value<DateTime> startUtc;
  final Value<DateTime> endUtc;
  final Value<String> timeZoneId;
  final Value<bool> allDay;
  final Value<String?> location;
  final Value<String?> description;
  final Value<String?> recurrenceRule;
  final Value<String?> recurrenceId;
  final Value<ResponseStatus> myResponse;
  final Value<ShowAs> showAs;
  final Value<EventVisibility> visibility;
  final Value<EventStatus> status;
  final Value<bool> deletedRemotely;
  final Value<int?> colorOverride;
  final Value<String?> mergedGroupId;
  final Value<String?> webUrl;
  final Value<String?> conferenceJson;
  final Value<String?> attendeesJson;
  final Value<String?> remindersJson;
  final Value<String?> attachmentsJson;
  final Value<bool> dirty;
  final Value<int> rowid;
  const EventsCompanion({
    this.id = const Value.absent(),
    this.calendarId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.providerEventId = const Value.absent(),
    this.etag = const Value.absent(),
    this.title = const Value.absent(),
    this.startUtc = const Value.absent(),
    this.endUtc = const Value.absent(),
    this.timeZoneId = const Value.absent(),
    this.allDay = const Value.absent(),
    this.location = const Value.absent(),
    this.description = const Value.absent(),
    this.recurrenceRule = const Value.absent(),
    this.recurrenceId = const Value.absent(),
    this.myResponse = const Value.absent(),
    this.showAs = const Value.absent(),
    this.visibility = const Value.absent(),
    this.status = const Value.absent(),
    this.deletedRemotely = const Value.absent(),
    this.colorOverride = const Value.absent(),
    this.mergedGroupId = const Value.absent(),
    this.webUrl = const Value.absent(),
    this.conferenceJson = const Value.absent(),
    this.attendeesJson = const Value.absent(),
    this.remindersJson = const Value.absent(),
    this.attachmentsJson = const Value.absent(),
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EventsCompanion.insert({
    required String id,
    required String calendarId,
    required String accountId,
    this.providerEventId = const Value.absent(),
    this.etag = const Value.absent(),
    required String title,
    required DateTime startUtc,
    required DateTime endUtc,
    this.timeZoneId = const Value.absent(),
    this.allDay = const Value.absent(),
    this.location = const Value.absent(),
    this.description = const Value.absent(),
    this.recurrenceRule = const Value.absent(),
    this.recurrenceId = const Value.absent(),
    this.myResponse = const Value.absent(),
    this.showAs = const Value.absent(),
    this.visibility = const Value.absent(),
    this.status = const Value.absent(),
    this.deletedRemotely = const Value.absent(),
    this.colorOverride = const Value.absent(),
    this.mergedGroupId = const Value.absent(),
    this.webUrl = const Value.absent(),
    this.conferenceJson = const Value.absent(),
    this.attendeesJson = const Value.absent(),
    this.remindersJson = const Value.absent(),
    this.attachmentsJson = const Value.absent(),
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       calendarId = Value(calendarId),
       accountId = Value(accountId),
       title = Value(title),
       startUtc = Value(startUtc),
       endUtc = Value(endUtc);
  static Insertable<Event> custom({
    Expression<String>? id,
    Expression<String>? calendarId,
    Expression<String>? accountId,
    Expression<String>? providerEventId,
    Expression<String>? etag,
    Expression<String>? title,
    Expression<DateTime>? startUtc,
    Expression<DateTime>? endUtc,
    Expression<String>? timeZoneId,
    Expression<bool>? allDay,
    Expression<String>? location,
    Expression<String>? description,
    Expression<String>? recurrenceRule,
    Expression<String>? recurrenceId,
    Expression<int>? myResponse,
    Expression<int>? showAs,
    Expression<int>? visibility,
    Expression<int>? status,
    Expression<bool>? deletedRemotely,
    Expression<int>? colorOverride,
    Expression<String>? mergedGroupId,
    Expression<String>? webUrl,
    Expression<String>? conferenceJson,
    Expression<String>? attendeesJson,
    Expression<String>? remindersJson,
    Expression<String>? attachmentsJson,
    Expression<bool>? dirty,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (calendarId != null) 'calendar_id': calendarId,
      if (accountId != null) 'account_id': accountId,
      if (providerEventId != null) 'provider_event_id': providerEventId,
      if (etag != null) 'etag': etag,
      if (title != null) 'title': title,
      if (startUtc != null) 'start_utc': startUtc,
      if (endUtc != null) 'end_utc': endUtc,
      if (timeZoneId != null) 'time_zone_id': timeZoneId,
      if (allDay != null) 'all_day': allDay,
      if (location != null) 'location': location,
      if (description != null) 'description': description,
      if (recurrenceRule != null) 'recurrence_rule': recurrenceRule,
      if (recurrenceId != null) 'recurrence_id': recurrenceId,
      if (myResponse != null) 'my_response': myResponse,
      if (showAs != null) 'show_as': showAs,
      if (visibility != null) 'visibility': visibility,
      if (status != null) 'status': status,
      if (deletedRemotely != null) 'deleted_remotely': deletedRemotely,
      if (colorOverride != null) 'color_override': colorOverride,
      if (mergedGroupId != null) 'merged_group_id': mergedGroupId,
      if (webUrl != null) 'web_url': webUrl,
      if (conferenceJson != null) 'conference_json': conferenceJson,
      if (attendeesJson != null) 'attendees_json': attendeesJson,
      if (remindersJson != null) 'reminders_json': remindersJson,
      if (attachmentsJson != null) 'attachments_json': attachmentsJson,
      if (dirty != null) 'dirty': dirty,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EventsCompanion copyWith({
    Value<String>? id,
    Value<String>? calendarId,
    Value<String>? accountId,
    Value<String?>? providerEventId,
    Value<String?>? etag,
    Value<String>? title,
    Value<DateTime>? startUtc,
    Value<DateTime>? endUtc,
    Value<String>? timeZoneId,
    Value<bool>? allDay,
    Value<String?>? location,
    Value<String?>? description,
    Value<String?>? recurrenceRule,
    Value<String?>? recurrenceId,
    Value<ResponseStatus>? myResponse,
    Value<ShowAs>? showAs,
    Value<EventVisibility>? visibility,
    Value<EventStatus>? status,
    Value<bool>? deletedRemotely,
    Value<int?>? colorOverride,
    Value<String?>? mergedGroupId,
    Value<String?>? webUrl,
    Value<String?>? conferenceJson,
    Value<String?>? attendeesJson,
    Value<String?>? remindersJson,
    Value<String?>? attachmentsJson,
    Value<bool>? dirty,
    Value<int>? rowid,
  }) {
    return EventsCompanion(
      id: id ?? this.id,
      calendarId: calendarId ?? this.calendarId,
      accountId: accountId ?? this.accountId,
      providerEventId: providerEventId ?? this.providerEventId,
      etag: etag ?? this.etag,
      title: title ?? this.title,
      startUtc: startUtc ?? this.startUtc,
      endUtc: endUtc ?? this.endUtc,
      timeZoneId: timeZoneId ?? this.timeZoneId,
      allDay: allDay ?? this.allDay,
      location: location ?? this.location,
      description: description ?? this.description,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      recurrenceId: recurrenceId ?? this.recurrenceId,
      myResponse: myResponse ?? this.myResponse,
      showAs: showAs ?? this.showAs,
      visibility: visibility ?? this.visibility,
      status: status ?? this.status,
      deletedRemotely: deletedRemotely ?? this.deletedRemotely,
      colorOverride: colorOverride ?? this.colorOverride,
      mergedGroupId: mergedGroupId ?? this.mergedGroupId,
      webUrl: webUrl ?? this.webUrl,
      conferenceJson: conferenceJson ?? this.conferenceJson,
      attendeesJson: attendeesJson ?? this.attendeesJson,
      remindersJson: remindersJson ?? this.remindersJson,
      attachmentsJson: attachmentsJson ?? this.attachmentsJson,
      dirty: dirty ?? this.dirty,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (calendarId.present) {
      map['calendar_id'] = Variable<String>(calendarId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (providerEventId.present) {
      map['provider_event_id'] = Variable<String>(providerEventId.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (startUtc.present) {
      map['start_utc'] = Variable<DateTime>(startUtc.value);
    }
    if (endUtc.present) {
      map['end_utc'] = Variable<DateTime>(endUtc.value);
    }
    if (timeZoneId.present) {
      map['time_zone_id'] = Variable<String>(timeZoneId.value);
    }
    if (allDay.present) {
      map['all_day'] = Variable<bool>(allDay.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (recurrenceRule.present) {
      map['recurrence_rule'] = Variable<String>(recurrenceRule.value);
    }
    if (recurrenceId.present) {
      map['recurrence_id'] = Variable<String>(recurrenceId.value);
    }
    if (myResponse.present) {
      map['my_response'] = Variable<int>(
        $EventsTable.$convertermyResponse.toSql(myResponse.value),
      );
    }
    if (showAs.present) {
      map['show_as'] = Variable<int>(
        $EventsTable.$convertershowAs.toSql(showAs.value),
      );
    }
    if (visibility.present) {
      map['visibility'] = Variable<int>(
        $EventsTable.$convertervisibility.toSql(visibility.value),
      );
    }
    if (status.present) {
      map['status'] = Variable<int>(
        $EventsTable.$converterstatus.toSql(status.value),
      );
    }
    if (deletedRemotely.present) {
      map['deleted_remotely'] = Variable<bool>(deletedRemotely.value);
    }
    if (colorOverride.present) {
      map['color_override'] = Variable<int>(colorOverride.value);
    }
    if (mergedGroupId.present) {
      map['merged_group_id'] = Variable<String>(mergedGroupId.value);
    }
    if (webUrl.present) {
      map['web_url'] = Variable<String>(webUrl.value);
    }
    if (conferenceJson.present) {
      map['conference_json'] = Variable<String>(conferenceJson.value);
    }
    if (attendeesJson.present) {
      map['attendees_json'] = Variable<String>(attendeesJson.value);
    }
    if (remindersJson.present) {
      map['reminders_json'] = Variable<String>(remindersJson.value);
    }
    if (attachmentsJson.present) {
      map['attachments_json'] = Variable<String>(attachmentsJson.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventsCompanion(')
          ..write('id: $id, ')
          ..write('calendarId: $calendarId, ')
          ..write('accountId: $accountId, ')
          ..write('providerEventId: $providerEventId, ')
          ..write('etag: $etag, ')
          ..write('title: $title, ')
          ..write('startUtc: $startUtc, ')
          ..write('endUtc: $endUtc, ')
          ..write('timeZoneId: $timeZoneId, ')
          ..write('allDay: $allDay, ')
          ..write('location: $location, ')
          ..write('description: $description, ')
          ..write('recurrenceRule: $recurrenceRule, ')
          ..write('recurrenceId: $recurrenceId, ')
          ..write('myResponse: $myResponse, ')
          ..write('showAs: $showAs, ')
          ..write('visibility: $visibility, ')
          ..write('status: $status, ')
          ..write('deletedRemotely: $deletedRemotely, ')
          ..write('colorOverride: $colorOverride, ')
          ..write('mergedGroupId: $mergedGroupId, ')
          ..write('webUrl: $webUrl, ')
          ..write('conferenceJson: $conferenceJson, ')
          ..write('attendeesJson: $attendeesJson, ')
          ..write('remindersJson: $remindersJson, ')
          ..write('attachmentsJson: $attachmentsJson, ')
          ..write('dirty: $dirty, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  @override
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    op,
    eventId,
    payloadJson,
    retryCount,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    } else if (isInserting) {
      context.missing(_opMeta);
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      op: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxData extends DataClass implements Insertable<OutboxData> {
  final int id;
  final String op;
  final String eventId;
  final String payloadJson;
  final int retryCount;
  final DateTime createdAt;
  const OutboxData({
    required this.id,
    required this.op,
    required this.eventId,
    required this.payloadJson,
    required this.retryCount,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['op'] = Variable<String>(op);
    map['event_id'] = Variable<String>(eventId);
    map['payload_json'] = Variable<String>(payloadJson);
    map['retry_count'] = Variable<int>(retryCount);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      id: Value(id),
      op: Value(op),
      eventId: Value(eventId),
      payloadJson: Value(payloadJson),
      retryCount: Value(retryCount),
      createdAt: Value(createdAt),
    );
  }

  factory OutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxData(
      id: serializer.fromJson<int>(json['id']),
      op: serializer.fromJson<String>(json['op']),
      eventId: serializer.fromJson<String>(json['eventId']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'op': serializer.toJson<String>(op),
      'eventId': serializer.toJson<String>(eventId),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'retryCount': serializer.toJson<int>(retryCount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  OutboxData copyWith({
    int? id,
    String? op,
    String? eventId,
    String? payloadJson,
    int? retryCount,
    DateTime? createdAt,
  }) => OutboxData(
    id: id ?? this.id,
    op: op ?? this.op,
    eventId: eventId ?? this.eventId,
    payloadJson: payloadJson ?? this.payloadJson,
    retryCount: retryCount ?? this.retryCount,
    createdAt: createdAt ?? this.createdAt,
  );
  OutboxData copyWithCompanion(OutboxCompanion data) {
    return OutboxData(
      id: data.id.present ? data.id.value : this.id,
      op: data.op.present ? data.op.value : this.op,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxData(')
          ..write('id: $id, ')
          ..write('op: $op, ')
          ..write('eventId: $eventId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('retryCount: $retryCount, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, op, eventId, payloadJson, retryCount, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxData &&
          other.id == this.id &&
          other.op == this.op &&
          other.eventId == this.eventId &&
          other.payloadJson == this.payloadJson &&
          other.retryCount == this.retryCount &&
          other.createdAt == this.createdAt);
}

class OutboxCompanion extends UpdateCompanion<OutboxData> {
  final Value<int> id;
  final Value<String> op;
  final Value<String> eventId;
  final Value<String> payloadJson;
  final Value<int> retryCount;
  final Value<DateTime> createdAt;
  const OutboxCompanion({
    this.id = const Value.absent(),
    this.op = const Value.absent(),
    this.eventId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  OutboxCompanion.insert({
    this.id = const Value.absent(),
    required String op,
    required String eventId,
    this.payloadJson = const Value.absent(),
    this.retryCount = const Value.absent(),
    required DateTime createdAt,
  }) : op = Value(op),
       eventId = Value(eventId),
       createdAt = Value(createdAt);
  static Insertable<OutboxData> custom({
    Expression<int>? id,
    Expression<String>? op,
    Expression<String>? eventId,
    Expression<String>? payloadJson,
    Expression<int>? retryCount,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (op != null) 'op': op,
      if (eventId != null) 'event_id': eventId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (retryCount != null) 'retry_count': retryCount,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  OutboxCompanion copyWith({
    Value<int>? id,
    Value<String>? op,
    Value<String>? eventId,
    Value<String>? payloadJson,
    Value<int>? retryCount,
    Value<DateTime>? createdAt,
  }) {
    return OutboxCompanion(
      id: id ?? this.id,
      op: op ?? this.op,
      eventId: eventId ?? this.eventId,
      payloadJson: payloadJson ?? this.payloadJson,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('id: $id, ')
          ..write('op: $op, ')
          ..write('eventId: $eventId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('retryCount: $retryCount, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ContactsTable extends Contacts
    with TableInfo<$ContactsTable, ContactRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContactsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _useCountMeta = const VerificationMeta(
    'useCount',
  );
  @override
  late final GeneratedColumn<int> useCount = GeneratedColumn<int>(
    'use_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    displayName,
    email,
    source,
    useCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'contacts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContactRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('use_count')) {
      context.handle(
        _useCountMeta,
        useCount.isAcceptableOrUnknown(data['use_count']!, _useCountMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ContactRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContactRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      useCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}use_count'],
      )!,
    );
  }

  @override
  $ContactsTable createAlias(String alias) {
    return $ContactsTable(attachedDatabase, alias);
  }
}

class ContactRow extends DataClass implements Insertable<ContactRow> {
  final String id;
  final String displayName;
  final String email;
  final String source;

  /// Сколько раз контакт добавляли участником — для сортировки подсказок по
  /// частоте (FR-K).
  final int useCount;
  const ContactRow({
    required this.id,
    required this.displayName,
    required this.email,
    required this.source,
    required this.useCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['display_name'] = Variable<String>(displayName);
    map['email'] = Variable<String>(email);
    map['source'] = Variable<String>(source);
    map['use_count'] = Variable<int>(useCount);
    return map;
  }

  ContactsCompanion toCompanion(bool nullToAbsent) {
    return ContactsCompanion(
      id: Value(id),
      displayName: Value(displayName),
      email: Value(email),
      source: Value(source),
      useCount: Value(useCount),
    );
  }

  factory ContactRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContactRow(
      id: serializer.fromJson<String>(json['id']),
      displayName: serializer.fromJson<String>(json['displayName']),
      email: serializer.fromJson<String>(json['email']),
      source: serializer.fromJson<String>(json['source']),
      useCount: serializer.fromJson<int>(json['useCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'displayName': serializer.toJson<String>(displayName),
      'email': serializer.toJson<String>(email),
      'source': serializer.toJson<String>(source),
      'useCount': serializer.toJson<int>(useCount),
    };
  }

  ContactRow copyWith({
    String? id,
    String? displayName,
    String? email,
    String? source,
    int? useCount,
  }) => ContactRow(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    email: email ?? this.email,
    source: source ?? this.source,
    useCount: useCount ?? this.useCount,
  );
  ContactRow copyWithCompanion(ContactsCompanion data) {
    return ContactRow(
      id: data.id.present ? data.id.value : this.id,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      email: data.email.present ? data.email.value : this.email,
      source: data.source.present ? data.source.value : this.source,
      useCount: data.useCount.present ? data.useCount.value : this.useCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContactRow(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('email: $email, ')
          ..write('source: $source, ')
          ..write('useCount: $useCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, displayName, email, source, useCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContactRow &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.email == this.email &&
          other.source == this.source &&
          other.useCount == this.useCount);
}

class ContactsCompanion extends UpdateCompanion<ContactRow> {
  final Value<String> id;
  final Value<String> displayName;
  final Value<String> email;
  final Value<String> source;
  final Value<int> useCount;
  final Value<int> rowid;
  const ContactsCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.email = const Value.absent(),
    this.source = const Value.absent(),
    this.useCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContactsCompanion.insert({
    required String id,
    required String displayName,
    required String email,
    this.source = const Value.absent(),
    this.useCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       displayName = Value(displayName),
       email = Value(email);
  static Insertable<ContactRow> custom({
    Expression<String>? id,
    Expression<String>? displayName,
    Expression<String>? email,
    Expression<String>? source,
    Expression<int>? useCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (email != null) 'email': email,
      if (source != null) 'source': source,
      if (useCount != null) 'use_count': useCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContactsCompanion copyWith({
    Value<String>? id,
    Value<String>? displayName,
    Value<String>? email,
    Value<String>? source,
    Value<int>? useCount,
    Value<int>? rowid,
  }) {
    return ContactsCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      source: source ?? this.source,
      useCount: useCount ?? this.useCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (useCount.present) {
      map['use_count'] = Variable<int>(useCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContactsCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('email: $email, ')
          ..write('source: $source, ')
          ..write('useCount: $useCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $CalendarsTable calendars = $CalendarsTable(this);
  late final $EventsTable events = $EventsTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $ContactsTable contacts = $ContactsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    accounts,
    calendars,
    events,
    outbox,
    contacts,
  ];
}

typedef $$AccountsTableCreateCompanionBuilder =
    AccountsCompanion Function({
      required String id,
      required ProviderType provider,
      required String displayName,
      required String email,
      Value<AccountStatus> status,
      Value<String> configJson,
      Value<String> refreshJson,
      Value<DateTime?> lastSyncUtc,
      Value<String?> lastError,
      Value<int> rowid,
    });
typedef $$AccountsTableUpdateCompanionBuilder =
    AccountsCompanion Function({
      Value<String> id,
      Value<ProviderType> provider,
      Value<String> displayName,
      Value<String> email,
      Value<AccountStatus> status,
      Value<String> configJson,
      Value<String> refreshJson,
      Value<DateTime?> lastSyncUtc,
      Value<String?> lastError,
      Value<int> rowid,
    });

final class $$AccountsTableReferences
    extends BaseReferences<_$AppDatabase, $AccountsTable, AccountRow> {
  $$AccountsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CalendarsTable, List<CalendarRow>>
  _calendarsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.calendars,
    aliasName: $_aliasNameGenerator(db.accounts.id, db.calendars.accountId),
  );

  $$CalendarsTableProcessedTableManager get calendarsRefs {
    final manager = $$CalendarsTableTableManager(
      $_db,
      $_db.calendars,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_calendarsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AccountsTableFilterComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ProviderType, ProviderType, int>
  get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AccountStatus, AccountStatus, int>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get refreshJson => $composableBuilder(
    column: $table.refreshJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncUtc => $composableBuilder(
    column: $table.lastSyncUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> calendarsRefs(
    Expression<bool> Function($$CalendarsTableFilterComposer f) f,
  ) {
    final $$CalendarsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.calendars,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarsTableFilterComposer(
            $db: $db,
            $table: $db.calendars,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get refreshJson => $composableBuilder(
    column: $table.refreshJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncUtc => $composableBuilder(
    column: $table.lastSyncUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ProviderType, int> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AccountStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get refreshJson => $composableBuilder(
    column: $table.refreshJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncUtc => $composableBuilder(
    column: $table.lastSyncUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  Expression<T> calendarsRefs<T extends Object>(
    Expression<T> Function($$CalendarsTableAnnotationComposer a) f,
  ) {
    final $$CalendarsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.calendars,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarsTableAnnotationComposer(
            $db: $db,
            $table: $db.calendars,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AccountsTable,
          AccountRow,
          $$AccountsTableFilterComposer,
          $$AccountsTableOrderingComposer,
          $$AccountsTableAnnotationComposer,
          $$AccountsTableCreateCompanionBuilder,
          $$AccountsTableUpdateCompanionBuilder,
          (AccountRow, $$AccountsTableReferences),
          AccountRow,
          PrefetchHooks Function({bool calendarsRefs})
        > {
  $$AccountsTableTableManager(_$AppDatabase db, $AccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<ProviderType> provider = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<AccountStatus> status = const Value.absent(),
                Value<String> configJson = const Value.absent(),
                Value<String> refreshJson = const Value.absent(),
                Value<DateTime?> lastSyncUtc = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion(
                id: id,
                provider: provider,
                displayName: displayName,
                email: email,
                status: status,
                configJson: configJson,
                refreshJson: refreshJson,
                lastSyncUtc: lastSyncUtc,
                lastError: lastError,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required ProviderType provider,
                required String displayName,
                required String email,
                Value<AccountStatus> status = const Value.absent(),
                Value<String> configJson = const Value.absent(),
                Value<String> refreshJson = const Value.absent(),
                Value<DateTime?> lastSyncUtc = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion.insert(
                id: id,
                provider: provider,
                displayName: displayName,
                email: email,
                status: status,
                configJson: configJson,
                refreshJson: refreshJson,
                lastSyncUtc: lastSyncUtc,
                lastError: lastError,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AccountsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({calendarsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (calendarsRefs) db.calendars],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (calendarsRefs)
                    await $_getPrefetchedData<
                      AccountRow,
                      $AccountsTable,
                      CalendarRow
                    >(
                      currentTable: table,
                      referencedTable: $$AccountsTableReferences
                          ._calendarsRefsTable(db),
                      managerFromTypedResult: (p0) => $$AccountsTableReferences(
                        db,
                        table,
                        p0,
                      ).calendarsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.accountId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$AccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AccountsTable,
      AccountRow,
      $$AccountsTableFilterComposer,
      $$AccountsTableOrderingComposer,
      $$AccountsTableAnnotationComposer,
      $$AccountsTableCreateCompanionBuilder,
      $$AccountsTableUpdateCompanionBuilder,
      (AccountRow, $$AccountsTableReferences),
      AccountRow,
      PrefetchHooks Function({bool calendarsRefs})
    >;
typedef $$CalendarsTableCreateCompanionBuilder =
    CalendarsCompanion Function({
      required String id,
      required String accountId,
      required String name,
      Value<String?> nameOverride,
      required int color,
      Value<int?> colorOverride,
      Value<int?> defaultReminderMinutes,
      Value<bool> visible,
      Value<String?> syncState,
      Value<bool> isPrimary,
      Value<bool> readOnly,
      Value<int> rowid,
    });
typedef $$CalendarsTableUpdateCompanionBuilder =
    CalendarsCompanion Function({
      Value<String> id,
      Value<String> accountId,
      Value<String> name,
      Value<String?> nameOverride,
      Value<int> color,
      Value<int?> colorOverride,
      Value<int?> defaultReminderMinutes,
      Value<bool> visible,
      Value<String?> syncState,
      Value<bool> isPrimary,
      Value<bool> readOnly,
      Value<int> rowid,
    });

final class $$CalendarsTableReferences
    extends BaseReferences<_$AppDatabase, $CalendarsTable, CalendarRow> {
  $$CalendarsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias(
        $_aliasNameGenerator(db.calendars.accountId, db.accounts.id),
      );

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$EventsTable, List<Event>> _eventsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.events,
    aliasName: $_aliasNameGenerator(db.calendars.id, db.events.calendarId),
  );

  $$EventsTableProcessedTableManager get eventsRefs {
    final manager = $$EventsTableTableManager(
      $_db,
      $_db.events,
    ).filter((f) => f.calendarId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_eventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CalendarsTableFilterComposer
    extends Composer<_$AppDatabase, $CalendarsTable> {
  $$CalendarsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameOverride => $composableBuilder(
    column: $table.nameOverride,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorOverride => $composableBuilder(
    column: $table.colorOverride,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get defaultReminderMinutes => $composableBuilder(
    column: $table.defaultReminderMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get visible => $composableBuilder(
    column: $table.visible,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPrimary => $composableBuilder(
    column: $table.isPrimary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get readOnly => $composableBuilder(
    column: $table.readOnly,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> eventsRefs(
    Expression<bool> Function($$EventsTableFilterComposer f) f,
  ) {
    final $$EventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.calendarId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableFilterComposer(
            $db: $db,
            $table: $db.events,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CalendarsTableOrderingComposer
    extends Composer<_$AppDatabase, $CalendarsTable> {
  $$CalendarsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameOverride => $composableBuilder(
    column: $table.nameOverride,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorOverride => $composableBuilder(
    column: $table.colorOverride,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get defaultReminderMinutes => $composableBuilder(
    column: $table.defaultReminderMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get visible => $composableBuilder(
    column: $table.visible,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPrimary => $composableBuilder(
    column: $table.isPrimary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get readOnly => $composableBuilder(
    column: $table.readOnly,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CalendarsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CalendarsTable> {
  $$CalendarsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get nameOverride => $composableBuilder(
    column: $table.nameOverride,
    builder: (column) => column,
  );

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get colorOverride => $composableBuilder(
    column: $table.colorOverride,
    builder: (column) => column,
  );

  GeneratedColumn<int> get defaultReminderMinutes => $composableBuilder(
    column: $table.defaultReminderMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get visible =>
      $composableBuilder(column: $table.visible, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<bool> get isPrimary =>
      $composableBuilder(column: $table.isPrimary, builder: (column) => column);

  GeneratedColumn<bool> get readOnly =>
      $composableBuilder(column: $table.readOnly, builder: (column) => column);

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> eventsRefs<T extends Object>(
    Expression<T> Function($$EventsTableAnnotationComposer a) f,
  ) {
    final $$EventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.calendarId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableAnnotationComposer(
            $db: $db,
            $table: $db.events,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CalendarsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CalendarsTable,
          CalendarRow,
          $$CalendarsTableFilterComposer,
          $$CalendarsTableOrderingComposer,
          $$CalendarsTableAnnotationComposer,
          $$CalendarsTableCreateCompanionBuilder,
          $$CalendarsTableUpdateCompanionBuilder,
          (CalendarRow, $$CalendarsTableReferences),
          CalendarRow,
          PrefetchHooks Function({bool accountId, bool eventsRefs})
        > {
  $$CalendarsTableTableManager(_$AppDatabase db, $CalendarsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalendarsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CalendarsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CalendarsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> nameOverride = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<int?> colorOverride = const Value.absent(),
                Value<int?> defaultReminderMinutes = const Value.absent(),
                Value<bool> visible = const Value.absent(),
                Value<String?> syncState = const Value.absent(),
                Value<bool> isPrimary = const Value.absent(),
                Value<bool> readOnly = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalendarsCompanion(
                id: id,
                accountId: accountId,
                name: name,
                nameOverride: nameOverride,
                color: color,
                colorOverride: colorOverride,
                defaultReminderMinutes: defaultReminderMinutes,
                visible: visible,
                syncState: syncState,
                isPrimary: isPrimary,
                readOnly: readOnly,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accountId,
                required String name,
                Value<String?> nameOverride = const Value.absent(),
                required int color,
                Value<int?> colorOverride = const Value.absent(),
                Value<int?> defaultReminderMinutes = const Value.absent(),
                Value<bool> visible = const Value.absent(),
                Value<String?> syncState = const Value.absent(),
                Value<bool> isPrimary = const Value.absent(),
                Value<bool> readOnly = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalendarsCompanion.insert(
                id: id,
                accountId: accountId,
                name: name,
                nameOverride: nameOverride,
                color: color,
                colorOverride: colorOverride,
                defaultReminderMinutes: defaultReminderMinutes,
                visible: visible,
                syncState: syncState,
                isPrimary: isPrimary,
                readOnly: readOnly,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CalendarsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({accountId = false, eventsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (eventsRefs) db.events],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (accountId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.accountId,
                                referencedTable: $$CalendarsTableReferences
                                    ._accountIdTable(db),
                                referencedColumn: $$CalendarsTableReferences
                                    ._accountIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (eventsRefs)
                    await $_getPrefetchedData<
                      CalendarRow,
                      $CalendarsTable,
                      Event
                    >(
                      currentTable: table,
                      referencedTable: $$CalendarsTableReferences
                          ._eventsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CalendarsTableReferences(db, table, p0).eventsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.calendarId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CalendarsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CalendarsTable,
      CalendarRow,
      $$CalendarsTableFilterComposer,
      $$CalendarsTableOrderingComposer,
      $$CalendarsTableAnnotationComposer,
      $$CalendarsTableCreateCompanionBuilder,
      $$CalendarsTableUpdateCompanionBuilder,
      (CalendarRow, $$CalendarsTableReferences),
      CalendarRow,
      PrefetchHooks Function({bool accountId, bool eventsRefs})
    >;
typedef $$EventsTableCreateCompanionBuilder =
    EventsCompanion Function({
      required String id,
      required String calendarId,
      required String accountId,
      Value<String?> providerEventId,
      Value<String?> etag,
      required String title,
      required DateTime startUtc,
      required DateTime endUtc,
      Value<String> timeZoneId,
      Value<bool> allDay,
      Value<String?> location,
      Value<String?> description,
      Value<String?> recurrenceRule,
      Value<String?> recurrenceId,
      Value<ResponseStatus> myResponse,
      Value<ShowAs> showAs,
      Value<EventVisibility> visibility,
      Value<EventStatus> status,
      Value<bool> deletedRemotely,
      Value<int?> colorOverride,
      Value<String?> mergedGroupId,
      Value<String?> webUrl,
      Value<String?> conferenceJson,
      Value<String?> attendeesJson,
      Value<String?> remindersJson,
      Value<String?> attachmentsJson,
      Value<bool> dirty,
      Value<int> rowid,
    });
typedef $$EventsTableUpdateCompanionBuilder =
    EventsCompanion Function({
      Value<String> id,
      Value<String> calendarId,
      Value<String> accountId,
      Value<String?> providerEventId,
      Value<String?> etag,
      Value<String> title,
      Value<DateTime> startUtc,
      Value<DateTime> endUtc,
      Value<String> timeZoneId,
      Value<bool> allDay,
      Value<String?> location,
      Value<String?> description,
      Value<String?> recurrenceRule,
      Value<String?> recurrenceId,
      Value<ResponseStatus> myResponse,
      Value<ShowAs> showAs,
      Value<EventVisibility> visibility,
      Value<EventStatus> status,
      Value<bool> deletedRemotely,
      Value<int?> colorOverride,
      Value<String?> mergedGroupId,
      Value<String?> webUrl,
      Value<String?> conferenceJson,
      Value<String?> attendeesJson,
      Value<String?> remindersJson,
      Value<String?> attachmentsJson,
      Value<bool> dirty,
      Value<int> rowid,
    });

final class $$EventsTableReferences
    extends BaseReferences<_$AppDatabase, $EventsTable, Event> {
  $$EventsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CalendarsTable _calendarIdTable(_$AppDatabase db) => db.calendars
      .createAlias($_aliasNameGenerator(db.events.calendarId, db.calendars.id));

  $$CalendarsTableProcessedTableManager get calendarId {
    final $_column = $_itemColumn<String>('calendar_id')!;

    final manager = $$CalendarsTableTableManager(
      $_db,
      $_db.calendars,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_calendarIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EventsTableFilterComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerEventId => $composableBuilder(
    column: $table.providerEventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startUtc => $composableBuilder(
    column: $table.startUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endUtc => $composableBuilder(
    column: $table.endUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeZoneId => $composableBuilder(
    column: $table.timeZoneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get allDay => $composableBuilder(
    column: $table.allDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceRule => $composableBuilder(
    column: $table.recurrenceRule,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceId => $composableBuilder(
    column: $table.recurrenceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ResponseStatus, ResponseStatus, int>
  get myResponse => $composableBuilder(
    column: $table.myResponse,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<ShowAs, ShowAs, int> get showAs =>
      $composableBuilder(
        column: $table.showAs,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<EventVisibility, EventVisibility, int>
  get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<EventStatus, EventStatus, int> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get deletedRemotely => $composableBuilder(
    column: $table.deletedRemotely,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorOverride => $composableBuilder(
    column: $table.colorOverride,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mergedGroupId => $composableBuilder(
    column: $table.mergedGroupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get webUrl => $composableBuilder(
    column: $table.webUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conferenceJson => $composableBuilder(
    column: $table.conferenceJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attendeesJson => $composableBuilder(
    column: $table.attendeesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remindersJson => $composableBuilder(
    column: $table.remindersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachmentsJson => $composableBuilder(
    column: $table.attachmentsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  $$CalendarsTableFilterComposer get calendarId {
    final $$CalendarsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarId,
      referencedTable: $db.calendars,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarsTableFilterComposer(
            $db: $db,
            $table: $db.calendars,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EventsTableOrderingComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerEventId => $composableBuilder(
    column: $table.providerEventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startUtc => $composableBuilder(
    column: $table.startUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endUtc => $composableBuilder(
    column: $table.endUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeZoneId => $composableBuilder(
    column: $table.timeZoneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allDay => $composableBuilder(
    column: $table.allDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceRule => $composableBuilder(
    column: $table.recurrenceRule,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceId => $composableBuilder(
    column: $table.recurrenceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get myResponse => $composableBuilder(
    column: $table.myResponse,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get showAs => $composableBuilder(
    column: $table.showAs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deletedRemotely => $composableBuilder(
    column: $table.deletedRemotely,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorOverride => $composableBuilder(
    column: $table.colorOverride,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mergedGroupId => $composableBuilder(
    column: $table.mergedGroupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get webUrl => $composableBuilder(
    column: $table.webUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conferenceJson => $composableBuilder(
    column: $table.conferenceJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attendeesJson => $composableBuilder(
    column: $table.attendeesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remindersJson => $composableBuilder(
    column: $table.remindersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachmentsJson => $composableBuilder(
    column: $table.attachmentsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  $$CalendarsTableOrderingComposer get calendarId {
    final $$CalendarsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarId,
      referencedTable: $db.calendars,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarsTableOrderingComposer(
            $db: $db,
            $table: $db.calendars,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get providerEventId => $composableBuilder(
    column: $table.providerEventId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get startUtc =>
      $composableBuilder(column: $table.startUtc, builder: (column) => column);

  GeneratedColumn<DateTime> get endUtc =>
      $composableBuilder(column: $table.endUtc, builder: (column) => column);

  GeneratedColumn<String> get timeZoneId => $composableBuilder(
    column: $table.timeZoneId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get allDay =>
      $composableBuilder(column: $table.allDay, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrenceRule => $composableBuilder(
    column: $table.recurrenceRule,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrenceId => $composableBuilder(
    column: $table.recurrenceId,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<ResponseStatus, int> get myResponse =>
      $composableBuilder(
        column: $table.myResponse,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<ShowAs, int> get showAs =>
      $composableBuilder(column: $table.showAs, builder: (column) => column);

  GeneratedColumnWithTypeConverter<EventVisibility, int> get visibility =>
      $composableBuilder(
        column: $table.visibility,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<EventStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get deletedRemotely => $composableBuilder(
    column: $table.deletedRemotely,
    builder: (column) => column,
  );

  GeneratedColumn<int> get colorOverride => $composableBuilder(
    column: $table.colorOverride,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mergedGroupId => $composableBuilder(
    column: $table.mergedGroupId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get webUrl =>
      $composableBuilder(column: $table.webUrl, builder: (column) => column);

  GeneratedColumn<String> get conferenceJson => $composableBuilder(
    column: $table.conferenceJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get attendeesJson => $composableBuilder(
    column: $table.attendeesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remindersJson => $composableBuilder(
    column: $table.remindersJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get attachmentsJson => $composableBuilder(
    column: $table.attachmentsJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  $$CalendarsTableAnnotationComposer get calendarId {
    final $$CalendarsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarId,
      referencedTable: $db.calendars,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarsTableAnnotationComposer(
            $db: $db,
            $table: $db.calendars,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EventsTable,
          Event,
          $$EventsTableFilterComposer,
          $$EventsTableOrderingComposer,
          $$EventsTableAnnotationComposer,
          $$EventsTableCreateCompanionBuilder,
          $$EventsTableUpdateCompanionBuilder,
          (Event, $$EventsTableReferences),
          Event,
          PrefetchHooks Function({bool calendarId})
        > {
  $$EventsTableTableManager(_$AppDatabase db, $EventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> calendarId = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String?> providerEventId = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime> startUtc = const Value.absent(),
                Value<DateTime> endUtc = const Value.absent(),
                Value<String> timeZoneId = const Value.absent(),
                Value<bool> allDay = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> recurrenceRule = const Value.absent(),
                Value<String?> recurrenceId = const Value.absent(),
                Value<ResponseStatus> myResponse = const Value.absent(),
                Value<ShowAs> showAs = const Value.absent(),
                Value<EventVisibility> visibility = const Value.absent(),
                Value<EventStatus> status = const Value.absent(),
                Value<bool> deletedRemotely = const Value.absent(),
                Value<int?> colorOverride = const Value.absent(),
                Value<String?> mergedGroupId = const Value.absent(),
                Value<String?> webUrl = const Value.absent(),
                Value<String?> conferenceJson = const Value.absent(),
                Value<String?> attendeesJson = const Value.absent(),
                Value<String?> remindersJson = const Value.absent(),
                Value<String?> attachmentsJson = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventsCompanion(
                id: id,
                calendarId: calendarId,
                accountId: accountId,
                providerEventId: providerEventId,
                etag: etag,
                title: title,
                startUtc: startUtc,
                endUtc: endUtc,
                timeZoneId: timeZoneId,
                allDay: allDay,
                location: location,
                description: description,
                recurrenceRule: recurrenceRule,
                recurrenceId: recurrenceId,
                myResponse: myResponse,
                showAs: showAs,
                visibility: visibility,
                status: status,
                deletedRemotely: deletedRemotely,
                colorOverride: colorOverride,
                mergedGroupId: mergedGroupId,
                webUrl: webUrl,
                conferenceJson: conferenceJson,
                attendeesJson: attendeesJson,
                remindersJson: remindersJson,
                attachmentsJson: attachmentsJson,
                dirty: dirty,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String calendarId,
                required String accountId,
                Value<String?> providerEventId = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                required String title,
                required DateTime startUtc,
                required DateTime endUtc,
                Value<String> timeZoneId = const Value.absent(),
                Value<bool> allDay = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> recurrenceRule = const Value.absent(),
                Value<String?> recurrenceId = const Value.absent(),
                Value<ResponseStatus> myResponse = const Value.absent(),
                Value<ShowAs> showAs = const Value.absent(),
                Value<EventVisibility> visibility = const Value.absent(),
                Value<EventStatus> status = const Value.absent(),
                Value<bool> deletedRemotely = const Value.absent(),
                Value<int?> colorOverride = const Value.absent(),
                Value<String?> mergedGroupId = const Value.absent(),
                Value<String?> webUrl = const Value.absent(),
                Value<String?> conferenceJson = const Value.absent(),
                Value<String?> attendeesJson = const Value.absent(),
                Value<String?> remindersJson = const Value.absent(),
                Value<String?> attachmentsJson = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventsCompanion.insert(
                id: id,
                calendarId: calendarId,
                accountId: accountId,
                providerEventId: providerEventId,
                etag: etag,
                title: title,
                startUtc: startUtc,
                endUtc: endUtc,
                timeZoneId: timeZoneId,
                allDay: allDay,
                location: location,
                description: description,
                recurrenceRule: recurrenceRule,
                recurrenceId: recurrenceId,
                myResponse: myResponse,
                showAs: showAs,
                visibility: visibility,
                status: status,
                deletedRemotely: deletedRemotely,
                colorOverride: colorOverride,
                mergedGroupId: mergedGroupId,
                webUrl: webUrl,
                conferenceJson: conferenceJson,
                attendeesJson: attendeesJson,
                remindersJson: remindersJson,
                attachmentsJson: attachmentsJson,
                dirty: dirty,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$EventsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({calendarId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (calendarId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.calendarId,
                                referencedTable: $$EventsTableReferences
                                    ._calendarIdTable(db),
                                referencedColumn: $$EventsTableReferences
                                    ._calendarIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EventsTable,
      Event,
      $$EventsTableFilterComposer,
      $$EventsTableOrderingComposer,
      $$EventsTableAnnotationComposer,
      $$EventsTableCreateCompanionBuilder,
      $$EventsTableUpdateCompanionBuilder,
      (Event, $$EventsTableReferences),
      Event,
      PrefetchHooks Function({bool calendarId})
    >;
typedef $$OutboxTableCreateCompanionBuilder =
    OutboxCompanion Function({
      Value<int> id,
      required String op,
      required String eventId,
      Value<String> payloadJson,
      Value<int> retryCount,
      required DateTime createdAt,
    });
typedef $$OutboxTableUpdateCompanionBuilder =
    OutboxCompanion Function({
      Value<int> id,
      Value<String> op,
      Value<String> eventId,
      Value<String> payloadJson,
      Value<int> retryCount,
      Value<DateTime> createdAt,
    });

class $$OutboxTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxTable,
          OutboxData,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
          OutboxData,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> op = const Value.absent(),
                Value<String> eventId = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => OutboxCompanion(
                id: id,
                op: op,
                eventId: eventId,
                payloadJson: payloadJson,
                retryCount: retryCount,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String op,
                required String eventId,
                Value<String> payloadJson = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                required DateTime createdAt,
              }) => OutboxCompanion.insert(
                id: id,
                op: op,
                eventId: eventId,
                payloadJson: payloadJson,
                retryCount: retryCount,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxTable,
      OutboxData,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
      OutboxData,
      PrefetchHooks Function()
    >;
typedef $$ContactsTableCreateCompanionBuilder =
    ContactsCompanion Function({
      required String id,
      required String displayName,
      required String email,
      Value<String> source,
      Value<int> useCount,
      Value<int> rowid,
    });
typedef $$ContactsTableUpdateCompanionBuilder =
    ContactsCompanion Function({
      Value<String> id,
      Value<String> displayName,
      Value<String> email,
      Value<String> source,
      Value<int> useCount,
      Value<int> rowid,
    });

class $$ContactsTableFilterComposer
    extends Composer<_$AppDatabase, $ContactsTable> {
  $$ContactsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get useCount => $composableBuilder(
    column: $table.useCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContactsTableOrderingComposer
    extends Composer<_$AppDatabase, $ContactsTable> {
  $$ContactsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get useCount => $composableBuilder(
    column: $table.useCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContactsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContactsTable> {
  $$ContactsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get useCount =>
      $composableBuilder(column: $table.useCount, builder: (column) => column);
}

class $$ContactsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContactsTable,
          ContactRow,
          $$ContactsTableFilterComposer,
          $$ContactsTableOrderingComposer,
          $$ContactsTableAnnotationComposer,
          $$ContactsTableCreateCompanionBuilder,
          $$ContactsTableUpdateCompanionBuilder,
          (
            ContactRow,
            BaseReferences<_$AppDatabase, $ContactsTable, ContactRow>,
          ),
          ContactRow,
          PrefetchHooks Function()
        > {
  $$ContactsTableTableManager(_$AppDatabase db, $ContactsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContactsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContactsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContactsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> useCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContactsCompanion(
                id: id,
                displayName: displayName,
                email: email,
                source: source,
                useCount: useCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String displayName,
                required String email,
                Value<String> source = const Value.absent(),
                Value<int> useCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContactsCompanion.insert(
                id: id,
                displayName: displayName,
                email: email,
                source: source,
                useCount: useCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContactsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContactsTable,
      ContactRow,
      $$ContactsTableFilterComposer,
      $$ContactsTableOrderingComposer,
      $$ContactsTableAnnotationComposer,
      $$ContactsTableCreateCompanionBuilder,
      $$ContactsTableUpdateCompanionBuilder,
      (ContactRow, BaseReferences<_$AppDatabase, $ContactsTable, ContactRow>),
      ContactRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$CalendarsTableTableManager get calendars =>
      $$CalendarsTableTableManager(_db, _db.calendars);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db, _db.events);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$ContactsTableTableManager get contacts =>
      $$ContactsTableTableManager(_db, _db.contacts);
}
