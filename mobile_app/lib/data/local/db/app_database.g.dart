// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CategoryGroupsTable extends CategoryGroups
    with TableInfo<$CategoryGroupsTable, CategoryGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoryGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _sortMeta = const VerificationMeta('sort');
  @override
  late final GeneratedColumn<int> sort = GeneratedColumn<int>(
    'sort',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isIncomeMeta = const VerificationMeta(
    'isIncome',
  );
  @override
  late final GeneratedColumn<bool> isIncome = GeneratedColumn<bool>(
    'is_income',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_income" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _presetKeyMeta = const VerificationMeta(
    'presetKey',
  );
  @override
  late final GeneratedColumn<String> presetKey = GeneratedColumn<String>(
    'preset_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
    'hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    sort,
    isIncome,
    source,
    presetKey,
    hidden,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'category_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryGroup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort')) {
      context.handle(
        _sortMeta,
        sort.isAcceptableOrUnknown(data['sort']!, _sortMeta),
      );
    } else if (isInserting) {
      context.missing(_sortMeta);
    }
    if (data.containsKey('is_income')) {
      context.handle(
        _isIncomeMeta,
        isIncome.isAcceptableOrUnknown(data['is_income']!, _isIncomeMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('preset_key')) {
      context.handle(
        _presetKeyMeta,
        presetKey.isAcceptableOrUnknown(data['preset_key']!, _presetKeyMeta),
      );
    }
    if (data.containsKey('hidden')) {
      context.handle(
        _hiddenMeta,
        hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CategoryGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryGroup(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort'],
      )!,
      isIncome: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_income'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      presetKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preset_key'],
      ),
      hidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hidden'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CategoryGroupsTable createAlias(String alias) {
    return $CategoryGroupsTable(attachedDatabase, alias);
  }
}

