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

class $LedgerAccountsTable extends LedgerAccounts
    with TableInfo<$LedgerAccountsTable, LedgerAccount> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LedgerAccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
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
  static const VerificationMeta _offBudgetMeta = const VerificationMeta(
    'offBudget',
  );
  @override
  late final GeneratedColumn<bool> offBudget = GeneratedColumn<bool>(
    'off_budget',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("off_budget" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _closedMeta = const VerificationMeta('closed');
  @override
  late final GeneratedColumn<bool> closed = GeneratedColumn<bool>(
    'closed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("closed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  static const VerificationMeta _bankIdMeta = const VerificationMeta('bankId');
  @override
  late final GeneratedColumn<String> bankId = GeneratedColumn<String>(
    'bank_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    id,
    scope,
    name,
    offBudget,
    closed,
    sort,
    bankId,
    updatedAt,
    deleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ledger_accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<LedgerAccount> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('off_budget')) {
      context.handle(
        _offBudgetMeta,
        offBudget.isAcceptableOrUnknown(data['off_budget']!, _offBudgetMeta),
      );
    }
    if (data.containsKey('closed')) {
      context.handle(
        _closedMeta,
        closed.isAcceptableOrUnknown(data['closed']!, _closedMeta),
      );
    }
    if (data.containsKey('sort')) {
      context.handle(
        _sortMeta,
        sort.isAcceptableOrUnknown(data['sort']!, _sortMeta),
      );
    } else if (isInserting) {
      context.missing(_sortMeta);
    }
    if (data.containsKey('bank_id')) {
      context.handle(
        _bankIdMeta,
        bankId.isAcceptableOrUnknown(data['bank_id']!, _bankIdMeta),
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
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LedgerAccount map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LedgerAccount(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      offBudget: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}off_budget'],
      )!,
      closed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}closed'],
      )!,
      sort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort'],
      )!,
      bankId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bank_id'],
      ),
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
  $LedgerAccountsTable createAlias(String alias) {
    return $LedgerAccountsTable(attachedDatabase, alias);
  }
}

class LedgerAccount extends DataClass implements Insertable<LedgerAccount> {
  final String id;
  final String scope;
  final String name;
  final bool offBudget;
  final bool closed;
  final int sort;