class CategoryGroup extends DataClass implements Insertable<CategoryGroup> {
  final String id;
  final String name;
  final int sort;
  final bool isIncome;
  final String source;
  final String? presetKey;
  final bool hidden;
  final int updatedAt;
  const CategoryGroup({
    required this.id,
    required this.name,
    required this.sort,
    required this.isIncome,
    required this.source,
    this.presetKey,
    required this.hidden,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['sort'] = Variable<int>(sort);
    map['is_income'] = Variable<bool>(isIncome);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || presetKey != null) {
      map['preset_key'] = Variable<String>(presetKey);
    }
    map['hidden'] = Variable<bool>(hidden);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  CategoryGroupsCompanion toCompanion(bool nullToAbsent) {
    return CategoryGroupsCompanion(
      id: Value(id),
      name: Value(name),
      sort: Value(sort),
      isIncome: Value(isIncome),
      source: Value(source),
      presetKey: presetKey == null && nullToAbsent
          ? const Value.absent()
          : Value(presetKey),
      hidden: Value(hidden),
      updatedAt: Value(updatedAt),
    );
  }

  factory CategoryGroup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryGroup(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sort: serializer.fromJson<int>(json['sort']),
      isIncome: serializer.fromJson<bool>(json['isIncome']),
      source: serializer.fromJson<String>(json['source']),
      presetKey: serializer.fromJson<String?>(json['presetKey']),
      hidden: serializer.fromJson<bool>(json['hidden']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'sort': serializer.toJson<int>(sort),
      'isIncome': serializer.toJson<bool>(isIncome),
      'source': serializer.toJson<String>(source),
      'presetKey': serializer.toJson<String?>(presetKey),
      'hidden': serializer.toJson<bool>(hidden),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  CategoryGroup copyWith({
    String? id,
    String? name,
    int? sort,
    bool? isIncome,
    String? source,
    Value<String?> presetKey = const Value.absent(),
    bool? hidden,
    int? updatedAt,
  }) => CategoryGroup(
    id: id ?? this.id,
    name: name ?? this.name,
    sort: sort ?? this.sort,
    isIncome: isIncome ?? this.isIncome,
    source: source ?? this.source,
    presetKey: presetKey.present ? presetKey.value : this.presetKey,
    hidden: hidden ?? this.hidden,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CategoryGroup copyWithCompanion(CategoryGroupsCompanion data) {
    return CategoryGroup(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sort: data.sort.present ? data.sort.value : this.sort,
      isIncome: data.isIncome.present ? data.isIncome.value : this.isIncome,
      source: data.source.present ? data.source.value : this.source,
      presetKey: data.presetKey.present ? data.presetKey.value : this.presetKey,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryGroup(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sort: $sort, ')
          ..write('isIncome: $isIncome, ')
          ..write('source: $source, ')
          ..write('presetKey: $presetKey, ')
          ..write('hidden: $hidden, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    sort,
    isIncome,
    source,
    presetKey,
    hidden,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryGroup &&
          other.id == this.id &&
          other.name == this.name &&
          other.sort == this.sort &&
          other.isIncome == this.isIncome &&
          other.source == this.source &&
          other.presetKey == this.presetKey &&
          other.hidden == this.hidden &&
          other.updatedAt == this.updatedAt);
}

class CategoryGroupsCompanion extends UpdateCompanion<CategoryGroup> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> sort;
  final Value<bool> isIncome;
  final Value<String> source;
  final Value<String?> presetKey;
  final Value<bool> hidden;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const CategoryGroupsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sort = const Value.absent(),
    this.isIncome = const Value.absent(),
    this.source = const Value.absent(),
    this.presetKey = const Value.absent(),
    this.hidden = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoryGroupsCompanion.insert({
    required String id,
    required String name,
    required int sort,
    this.isIncome = const Value.absent(),
    required String source,
    this.presetKey = const Value.absent(),
    this.hidden = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       sort = Value(sort),
       source = Value(source),
       updatedAt = Value(updatedAt);
  static Insertable<CategoryGroup> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? sort,
    Expression<bool>? isIncome,
    Expression<String>? source,
    Expression<String>? presetKey,
    Expression<bool>? hidden,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sort != null) 'sort': sort,
      if (isIncome != null) 'is_income': isIncome,
      if (source != null) 'source': source,
      if (presetKey != null) 'preset_key': presetKey,
      if (hidden != null) 'hidden': hidden,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoryGroupsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? sort,
    Value<bool>? isIncome,
    Value<String>? source,
    Value<String?>? presetKey,
    Value<bool>? hidden,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return CategoryGroupsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      sort: sort ?? this.sort,
      isIncome: isIncome ?? this.isIncome,
      source: source ?? this.source,
      presetKey: presetKey ?? this.presetKey,
      hidden: hidden ?? this.hidden,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sort.present) {
      map['sort'] = Variable<int>(sort.value);
    }
    if (isIncome.present) {
      map['is_income'] = Variable<bool>(isIncome.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (presetKey.present) {
      map['preset_key'] = Variable<String>(presetKey.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoryGroupsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sort: $sort, ')
          ..write('isIncome: $isIncome, ')
          ..write('source: $source, ')
          ..write('presetKey: $presetKey, ')
          ..write('hidden: $hidden, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES category_groups (id)',
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
  static const VerificationMeta _sortMeta = const VerificationMeta('sort');
  @override
  late final GeneratedColumn<int> sort = GeneratedColumn<int>(
    'sort',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _presetKeyMeta = const VerificationMeta(
    'presetKey',
  );
  @override
  late final GeneratedColumn<String> presetKey = GeneratedColumn<String>(
    'preset_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
    'hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    groupId,
    name,
    sort,
    source,
    presetKey,
    hidden,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort')) {
      context.handle(
        _sortMeta,
        sort.isAcceptableOrUnknown(data['sort']!, _sortMeta),
      );
    } else if (isInserting) {
      context.missing(_sortMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('preset_key')) {
      context.handle(
        _presetKeyMeta,
        presetKey.isAcceptableOrUnknown(data['preset_key']!, _presetKeyMeta),
      );
    }
    if (data.containsKey('hidden')) {
      context.handle(
        _hiddenMeta,
        hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      presetKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preset_key'],
      ),
      hidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hidden'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final String id;
  final String groupId;
  final String name;
  final int sort;
  final String source;
  final String? presetKey;
  final bool hidden;
  final int updatedAt;
  const Category({
    required this.id,
    required this.groupId,
    required this.name,
    required this.sort,
    required this.source,
    this.presetKey,
    required this.hidden,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    map['name'] = Variable<String>(name);
    map['sort'] = Variable<int>(sort);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || presetKey != null) {
      map['preset_key'] = Variable<String>(presetKey);
    }
    map['hidden'] = Variable<bool>(hidden);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      groupId: Value(groupId),
      name: Value(name),
      sort: Value(sort),
      source: Value(source),
      presetKey: presetKey == null && nullToAbsent
          ? const Value.absent()
          : Value(presetKey),
      hidden: Value(hidden),
      updatedAt: Value(updatedAt),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      name: serializer.fromJson<String>(json['name']),
      sort: serializer.fromJson<int>(json['sort']),
      source: serializer.fromJson<String>(json['source']),
      presetKey: serializer.fromJson<String?>(json['presetKey']),
      hidden: serializer.fromJson<bool>(json['hidden']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'name': serializer.toJson<String>(name),
      'sort': serializer.toJson<int>(sort),
      'source': serializer.toJson<String>(source),
      'presetKey': serializer.toJson<String?>(presetKey),
      'hidden': serializer.toJson<bool>(hidden),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  Category copyWith({
    String? id,
    String? groupId,
    String? name,
    int? sort,
    String? source,
    Value<String?> presetKey = const Value.absent(),
    bool? hidden,
    int? updatedAt,
  }) => Category(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    name: name ?? this.name,
    sort: sort ?? this.sort,
    source: source ?? this.source,
    presetKey: presetKey.present ? presetKey.value : this.presetKey,
    hidden: hidden ?? this.hidden,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      name: data.name.present ? data.name.value : this.name,
      sort: data.sort.present ? data.sort.value : this.sort,
      source: data.source.present ? data.source.value : this.source,
      presetKey: data.presetKey.present ? data.presetKey.value : this.presetKey,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('name: $name, ')
          ..write('sort: $sort, ')
          ..write('source: $source, ')
          ..write('presetKey: $presetKey, ')
          ..write('hidden: $hidden, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    groupId,
    name,
    sort,
    source,
    presetKey,
    hidden,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.name == this.name &&
          other.sort == this.sort &&
          other.source == this.source &&
          other.presetKey == this.presetKey &&
          other.hidden == this.hidden &&
          other.updatedAt == this.updatedAt);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<String> name;
  final Value<int> sort;
  final Value<String> source;
  final Value<String?> presetKey;
  final Value<bool> hidden;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.name = const Value.absent(),
    this.sort = const Value.absent(),
    this.source = const Value.absent(),
    this.presetKey = const Value.absent(),
    this.hidden = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    required String groupId,
    required String name,
    required int sort,
    required String source,
    this.presetKey = const Value.absent(),
    this.hidden = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       groupId = Value(groupId),
       name = Value(name),
       sort = Value(sort),
       source = Value(source),
       updatedAt = Value(updatedAt);
  static Insertable<Category> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<String>? name,
    Expression<int>? sort,
    Expression<String>? source,
    Expression<String>? presetKey,
    Expression<bool>? hidden,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (name != null) 'name': name,
      if (sort != null) 'sort': sort,
      if (source != null) 'source': source,
      if (presetKey != null) 'preset_key': presetKey,
      if (hidden != null) 'hidden': hidden,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? groupId,
    Value<String>? name,
    Value<int>? sort,
    Value<String>? source,
    Value<String?>? presetKey,
    Value<bool>? hidden,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      sort: sort ?? this.sort,
      source: source ?? this.source,
      presetKey: presetKey ?? this.presetKey,
      hidden: hidden ?? this.hidden,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sort.present) {
      map['sort'] = Variable<int>(sort.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (presetKey.present) {
      map['preset_key'] = Variable<String>(presetKey.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('name: $name, ')
          ..write('sort: $sort, ')
          ..write('source: $source, ')
          ..write('presetKey: $presetKey, ')
          ..write('hidden: $hidden, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoryLinksTable extends CategoryLinks
    with TableInfo<$CategoryLinksTable, CategoryLink> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoryLinksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _budgetSyncIdMeta = const VerificationMeta(
    'budgetSyncId',
  );
  @override
  late final GeneratedColumn<String> budgetSyncId = GeneratedColumn<String>(
    'budget_sync_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actualCategoryIdMeta = const VerificationMeta(
    'actualCategoryId',
  );
  @override
  late final GeneratedColumn<String> actualCategoryId = GeneratedColumn<String>(
    'actual_category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    categoryId,
    budgetSyncId,
    actualCategoryId,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'category_links';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryLink> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('budget_sync_id')) {
      context.handle(
        _budgetSyncIdMeta,
        budgetSyncId.isAcceptableOrUnknown(
          data['budget_sync_id']!,
          _budgetSyncIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_budgetSyncIdMeta);
    }
    if (data.containsKey('actual_category_id')) {
      context.handle(
        _actualCategoryIdMeta,
        actualCategoryId.isAcceptableOrUnknown(
          data['actual_category_id']!,
          _actualCategoryIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_actualCategoryIdMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {categoryId, budgetSyncId};
  @override
  CategoryLink map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryLink(
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      budgetSyncId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}budget_sync_id'],
      )!,
      actualCategoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actual_category_id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CategoryLinksTable createAlias(String alias) {
    return $CategoryLinksTable(attachedDatabase, alias);
  }
}

class CategoryLink extends DataClass implements Insertable<CategoryLink> {
  final String categoryId;
  final String budgetSyncId;
  final String actualCategoryId;

  /// Epoch ms, for the sync (schema 2; 0 for links made before).
  final int updatedAt;
  const CategoryLink({
    required this.categoryId,
    required this.budgetSyncId,
    required this.actualCategoryId,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['category_id'] = Variable<String>(categoryId);
    map['budget_sync_id'] = Variable<String>(budgetSyncId);
    map['actual_category_id'] = Variable<String>(actualCategoryId);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  CategoryLinksCompanion toCompanion(bool nullToAbsent) {
    return CategoryLinksCompanion(
      categoryId: Value(categoryId),
      budgetSyncId: Value(budgetSyncId),
      actualCategoryId: Value(actualCategoryId),
      updatedAt: Value(updatedAt),
    );
  }

  factory CategoryLink.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryLink(
      categoryId: serializer.fromJson<String>(json['categoryId']),
      budgetSyncId: serializer.fromJson<String>(json['budgetSyncId']),
      actualCategoryId: serializer.fromJson<String>(json['actualCategoryId']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'categoryId': serializer.toJson<String>(categoryId),
      'budgetSyncId': serializer.toJson<String>(budgetSyncId),
      'actualCategoryId': serializer.toJson<String>(actualCategoryId),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  CategoryLink copyWith({
    String? categoryId,
    String? budgetSyncId,
    String? actualCategoryId,
    int? updatedAt,
  }) => CategoryLink(
    categoryId: categoryId ?? this.categoryId,
    budgetSyncId: budgetSyncId ?? this.budgetSyncId,
    actualCategoryId: actualCategoryId ?? this.actualCategoryId,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CategoryLink copyWithCompanion(CategoryLinksCompanion data) {
    return CategoryLink(
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      budgetSyncId: data.budgetSyncId.present
          ? data.budgetSyncId.value
          : this.budgetSyncId,
      actualCategoryId: data.actualCategoryId.present
          ? data.actualCategoryId.value
          : this.actualCategoryId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryLink(')
          ..write('categoryId: $categoryId, ')
          ..write('budgetSyncId: $budgetSyncId, ')
          ..write('actualCategoryId: $actualCategoryId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(categoryId, budgetSyncId, actualCategoryId, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryLink &&
          other.categoryId == this.categoryId &&
          other.budgetSyncId == this.budgetSyncId &&
          other.actualCategoryId == this.actualCategoryId &&
          other.updatedAt == this.updatedAt);
}

class CategoryLinksCompanion extends UpdateCompanion<CategoryLink> {
  final Value<String> categoryId;
  final Value<String> budgetSyncId;
  final Value<String> actualCategoryId;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const CategoryLinksCompanion({
    this.categoryId = const Value.absent(),
    this.budgetSyncId = const Value.absent(),
    this.actualCategoryId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoryLinksCompanion.insert({
    required String categoryId,
    required String budgetSyncId,
    required String actualCategoryId,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : categoryId = Value(categoryId),
       budgetSyncId = Value(budgetSyncId),
       actualCategoryId = Value(actualCategoryId);
  static Insertable<CategoryLink> custom({
    Expression<String>? categoryId,
    Expression<String>? budgetSyncId,
    Expression<String>? actualCategoryId,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (categoryId != null) 'category_id': categoryId,
      if (budgetSyncId != null) 'budget_sync_id': budgetSyncId,
      if (actualCategoryId != null) 'actual_category_id': actualCategoryId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoryLinksCompanion copyWith({
    Value<String>? categoryId,
    Value<String>? budgetSyncId,
    Value<String>? actualCategoryId,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return CategoryLinksCompanion(
      categoryId: categoryId ?? this.categoryId,
      budgetSyncId: budgetSyncId ?? this.budgetSyncId,
      actualCategoryId: actualCategoryId ?? this.actualCategoryId,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (budgetSyncId.present) {
      map['budget_sync_id'] = Variable<String>(budgetSyncId.value);
    }
    if (actualCategoryId.present) {
      map['actual_category_id'] = Variable<String>(actualCategoryId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoryLinksCompanion(')
          ..write('categoryId: $categoryId, ')
          ..write('budgetSyncId: $budgetSyncId, ')
          ..write('actualCategoryId: $actualCategoryId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PayeeCategoriesTable extends PayeeCategories
    with TableInfo<$PayeeCategoriesTable, PayeeCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PayeeCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _budgetSyncIdMeta = const VerificationMeta(
    'budgetSyncId',
  );
  @override
  late final GeneratedColumn<String> budgetSyncId = GeneratedColumn<String>(
    'budget_sync_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payeeKeyMeta = const VerificationMeta(
    'payeeKey',
  );
  @override
  late final GeneratedColumn<String> payeeKey = GeneratedColumn<String>(
    'payee_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payeeLabelMeta = const VerificationMeta(
    'payeeLabel',
  );
  @override
  late final GeneratedColumn<String> payeeLabel = GeneratedColumn<String>(
    'payee_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    budgetSyncId,
    payeeKey,
    payeeLabel,
    categoryId,
    updatedAt,
    deleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payee_categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<PayeeCategory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('budget_sync_id')) {
      context.handle(
        _budgetSyncIdMeta,
        budgetSyncId.isAcceptableOrUnknown(
          data['budget_sync_id']!,
          _budgetSyncIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_budgetSyncIdMeta);
    }
    if (data.containsKey('payee_key')) {
      context.handle(
        _payeeKeyMeta,
        payeeKey.isAcceptableOrUnknown(data['payee_key']!, _payeeKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_payeeKeyMeta);
    }
    if (data.containsKey('payee_label')) {
      context.handle(
        _payeeLabelMeta,
        payeeLabel.isAcceptableOrUnknown(data['payee_label']!, _payeeLabelMeta),
      );
    } else if (isInserting) {
      context.missing(_payeeLabelMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {budgetSyncId, payeeKey};
  @override
  PayeeCategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PayeeCategory(
      budgetSyncId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}budget_sync_id'],
      )!,
      payeeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payee_key'],
      )!,
      payeeLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payee_label'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
    );
  }

  @override
  $PayeeCategoriesTable createAlias(String alias) {
    return $PayeeCategoriesTable(attachedDatabase, alias);
  }
}

class PayeeCategory extends DataClass implements Insertable<PayeeCategory> {
  final String budgetSyncId;
  final String payeeKey;
  final String payeeLabel;
  final String categoryId;
  final int updatedAt;
  final bool deleted;
  const PayeeCategory({
    required this.budgetSyncId,
    required this.payeeKey,
    required this.payeeLabel,
    required this.categoryId,
    required this.updatedAt,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['budget_sync_id'] = Variable<String>(budgetSyncId);
    map['payee_key'] = Variable<String>(payeeKey);
    map['payee_label'] = Variable<String>(payeeLabel);
    map['category_id'] = Variable<String>(categoryId);
    map['updated_at'] = Variable<int>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  PayeeCategoriesCompanion toCompanion(bool nullToAbsent) {
    return PayeeCategoriesCompanion(
      budgetSyncId: Value(budgetSyncId),
      payeeKey: Value(payeeKey),
      payeeLabel: Value(payeeLabel),
      categoryId: Value(categoryId),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
    );
  }

  factory PayeeCategory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PayeeCategory(
      budgetSyncId: serializer.fromJson<String>(json['budgetSyncId']),
      payeeKey: serializer.fromJson<String>(json['payeeKey']),
      payeeLabel: serializer.fromJson<String>(json['payeeLabel']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'budgetSyncId': serializer.toJson<String>(budgetSyncId),
      'payeeKey': serializer.toJson<String>(payeeKey),
      'payeeLabel': serializer.toJson<String>(payeeLabel),
      'categoryId': serializer.toJson<String>(categoryId),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  PayeeCategory copyWith({
    String? budgetSyncId,
    String? payeeKey,
    String? payeeLabel,
    String? categoryId,
    int? updatedAt,
    bool? deleted,
  }) => PayeeCategory(
    budgetSyncId: budgetSyncId ?? this.budgetSyncId,
    payeeKey: payeeKey ?? this.payeeKey,
    payeeLabel: payeeLabel ?? this.payeeLabel,
    categoryId: categoryId ?? this.categoryId,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
  );
  PayeeCategory copyWithCompanion(PayeeCategoriesCompanion data) {
    return PayeeCategory(
      budgetSyncId: data.budgetSyncId.present
          ? data.budgetSyncId.value
          : this.budgetSyncId,
      payeeKey: data.payeeKey.present ? data.payeeKey.value : this.payeeKey,
      payeeLabel: data.payeeLabel.present
          ? data.payeeLabel.value
          : this.payeeLabel,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PayeeCategory(')
          ..write('budgetSyncId: $budgetSyncId, ')
          ..write('payeeKey: $payeeKey, ')
          ..write('payeeLabel: $payeeLabel, ')
          ..write('categoryId: $categoryId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    budgetSyncId,
    payeeKey,
    payeeLabel,
    categoryId,
    updatedAt,
    deleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PayeeCategory &&
          other.budgetSyncId == this.budgetSyncId &&
          other.payeeKey == this.payeeKey &&
          other.payeeLabel == this.payeeLabel &&
          other.categoryId == this.categoryId &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted);
}

class PayeeCategoriesCompanion extends UpdateCompanion<PayeeCategory> {
  final Value<String> budgetSyncId;
  final Value<String> payeeKey;
  final Value<String> payeeLabel;
  final Value<String> categoryId;
  final Value<int> updatedAt;
  final Value<bool> deleted;
  final Value<int> rowid;
  const PayeeCategoriesCompanion({
    this.budgetSyncId = const Value.absent(),
    this.payeeKey = const Value.absent(),
    this.payeeLabel = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PayeeCategoriesCompanion.insert({
    required String budgetSyncId,
    required String payeeKey,
    required String payeeLabel,
    required String categoryId,
    required int updatedAt,
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : budgetSyncId = Value(budgetSyncId),
       payeeKey = Value(payeeKey),
       payeeLabel = Value(payeeLabel),
       categoryId = Value(categoryId),
       updatedAt = Value(updatedAt);
  static Insertable<PayeeCategory> custom({
    Expression<String>? budgetSyncId,
    Expression<String>? payeeKey,
    Expression<String>? payeeLabel,
    Expression<String>? categoryId,
    Expression<int>? updatedAt,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (budgetSyncId != null) 'budget_sync_id': budgetSyncId,
      if (payeeKey != null) 'payee_key': payeeKey,
      if (payeeLabel != null) 'payee_label': payeeLabel,
      if (categoryId != null) 'category_id': categoryId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PayeeCategoriesCompanion copyWith({
    Value<String>? budgetSyncId,
    Value<String>? payeeKey,
    Value<String>? payeeLabel,
    Value<String>? categoryId,
    Value<int>? updatedAt,
    Value<bool>? deleted,
    Value<int>? rowid,
  }) {
    return PayeeCategoriesCompanion(
      budgetSyncId: budgetSyncId ?? this.budgetSyncId,
      payeeKey: payeeKey ?? this.payeeKey,
      payeeLabel: payeeLabel ?? this.payeeLabel,
      categoryId: categoryId ?? this.categoryId,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (budgetSyncId.present) {
      map['budget_sync_id'] = Variable<String>(budgetSyncId.value);
    }
    if (payeeKey.present) {
      map['payee_key'] = Variable<String>(payeeKey.value);
    }
    if (payeeLabel.present) {
      map['payee_label'] = Variable<String>(payeeLabel.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PayeeCategoriesCompanion(')
          ..write('budgetSyncId: $budgetSyncId, ')
          ..write('payeeKey: $payeeKey, ')
          ..write('payeeLabel: $payeeLabel, ')
          ..write('categoryId: $categoryId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CategoryGroupsTable categoryGroups = $CategoryGroupsTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $CategoryLinksTable categoryLinks = $CategoryLinksTable(this);
  late final $PayeeCategoriesTable payeeCategories = $PayeeCategoriesTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    categoryGroups,
    categories,
    categoryLinks,
    payeeCategories,
  ];
}

typedef $$CategoryGroupsTableCreateCompanionBuilder =
    CategoryGroupsCompanion Function({
      required String id,
      required String name,
      required int sort,
      Value<bool> isIncome,
      required String source,
      Value<String?> presetKey,
      Value<bool> hidden,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$CategoryGroupsTableUpdateCompanionBuilder =
    CategoryGroupsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> sort,
      Value<bool> isIncome,
      Value<String> source,
      Value<String?> presetKey,
      Value<bool> hidden,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$CategoryGroupsTableReferences
    extends BaseReferences<_$AppDatabase, $CategoryGroupsTable, CategoryGroup> {
  $$CategoryGroupsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$CategoriesTable, List<Category>>
  _categoriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.categories,
    aliasName: 'category_groups__id__categories__group_id',
  );

  $$CategoriesTableProcessedTableManager get categoriesRefs {
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_categoriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CategoryGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $CategoryGroupsTable> {
  $$CategoryGroupsTableFilterComposer({
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

  ColumnFilters<int> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isIncome => $composableBuilder(
    column: $table.isIncome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get presetKey => $composableBuilder(
    column: $table.presetKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> categoriesRefs(
    Expression<bool> Function($$CategoriesTableFilterComposer f) f,
  ) {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoryGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoryGroupsTable> {
  $$CategoryGroupsTableOrderingComposer({
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

  ColumnOrderings<int> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isIncome => $composableBuilder(
    column: $table.isIncome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get presetKey => $composableBuilder(
    column: $table.presetKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoryGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoryGroupsTable> {
  $$CategoryGroupsTableAnnotationComposer({
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

  GeneratedColumn<int> get sort =>
      $composableBuilder(column: $table.sort, builder: (column) => column);

  GeneratedColumn<bool> get isIncome =>
      $composableBuilder(column: $table.isIncome, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get presetKey =>
      $composableBuilder(column: $table.presetKey, builder: (column) => column);

  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> categoriesRefs<T extends Object>(
    Expression<T> Function($$CategoriesTableAnnotationComposer a) f,
  ) {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoryGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoryGroupsTable,
          CategoryGroup,
          $$CategoryGroupsTableFilterComposer,
          $$CategoryGroupsTableOrderingComposer,
          $$CategoryGroupsTableAnnotationComposer,
          $$CategoryGroupsTableCreateCompanionBuilder,
          $$CategoryGroupsTableUpdateCompanionBuilder,
          (CategoryGroup, $$CategoryGroupsTableReferences),
          CategoryGroup,
          PrefetchHooks Function({bool categoriesRefs})
        > {
  $$CategoryGroupsTableTableManager(
    _$AppDatabase db,
    $CategoryGroupsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoryGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoryGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoryGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sort = const Value.absent(),
                Value<bool> isIncome = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> presetKey = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoryGroupsCompanion(
                id: id,
                name: name,
                sort: sort,
                isIncome: isIncome,
                source: source,
                presetKey: presetKey,
                hidden: hidden,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int sort,
                Value<bool> isIncome = const Value.absent(),
                required String source,
                Value<String?> presetKey = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CategoryGroupsCompanion.insert(
                id: id,
                name: name,
                sort: sort,
                isIncome: isIncome,
                source: source,
                presetKey: presetKey,
                hidden: hidden,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoryGroupsTable, CategoryGroup>(table),
                  $$CategoryGroupsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (categoriesRefs) db.categories],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (categoriesRefs)
                    await $_getPrefetchedDataByColumns<
                      CategoryGroup,
                      $CategoryGroupsTable,
                      Category,
                      $CategoriesTable
                    >(
                      currentTable: table,
                      referencedTable: $$CategoryGroupsTableReferences
                          ._categoriesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CategoryGroupsTableReferences(
                            db,
                            table,
                            p0,
                          ).categoriesRefs,
                      currentColumn: 'id',
                      referencedColumn: 'group_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CategoryGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoryGroupsTable,
      CategoryGroup,
      $$CategoryGroupsTableFilterComposer,
      $$CategoryGroupsTableOrderingComposer,
      $$CategoryGroupsTableAnnotationComposer,
      $$CategoryGroupsTableCreateCompanionBuilder,
      $$CategoryGroupsTableUpdateCompanionBuilder,
      (CategoryGroup, $$CategoryGroupsTableReferences),
      CategoryGroup,
      PrefetchHooks Function({bool categoriesRefs})
    >;
typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  required String id,
  required String groupId,
  required String name,
  required int sort,
  required String source,
  Value<String?> presetKey,
  Value<bool> hidden,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<String> id,
  Value<String> groupId,
  Value<String> name,
  Value<int> sort,
  Value<String> source,
  Value<String?> presetKey,
  Value<bool> hidden,
  Value<int> updatedAt,
  Value<int> rowid,
});

final class $$CategoriesTableReferences
    extends BaseReferences<_$AppDatabase, $CategoriesTable, Category> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoryGroupsTable _groupIdTable(_$AppDatabase db) => db
      .categoryGroups
      .createAlias('categories__group_id__category_groups__id');

  $$CategoryGroupsTableProcessedTableManager get groupId {
    final $_column = $_itemColumn<String>('group_id')!;

    final manager = $$CategoryGroupsTableTableManager(
      $_db,
      $_db.categoryGroups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$CategoryLinksTable, List<CategoryLink>>
  _categoryLinksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.categoryLinks,
    aliasName: 'categories__id__category_links__category_id',
  );

  $$CategoryLinksTableProcessedTableManager get categoryLinksRefs {
    final manager = $$CategoryLinksTableTableManager(
      $_db,
      $_db.categoryLinks,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_categoryLinksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PayeeCategoriesTable, List<PayeeCategory>>
  _payeeCategoriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.payeeCategories,
    aliasName: 'categories__id__payee_categories__category_id',
  );

  $$PayeeCategoriesTableProcessedTableManager get payeeCategoriesRefs {
    final manager = $$PayeeCategoriesTableTableManager(
      $_db,
      $_db.payeeCategories,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _payeeCategoriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
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

  ColumnFilters<int> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get presetKey => $composableBuilder(
    column: $table.presetKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoryGroupsTableFilterComposer get groupId {
    final $$CategoryGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.categoryGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryGroupsTableFilterComposer(
            $db: $db,
            $table: $db.categoryGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> categoryLinksRefs(
    Expression<bool> Function($$CategoryLinksTableFilterComposer f) f,
  ) {
    final $$CategoryLinksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.categoryLinks,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryLinksTableFilterComposer(
            $db: $db,
            $table: $db.categoryLinks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> payeeCategoriesRefs(
    Expression<bool> Function($$PayeeCategoriesTableFilterComposer f) f,
  ) {
    final $$PayeeCategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payeeCategories,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayeeCategoriesTableFilterComposer(
            $db: $db,
            $table: $db.payeeCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
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

  ColumnOrderings<int> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get presetKey => $composableBuilder(
    column: $table.presetKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoryGroupsTableOrderingComposer get groupId {
    final $$CategoryGroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.categoryGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryGroupsTableOrderingComposer(
            $db: $db,
            $table: $db.categoryGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
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

  GeneratedColumn<int> get sort =>
      $composableBuilder(column: $table.sort, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get presetKey =>
      $composableBuilder(column: $table.presetKey, builder: (column) => column);

  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$CategoryGroupsTableAnnotationComposer get groupId {
    final $$CategoryGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.categoryGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.categoryGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> categoryLinksRefs<T extends Object>(
    Expression<T> Function($$CategoryLinksTableAnnotationComposer a) f,
  ) {
    final $$CategoryLinksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.categoryLinks,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryLinksTableAnnotationComposer(
            $db: $db,
            $table: $db.categoryLinks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> payeeCategoriesRefs<T extends Object>(
    Expression<T> Function($$PayeeCategoriesTableAnnotationComposer a) f,
  ) {
    final $$PayeeCategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payeeCategories,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayeeCategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.payeeCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (Category, $$CategoriesTableReferences),
          Category,
          PrefetchHooks Function({
            bool groupId,
            bool categoryLinksRefs,
            bool payeeCategoriesRefs,
          })
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sort = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> presetKey = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                groupId: groupId,
                name: name,
                sort: sort,
                source: source,
                presetKey: presetKey,
                hidden: hidden,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String groupId,
                required String name,
                required int sort,
                required String source,
                Value<String?> presetKey = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                groupId: groupId,
                name: name,
                sort: sort,
                source: source,
                presetKey: presetKey,
                hidden: hidden,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoriesTable, Category>(table),
                  $$CategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                groupId = false,
                categoryLinksRefs = false,
                payeeCategoriesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (categoryLinksRefs) db.categoryLinks,
                    if (payeeCategoriesRefs) db.payeeCategories,
                  ],
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
                        if (groupId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.groupId,
                            referencedTable: $$CategoriesTableReferences
                                ._groupIdTable(db),
                            referencedColumn: $$CategoriesTableReferences
                                ._groupIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (categoryLinksRefs)
                        await $_getPrefetchedDataByColumns<
                          Category,
                          $CategoriesTable,
                          CategoryLink,
                          $CategoryLinksTable
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._categoryLinksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).categoryLinksRefs,
                          currentColumn: 'id',
                          referencedColumn: 'category_id',
                          typedResults: items,
                        ),
                      if (payeeCategoriesRefs)
                        await $_getPrefetchedDataByColumns<
                          Category,
                          $CategoriesTable,
                          PayeeCategory,
                          $PayeeCategoriesTable
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._payeeCategoriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).payeeCategoriesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'category_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, $$CategoriesTableReferences),
      Category,
      PrefetchHooks Function({
        bool groupId,
        bool categoryLinksRefs,
        bool payeeCategoriesRefs,
      })
    >;
typedef $$CategoryLinksTableCreateCompanionBuilder =
    CategoryLinksCompanion Function({
      required String categoryId,
      required String budgetSyncId,
      required String actualCategoryId,
      Value<int> updatedAt,
      Value<int> rowid,
    });
typedef $$CategoryLinksTableUpdateCompanionBuilder =
    CategoryLinksCompanion Function({
      Value<String> categoryId,
      Value<String> budgetSyncId,
      Value<String> actualCategoryId,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$CategoryLinksTableReferences
    extends BaseReferences<_$AppDatabase, $CategoryLinksTable, CategoryLink> {
  $$CategoryLinksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias('category_links__category_id__categories__id');

  $$CategoriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<String>('category_id')!;

    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CategoryLinksTableFilterComposer
    extends Composer<_$AppDatabase, $CategoryLinksTable> {
  $$CategoryLinksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get budgetSyncId => $composableBuilder(
    column: $table.budgetSyncId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actualCategoryId => $composableBuilder(
    column: $table.actualCategoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategoryLinksTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoryLinksTable> {
  $$CategoryLinksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get budgetSyncId => $composableBuilder(
    column: $table.budgetSyncId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actualCategoryId => $composableBuilder(
    column: $table.actualCategoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategoryLinksTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoryLinksTable> {
  $$CategoryLinksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get budgetSyncId => $composableBuilder(
    column: $table.budgetSyncId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actualCategoryId => $composableBuilder(
    column: $table.actualCategoryId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategoryLinksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoryLinksTable,
          CategoryLink,
          $$CategoryLinksTableFilterComposer,
          $$CategoryLinksTableOrderingComposer,
          $$CategoryLinksTableAnnotationComposer,
          $$CategoryLinksTableCreateCompanionBuilder,
          $$CategoryLinksTableUpdateCompanionBuilder,
          (CategoryLink, $$CategoryLinksTableReferences),
          CategoryLink,
          PrefetchHooks Function({bool categoryId})
        > {
  $$CategoryLinksTableTableManager(_$AppDatabase db, $CategoryLinksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoryLinksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoryLinksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoryLinksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> categoryId = const Value.absent(),
                Value<String> budgetSyncId = const Value.absent(),
                Value<String> actualCategoryId = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoryLinksCompanion(
                categoryId: categoryId,
                budgetSyncId: budgetSyncId,
                actualCategoryId: actualCategoryId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String categoryId,
                required String budgetSyncId,
                required String actualCategoryId,
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoryLinksCompanion.insert(
                categoryId: categoryId,
                budgetSyncId: budgetSyncId,
                actualCategoryId: actualCategoryId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoryLinksTable, CategoryLink>(table),
                  $$CategoryLinksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false}) {
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
                    if (categoryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.categoryId,
                        referencedTable: $$CategoryLinksTableReferences
                            ._categoryIdTable(db),
                        referencedColumn: $$CategoryLinksTableReferences
                            ._categoryIdTable(db)
                            .id,
                      ) as T;
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

typedef $$CategoryLinksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoryLinksTable,
      CategoryLink,
      $$CategoryLinksTableFilterComposer,
      $$CategoryLinksTableOrderingComposer,
      $$CategoryLinksTableAnnotationComposer,
      $$CategoryLinksTableCreateCompanionBuilder,
      $$CategoryLinksTableUpdateCompanionBuilder,
      (CategoryLink, $$CategoryLinksTableReferences),
      CategoryLink,
      PrefetchHooks Function({bool categoryId})
    >;
typedef $$PayeeCategoriesTableCreateCompanionBuilder =
    PayeeCategoriesCompanion Function({
      required String budgetSyncId,
      required String payeeKey,
      required String payeeLabel,
      required String categoryId,
      required int updatedAt,
      Value<bool> deleted,
      Value<int> rowid,
    });
typedef $$PayeeCategoriesTableUpdateCompanionBuilder =
    PayeeCategoriesCompanion Function({
      Value<String> budgetSyncId,
      Value<String> payeeKey,
      Value<String> payeeLabel,
      Value<String> categoryId,
      Value<int> updatedAt,
      Value<bool> deleted,
      Value<int> rowid,
    });

final class $$PayeeCategoriesTableReferences
    extends
        BaseReferences<_$AppDatabase, $PayeeCategoriesTable, PayeeCategory> {
  $$PayeeCategoriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) => db.categories
      .createAlias('payee_categories__category_id__categories__id');

  $$CategoriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<String>('category_id')!;

    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PayeeCategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $PayeeCategoriesTable> {
  $$PayeeCategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get budgetSyncId => $composableBuilder(
    column: $table.budgetSyncId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payeeKey => $composableBuilder(
    column: $table.payeeKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payeeLabel => $composableBuilder(
    column: $table.payeeLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PayeeCategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $PayeeCategoriesTable> {
  $$PayeeCategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get budgetSyncId => $composableBuilder(
    column: $table.budgetSyncId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payeeKey => $composableBuilder(
    column: $table.payeeKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payeeLabel => $composableBuilder(
    column: $table.payeeLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PayeeCategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PayeeCategoriesTable> {
  $$PayeeCategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get budgetSyncId => $composableBuilder(
    column: $table.budgetSyncId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payeeKey =>
      $composableBuilder(column: $table.payeeKey, builder: (column) => column);

  GeneratedColumn<String> get payeeLabel => $composableBuilder(
    column: $table.payeeLabel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PayeeCategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PayeeCategoriesTable,
          PayeeCategory,
          $$PayeeCategoriesTableFilterComposer,
          $$PayeeCategoriesTableOrderingComposer,
          $$PayeeCategoriesTableAnnotationComposer,
          $$PayeeCategoriesTableCreateCompanionBuilder,
          $$PayeeCategoriesTableUpdateCompanionBuilder,
          (PayeeCategory, $$PayeeCategoriesTableReferences),
          PayeeCategory,
          PrefetchHooks Function({bool categoryId})
        > {
  $$PayeeCategoriesTableTableManager(
    _$AppDatabase db,
    $PayeeCategoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PayeeCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PayeeCategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PayeeCategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> budgetSyncId = const Value.absent(),
                Value<String> payeeKey = const Value.absent(),
                Value<String> payeeLabel = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PayeeCategoriesCompanion(
                budgetSyncId: budgetSyncId,
                payeeKey: payeeKey,
                payeeLabel: payeeLabel,
                categoryId: categoryId,
                updatedAt: updatedAt,
                deleted: deleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String budgetSyncId,
                required String payeeKey,
                required String payeeLabel,
                required String categoryId,
                required int updatedAt,
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PayeeCategoriesCompanion.insert(
                budgetSyncId: budgetSyncId,
                payeeKey: payeeKey,
                payeeLabel: payeeLabel,
                categoryId: categoryId,
                updatedAt: updatedAt,
                deleted: deleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PayeeCategoriesTable, PayeeCategory>(table),
                  $$PayeeCategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false}) {
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
                    if (categoryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.categoryId,
                        referencedTable: $$PayeeCategoriesTableReferences
                            ._categoryIdTable(db),
                        referencedColumn: $$PayeeCategoriesTableReferences
                            ._categoryIdTable(db)
                            .id,
                      ) as T;
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

typedef $$PayeeCategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PayeeCategoriesTable,
      PayeeCategory,
      $$PayeeCategoriesTableFilterComposer,
      $$PayeeCategoriesTableOrderingComposer,
      $$PayeeCategoriesTableAnnotationComposer,
      $$PayeeCategoriesTableCreateCompanionBuilder,
      $$PayeeCategoriesTableUpdateCompanionBuilder,
      (PayeeCategory, $$PayeeCategoriesTableReferences),
      PayeeCategory,
      PrefetchHooks Function({bool categoryId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CategoryGroupsTableTableManager get categoryGroups =>
      $$CategoryGroupsTableTableManager(_db, _db.categoryGroups);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$CategoryLinksTableTableManager get categoryLinks =>
      $$CategoryLinksTableTableManager(_db, _db.categoryLinks);
  $$PayeeCategoriesTableTableManager get payeeCategories =>
      $$PayeeCategoriesTableTableManager(_db, _db.payeeCategories);
}