  /// The statement parser's bank id, to suggest this account on import.
  final String? bankId;
  final int updatedAt;
  final bool deleted;
  const LedgerAccount({
    required this.id,
    required this.scope,
    required this.name,
    required this.offBudget,
    required this.closed,
    required this.sort,
    this.bankId,
    required this.updatedAt,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['scope'] = Variable<String>(scope);
    map['name'] = Variable<String>(name);
    map['off_budget'] = Variable<bool>(offBudget);
    map['closed'] = Variable<bool>(closed);
    map['sort'] = Variable<int>(sort);
    if (!nullToAbsent || bankId != null) {
      map['bank_id'] = Variable<String>(bankId);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  LedgerAccountsCompanion toCompanion(bool nullToAbsent) {
    return LedgerAccountsCompanion(
      id: Value(id),
      scope: Value(scope),
      name: Value(name),
      offBudget: Value(offBudget),
      closed: Value(closed),
      sort: Value(sort),
      bankId: bankId == null && nullToAbsent
          ? const Value.absent()
          : Value(bankId),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
    );
  }

  factory LedgerAccount.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LedgerAccount(
      id: serializer.fromJson<String>(json['id']),
      scope: serializer.fromJson<String>(json['scope']),
      name: serializer.fromJson<String>(json['name']),
      offBudget: serializer.fromJson<bool>(json['offBudget']),
      closed: serializer.fromJson<bool>(json['closed']),
      sort: serializer.fromJson<int>(json['sort']),
      bankId: serializer.fromJson<String?>(json['bankId']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'scope': serializer.toJson<String>(scope),
      'name': serializer.toJson<String>(name),
      'offBudget': serializer.toJson<bool>(offBudget),
      'closed': serializer.toJson<bool>(closed),
      'sort': serializer.toJson<int>(sort),
      'bankId': serializer.toJson<String?>(bankId),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  LedgerAccount copyWith({
    String? id,
    String? scope,
    String? name,
    bool? offBudget,
    bool? closed,
    int? sort,
    Value<String?> bankId = const Value.absent(),
    int? updatedAt,
    bool? deleted,
  }) => LedgerAccount(
    id: id ?? this.id,
    scope: scope ?? this.scope,
    name: name ?? this.name,
    offBudget: offBudget ?? this.offBudget,
    closed: closed ?? this.closed,
    sort: sort ?? this.sort,
    bankId: bankId.present ? bankId.value : this.bankId,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
  );
  LedgerAccount copyWithCompanion(LedgerAccountsCompanion data) {
    return LedgerAccount(
      id: data.id.present ? data.id.value : this.id,
      scope: data.scope.present ? data.scope.value : this.scope,
      name: data.name.present ? data.name.value : this.name,
      offBudget: data.offBudget.present ? data.offBudget.value : this.offBudget,
      closed: data.closed.present ? data.closed.value : this.closed,
      sort: data.sort.present ? data.sort.value : this.sort,
      bankId: data.bankId.present ? data.bankId.value : this.bankId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LedgerAccount(')
          ..write('id: $id, ')
          ..write('scope: $scope, ')
          ..write('name: $name, ')
          ..write('offBudget: $offBudget, ')
          ..write('closed: $closed, ')
          ..write('sort: $sort, ')
          ..write('bankId: $bankId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    scope,
    name,
    offBudget,
    closed,
    sort,
    bankId,
    updatedAt,
    deleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LedgerAccount &&
          other.id == this.id &&
          other.scope == this.scope &&
          other.name == this.name &&
          other.offBudget == this.offBudget &&
          other.closed == this.closed &&
          other.sort == this.sort &&
          other.bankId == this.bankId &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted);
}

class LedgerAccountsCompanion extends UpdateCompanion<LedgerAccount> {
  final Value<String> id;
  final Value<String> scope;
  final Value<String> name;
  final Value<bool> offBudget;
  final Value<bool> closed;
  final Value<int> sort;
  final Value<String?> bankId;
  final Value<int> updatedAt;
  final Value<bool> deleted;
  final Value<int> rowid;
  const LedgerAccountsCompanion({
    this.id = const Value.absent(),
    this.scope = const Value.absent(),
    this.name = const Value.absent(),
    this.offBudget = const Value.absent(),
    this.closed = const Value.absent(),
    this.sort = const Value.absent(),
    this.bankId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LedgerAccountsCompanion.insert({
    required String id,
    required String scope,
    required String name,
    this.offBudget = const Value.absent(),
    this.closed = const Value.absent(),
    required int sort,
    this.bankId = const Value.absent(),
    required int updatedAt,
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       scope = Value(scope),
       name = Value(name),
       sort = Value(sort),
       updatedAt = Value(updatedAt);
  static Insertable<LedgerAccount> custom({
    Expression<String>? id,
    Expression<String>? scope,
    Expression<String>? name,
    Expression<bool>? offBudget,
    Expression<bool>? closed,
    Expression<int>? sort,
    Expression<String>? bankId,
    Expression<int>? updatedAt,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scope != null) 'scope': scope,
      if (name != null) 'name': name,
      if (offBudget != null) 'off_budget': offBudget,
      if (closed != null) 'closed': closed,
      if (sort != null) 'sort': sort,
      if (bankId != null) 'bank_id': bankId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LedgerAccountsCompanion copyWith({
    Value<String>? id,
    Value<String>? scope,
    Value<String>? name,
    Value<bool>? offBudget,
    Value<bool>? closed,
    Value<int>? sort,
    Value<String?>? bankId,
    Value<int>? updatedAt,
    Value<bool>? deleted,
    Value<int>? rowid,
  }) {
    return LedgerAccountsCompanion(
      id: id ?? this.id,
      scope: scope ?? this.scope,
      name: name ?? this.name,
      offBudget: offBudget ?? this.offBudget,
      closed: closed ?? this.closed,
      sort: sort ?? this.sort,
      bankId: bankId ?? this.bankId,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (offBudget.present) {
      map['off_budget'] = Variable<bool>(offBudget.value);
    }
    if (closed.present) {
      map['closed'] = Variable<bool>(closed.value);
    }
    if (sort.present) {
      map['sort'] = Variable<int>(sort.value);
    }
    if (bankId.present) {
      map['bank_id'] = Variable<String>(bankId.value);
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
    return (StringBuffer('LedgerAccountsCompanion(')
          ..write('id: $id, ')
          ..write('scope: $scope, ')
          ..write('name: $name, ')
          ..write('offBudget: $offBudget, ')
          ..write('closed: $closed, ')
          ..write('sort: $sort, ')
          ..write('bankId: $bankId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LedgerPayeesTable extends LedgerPayees
    with TableInfo<$LedgerPayeesTable, LedgerPayee> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LedgerPayeesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
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
  static const VerificationMeta _transferAccountIdMeta = const VerificationMeta(
    'transferAccountId',
  );
  @override
  late final GeneratedColumn<String> transferAccountId =
      GeneratedColumn<String>(
        'transfer_account_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
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
    id,
    scope,
    name,
    transferAccountId,
    updatedAt,
    deleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ledger_payees';
  @override
  VerificationContext validateIntegrity(
    Insertable<LedgerPayee> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('transfer_account_id')) {
      context.handle(
        _transferAccountIdMeta,
        transferAccountId.isAcceptableOrUnknown(
          data['transfer_account_id']!,
          _transferAccountIdMeta,
        ),
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
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LedgerPayee map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LedgerPayee(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      transferAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transfer_account_id'],
      ),
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
  $LedgerPayeesTable createAlias(String alias) {
    return $LedgerPayeesTable(attachedDatabase, alias);
  }
}

class LedgerPayee extends DataClass implements Insertable<LedgerPayee> {
  final String id;
  final String scope;
  final String name;

  /// Set for Actual's transfer payees ("Transfer: Savings").
  final String? transferAccountId;
  final int updatedAt;
  final bool deleted;
  const LedgerPayee({
    required this.id,
    required this.scope,
    required this.name,
    this.transferAccountId,
    required this.updatedAt,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['scope'] = Variable<String>(scope);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || transferAccountId != null) {
      map['transfer_account_id'] = Variable<String>(transferAccountId);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  LedgerPayeesCompanion toCompanion(bool nullToAbsent) {
    return LedgerPayeesCompanion(
      id: Value(id),
      scope: Value(scope),
      name: Value(name),
      transferAccountId: transferAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(transferAccountId),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
    );
  }

  factory LedgerPayee.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LedgerPayee(
      id: serializer.fromJson<String>(json['id']),
      scope: serializer.fromJson<String>(json['scope']),
      name: serializer.fromJson<String>(json['name']),
      transferAccountId: serializer.fromJson<String?>(
        json['transferAccountId'],
      ),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'scope': serializer.toJson<String>(scope),
      'name': serializer.toJson<String>(name),
      'transferAccountId': serializer.toJson<String?>(transferAccountId),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  LedgerPayee copyWith({
    String? id,
    String? scope,
    String? name,
    Value<String?> transferAccountId = const Value.absent(),
    int? updatedAt,
    bool? deleted,
  }) => LedgerPayee(
    id: id ?? this.id,
    scope: scope ?? this.scope,
    name: name ?? this.name,
    transferAccountId: transferAccountId.present
        ? transferAccountId.value
        : this.transferAccountId,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
  );
  LedgerPayee copyWithCompanion(LedgerPayeesCompanion data) {
    return LedgerPayee(
      id: data.id.present ? data.id.value : this.id,
      scope: data.scope.present ? data.scope.value : this.scope,
      name: data.name.present ? data.name.value : this.name,
      transferAccountId: data.transferAccountId.present
          ? data.transferAccountId.value
          : this.transferAccountId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LedgerPayee(')
          ..write('id: $id, ')
          ..write('scope: $scope, ')
          ..write('name: $name, ')
          ..write('transferAccountId: $transferAccountId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, scope, name, transferAccountId, updatedAt, deleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LedgerPayee &&
          other.id == this.id &&
          other.scope == this.scope &&
          other.name == this.name &&
          other.transferAccountId == this.transferAccountId &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted);
}

class LedgerPayeesCompanion extends UpdateCompanion<LedgerPayee> {
  final Value<String> id;
  final Value<String> scope;
  final Value<String> name;
  final Value<String?> transferAccountId;
  final Value<int> updatedAt;
  final Value<bool> deleted;
  final Value<int> rowid;
  const LedgerPayeesCompanion({
    this.id = const Value.absent(),
    this.scope = const Value.absent(),
    this.name = const Value.absent(),
    this.transferAccountId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LedgerPayeesCompanion.insert({
    required String id,
    required String scope,
    required String name,
    this.transferAccountId = const Value.absent(),
    required int updatedAt,
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       scope = Value(scope),
       name = Value(name),
       updatedAt = Value(updatedAt);
  static Insertable<LedgerPayee> custom({
    Expression<String>? id,
    Expression<String>? scope,
    Expression<String>? name,
    Expression<String>? transferAccountId,
    Expression<int>? updatedAt,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scope != null) 'scope': scope,
      if (name != null) 'name': name,
      if (transferAccountId != null) 'transfer_account_id': transferAccountId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LedgerPayeesCompanion copyWith({
    Value<String>? id,
    Value<String>? scope,
    Value<String>? name,
    Value<String?>? transferAccountId,
    Value<int>? updatedAt,
    Value<bool>? deleted,
    Value<int>? rowid,
  }) {
    return LedgerPayeesCompanion(
      id: id ?? this.id,
      scope: scope ?? this.scope,
      name: name ?? this.name,
      transferAccountId: transferAccountId ?? this.transferAccountId,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (transferAccountId.present) {
      map['transfer_account_id'] = Variable<String>(transferAccountId.value);
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
    return (StringBuffer('LedgerPayeesCompanion(')
          ..write('id: $id, ')
          ..write('scope: $scope, ')
          ..write('name: $name, ')
          ..write('transferAccountId: $transferAccountId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LedgerTransactionsTable extends LedgerTransactions
    with TableInfo<$LedgerTransactionsTable, LedgerTransaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LedgerTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
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
      'REFERENCES ledger_accounts (id)',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountCentsMeta = const VerificationMeta(
    'amountCents',
  );
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
    'amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payeeIdMeta = const VerificationMeta(
    'payeeId',
  );
  @override
  late final GeneratedColumn<String> payeeId = GeneratedColumn<String>(
    'payee_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _clearedMeta = const VerificationMeta(
    'cleared',
  );
  @override
  late final GeneratedColumn<bool> cleared = GeneratedColumn<bool>(
    'cleared',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("cleared" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _importedIdMeta = const VerificationMeta(
    'importedId',
  );
  @override
  late final GeneratedColumn<String> importedId = GeneratedColumn<String>(
    'imported_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startingBalanceMeta = const VerificationMeta(
    'startingBalance',
  );
  @override
  late final GeneratedColumn<bool> startingBalance = GeneratedColumn<bool>(
    'starting_balance',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("starting_balance" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _transferIdMeta = const VerificationMeta(
    'transferId',
  );
  @override
  late final GeneratedColumn<String> transferId = GeneratedColumn<String>(
    'transfer_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isParentMeta = const VerificationMeta(
    'isParent',
  );
  @override
  late final GeneratedColumn<bool> isParent = GeneratedColumn<bool>(
    'is_parent',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_parent" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
    id,
    scope,
    accountId,
    date,
    amountCents,
    payeeId,
    categoryId,
    notes,
    cleared,
    importedId,
    startingBalance,
    transferId,
    parentId,
    isParent,
    createdAt,
    updatedAt,
    deleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ledger_transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<LedgerTransaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('amount_cents')) {
      context.handle(
        _amountCentsMeta,
        amountCents.isAcceptableOrUnknown(
          data['amount_cents']!,
          _amountCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountCentsMeta);
    }
    if (data.containsKey('payee_id')) {
      context.handle(
        _payeeIdMeta,
        payeeId.isAcceptableOrUnknown(data['payee_id']!, _payeeIdMeta),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('cleared')) {
      context.handle(
        _clearedMeta,
        cleared.isAcceptableOrUnknown(data['cleared']!, _clearedMeta),
      );
    }
    if (data.containsKey('imported_id')) {
      context.handle(
        _importedIdMeta,
        importedId.isAcceptableOrUnknown(data['imported_id']!, _importedIdMeta),
      );
    }
    if (data.containsKey('starting_balance')) {
      context.handle(
        _startingBalanceMeta,
        startingBalance.isAcceptableOrUnknown(
          data['starting_balance']!,
          _startingBalanceMeta,
        ),
      );
    }
    if (data.containsKey('transfer_id')) {
      context.handle(
        _transferIdMeta,
        transferId.isAcceptableOrUnknown(data['transfer_id']!, _transferIdMeta),
      );
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('is_parent')) {
      context.handle(
        _isParentMeta,
        isParent.isAcceptableOrUnknown(data['is_parent']!, _isParentMeta),
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LedgerTransaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LedgerTransaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      amountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_cents'],
      )!,
      payeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payee_id'],
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      cleared: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}cleared'],
      )!,
      importedId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}imported_id'],
      ),
      startingBalance: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}starting_balance'],
      )!,
      transferId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transfer_id'],
      ),
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      isParent: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_parent'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
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
  $LedgerTransactionsTable createAlias(String alias) {
    return $LedgerTransactionsTable(attachedDatabase, alias);
  }
}

class LedgerTransaction extends DataClass
    implements Insertable<LedgerTransaction> {
  final String id;
  final String scope;
  final String accountId;

  /// YYYY-MM-DD.
  final String date;
  final int amountCents;
  final String? payeeId;

  /// The phone's category id (`preset:…`, `local:<uuid>`, `actual:<id>`).
  /// No foreign key: an Actual category can arrive after its transactions.
  final String? categoryId;
  final String? notes;
  final bool cleared;

  /// `pdfimport-…` (a statement) or `app-<clientId>` (quick add), as in
  /// Actual: importing the same statement twice adds nothing.
  final String? importedId;
  final bool startingBalance;

  /// From Actual (Phase 5); read-only on the phone in v1.
  final String? transferId;
  final String? parentId;
  final bool isParent;
  final int createdAt;
  final int updatedAt;
  final bool deleted;
  const LedgerTransaction({
    required this.id,
    required this.scope,
    required this.accountId,
    required this.date,
    required this.amountCents,
    this.payeeId,
    this.categoryId,
    this.notes,
    required this.cleared,
    this.importedId,
    required this.startingBalance,
    this.transferId,
    this.parentId,
    required this.isParent,
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['scope'] = Variable<String>(scope);
    map['account_id'] = Variable<String>(accountId);
    map['date'] = Variable<String>(date);
    map['amount_cents'] = Variable<int>(amountCents);
    if (!nullToAbsent || payeeId != null) {
      map['payee_id'] = Variable<String>(payeeId);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['cleared'] = Variable<bool>(cleared);
    if (!nullToAbsent || importedId != null) {
      map['imported_id'] = Variable<String>(importedId);
    }
    map['starting_balance'] = Variable<bool>(startingBalance);
    if (!nullToAbsent || transferId != null) {
      map['transfer_id'] = Variable<String>(transferId);
    }
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['is_parent'] = Variable<bool>(isParent);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  LedgerTransactionsCompanion toCompanion(bool nullToAbsent) {
    return LedgerTransactionsCompanion(
      id: Value(id),
      scope: Value(scope),
      accountId: Value(accountId),
      date: Value(date),
      amountCents: Value(amountCents),
      payeeId: payeeId == null && nullToAbsent
          ? const Value.absent()
          : Value(payeeId),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      cleared: Value(cleared),
      importedId: importedId == null && nullToAbsent
          ? const Value.absent()
          : Value(importedId),
      startingBalance: Value(startingBalance),
      transferId: transferId == null && nullToAbsent
          ? const Value.absent()
          : Value(transferId),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      isParent: Value(isParent),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
    );
  }

  factory LedgerTransaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LedgerTransaction(
      id: serializer.fromJson<String>(json['id']),
      scope: serializer.fromJson<String>(json['scope']),
      accountId: serializer.fromJson<String>(json['accountId']),
      date: serializer.fromJson<String>(json['date']),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      payeeId: serializer.fromJson<String?>(json['payeeId']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      notes: serializer.fromJson<String?>(json['notes']),
      cleared: serializer.fromJson<bool>(json['cleared']),
      importedId: serializer.fromJson<String?>(json['importedId']),
      startingBalance: serializer.fromJson<bool>(json['startingBalance']),
      transferId: serializer.fromJson<String?>(json['transferId']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      isParent: serializer.fromJson<bool>(json['isParent']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'scope': serializer.toJson<String>(scope),
      'accountId': serializer.toJson<String>(accountId),
      'date': serializer.toJson<String>(date),
      'amountCents': serializer.toJson<int>(amountCents),
      'payeeId': serializer.toJson<String?>(payeeId),
      'categoryId': serializer.toJson<String?>(categoryId),
      'notes': serializer.toJson<String?>(notes),
      'cleared': serializer.toJson<bool>(cleared),
      'importedId': serializer.toJson<String?>(importedId),
      'startingBalance': serializer.toJson<bool>(startingBalance),
      'transferId': serializer.toJson<String?>(transferId),
      'parentId': serializer.toJson<String?>(parentId),
      'isParent': serializer.toJson<bool>(isParent),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  LedgerTransaction copyWith({
    String? id,
    String? scope,
    String? accountId,
    String? date,
    int? amountCents,
    Value<String?> payeeId = const Value.absent(),
    Value<String?> categoryId = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    bool? cleared,
    Value<String?> importedId = const Value.absent(),
    bool? startingBalance,
    Value<String?> transferId = const Value.absent(),
    Value<String?> parentId = const Value.absent(),
    bool? isParent,
    int? createdAt,
    int? updatedAt,
    bool? deleted,
  }) => LedgerTransaction(
    id: id ?? this.id,
    scope: scope ?? this.scope,
    accountId: accountId ?? this.accountId,
    date: date ?? this.date,
    amountCents: amountCents ?? this.amountCents,
    payeeId: payeeId.present ? payeeId.value : this.payeeId,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    notes: notes.present ? notes.value : this.notes,
    cleared: cleared ?? this.cleared,
    importedId: importedId.present ? importedId.value : this.importedId,
    startingBalance: startingBalance ?? this.startingBalance,
    transferId: transferId.present ? transferId.value : this.transferId,
    parentId: parentId.present ? parentId.value : this.parentId,
    isParent: isParent ?? this.isParent,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
  );
  LedgerTransaction copyWithCompanion(LedgerTransactionsCompanion data) {
    return LedgerTransaction(
      id: data.id.present ? data.id.value : this.id,
      scope: data.scope.present ? data.scope.value : this.scope,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      date: data.date.present ? data.date.value : this.date,
      amountCents: data.amountCents.present
          ? data.amountCents.value
          : this.amountCents,
      payeeId: data.payeeId.present ? data.payeeId.value : this.payeeId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      notes: data.notes.present ? data.notes.value : this.notes,
      cleared: data.cleared.present ? data.cleared.value : this.cleared,
      importedId: data.importedId.present
          ? data.importedId.value
          : this.importedId,
      startingBalance: data.startingBalance.present
          ? data.startingBalance.value
          : this.startingBalance,
      transferId: data.transferId.present
          ? data.transferId.value
          : this.transferId,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      isParent: data.isParent.present ? data.isParent.value : this.isParent,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LedgerTransaction(')
          ..write('id: $id, ')
          ..write('scope: $scope, ')
          ..write('accountId: $accountId, ')
          ..write('date: $date, ')
          ..write('amountCents: $amountCents, ')
          ..write('payeeId: $payeeId, ')
          ..write('categoryId: $categoryId, ')
          ..write('notes: $notes, ')
          ..write('cleared: $cleared, ')
          ..write('importedId: $importedId, ')
          ..write('startingBalance: $startingBalance, ')
          ..write('transferId: $transferId, ')
          ..write('parentId: $parentId, ')
          ..write('isParent: $isParent, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    scope,
    accountId,
    date,
    amountCents,
    payeeId,
    categoryId,
    notes,
    cleared,
    importedId,
    startingBalance,
    transferId,
    parentId,
    isParent,
    createdAt,
    updatedAt,
    deleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LedgerTransaction &&
          other.id == this.id &&
          other.scope == this.scope &&
          other.accountId == this.accountId &&
          other.date == this.date &&
          other.amountCents == this.amountCents &&
          other.payeeId == this.payeeId &&
          other.categoryId == this.categoryId &&
          other.notes == this.notes &&
          other.cleared == this.cleared &&
          other.importedId == this.importedId &&
          other.startingBalance == this.startingBalance &&
          other.transferId == this.transferId &&
          other.parentId == this.parentId &&
          other.isParent == this.isParent &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted);
}

class LedgerTransactionsCompanion extends UpdateCompanion<LedgerTransaction> {
  final Value<String> id;
  final Value<String> scope;
  final Value<String> accountId;
  final Value<String> date;
  final Value<int> amountCents;
  final Value<String?> payeeId;
  final Value<String?> categoryId;
  final Value<String?> notes;
  final Value<bool> cleared;
  final Value<String?> importedId;
  final Value<bool> startingBalance;
  final Value<String?> transferId;
  final Value<String?> parentId;
  final Value<bool> isParent;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<bool> deleted;
  final Value<int> rowid;
  const LedgerTransactionsCompanion({
    this.id = const Value.absent(),
    this.scope = const Value.absent(),
    this.accountId = const Value.absent(),
    this.date = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.payeeId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.notes = const Value.absent(),
    this.cleared = const Value.absent(),
    this.importedId = const Value.absent(),
    this.startingBalance = const Value.absent(),
    this.transferId = const Value.absent(),
    this.parentId = const Value.absent(),
    this.isParent = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LedgerTransactionsCompanion.insert({
    required String id,
    required String scope,
    required String accountId,
    required String date,
    required int amountCents,
    this.payeeId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.notes = const Value.absent(),
    this.cleared = const Value.absent(),
    this.importedId = const Value.absent(),
    this.startingBalance = const Value.absent(),
    this.transferId = const Value.absent(),
    this.parentId = const Value.absent(),
    this.isParent = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       scope = Value(scope),
       accountId = Value(accountId),
       date = Value(date),
       amountCents = Value(amountCents),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LedgerTransaction> custom({
    Expression<String>? id,
    Expression<String>? scope,
    Expression<String>? accountId,
    Expression<String>? date,
    Expression<int>? amountCents,
    Expression<String>? payeeId,
    Expression<String>? categoryId,
    Expression<String>? notes,
    Expression<bool>? cleared,
    Expression<String>? importedId,
    Expression<bool>? startingBalance,
    Expression<String>? transferId,
    Expression<String>? parentId,
    Expression<bool>? isParent,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scope != null) 'scope': scope,
      if (accountId != null) 'account_id': accountId,
      if (date != null) 'date': date,
      if (amountCents != null) 'amount_cents': amountCents,
      if (payeeId != null) 'payee_id': payeeId,
      if (categoryId != null) 'category_id': categoryId,
      if (notes != null) 'notes': notes,
      if (cleared != null) 'cleared': cleared,
      if (importedId != null) 'imported_id': importedId,
      if (startingBalance != null) 'starting_balance': startingBalance,
      if (transferId != null) 'transfer_id': transferId,
      if (parentId != null) 'parent_id': parentId,
      if (isParent != null) 'is_parent': isParent,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LedgerTransactionsCompanion copyWith({
    Value<String>? id,
    Value<String>? scope,
    Value<String>? accountId,
    Value<String>? date,
    Value<int>? amountCents,
    Value<String?>? payeeId,
    Value<String?>? categoryId,
    Value<String?>? notes,
    Value<bool>? cleared,
    Value<String?>? importedId,
    Value<bool>? startingBalance,
    Value<String?>? transferId,
    Value<String?>? parentId,
    Value<bool>? isParent,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<bool>? deleted,
    Value<int>? rowid,
  }) {
    return LedgerTransactionsCompanion(
      id: id ?? this.id,
      scope: scope ?? this.scope,
      accountId: accountId ?? this.accountId,
      date: date ?? this.date,
      amountCents: amountCents ?? this.amountCents,
      payeeId: payeeId ?? this.payeeId,
      categoryId: categoryId ?? this.categoryId,
      notes: notes ?? this.notes,
      cleared: cleared ?? this.cleared,
      importedId: importedId ?? this.importedId,
      startingBalance: startingBalance ?? this.startingBalance,
      transferId: transferId ?? this.transferId,
      parentId: parentId ?? this.parentId,
      isParent: isParent ?? this.isParent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (payeeId.present) {
      map['payee_id'] = Variable<String>(payeeId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (cleared.present) {
      map['cleared'] = Variable<bool>(cleared.value);
    }
    if (importedId.present) {
      map['imported_id'] = Variable<String>(importedId.value);
    }
    if (startingBalance.present) {
      map['starting_balance'] = Variable<bool>(startingBalance.value);
    }
    if (transferId.present) {
      map['transfer_id'] = Variable<String>(transferId.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (isParent.present) {
      map['is_parent'] = Variable<bool>(isParent.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
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
    return (StringBuffer('LedgerTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('scope: $scope, ')
          ..write('accountId: $accountId, ')
          ..write('date: $date, ')
          ..write('amountCents: $amountCents, ')
          ..write('payeeId: $payeeId, ')
          ..write('categoryId: $categoryId, ')
          ..write('notes: $notes, ')
          ..write('cleared: $cleared, ')
          ..write('importedId: $importedId, ')
          ..write('startingBalance: $startingBalance, ')
          ..write('transferId: $transferId, ')
          ..write('parentId: $parentId, ')
          ..write('isParent: $isParent, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LedgerBudgetsTable extends LedgerBudgets
    with TableInfo<$LedgerBudgetsTable, LedgerBudget> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LedgerBudgetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
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
  );
  static const VerificationMeta _monthMeta = const VerificationMeta('month');
  @override
  late final GeneratedColumn<String> month = GeneratedColumn<String>(
    'month',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _budgetedCentsMeta = const VerificationMeta(
    'budgetedCents',
  );
  @override
  late final GeneratedColumn<int> budgetedCents = GeneratedColumn<int>(
    'budgeted_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _carryoverMeta = const VerificationMeta(
    'carryover',
  );
  @override
  late final GeneratedColumn<bool> carryover = GeneratedColumn<bool>(
    'carryover',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("carryover" IN (0, 1))',
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
    scope,
    categoryId,
    month,
    budgetedCents,
    carryover,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ledger_budgets';
  @override
  VerificationContext validateIntegrity(
    Insertable<LedgerBudget> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('month')) {
      context.handle(
        _monthMeta,
        month.isAcceptableOrUnknown(data['month']!, _monthMeta),
      );
    } else if (isInserting) {
      context.missing(_monthMeta);
    }
    if (data.containsKey('budgeted_cents')) {
      context.handle(
        _budgetedCentsMeta,
        budgetedCents.isAcceptableOrUnknown(
          data['budgeted_cents']!,
          _budgetedCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_budgetedCentsMeta);
    }
    if (data.containsKey('carryover')) {
      context.handle(
        _carryoverMeta,
        carryover.isAcceptableOrUnknown(data['carryover']!, _carryoverMeta),
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
  Set<GeneratedColumn> get $primaryKey => {scope, categoryId, month};
  @override
  LedgerBudget map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LedgerBudget(
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      month: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}month'],
      )!,
      budgetedCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}budgeted_cents'],
      )!,
      carryover: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}carryover'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LedgerBudgetsTable createAlias(String alias) {
    return $LedgerBudgetsTable(attachedDatabase, alias);
  }
}

class LedgerBudget extends DataClass implements Insertable<LedgerBudget> {
  final String scope;
  final String categoryId;

  /// YYYY-MM.
  final String month;
  final int budgetedCents;

  /// Envelope budgets: overspending carries into next month.
  final bool carryover;
  final int updatedAt;
  const LedgerBudget({
    required this.scope,
    required this.categoryId,
    required this.month,
    required this.budgetedCents,
    required this.carryover,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope'] = Variable<String>(scope);
    map['category_id'] = Variable<String>(categoryId);
    map['month'] = Variable<String>(month);
    map['budgeted_cents'] = Variable<int>(budgetedCents);
    map['carryover'] = Variable<bool>(carryover);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  LedgerBudgetsCompanion toCompanion(bool nullToAbsent) {
    return LedgerBudgetsCompanion(
      scope: Value(scope),
      categoryId: Value(categoryId),
      month: Value(month),
      budgetedCents: Value(budgetedCents),
      carryover: Value(carryover),
      updatedAt: Value(updatedAt),
    );
  }

  factory LedgerBudget.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LedgerBudget(
      scope: serializer.fromJson<String>(json['scope']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      month: serializer.fromJson<String>(json['month']),
      budgetedCents: serializer.fromJson<int>(json['budgetedCents']),
      carryover: serializer.fromJson<bool>(json['carryover']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scope': serializer.toJson<String>(scope),
      'categoryId': serializer.toJson<String>(categoryId),
      'month': serializer.toJson<String>(month),
      'budgetedCents': serializer.toJson<int>(budgetedCents),
      'carryover': serializer.toJson<bool>(carryover),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  LedgerBudget copyWith({
    String? scope,
    String? categoryId,
    String? month,
    int? budgetedCents,
    bool? carryover,
    int? updatedAt,
  }) => LedgerBudget(
    scope: scope ?? this.scope,
    categoryId: categoryId ?? this.categoryId,
    month: month ?? this.month,
    budgetedCents: budgetedCents ?? this.budgetedCents,
    carryover: carryover ?? this.carryover,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LedgerBudget copyWithCompanion(LedgerBudgetsCompanion data) {
    return LedgerBudget(
      scope: data.scope.present ? data.scope.value : this.scope,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      month: data.month.present ? data.month.value : this.month,
      budgetedCents: data.budgetedCents.present
          ? data.budgetedCents.value
          : this.budgetedCents,
      carryover: data.carryover.present ? data.carryover.value : this.carryover,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LedgerBudget(')
          ..write('scope: $scope, ')
          ..write('categoryId: $categoryId, ')
          ..write('month: $month, ')
          ..write('budgetedCents: $budgetedCents, ')
          ..write('carryover: $carryover, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    scope,
    categoryId,
    month,
    budgetedCents,
    carryover,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LedgerBudget &&
          other.scope == this.scope &&
          other.categoryId == this.categoryId &&
          other.month == this.month &&
          other.budgetedCents == this.budgetedCents &&
          other.carryover == this.carryover &&
          other.updatedAt == this.updatedAt);
}

class LedgerBudgetsCompanion extends UpdateCompanion<LedgerBudget> {
  final Value<String> scope;
  final Value<String> categoryId;
  final Value<String> month;
  final Value<int> budgetedCents;
  final Value<bool> carryover;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const LedgerBudgetsCompanion({
    this.scope = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.month = const Value.absent(),
    this.budgetedCents = const Value.absent(),
    this.carryover = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LedgerBudgetsCompanion.insert({
    required String scope,
    required String categoryId,
    required String month,
    required int budgetedCents,
    this.carryover = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : scope = Value(scope),
       categoryId = Value(categoryId),
       month = Value(month),
       budgetedCents = Value(budgetedCents),
       updatedAt = Value(updatedAt);
  static Insertable<LedgerBudget> custom({
    Expression<String>? scope,
    Expression<String>? categoryId,
    Expression<String>? month,
    Expression<int>? budgetedCents,
    Expression<bool>? carryover,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scope != null) 'scope': scope,
      if (categoryId != null) 'category_id': categoryId,
      if (month != null) 'month': month,
      if (budgetedCents != null) 'budgeted_cents': budgetedCents,
      if (carryover != null) 'carryover': carryover,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LedgerBudgetsCompanion copyWith({
    Value<String>? scope,
    Value<String>? categoryId,
    Value<String>? month,
    Value<int>? budgetedCents,
    Value<bool>? carryover,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return LedgerBudgetsCompanion(
      scope: scope ?? this.scope,
      categoryId: categoryId ?? this.categoryId,
      month: month ?? this.month,
      budgetedCents: budgetedCents ?? this.budgetedCents,
      carryover: carryover ?? this.carryover,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (month.present) {
      map['month'] = Variable<String>(month.value);
    }
    if (budgetedCents.present) {
      map['budgeted_cents'] = Variable<int>(budgetedCents.value);
    }
    if (carryover.present) {
      map['carryover'] = Variable<bool>(carryover.value);
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
    return (StringBuffer('LedgerBudgetsCompanion(')
          ..write('scope: $scope, ')
          ..write('categoryId: $categoryId, ')
          ..write('month: $month, ')
          ..write('budgetedCents: $budgetedCents, ')
          ..write('carryover: $carryover, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LedgerOutboxTable extends LedgerOutbox
    with TableInfo<$LedgerOutboxTable, LedgerOutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LedgerOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<String> rowId = GeneratedColumn<String>(
    'row_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
    seq,
    scope,
    kind,
    rowId,
    op,
    createdAt,
    attempts,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ledger_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<LedgerOutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rowIdMeta);
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    } else if (isInserting) {
      context.missing(_opMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
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
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {kind, rowId},
  ];
  @override
  LedgerOutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LedgerOutboxData(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_id'],
      )!,
      op: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $LedgerOutboxTable createAlias(String alias) {
    return $LedgerOutboxTable(attachedDatabase, alias);
  }
}

class LedgerOutboxData extends DataClass
    implements Insertable<LedgerOutboxData> {
  final int seq;
  final String scope;

  /// 'account' | 'payee' | 'transaction' | 'budget'.
  final String kind;

  /// The row's id; for a budget amount, `<categoryId>|<YYYY-MM>`.
  final String rowId;

  /// 'put' | 'delete'.
  final String op;
  final int createdAt;
  final int attempts;

  /// An error code from the last attempt, never a message carrying data.
  final String? lastError;
  const LedgerOutboxData({
    required this.seq,
    required this.scope,
    required this.kind,
    required this.rowId,
    required this.op,
    required this.createdAt,
    required this.attempts,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['scope'] = Variable<String>(scope);
    map['kind'] = Variable<String>(kind);
    map['row_id'] = Variable<String>(rowId);
    map['op'] = Variable<String>(op);
    map['created_at'] = Variable<int>(createdAt);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  LedgerOutboxCompanion toCompanion(bool nullToAbsent) {
    return LedgerOutboxCompanion(
      seq: Value(seq),
      scope: Value(scope),
      kind: Value(kind),
      rowId: Value(rowId),
      op: Value(op),
      createdAt: Value(createdAt),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory LedgerOutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LedgerOutboxData(
      seq: serializer.fromJson<int>(json['seq']),
      scope: serializer.fromJson<String>(json['scope']),
      kind: serializer.fromJson<String>(json['kind']),
      rowId: serializer.fromJson<String>(json['rowId']),
      op: serializer.fromJson<String>(json['op']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'scope': serializer.toJson<String>(scope),
      'kind': serializer.toJson<String>(kind),
      'rowId': serializer.toJson<String>(rowId),
      'op': serializer.toJson<String>(op),
      'createdAt': serializer.toJson<int>(createdAt),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  LedgerOutboxData copyWith({
    int? seq,
    String? scope,
    String? kind,
    String? rowId,
    String? op,
    int? createdAt,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
  }) => LedgerOutboxData(
    seq: seq ?? this.seq,
    scope: scope ?? this.scope,
    kind: kind ?? this.kind,
    rowId: rowId ?? this.rowId,
    op: op ?? this.op,
    createdAt: createdAt ?? this.createdAt,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  LedgerOutboxData copyWithCompanion(LedgerOutboxCompanion data) {
    return LedgerOutboxData(
      seq: data.seq.present ? data.seq.value : this.seq,
      scope: data.scope.present ? data.scope.value : this.scope,
      kind: data.kind.present ? data.kind.value : this.kind,
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      op: data.op.present ? data.op.value : this.op,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LedgerOutboxData(')
          ..write('seq: $seq, ')
          ..write('scope: $scope, ')
          ..write('kind: $kind, ')
          ..write('rowId: $rowId, ')
          ..write('op: $op, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(seq, scope, kind, rowId, op, createdAt, attempts, lastError);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LedgerOutboxData &&
          other.seq == this.seq &&
          other.scope == this.scope &&
          other.kind == this.kind &&
          other.rowId == this.rowId &&
          other.op == this.op &&
          other.createdAt == this.createdAt &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError);
}

class LedgerOutboxCompanion extends UpdateCompanion<LedgerOutboxData> {
  final Value<int> seq;
  final Value<String> scope;
  final Value<String> kind;
  final Value<String> rowId;
  final Value<String> op;
  final Value<int> createdAt;
  final Value<int> attempts;
  final Value<String?> lastError;
  const LedgerOutboxCompanion({
    this.seq = const Value.absent(),
    this.scope = const Value.absent(),
    this.kind = const Value.absent(),
    this.rowId = const Value.absent(),
    this.op = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  LedgerOutboxCompanion.insert({
    this.seq = const Value.absent(),
    required String scope,
    required String kind,
    required String rowId,
    required String op,
    required int createdAt,
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
  }) : scope = Value(scope),
       kind = Value(kind),
       rowId = Value(rowId),
       op = Value(op),
       createdAt = Value(createdAt);
  static Insertable<LedgerOutboxData> custom({
    Expression<int>? seq,
    Expression<String>? scope,
    Expression<String>? kind,
    Expression<String>? rowId,
    Expression<String>? op,
    Expression<int>? createdAt,
    Expression<int>? attempts,
    Expression<String>? lastError,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (scope != null) 'scope': scope,
      if (kind != null) 'kind': kind,
      if (rowId != null) 'row_id': rowId,
      if (op != null) 'op': op,
      if (createdAt != null) 'created_at': createdAt,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
    });
  }

  LedgerOutboxCompanion copyWith({
    Value<int>? seq,
    Value<String>? scope,
    Value<String>? kind,
    Value<String>? rowId,
    Value<String>? op,
    Value<int>? createdAt,
    Value<int>? attempts,
    Value<String?>? lastError,
  }) {
    return LedgerOutboxCompanion(
      seq: seq ?? this.seq,
      scope: scope ?? this.scope,
      kind: kind ?? this.kind,
      rowId: rowId ?? this.rowId,
      op: op ?? this.op,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (rowId.present) {
      map['row_id'] = Variable<String>(rowId.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LedgerOutboxCompanion(')
          ..write('seq: $seq, ')
          ..write('scope: $scope, ')
          ..write('kind: $kind, ')
          ..write('rowId: $rowId, ')
          ..write('op: $op, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }
}

class $LedgerSyncStateTable extends LedgerSyncState
    with TableInfo<$LedgerSyncStateTable, LedgerSyncStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LedgerSyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _budgetModeMeta = const VerificationMeta(
    'budgetMode',
  );
  @override
  late final GeneratedColumn<String> budgetMode = GeneratedColumn<String>(
    'budget_mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastPulledAtMeta = const VerificationMeta(
    'lastPulledAt',
  );
  @override
  late final GeneratedColumn<int> lastPulledAt = GeneratedColumn<int>(
    'last_pulled_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cursorEpochMeta = const VerificationMeta(
    'cursorEpoch',
  );
  @override
  late final GeneratedColumn<String> cursorEpoch = GeneratedColumn<String>(
    'cursor_epoch',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cursorLastIdMeta = const VerificationMeta(
    'cursorLastId',
  );
  @override
  late final GeneratedColumn<int> cursorLastId = GeneratedColumn<int>(
    'cursor_last_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    scope,
    budgetMode,
    lastPulledAt,
    cursorEpoch,
    cursorLastId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ledger_sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<LedgerSyncStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('budget_mode')) {
      context.handle(
        _budgetModeMeta,
        budgetMode.isAcceptableOrUnknown(data['budget_mode']!, _budgetModeMeta),
      );
    }
    if (data.containsKey('last_pulled_at')) {
      context.handle(
        _lastPulledAtMeta,
        lastPulledAt.isAcceptableOrUnknown(
          data['last_pulled_at']!,
          _lastPulledAtMeta,
        ),
      );
    }
    if (data.containsKey('cursor_epoch')) {
      context.handle(
        _cursorEpochMeta,
        cursorEpoch.isAcceptableOrUnknown(
          data['cursor_epoch']!,
          _cursorEpochMeta,
        ),
      );
    }
    if (data.containsKey('cursor_last_id')) {
      context.handle(
        _cursorLastIdMeta,
        cursorLastId.isAcceptableOrUnknown(
          data['cursor_last_id']!,
          _cursorLastIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scope};
  @override
  LedgerSyncStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LedgerSyncStateData(
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      budgetMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}budget_mode'],
      ),
      lastPulledAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_pulled_at'],
      ),
      cursorEpoch: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cursor_epoch'],
      ),
      cursorLastId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cursor_last_id'],
      ),
    );
  }

  @override
  $LedgerSyncStateTable createAlias(String alias) {
    return $LedgerSyncStateTable(attachedDatabase, alias);
  }
}

class LedgerSyncStateData extends DataClass
    implements Insertable<LedgerSyncStateData> {
  final String scope;

  /// 'tracking' | 'envelope'; for the phone's own scope, the user's choice.
  final String? budgetMode;
  final int? lastPulledAt;

  /// The backend's change-log cursor (Phase 0).
  final String? cursorEpoch;
  final int? cursorLastId;
  const LedgerSyncStateData({
    required this.scope,
    this.budgetMode,
    this.lastPulledAt,
    this.cursorEpoch,
    this.cursorLastId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope'] = Variable<String>(scope);
    if (!nullToAbsent || budgetMode != null) {
      map['budget_mode'] = Variable<String>(budgetMode);
    }
    if (!nullToAbsent || lastPulledAt != null) {
      map['last_pulled_at'] = Variable<int>(lastPulledAt);
    }
    if (!nullToAbsent || cursorEpoch != null) {
      map['cursor_epoch'] = Variable<String>(cursorEpoch);
    }
    if (!nullToAbsent || cursorLastId != null) {
      map['cursor_last_id'] = Variable<int>(cursorLastId);
    }
    return map;
  }

  LedgerSyncStateCompanion toCompanion(bool nullToAbsent) {
    return LedgerSyncStateCompanion(
      scope: Value(scope),
      budgetMode: budgetMode == null && nullToAbsent
          ? const Value.absent()
          : Value(budgetMode),
      lastPulledAt: lastPulledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPulledAt),
      cursorEpoch: cursorEpoch == null && nullToAbsent
          ? const Value.absent()
          : Value(cursorEpoch),
      cursorLastId: cursorLastId == null && nullToAbsent
          ? const Value.absent()
          : Value(cursorLastId),
    );
  }

  factory LedgerSyncStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LedgerSyncStateData(
      scope: serializer.fromJson<String>(json['scope']),
      budgetMode: serializer.fromJson<String?>(json['budgetMode']),
      lastPulledAt: serializer.fromJson<int?>(json['lastPulledAt']),
      cursorEpoch: serializer.fromJson<String?>(json['cursorEpoch']),
      cursorLastId: serializer.fromJson<int?>(json['cursorLastId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scope': serializer.toJson<String>(scope),
      'budgetMode': serializer.toJson<String?>(budgetMode),
      'lastPulledAt': serializer.toJson<int?>(lastPulledAt),
      'cursorEpoch': serializer.toJson<String?>(cursorEpoch),
      'cursorLastId': serializer.toJson<int?>(cursorLastId),
    };
  }

  LedgerSyncStateData copyWith({
    String? scope,
    Value<String?> budgetMode = const Value.absent(),
    Value<int?> lastPulledAt = const Value.absent(),
    Value<String?> cursorEpoch = const Value.absent(),
    Value<int?> cursorLastId = const Value.absent(),
  }) => LedgerSyncStateData(
    scope: scope ?? this.scope,
    budgetMode: budgetMode.present ? budgetMode.value : this.budgetMode,
    lastPulledAt: lastPulledAt.present ? lastPulledAt.value : this.lastPulledAt,
    cursorEpoch: cursorEpoch.present ? cursorEpoch.value : this.cursorEpoch,
    cursorLastId: cursorLastId.present ? cursorLastId.value : this.cursorLastId,
  );
  LedgerSyncStateData copyWithCompanion(LedgerSyncStateCompanion data) {
    return LedgerSyncStateData(
      scope: data.scope.present ? data.scope.value : this.scope,
      budgetMode: data.budgetMode.present
          ? data.budgetMode.value
          : this.budgetMode,
      lastPulledAt: data.lastPulledAt.present
          ? data.lastPulledAt.value
          : this.lastPulledAt,
      cursorEpoch: data.cursorEpoch.present
          ? data.cursorEpoch.value
          : this.cursorEpoch,
      cursorLastId: data.cursorLastId.present
          ? data.cursorLastId.value
          : this.cursorLastId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LedgerSyncStateData(')
          ..write('scope: $scope, ')
          ..write('budgetMode: $budgetMode, ')
          ..write('lastPulledAt: $lastPulledAt, ')
          ..write('cursorEpoch: $cursorEpoch, ')
          ..write('cursorLastId: $cursorLastId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(scope, budgetMode, lastPulledAt, cursorEpoch, cursorLastId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LedgerSyncStateData &&
          other.scope == this.scope &&
          other.budgetMode == this.budgetMode &&
          other.lastPulledAt == this.lastPulledAt &&
          other.cursorEpoch == this.cursorEpoch &&
          other.cursorLastId == this.cursorLastId);
}

class LedgerSyncStateCompanion extends UpdateCompanion<LedgerSyncStateData> {
  final Value<String> scope;
  final Value<String?> budgetMode;
  final Value<int?> lastPulledAt;
  final Value<String?> cursorEpoch;
  final Value<int?> cursorLastId;
  final Value<int> rowid;
  const LedgerSyncStateCompanion({
    this.scope = const Value.absent(),
    this.budgetMode = const Value.absent(),
    this.lastPulledAt = const Value.absent(),
    this.cursorEpoch = const Value.absent(),
    this.cursorLastId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LedgerSyncStateCompanion.insert({
    required String scope,
    this.budgetMode = const Value.absent(),
    this.lastPulledAt = const Value.absent(),
    this.cursorEpoch = const Value.absent(),
    this.cursorLastId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : scope = Value(scope);
  static Insertable<LedgerSyncStateData> custom({
    Expression<String>? scope,
    Expression<String>? budgetMode,
    Expression<int>? lastPulledAt,
    Expression<String>? cursorEpoch,
    Expression<int>? cursorLastId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scope != null) 'scope': scope,
      if (budgetMode != null) 'budget_mode': budgetMode,
      if (lastPulledAt != null) 'last_pulled_at': lastPulledAt,
      if (cursorEpoch != null) 'cursor_epoch': cursorEpoch,
      if (cursorLastId != null) 'cursor_last_id': cursorLastId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LedgerSyncStateCompanion copyWith({
    Value<String>? scope,
    Value<String?>? budgetMode,
    Value<int?>? lastPulledAt,
    Value<String?>? cursorEpoch,
    Value<int?>? cursorLastId,
    Value<int>? rowid,
  }) {
    return LedgerSyncStateCompanion(
      scope: scope ?? this.scope,
      budgetMode: budgetMode ?? this.budgetMode,
      lastPulledAt: lastPulledAt ?? this.lastPulledAt,
      cursorEpoch: cursorEpoch ?? this.cursorEpoch,
      cursorLastId: cursorLastId ?? this.cursorLastId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (budgetMode.present) {
      map['budget_mode'] = Variable<String>(budgetMode.value);
    }
    if (lastPulledAt.present) {
      map['last_pulled_at'] = Variable<int>(lastPulledAt.value);
    }
    if (cursorEpoch.present) {
      map['cursor_epoch'] = Variable<String>(cursorEpoch.value);
    }
    if (cursorLastId.present) {
      map['cursor_last_id'] = Variable<int>(cursorLastId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LedgerSyncStateCompanion(')
          ..write('scope: $scope, ')
          ..write('budgetMode: $budgetMode, ')
          ..write('lastPulledAt: $lastPulledAt, ')
          ..write('cursorEpoch: $cursorEpoch, ')
          ..write('cursorLastId: $cursorLastId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LedgerCategoriesTable extends LedgerCategories
    with TableInfo<$LedgerCategoriesTable, LedgerCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LedgerCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
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
  static const VerificationMeta _sortMeta = const VerificationMeta('sort');
  @override
  late final GeneratedColumn<int> sort = GeneratedColumn<int>(
    'sort',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  );
  static const VerificationMeta _groupNameMeta = const VerificationMeta(
    'groupName',
  );
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
    'group_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIsIncomeMeta = const VerificationMeta(
    'groupIsIncome',
  );
  @override
  late final GeneratedColumn<bool> groupIsIncome = GeneratedColumn<bool>(
    'group_is_income',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("group_is_income" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _groupHiddenMeta = const VerificationMeta(
    'groupHidden',
  );
  @override
  late final GeneratedColumn<bool> groupHidden = GeneratedColumn<bool>(
    'group_hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("group_hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _groupSortMeta = const VerificationMeta(
    'groupSort',
  );
  @override
  late final GeneratedColumn<int> groupSort = GeneratedColumn<int>(
    'group_sort',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    scope,
    id,
    name,
    hidden,
    sort,
    groupId,
    groupName,
    groupIsIncome,
    groupHidden,
    groupSort,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ledger_categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<LedgerCategory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
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
    if (data.containsKey('hidden')) {
      context.handle(
        _hiddenMeta,
        hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta),
      );
    }
    if (data.containsKey('sort')) {
      context.handle(
        _sortMeta,
        sort.isAcceptableOrUnknown(data['sort']!, _sortMeta),
      );
    } else if (isInserting) {
      context.missing(_sortMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('group_name')) {
      context.handle(
        _groupNameMeta,
        groupName.isAcceptableOrUnknown(data['group_name']!, _groupNameMeta),
      );
    } else if (isInserting) {
      context.missing(_groupNameMeta);
    }
    if (data.containsKey('group_is_income')) {
      context.handle(
        _groupIsIncomeMeta,
        groupIsIncome.isAcceptableOrUnknown(
          data['group_is_income']!,
          _groupIsIncomeMeta,
        ),
      );
    }
    if (data.containsKey('group_hidden')) {
      context.handle(
        _groupHiddenMeta,
        groupHidden.isAcceptableOrUnknown(
          data['group_hidden']!,
          _groupHiddenMeta,
        ),
      );
    }
    if (data.containsKey('group_sort')) {
      context.handle(
        _groupSortMeta,
        groupSort.isAcceptableOrUnknown(data['group_sort']!, _groupSortMeta),
      );
    } else if (isInserting) {
      context.missing(_groupSortMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scope, id};
  @override
  LedgerCategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LedgerCategory(
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      hidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hidden'],
      )!,
      sort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      groupName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_name'],
      )!,
      groupIsIncome: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}group_is_income'],
      )!,
      groupHidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}group_hidden'],
      )!,
      groupSort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}group_sort'],
      )!,
    );
  }

  @override
  $LedgerCategoriesTable createAlias(String alias) {
    return $LedgerCategoriesTable(attachedDatabase, alias);
  }
}

class LedgerCategory extends DataClass implements Insertable<LedgerCategory> {
  final String scope;
  final String id;
  final String name;
  final bool hidden;
  final int sort;
  final String groupId;
  final String groupName;
  final bool groupIsIncome;
  final bool groupHidden;
  final int groupSort;
  const LedgerCategory({
    required this.scope,
    required this.id,
    required this.name,
    required this.hidden,
    required this.sort,
    required this.groupId,
    required this.groupName,
    required this.groupIsIncome,
    required this.groupHidden,
    required this.groupSort,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope'] = Variable<String>(scope);
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['hidden'] = Variable<bool>(hidden);
    map['sort'] = Variable<int>(sort);
    map['group_id'] = Variable<String>(groupId);
    map['group_name'] = Variable<String>(groupName);
    map['group_is_income'] = Variable<bool>(groupIsIncome);
    map['group_hidden'] = Variable<bool>(groupHidden);
    map['group_sort'] = Variable<int>(groupSort);
    return map;
  }

  LedgerCategoriesCompanion toCompanion(bool nullToAbsent) {
    return LedgerCategoriesCompanion(
      scope: Value(scope),
      id: Value(id),
      name: Value(name),
      hidden: Value(hidden),
      sort: Value(sort),
      groupId: Value(groupId),
      groupName: Value(groupName),
      groupIsIncome: Value(groupIsIncome),
      groupHidden: Value(groupHidden),
      groupSort: Value(groupSort),
    );
  }

  factory LedgerCategory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LedgerCategory(
      scope: serializer.fromJson<String>(json['scope']),
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      hidden: serializer.fromJson<bool>(json['hidden']),
      sort: serializer.fromJson<int>(json['sort']),
      groupId: serializer.fromJson<String>(json['groupId']),
      groupName: serializer.fromJson<String>(json['groupName']),
      groupIsIncome: serializer.fromJson<bool>(json['groupIsIncome']),
      groupHidden: serializer.fromJson<bool>(json['groupHidden']),
      groupSort: serializer.fromJson<int>(json['groupSort']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scope': serializer.toJson<String>(scope),
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'hidden': serializer.toJson<bool>(hidden),
      'sort': serializer.toJson<int>(sort),
      'groupId': serializer.toJson<String>(groupId),
      'groupName': serializer.toJson<String>(groupName),
      'groupIsIncome': serializer.toJson<bool>(groupIsIncome),
      'groupHidden': serializer.toJson<bool>(groupHidden),
      'groupSort': serializer.toJson<int>(groupSort),
    };
  }

  LedgerCategory copyWith({
    String? scope,
    String? id,
    String? name,
    bool? hidden,
    int? sort,
    String? groupId,
    String? groupName,
    bool? groupIsIncome,
    bool? groupHidden,
    int? groupSort,
  }) => LedgerCategory(
    scope: scope ?? this.scope,
    id: id ?? this.id,
    name: name ?? this.name,
    hidden: hidden ?? this.hidden,
    sort: sort ?? this.sort,
    groupId: groupId ?? this.groupId,
    groupName: groupName ?? this.groupName,
    groupIsIncome: groupIsIncome ?? this.groupIsIncome,
    groupHidden: groupHidden ?? this.groupHidden,
    groupSort: groupSort ?? this.groupSort,
  );
  LedgerCategory copyWithCompanion(LedgerCategoriesCompanion data) {
    return LedgerCategory(
      scope: data.scope.present ? data.scope.value : this.scope,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
      sort: data.sort.present ? data.sort.value : this.sort,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      groupName: data.groupName.present ? data.groupName.value : this.groupName,
      groupIsIncome: data.groupIsIncome.present
          ? data.groupIsIncome.value
          : this.groupIsIncome,
      groupHidden: data.groupHidden.present
          ? data.groupHidden.value
          : this.groupHidden,
      groupSort: data.groupSort.present ? data.groupSort.value : this.groupSort,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LedgerCategory(')
          ..write('scope: $scope, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('hidden: $hidden, ')
          ..write('sort: $sort, ')
          ..write('groupId: $groupId, ')
          ..write('groupName: $groupName, ')
          ..write('groupIsIncome: $groupIsIncome, ')
          ..write('groupHidden: $groupHidden, ')
          ..write('groupSort: $groupSort')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    scope,
    id,
    name,
    hidden,
    sort,
    groupId,
    groupName,
    groupIsIncome,
    groupHidden,
    groupSort,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LedgerCategory &&
          other.scope == this.scope &&
          other.id == this.id &&
          other.name == this.name &&
          other.hidden == this.hidden &&
          other.sort == this.sort &&
          other.groupId == this.groupId &&
          other.groupName == this.groupName &&
          other.groupIsIncome == this.groupIsIncome &&
          other.groupHidden == this.groupHidden &&
          other.groupSort == this.groupSort);
}

class LedgerCategoriesCompanion extends UpdateCompanion<LedgerCategory> {
  final Value<String> scope;
  final Value<String> id;
  final Value<String> name;
  final Value<bool> hidden;
  final Value<int> sort;
  final Value<String> groupId;
  final Value<String> groupName;
  final Value<bool> groupIsIncome;
  final Value<bool> groupHidden;
  final Value<int> groupSort;
  final Value<int> rowid;
  const LedgerCategoriesCompanion({
    this.scope = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.hidden = const Value.absent(),
    this.sort = const Value.absent(),
    this.groupId = const Value.absent(),
    this.groupName = const Value.absent(),
    this.groupIsIncome = const Value.absent(),
    this.groupHidden = const Value.absent(),
    this.groupSort = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LedgerCategoriesCompanion.insert({
    required String scope,
    required String id,
    required String name,
    this.hidden = const Value.absent(),
    required int sort,
    required String groupId,
    required String groupName,
    this.groupIsIncome = const Value.absent(),
    this.groupHidden = const Value.absent(),
    required int groupSort,
    this.rowid = const Value.absent(),
  }) : scope = Value(scope),
       id = Value(id),
       name = Value(name),
       sort = Value(sort),
       groupId = Value(groupId),
       groupName = Value(groupName),
       groupSort = Value(groupSort);
  static Insertable<LedgerCategory> custom({
    Expression<String>? scope,
    Expression<String>? id,
    Expression<String>? name,
    Expression<bool>? hidden,
    Expression<int>? sort,
    Expression<String>? groupId,
    Expression<String>? groupName,
    Expression<bool>? groupIsIncome,
    Expression<bool>? groupHidden,
    Expression<int>? groupSort,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scope != null) 'scope': scope,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (hidden != null) 'hidden': hidden,
      if (sort != null) 'sort': sort,
      if (groupId != null) 'group_id': groupId,
      if (groupName != null) 'group_name': groupName,
      if (groupIsIncome != null) 'group_is_income': groupIsIncome,
      if (groupHidden != null) 'group_hidden': groupHidden,
      if (groupSort != null) 'group_sort': groupSort,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LedgerCategoriesCompanion copyWith({
    Value<String>? scope,
    Value<String>? id,
    Value<String>? name,
    Value<bool>? hidden,
    Value<int>? sort,
    Value<String>? groupId,
    Value<String>? groupName,
    Value<bool>? groupIsIncome,
    Value<bool>? groupHidden,
    Value<int>? groupSort,
    Value<int>? rowid,
  }) {
    return LedgerCategoriesCompanion(
      scope: scope ?? this.scope,
      id: id ?? this.id,
      name: name ?? this.name,
      hidden: hidden ?? this.hidden,
      sort: sort ?? this.sort,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      groupIsIncome: groupIsIncome ?? this.groupIsIncome,
      groupHidden: groupHidden ?? this.groupHidden,
      groupSort: groupSort ?? this.groupSort,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (sort.present) {
      map['sort'] = Variable<int>(sort.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (groupName.present) {
      map['group_name'] = Variable<String>(groupName.value);
    }
    if (groupIsIncome.present) {
      map['group_is_income'] = Variable<bool>(groupIsIncome.value);
    }
    if (groupHidden.present) {
      map['group_hidden'] = Variable<bool>(groupHidden.value);
    }
    if (groupSort.present) {
      map['group_sort'] = Variable<int>(groupSort.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LedgerCategoriesCompanion(')
          ..write('scope: $scope, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('hidden: $hidden, ')
          ..write('sort: $sort, ')
          ..write('groupId: $groupId, ')
          ..write('groupName: $groupName, ')
          ..write('groupIsIncome: $groupIsIncome, ')
          ..write('groupHidden: $groupHidden, ')
          ..write('groupSort: $groupSort, ')
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
  late final $LedgerAccountsTable ledgerAccounts = $LedgerAccountsTable(this);
  late final $LedgerPayeesTable ledgerPayees = $LedgerPayeesTable(this);
  late final $LedgerTransactionsTable ledgerTransactions =
      $LedgerTransactionsTable(this);
  late final $LedgerBudgetsTable ledgerBudgets = $LedgerBudgetsTable(this);
  late final $LedgerOutboxTable ledgerOutbox = $LedgerOutboxTable(this);
  late final $LedgerSyncStateTable ledgerSyncState = $LedgerSyncStateTable(
    this,
  );
  late final $LedgerCategoriesTable ledgerCategories = $LedgerCategoriesTable(
    this,
  );
  late final Index ledgerTransactionsAccountDate = Index(
    'ledger_transactions_account_date',
    'CREATE INDEX ledger_transactions_account_date ON ledger_transactions (account_id, date)',
  );
  late final Index ledgerTransactionsScopeDate = Index(
    'ledger_transactions_scope_date',
    'CREATE INDEX ledger_transactions_scope_date ON ledger_transactions (scope, date)',
  );
  late final Index ledgerTransactionsAccountImported = Index(
    'ledger_transactions_account_imported',
    'CREATE INDEX ledger_transactions_account_imported ON ledger_transactions (account_id, imported_id)',
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
    ledgerAccounts,
    ledgerPayees,
    ledgerTransactions,
    ledgerBudgets,
    ledgerOutbox,
    ledgerSyncState,
    ledgerCategories,
    ledgerTransactionsAccountDate,
    ledgerTransactionsScopeDate,
    ledgerTransactionsAccountImported,
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
typedef $$LedgerAccountsTableCreateCompanionBuilder =
    LedgerAccountsCompanion Function({
      required String id,
      required String scope,
      required String name,
      Value<bool> offBudget,
      Value<bool> closed,
      required int sort,
      Value<String?> bankId,
      required int updatedAt,
      Value<bool> deleted,
      Value<int> rowid,
    });
typedef $$LedgerAccountsTableUpdateCompanionBuilder =
    LedgerAccountsCompanion Function({
      Value<String> id,
      Value<String> scope,
      Value<String> name,
      Value<bool> offBudget,
      Value<bool> closed,
      Value<int> sort,
      Value<String?> bankId,
      Value<int> updatedAt,
      Value<bool> deleted,
      Value<int> rowid,
    });

final class $$LedgerAccountsTableReferences
    extends BaseReferences<_$AppDatabase, $LedgerAccountsTable, LedgerAccount> {
  $$LedgerAccountsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$LedgerTransactionsTable, List<LedgerTransaction>>
  _ledgerTransactionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.ledgerTransactions,
        aliasName: 'ledger_accounts__id__ledger_transactions__account_id',
      );

  $$LedgerTransactionsTableProcessedTableManager get ledgerTransactionsRefs {
    final manager = $$LedgerTransactionsTableTableManager(
      $_db,
      $_db.ledgerTransactions,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _ledgerTransactionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LedgerAccountsTableFilterComposer
    extends Composer<_$AppDatabase, $LedgerAccountsTable> {
  $$LedgerAccountsTableFilterComposer({
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

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get offBudget => $composableBuilder(
    column: $table.offBudget,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get closed => $composableBuilder(
    column: $table.closed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bankId => $composableBuilder(
    column: $table.bankId,
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

  Expression<bool> ledgerTransactionsRefs(
    Expression<bool> Function($$LedgerTransactionsTableFilterComposer f) f,
  ) {
    final $$LedgerTransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.ledgerTransactions,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LedgerTransactionsTableFilterComposer(
            $db: $db,
            $table: $db.ledgerTransactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LedgerAccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $LedgerAccountsTable> {
  $$LedgerAccountsTableOrderingComposer({
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

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get offBudget => $composableBuilder(
    column: $table.offBudget,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get closed => $composableBuilder(
    column: $table.closed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bankId => $composableBuilder(
    column: $table.bankId,
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
}

class $$LedgerAccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LedgerAccountsTable> {
  $$LedgerAccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get offBudget =>
      $composableBuilder(column: $table.offBudget, builder: (column) => column);

  GeneratedColumn<bool> get closed =>
      $composableBuilder(column: $table.closed, builder: (column) => column);

  GeneratedColumn<int> get sort =>
      $composableBuilder(column: $table.sort, builder: (column) => column);

  GeneratedColumn<String> get bankId =>
      $composableBuilder(column: $table.bankId, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  Expression<T> ledgerTransactionsRefs<T extends Object>(
    Expression<T> Function($$LedgerTransactionsTableAnnotationComposer a) f,
  ) {
    final $$LedgerTransactionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.ledgerTransactions,
          getReferencedColumn: (t) => t.accountId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LedgerTransactionsTableAnnotationComposer(
                $db: $db,
                $table: $db.ledgerTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$LedgerAccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LedgerAccountsTable,
          LedgerAccount,
          $$LedgerAccountsTableFilterComposer,
          $$LedgerAccountsTableOrderingComposer,
          $$LedgerAccountsTableAnnotationComposer,
          $$LedgerAccountsTableCreateCompanionBuilder,
          $$LedgerAccountsTableUpdateCompanionBuilder,
          (LedgerAccount, $$LedgerAccountsTableReferences),
          LedgerAccount,
          PrefetchHooks Function({bool ledgerTransactionsRefs})
        > {
  $$LedgerAccountsTableTableManager(
    _$AppDatabase db,
    $LedgerAccountsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LedgerAccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LedgerAccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LedgerAccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> offBudget = const Value.absent(),
                Value<bool> closed = const Value.absent(),
                Value<int> sort = const Value.absent(),
                Value<String?> bankId = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LedgerAccountsCompanion(
                id: id,
                scope: scope,
                name: name,
                offBudget: offBudget,
                closed: closed,
                sort: sort,
                bankId: bankId,
                updatedAt: updatedAt,
                deleted: deleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String scope,
                required String name,
                Value<bool> offBudget = const Value.absent(),
                Value<bool> closed = const Value.absent(),
                required int sort,
                Value<String?> bankId = const Value.absent(),
                required int updatedAt,
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LedgerAccountsCompanion.insert(
                id: id,
                scope: scope,
                name: name,
                offBudget: offBudget,
                closed: closed,
                sort: sort,
                bankId: bankId,
                updatedAt: updatedAt,
                deleted: deleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LedgerAccountsTable, LedgerAccount>(table),
                  $$LedgerAccountsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({ledgerTransactionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (ledgerTransactionsRefs) db.ledgerTransactions,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (ledgerTransactionsRefs)
                    await $_getPrefetchedDataByColumns<
                      LedgerAccount,
                      $LedgerAccountsTable,
                      LedgerTransaction,
                      $LedgerTransactionsTable
                    >(
                      currentTable: table,
                      referencedTable: $$LedgerAccountsTableReferences
                          ._ledgerTransactionsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LedgerAccountsTableReferences(
                            db,
                            table,
                            p0,
                          ).ledgerTransactionsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'account_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LedgerAccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LedgerAccountsTable,
      LedgerAccount,
      $$LedgerAccountsTableFilterComposer,
      $$LedgerAccountsTableOrderingComposer,
      $$LedgerAccountsTableAnnotationComposer,
      $$LedgerAccountsTableCreateCompanionBuilder,
      $$LedgerAccountsTableUpdateCompanionBuilder,
      (LedgerAccount, $$LedgerAccountsTableReferences),
      LedgerAccount,
      PrefetchHooks Function({bool ledgerTransactionsRefs})
    >;
typedef $$LedgerPayeesTableCreateCompanionBuilder =
    LedgerPayeesCompanion Function({
      required String id,
      required String scope,
      required String name,
      Value<String?> transferAccountId,
      required int updatedAt,
      Value<bool> deleted,
      Value<int> rowid,
    });
typedef $$LedgerPayeesTableUpdateCompanionBuilder =
    LedgerPayeesCompanion Function({
      Value<String> id,
      Value<String> scope,
      Value<String> name,
      Value<String?> transferAccountId,
      Value<int> updatedAt,
      Value<bool> deleted,
      Value<int> rowid,
    });

class $$LedgerPayeesTableFilterComposer
    extends Composer<_$AppDatabase, $LedgerPayeesTable> {
  $$LedgerPayeesTableFilterComposer({
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

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transferAccountId => $composableBuilder(
    column: $table.transferAccountId,
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
}

class $$LedgerPayeesTableOrderingComposer
    extends Composer<_$AppDatabase, $LedgerPayeesTable> {
  $$LedgerPayeesTableOrderingComposer({
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

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transferAccountId => $composableBuilder(
    column: $table.transferAccountId,
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
}

class $$LedgerPayeesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LedgerPayeesTable> {
  $$LedgerPayeesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get transferAccountId => $composableBuilder(
    column: $table.transferAccountId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);
}

class $$LedgerPayeesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LedgerPayeesTable,
          LedgerPayee,
          $$LedgerPayeesTableFilterComposer,
          $$LedgerPayeesTableOrderingComposer,
          $$LedgerPayeesTableAnnotationComposer,
          $$LedgerPayeesTableCreateCompanionBuilder,
          $$LedgerPayeesTableUpdateCompanionBuilder,
          (
            LedgerPayee,
            BaseReferences<_$AppDatabase, $LedgerPayeesTable, LedgerPayee>,
          ),
          LedgerPayee,
          PrefetchHooks Function()
        > {
  $$LedgerPayeesTableTableManager(_$AppDatabase db, $LedgerPayeesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LedgerPayeesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LedgerPayeesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LedgerPayeesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> transferAccountId = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LedgerPayeesCompanion(
                id: id,
                scope: scope,
                name: name,
                transferAccountId: transferAccountId,
                updatedAt: updatedAt,
                deleted: deleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String scope,
                required String name,
                Value<String?> transferAccountId = const Value.absent(),
                required int updatedAt,
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LedgerPayeesCompanion.insert(
                id: id,
                scope: scope,
                name: name,
                transferAccountId: transferAccountId,
                updatedAt: updatedAt,
                deleted: deleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LedgerPayeesTable, LedgerPayee>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LedgerPayeesTable,
                    LedgerPayee
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LedgerPayeesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LedgerPayeesTable,
      LedgerPayee,
      $$LedgerPayeesTableFilterComposer,
      $$LedgerPayeesTableOrderingComposer,
      $$LedgerPayeesTableAnnotationComposer,
      $$LedgerPayeesTableCreateCompanionBuilder,
      $$LedgerPayeesTableUpdateCompanionBuilder,
      (
        LedgerPayee,
        BaseReferences<_$AppDatabase, $LedgerPayeesTable, LedgerPayee>,
      ),
      LedgerPayee,
      PrefetchHooks Function()
    >;
typedef $$LedgerTransactionsTableCreateCompanionBuilder =
    LedgerTransactionsCompanion Function({
      required String id,
      required String scope,
      required String accountId,
      required String date,
      required int amountCents,
      Value<String?> payeeId,
      Value<String?> categoryId,
      Value<String?> notes,
      Value<bool> cleared,
      Value<String?> importedId,
      Value<bool> startingBalance,
      Value<String?> transferId,
      Value<String?> parentId,
      Value<bool> isParent,
      required int createdAt,
      required int updatedAt,
      Value<bool> deleted,
      Value<int> rowid,
    });
typedef $$LedgerTransactionsTableUpdateCompanionBuilder =
    LedgerTransactionsCompanion Function({
      Value<String> id,
      Value<String> scope,
      Value<String> accountId,
      Value<String> date,
      Value<int> amountCents,
      Value<String?> payeeId,
      Value<String?> categoryId,
      Value<String?> notes,
      Value<bool> cleared,
      Value<String?> importedId,
      Value<bool> startingBalance,
      Value<String?> transferId,
      Value<String?> parentId,
      Value<bool> isParent,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<bool> deleted,
      Value<int> rowid,
    });

final class $$LedgerTransactionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $LedgerTransactionsTable,
          LedgerTransaction
        > {
  $$LedgerTransactionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LedgerAccountsTable _accountIdTable(_$AppDatabase db) => db
      .ledgerAccounts
      .createAlias('ledger_transactions__account_id__ledger_accounts__id');

  $$LedgerAccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('account_id')!;

    final manager = $$LedgerAccountsTableTableManager(
      $_db,
      $_db.ledgerAccounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LedgerTransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $LedgerTransactionsTable> {
  $$LedgerTransactionsTableFilterComposer({
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

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payeeId => $composableBuilder(
    column: $table.payeeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get cleared => $composableBuilder(
    column: $table.cleared,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importedId => $composableBuilder(
    column: $table.importedId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get startingBalance => $composableBuilder(
    column: $table.startingBalance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transferId => $composableBuilder(
    column: $table.transferId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isParent => $composableBuilder(
    column: $table.isParent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
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

  $$LedgerAccountsTableFilterComposer get accountId {
    final $$LedgerAccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.ledgerAccounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LedgerAccountsTableFilterComposer(
            $db: $db,
            $table: $db.ledgerAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LedgerTransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $LedgerTransactionsTable> {
  $$LedgerTransactionsTableOrderingComposer({
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

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payeeId => $composableBuilder(
    column: $table.payeeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get cleared => $composableBuilder(
    column: $table.cleared,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importedId => $composableBuilder(
    column: $table.importedId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get startingBalance => $composableBuilder(
    column: $table.startingBalance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transferId => $composableBuilder(
    column: $table.transferId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isParent => $composableBuilder(
    column: $table.isParent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
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

  $$LedgerAccountsTableOrderingComposer get accountId {
    final $$LedgerAccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.ledgerAccounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LedgerAccountsTableOrderingComposer(
            $db: $db,
            $table: $db.ledgerAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LedgerTransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LedgerTransactionsTable> {
  $$LedgerTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payeeId =>
      $composableBuilder(column: $table.payeeId, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<bool> get cleared =>
      $composableBuilder(column: $table.cleared, builder: (column) => column);

  GeneratedColumn<String> get importedId => $composableBuilder(
    column: $table.importedId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get startingBalance => $composableBuilder(
    column: $table.startingBalance,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transferId => $composableBuilder(
    column: $table.transferId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<bool> get isParent =>
      $composableBuilder(column: $table.isParent, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  $$LedgerAccountsTableAnnotationComposer get accountId {
    final $$LedgerAccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.ledgerAccounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LedgerAccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.ledgerAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LedgerTransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LedgerTransactionsTable,
          LedgerTransaction,
          $$LedgerTransactionsTableFilterComposer,
          $$LedgerTransactionsTableOrderingComposer,
          $$LedgerTransactionsTableAnnotationComposer,
          $$LedgerTransactionsTableCreateCompanionBuilder,
          $$LedgerTransactionsTableUpdateCompanionBuilder,
          (LedgerTransaction, $$LedgerTransactionsTableReferences),
          LedgerTransaction,
          PrefetchHooks Function({bool accountId})
        > {
  $$LedgerTransactionsTableTableManager(
    _$AppDatabase db,
    $LedgerTransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LedgerTransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LedgerTransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LedgerTransactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<int> amountCents = const Value.absent(),
                Value<String?> payeeId = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<bool> cleared = const Value.absent(),
                Value<String?> importedId = const Value.absent(),
                Value<bool> startingBalance = const Value.absent(),
                Value<String?> transferId = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<bool> isParent = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LedgerTransactionsCompanion(
                id: id,
                scope: scope,
                accountId: accountId,
                date: date,
                amountCents: amountCents,
                payeeId: payeeId,
                categoryId: categoryId,
                notes: notes,
                cleared: cleared,
                importedId: importedId,
                startingBalance: startingBalance,
                transferId: transferId,
                parentId: parentId,
                isParent: isParent,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deleted: deleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String scope,
                required String accountId,
                required String date,
                required int amountCents,
                Value<String?> payeeId = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<bool> cleared = const Value.absent(),
                Value<String?> importedId = const Value.absent(),
                Value<bool> startingBalance = const Value.absent(),
                Value<String?> transferId = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<bool> isParent = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LedgerTransactionsCompanion.insert(
                id: id,
                scope: scope,
                accountId: accountId,
                date: date,
                amountCents: amountCents,
                payeeId: payeeId,
                categoryId: categoryId,
                notes: notes,
                cleared: cleared,
                importedId: importedId,
                startingBalance: startingBalance,
                transferId: transferId,
                parentId: parentId,
                isParent: isParent,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deleted: deleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LedgerTransactionsTable, LedgerTransaction>(
                    table,
                  ),
                  $$LedgerTransactionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({accountId = false}) {
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
                    if (accountId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.accountId,
                        referencedTable: $$LedgerTransactionsTableReferences
                            ._accountIdTable(db),
                        referencedColumn: $$LedgerTransactionsTableReferences
                            ._accountIdTable(db)
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

typedef $$LedgerTransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LedgerTransactionsTable,
      LedgerTransaction,
      $$LedgerTransactionsTableFilterComposer,
      $$LedgerTransactionsTableOrderingComposer,
      $$LedgerTransactionsTableAnnotationComposer,
      $$LedgerTransactionsTableCreateCompanionBuilder,
      $$LedgerTransactionsTableUpdateCompanionBuilder,
      (LedgerTransaction, $$LedgerTransactionsTableReferences),
      LedgerTransaction,
      PrefetchHooks Function({bool accountId})
    >;
typedef $$LedgerBudgetsTableCreateCompanionBuilder =
    LedgerBudgetsCompanion Function({
      required String scope,
      required String categoryId,
      required String month,
      required int budgetedCents,
      Value<bool> carryover,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$LedgerBudgetsTableUpdateCompanionBuilder =
    LedgerBudgetsCompanion Function({
      Value<String> scope,
      Value<String> categoryId,
      Value<String> month,
      Value<int> budgetedCents,
      Value<bool> carryover,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$LedgerBudgetsTableFilterComposer
    extends Composer<_$AppDatabase, $LedgerBudgetsTable> {
  $$LedgerBudgetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get budgetedCents => $composableBuilder(
    column: $table.budgetedCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get carryover => $composableBuilder(
    column: $table.carryover,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LedgerBudgetsTableOrderingComposer
    extends Composer<_$AppDatabase, $LedgerBudgetsTable> {
  $$LedgerBudgetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get budgetedCents => $composableBuilder(
    column: $table.budgetedCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get carryover => $composableBuilder(
    column: $table.carryover,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LedgerBudgetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LedgerBudgetsTable> {
  $$LedgerBudgetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get month =>
      $composableBuilder(column: $table.month, builder: (column) => column);

  GeneratedColumn<int> get budgetedCents => $composableBuilder(
    column: $table.budgetedCents,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get carryover =>
      $composableBuilder(column: $table.carryover, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LedgerBudgetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LedgerBudgetsTable,
          LedgerBudget,
          $$LedgerBudgetsTableFilterComposer,
          $$LedgerBudgetsTableOrderingComposer,
          $$LedgerBudgetsTableAnnotationComposer,
          $$LedgerBudgetsTableCreateCompanionBuilder,
          $$LedgerBudgetsTableUpdateCompanionBuilder,
          (
            LedgerBudget,
            BaseReferences<_$AppDatabase, $LedgerBudgetsTable, LedgerBudget>,
          ),
          LedgerBudget,
          PrefetchHooks Function()
        > {
  $$LedgerBudgetsTableTableManager(_$AppDatabase db, $LedgerBudgetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LedgerBudgetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LedgerBudgetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LedgerBudgetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> scope = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<String> month = const Value.absent(),
                Value<int> budgetedCents = const Value.absent(),
                Value<bool> carryover = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LedgerBudgetsCompanion(
                scope: scope,
                categoryId: categoryId,
                month: month,
                budgetedCents: budgetedCents,
                carryover: carryover,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String scope,
                required String categoryId,
                required String month,
                required int budgetedCents,
                Value<bool> carryover = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LedgerBudgetsCompanion.insert(
                scope: scope,
                categoryId: categoryId,
                month: month,
                budgetedCents: budgetedCents,
                carryover: carryover,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LedgerBudgetsTable, LedgerBudget>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LedgerBudgetsTable,
                    LedgerBudget
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LedgerBudgetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LedgerBudgetsTable,
      LedgerBudget,
      $$LedgerBudgetsTableFilterComposer,
      $$LedgerBudgetsTableOrderingComposer,
      $$LedgerBudgetsTableAnnotationComposer,
      $$LedgerBudgetsTableCreateCompanionBuilder,
      $$LedgerBudgetsTableUpdateCompanionBuilder,
      (
        LedgerBudget,
        BaseReferences<_$AppDatabase, $LedgerBudgetsTable, LedgerBudget>,
      ),
      LedgerBudget,
      PrefetchHooks Function()
    >;
typedef $$LedgerOutboxTableCreateCompanionBuilder =
    LedgerOutboxCompanion Function({
      Value<int> seq,
      required String scope,
      required String kind,
      required String rowId,
      required String op,
      required int createdAt,
      Value<int> attempts,
      Value<String?> lastError,
    });
typedef $$LedgerOutboxTableUpdateCompanionBuilder =
    LedgerOutboxCompanion Function({
      Value<int> seq,
      Value<String> scope,
      Value<String> kind,
      Value<String> rowId,
      Value<String> op,
      Value<int> createdAt,
      Value<int> attempts,
      Value<String?> lastError,
    });

class $$LedgerOutboxTableFilterComposer
    extends Composer<_$AppDatabase, $LedgerOutboxTable> {
  $$LedgerOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LedgerOutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $LedgerOutboxTable> {
  $$LedgerOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LedgerOutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $LedgerOutboxTable> {
  $$LedgerOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$LedgerOutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LedgerOutboxTable,
          LedgerOutboxData,
          $$LedgerOutboxTableFilterComposer,
          $$LedgerOutboxTableOrderingComposer,
          $$LedgerOutboxTableAnnotationComposer,
          $$LedgerOutboxTableCreateCompanionBuilder,
          $$LedgerOutboxTableUpdateCompanionBuilder,
          (
            LedgerOutboxData,
            BaseReferences<_$AppDatabase, $LedgerOutboxTable, LedgerOutboxData>,
          ),
          LedgerOutboxData,
          PrefetchHooks Function()
        > {
  $$LedgerOutboxTableTableManager(_$AppDatabase db, $LedgerOutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LedgerOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LedgerOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LedgerOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> rowId = const Value.absent(),
                Value<String> op = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => LedgerOutboxCompanion(
                seq: seq,
                scope: scope,
                kind: kind,
                rowId: rowId,
                op: op,
                createdAt: createdAt,
                attempts: attempts,
                lastError: lastError,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String scope,
                required String kind,
                required String rowId,
                required String op,
                required int createdAt,
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => LedgerOutboxCompanion.insert(
                seq: seq,
                scope: scope,
                kind: kind,
                rowId: rowId,
                op: op,
                createdAt: createdAt,
                attempts: attempts,
                lastError: lastError,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LedgerOutboxTable, LedgerOutboxData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LedgerOutboxTable,
                    LedgerOutboxData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LedgerOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LedgerOutboxTable,
      LedgerOutboxData,
      $$LedgerOutboxTableFilterComposer,
      $$LedgerOutboxTableOrderingComposer,
      $$LedgerOutboxTableAnnotationComposer,
      $$LedgerOutboxTableCreateCompanionBuilder,
      $$LedgerOutboxTableUpdateCompanionBuilder,
      (
        LedgerOutboxData,
        BaseReferences<_$AppDatabase, $LedgerOutboxTable, LedgerOutboxData>,
      ),
      LedgerOutboxData,
      PrefetchHooks Function()
    >;
typedef $$LedgerSyncStateTableCreateCompanionBuilder =
    LedgerSyncStateCompanion Function({
      required String scope,
      Value<String?> budgetMode,
      Value<int?> lastPulledAt,
      Value<String?> cursorEpoch,
      Value<int?> cursorLastId,
      Value<int> rowid,
    });
typedef $$LedgerSyncStateTableUpdateCompanionBuilder =
    LedgerSyncStateCompanion Function({
      Value<String> scope,
      Value<String?> budgetMode,
      Value<int?> lastPulledAt,
      Value<String?> cursorEpoch,
      Value<int?> cursorLastId,
      Value<int> rowid,
    });

class $$LedgerSyncStateTableFilterComposer
    extends Composer<_$AppDatabase, $LedgerSyncStateTable> {
  $$LedgerSyncStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get budgetMode => $composableBuilder(
    column: $table.budgetMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPulledAt => $composableBuilder(
    column: $table.lastPulledAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cursorEpoch => $composableBuilder(
    column: $table.cursorEpoch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cursorLastId => $composableBuilder(
    column: $table.cursorLastId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LedgerSyncStateTableOrderingComposer
    extends Composer<_$AppDatabase, $LedgerSyncStateTable> {
  $$LedgerSyncStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get budgetMode => $composableBuilder(
    column: $table.budgetMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPulledAt => $composableBuilder(
    column: $table.lastPulledAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cursorEpoch => $composableBuilder(
    column: $table.cursorEpoch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cursorLastId => $composableBuilder(
    column: $table.cursorLastId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LedgerSyncStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $LedgerSyncStateTable> {
  $$LedgerSyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get budgetMode => $composableBuilder(
    column: $table.budgetMode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastPulledAt => $composableBuilder(
    column: $table.lastPulledAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cursorEpoch => $composableBuilder(
    column: $table.cursorEpoch,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cursorLastId => $composableBuilder(
    column: $table.cursorLastId,
    builder: (column) => column,
  );
}

class $$LedgerSyncStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LedgerSyncStateTable,
          LedgerSyncStateData,
          $$LedgerSyncStateTableFilterComposer,
          $$LedgerSyncStateTableOrderingComposer,
          $$LedgerSyncStateTableAnnotationComposer,
          $$LedgerSyncStateTableCreateCompanionBuilder,
          $$LedgerSyncStateTableUpdateCompanionBuilder,
          (
            LedgerSyncStateData,
            BaseReferences<
              _$AppDatabase,
              $LedgerSyncStateTable,
              LedgerSyncStateData
            >,
          ),
          LedgerSyncStateData,
          PrefetchHooks Function()
        > {
  $$LedgerSyncStateTableTableManager(
    _$AppDatabase db,
    $LedgerSyncStateTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LedgerSyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LedgerSyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LedgerSyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> scope = const Value.absent(),
                Value<String?> budgetMode = const Value.absent(),
                Value<int?> lastPulledAt = const Value.absent(),
                Value<String?> cursorEpoch = const Value.absent(),
                Value<int?> cursorLastId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LedgerSyncStateCompanion(
                scope: scope,
                budgetMode: budgetMode,
                lastPulledAt: lastPulledAt,
                cursorEpoch: cursorEpoch,
                cursorLastId: cursorLastId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String scope,
                Value<String?> budgetMode = const Value.absent(),
                Value<int?> lastPulledAt = const Value.absent(),
                Value<String?> cursorEpoch = const Value.absent(),
                Value<int?> cursorLastId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LedgerSyncStateCompanion.insert(
                scope: scope,
                budgetMode: budgetMode,
                lastPulledAt: lastPulledAt,
                cursorEpoch: cursorEpoch,
                cursorLastId: cursorLastId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LedgerSyncStateTable, LedgerSyncStateData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $LedgerSyncStateTable,
                    LedgerSyncStateData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LedgerSyncStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LedgerSyncStateTable,
      LedgerSyncStateData,
      $$LedgerSyncStateTableFilterComposer,
      $$LedgerSyncStateTableOrderingComposer,
      $$LedgerSyncStateTableAnnotationComposer,
      $$LedgerSyncStateTableCreateCompanionBuilder,
      $$LedgerSyncStateTableUpdateCompanionBuilder,
      (
        LedgerSyncStateData,
        BaseReferences<
          _$AppDatabase,
          $LedgerSyncStateTable,
          LedgerSyncStateData
        >,
      ),
      LedgerSyncStateData,
      PrefetchHooks Function()
    >;
typedef $$LedgerCategoriesTableCreateCompanionBuilder =
    LedgerCategoriesCompanion Function({
      required String scope,
      required String id,
      required String name,
      Value<bool> hidden,
      required int sort,
      required String groupId,
      required String groupName,
      Value<bool> groupIsIncome,
      Value<bool> groupHidden,
      required int groupSort,
      Value<int> rowid,
    });
typedef $$LedgerCategoriesTableUpdateCompanionBuilder =
    LedgerCategoriesCompanion Function({
      Value<String> scope,
      Value<String> id,
      Value<String> name,
      Value<bool> hidden,
      Value<int> sort,
      Value<String> groupId,
      Value<String> groupName,
      Value<bool> groupIsIncome,
      Value<bool> groupHidden,
      Value<int> groupSort,
      Value<int> rowid,
    });

class $$LedgerCategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $LedgerCategoriesTable> {
  $$LedgerCategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get groupIsIncome => $composableBuilder(
    column: $table.groupIsIncome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get groupHidden => $composableBuilder(
    column: $table.groupHidden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get groupSort => $composableBuilder(
    column: $table.groupSort,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LedgerCategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $LedgerCategoriesTable> {
  $$LedgerCategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get groupIsIncome => $composableBuilder(
    column: $table.groupIsIncome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get groupHidden => $composableBuilder(
    column: $table.groupHidden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get groupSort => $composableBuilder(
    column: $table.groupSort,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LedgerCategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LedgerCategoriesTable> {
  $$LedgerCategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);

  GeneratedColumn<int> get sort =>
      $composableBuilder(column: $table.sort, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get groupName =>
      $composableBuilder(column: $table.groupName, builder: (column) => column);

  GeneratedColumn<bool> get groupIsIncome => $composableBuilder(
    column: $table.groupIsIncome,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get groupHidden => $composableBuilder(
    column: $table.groupHidden,
    builder: (column) => column,
  );

  GeneratedColumn<int> get groupSort =>
      $composableBuilder(column: $table.groupSort, builder: (column) => column);
}

class $$LedgerCategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LedgerCategoriesTable,
          LedgerCategory,
          $$LedgerCategoriesTableFilterComposer,
          $$LedgerCategoriesTableOrderingComposer,
          $$LedgerCategoriesTableAnnotationComposer,
          $$LedgerCategoriesTableCreateCompanionBuilder,
          $$LedgerCategoriesTableUpdateCompanionBuilder,
          (
            LedgerCategory,
            BaseReferences<
              _$AppDatabase,
              $LedgerCategoriesTable,
              LedgerCategory
            >,
          ),
          LedgerCategory,
          PrefetchHooks Function()
        > {
  $$LedgerCategoriesTableTableManager(
    _$AppDatabase db,
    $LedgerCategoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LedgerCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LedgerCategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LedgerCategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> scope = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<int> sort = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<String> groupName = const Value.absent(),
                Value<bool> groupIsIncome = const Value.absent(),
                Value<bool> groupHidden = const Value.absent(),
                Value<int> groupSort = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LedgerCategoriesCompanion(
                scope: scope,
                id: id,
                name: name,
                hidden: hidden,
                sort: sort,
                groupId: groupId,
                groupName: groupName,
                groupIsIncome: groupIsIncome,
                groupHidden: groupHidden,
                groupSort: groupSort,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String scope,
                required String id,
                required String name,
                Value<bool> hidden = const Value.absent(),
                required int sort,
                required String groupId,
                required String groupName,
                Value<bool> groupIsIncome = const Value.absent(),
                Value<bool> groupHidden = const Value.absent(),
                required int groupSort,
                Value<int> rowid = const Value.absent(),
              }) => LedgerCategoriesCompanion.insert(
                scope: scope,
                id: id,
                name: name,
                hidden: hidden,
                sort: sort,
                groupId: groupId,
                groupName: groupName,
                groupIsIncome: groupIsIncome,
                groupHidden: groupHidden,
                groupSort: groupSort,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LedgerCategoriesTable, LedgerCategory>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LedgerCategoriesTable,
                    LedgerCategory
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LedgerCategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LedgerCategoriesTable,
      LedgerCategory,
      $$LedgerCategoriesTableFilterComposer,
      $$LedgerCategoriesTableOrderingComposer,
      $$LedgerCategoriesTableAnnotationComposer,
      $$LedgerCategoriesTableCreateCompanionBuilder,
      $$LedgerCategoriesTableUpdateCompanionBuilder,
      (
        LedgerCategory,
        BaseReferences<_$AppDatabase, $LedgerCategoriesTable, LedgerCategory>,
      ),
      LedgerCategory,
      PrefetchHooks Function()
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
  $$LedgerAccountsTableTableManager get ledgerAccounts =>
      $$LedgerAccountsTableTableManager(_db, _db.ledgerAccounts);
  $$LedgerPayeesTableTableManager get ledgerPayees =>
      $$LedgerPayeesTableTableManager(_db, _db.ledgerPayees);
  $$LedgerTransactionsTableTableManager get ledgerTransactions =>
      $$LedgerTransactionsTableTableManager(_db, _db.ledgerTransactions);
  $$LedgerBudgetsTableTableManager get ledgerBudgets =>
      $$LedgerBudgetsTableTableManager(_db, _db.ledgerBudgets);
  $$LedgerOutboxTableTableManager get ledgerOutbox =>
      $$LedgerOutboxTableTableManager(_db, _db.ledgerOutbox);
  $$LedgerSyncStateTableTableManager get ledgerSyncState =>
      $$LedgerSyncStateTableTableManager(_db, _db.ledgerSyncState);
  $$LedgerCategoriesTableTableManager get ledgerCategories =>
      $$LedgerCategoriesTableTableManager(_db, _db.ledgerCategories);
}
