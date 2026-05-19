import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalDb {
  LocalDb._();

  static final LocalDb instance = LocalDb._();
  static const String _appDirectoryName = 'Invest System';
  static const String _databaseDirectoryName = 'database';
  static const String _databaseFileName = 'invest_system.db';
  static const int _databaseVersion = 5;

  Database? _db;
  Future<void>? _initFuture;
  String? _databasePath;
  bool _useMemory = false;
  final Map<String, Map<String, Map<String, Object?>>> _memoryTables = {};

  String? get databasePath => _databasePath;
  Database get database => _requireDb();

  Future<void> init() {
    return _initFuture ??= _initInternal();
  }

  Future<void> _initInternal() async {
    if (_db != null || _useMemory) return;

    if (kIsWeb) {
      _useMemory = true;
      _initMemoryTables();
      _log('Initialized in-memory database for web.');
      return;
    }

    final path = await _resolveDatabasePath();
    _databasePath = path;
    _log('Opening SQLite database at $path');

    try {
      _db = await openDatabase(
        path,
        version: _databaseVersion,
        singleInstance: true,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON;');
        },
        onCreate: (db, version) async {
          _log('Creating SQLite schema version $version');
          await _migrate(db, fromVersion: 0, toVersion: version);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          _log('Upgrading SQLite schema from $oldVersion to $newVersion');
          await _migrate(
            db,
            fromVersion: oldVersion,
            toVersion: newVersion,
          );
        },
        onDowngrade: (db, oldVersion, newVersion) async {
          _log(
            'Database downgrade requested from $oldVersion to $newVersion. '
            'Keeping schema and ensuring required tables/columns exist.',
          );
          await _ensureSchema(db);
        },
        onOpen: (db) async {
          await _ensureSchema(db);
          _log('SQLite database opened successfully.');
        },
      );
    } catch (error, stackTrace) {
      _log(
        'Failed to open SQLite database at $path: $error',
        stackTrace: stackTrace,
      );
      _initFuture = null;
      throw StateError(
        'Failed to open local database at "$path". '
        'Ensure the application can write to the user documents folder. '
        'Original error: $error',
      );
    }
  }

  Future<String> _resolveDatabasePath() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final databaseDirectory = Directory(
      p.join(
        documentsDirectory.path,
        _appDirectoryName,
        _databaseDirectoryName,
      ),
    );

    if (!await databaseDirectory.exists()) {
      await databaseDirectory.create(recursive: true);
      _log('Created SQLite directory: ${databaseDirectory.path}');
    }

    return p.join(databaseDirectory.path, _databaseFileName);
  }

  Future<void> _migrate(
    Database db, {
    required int fromVersion,
    required int toVersion,
  }) async {
    _log('Applying SQLite migrations from $fromVersion to $toVersion');
    await db.transaction((txn) async {
      await _createTables(txn);
      await _ensureColumns(txn);
    });
  }

  Future<void> _ensureSchema(DatabaseExecutor db) async {
    await _createTables(db);
    await _ensureColumns(db);
  }

  void _initMemoryTables() {
    for (final name in const [
      'customers',
      'units',
      'sales',
      'payments',
      'suppliers',
      'purchases',
      'supplier_payments',
      'app_users',
      'app_session',
    ]) {
      _memoryTables.putIfAbsent(name, () => <String, Map<String, Object?>>{});
    }
  }

  Future<void> _createTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id TEXT PRIMARY KEY,
        owner_uid TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        email TEXT NOT NULL,
        company TEXT NOT NULL,
        notes TEXT NOT NULL,
        province TEXT NOT NULL,
        district TEXT NOT NULL,
        address TEXT,
        deleted INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        dirty INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS units (
        id TEXT PRIMARY KEY,
        owner_uid TEXT NOT NULL,
        name TEXT NOT NULL,
        is_active INTEGER NOT NULL,
        deleted INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        dirty INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales (
        id TEXT PRIMARY KEY,
        owner_uid TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        date INTEGER NOT NULL,
        quantity_value REAL NOT NULL,
        unit_id TEXT NOT NULL,
        price_per_unit REAL NOT NULL,
        total_price REAL NOT NULL,
        note TEXT,
        deleted INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        dirty INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payments (
        id TEXT PRIMARY KEY,
        owner_uid TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        sale_id TEXT,
        date INTEGER NOT NULL,
        amount REAL NOT NULL,
        note TEXT,
        deleted INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        dirty INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id TEXT PRIMARY KEY,
        owner_uid TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        province TEXT NOT NULL,
        district TEXT NOT NULL,
        address TEXT,
        deleted INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        dirty INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchases (
        id TEXT PRIMARY KEY,
        owner_uid TEXT NOT NULL,
        supplier_id TEXT NOT NULL,
        date INTEGER NOT NULL,
        quantity_value REAL NOT NULL,
        unit_id TEXT NOT NULL,
        price_per_unit REAL NOT NULL,
        total_price REAL NOT NULL,
        note TEXT,
        deleted INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        dirty INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS supplier_payments (
        id TEXT PRIMARY KEY,
        owner_uid TEXT NOT NULL,
        supplier_id TEXT NOT NULL,
        purchase_id TEXT,
        date INTEGER NOT NULL,
        amount REAL NOT NULL,
        note TEXT,
        deleted INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        dirty INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL,
        permissions_json TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        is_active INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_session (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        current_uid TEXT
      )
    ''');
  }

  Future<void> _ensureColumns(DatabaseExecutor db) async {
    await _addColumnIfMissing(db, 'customers', 'province', "TEXT NOT NULL DEFAULT ''");
    await _addColumnIfMissing(db, 'customers', 'district', "TEXT NOT NULL DEFAULT ''");
    await _addColumnIfMissing(db, 'customers', 'address', 'TEXT');
    await _addColumnIfMissing(db, 'customers', 'email', "TEXT NOT NULL DEFAULT ''");
    await _addColumnIfMissing(db, 'customers', 'company', "TEXT NOT NULL DEFAULT ''");
    await _addColumnIfMissing(db, 'customers', 'notes', "TEXT NOT NULL DEFAULT ''");
    await _addColumnIfMissing(db, 'customers', 'deleted', 'INTEGER NOT NULL DEFAULT 0');

    await _addColumnIfMissing(db, 'units', 'is_active', 'INTEGER NOT NULL DEFAULT 1');
    await _addColumnIfMissing(db, 'units', 'deleted', 'INTEGER NOT NULL DEFAULT 0');

    await _addColumnIfMissing(db, 'sales', 'customer_id', "TEXT NOT NULL DEFAULT ''");
    await _addColumnIfMissing(db, 'sales', 'date', 'INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfMissing(db, 'sales', 'quantity_value', 'REAL NOT NULL DEFAULT 0');
    await _addColumnIfMissing(db, 'sales', 'unit_id', "TEXT NOT NULL DEFAULT ''");
    await _addColumnIfMissing(db, 'sales', 'price_per_unit', 'REAL NOT NULL DEFAULT 0');
    await _addColumnIfMissing(db, 'sales', 'total_price', 'REAL NOT NULL DEFAULT 0');
    await _addColumnIfMissing(db, 'sales', 'note', 'TEXT');
    await _addColumnIfMissing(db, 'sales', 'deleted', 'INTEGER NOT NULL DEFAULT 0');

    await _addColumnIfMissing(db, 'payments', 'customer_id', "TEXT NOT NULL DEFAULT ''");
    await _addColumnIfMissing(db, 'payments', 'sale_id', 'TEXT');
    await _addColumnIfMissing(db, 'payments', 'date', 'INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfMissing(db, 'payments', 'amount', 'REAL NOT NULL DEFAULT 0');
    await _addColumnIfMissing(db, 'payments', 'note', 'TEXT');
    await _addColumnIfMissing(db, 'payments', 'deleted', 'INTEGER NOT NULL DEFAULT 0');

    await _addColumnIfMissing(db, 'suppliers', 'province', "TEXT NOT NULL DEFAULT ''");
    await _addColumnIfMissing(db, 'suppliers', 'district', "TEXT NOT NULL DEFAULT ''");
    await _addColumnIfMissing(db, 'suppliers', 'address', 'TEXT');
    await _addColumnIfMissing(db, 'suppliers', 'deleted', 'INTEGER NOT NULL DEFAULT 0');

    await _addColumnIfMissing(db, 'purchases', 'supplier_id', "TEXT NOT NULL DEFAULT ''");
    await _addColumnIfMissing(db, 'purchases', 'date', 'INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfMissing(db, 'purchases', 'quantity_value', 'REAL NOT NULL DEFAULT 0');
    await _addColumnIfMissing(db, 'purchases', 'unit_id', "TEXT NOT NULL DEFAULT ''");
    await _addColumnIfMissing(db, 'purchases', 'price_per_unit', 'REAL NOT NULL DEFAULT 0');
    await _addColumnIfMissing(db, 'purchases', 'total_price', 'REAL NOT NULL DEFAULT 0');
    await _addColumnIfMissing(db, 'purchases', 'note', 'TEXT');
    await _addColumnIfMissing(db, 'purchases', 'deleted', 'INTEGER NOT NULL DEFAULT 0');

    await _addColumnIfMissing(db, 'supplier_payments', 'supplier_id', "TEXT NOT NULL DEFAULT ''");
    await _addColumnIfMissing(db, 'supplier_payments', 'purchase_id', 'TEXT');
    await _addColumnIfMissing(db, 'supplier_payments', 'date', 'INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfMissing(db, 'supplier_payments', 'amount', 'REAL NOT NULL DEFAULT 0');
    await _addColumnIfMissing(db, 'supplier_payments', 'note', 'TEXT');
    await _addColumnIfMissing(db, 'supplier_payments', 'deleted', 'INTEGER NOT NULL DEFAULT 0');

    await _addColumnIfMissing(db, 'app_users', 'name', "TEXT NOT NULL DEFAULT ''");
    await _addColumnIfMissing(db, 'app_users', 'email', "TEXT NOT NULL DEFAULT ''");
    await _addColumnIfMissing(db, 'app_users', 'password_hash', "TEXT NOT NULL DEFAULT ''");
    await _addColumnIfMissing(db, 'app_users', 'role', "TEXT NOT NULL DEFAULT 'viewer'");
    await _addColumnIfMissing(db, 'app_users', 'permissions_json', "TEXT NOT NULL DEFAULT '{}'");
    await _addColumnIfMissing(db, 'app_users', 'updated_at', 'INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfMissing(db, 'app_users', 'is_active', 'INTEGER NOT NULL DEFAULT 1');
    await _addColumnIfMissing(db, 'app_session', 'current_uid', 'TEXT');
  }

  Future<void> _addColumnIfMissing(
    DatabaseExecutor db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (exists) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  Future<List<Map<String, Object?>>> getAll(
    String table, {
    String? ownerUid,
    bool all = false,
  }) async {
    if (_useMemory) {
      final rows = _memoryTables[table]?.values ?? const Iterable.empty();
      final filtered = rows.where((row) {
        if ((row['deleted'] as int?) == 1) return false;
        if (all) return true;
        return (row['owner_uid'] as String? ?? '') == (ownerUid ?? '');
      }).toList();
      filtered.sort((a, b) {
        final aUpdated = (a['updated_at'] as int?) ?? 0;
        final bUpdated = (b['updated_at'] as int?) ?? 0;
        return bUpdated.compareTo(aUpdated);
      });
      return filtered.map((row) => Map<String, Object?>.from(row)).toList();
    }
    final rows = await _requireDb().query(
      table,
      where: all ? 'deleted = 0' : 'owner_uid = ? AND deleted = 0',
      whereArgs: all ? null : [ownerUid],
      orderBy: 'updated_at DESC',
    );
    return rows;
  }

  Future<Map<String, Object?>?> getById(
    String table,
    String id, {
    String? ownerUid,
  }) async {
    if (_useMemory) {
      final row = _memoryTables[table]?[id];
      if (row == null) return null;
      if (ownerUid != null &&
          (row['owner_uid'] as String? ?? '') != ownerUid) {
        return null;
      }
      return Map<String, Object?>.from(row);
    }
    final rows = await _requireDb().query(
      table,
      where: ownerUid == null ? 'id = ?' : 'id = ? AND owner_uid = ?',
      whereArgs: ownerUid == null ? [id] : [id, ownerUid],
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> upsert(String table, Map<String, Object?> data) async {
    if (_useMemory) {
      final id = data['id'] as String?;
      if (id == null || id.isEmpty) return;
      _memoryTables[table]?[id] = Map<String, Object?>.from(data);
      return;
    }
    await _requireDb().insert(
      table,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> getDirty(
    String table, {
    String? ownerUid,
    bool all = false,
  }) async {
    if (_useMemory) {
      final rows = _memoryTables[table]?.values ?? const Iterable.empty();
      final filtered = rows.where((row) {
        if ((row['dirty'] as int?) != 1) return false;
        if (all) return true;
        return (row['owner_uid'] as String? ?? '') == (ownerUid ?? '');
      }).toList();
      return filtered.map((row) => Map<String, Object?>.from(row)).toList();
    }
    final rows = await _requireDb().query(
      table,
      where: all ? 'dirty = 1' : 'dirty = 1 AND owner_uid = ?',
      whereArgs: all ? null : [ownerUid],
    );
    return rows;
  }

  Future<void> markClean(String table, String id) async {
    if (_useMemory) {
      final row = _memoryTables[table]?[id];
      if (row != null) {
        row['dirty'] = 0;
      }
      return;
    }
    await _requireDb().update(
      table,
      {'dirty': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(String table, String id) async {
    if (_useMemory) {
      _memoryTables[table]?.remove(id);
      return;
    }
    await _requireDb().delete(
      table,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> claimUnowned(String table, String ownerUid) async {
    if (_useMemory) {
      final tableMap = _memoryTables[table];
      if (tableMap == null) return;
      for (final row in tableMap.values) {
        if ((row['owner_uid'] as String? ?? '') == '') {
          row['owner_uid'] = ownerUid;
        }
      }
      return;
    }
    await _requireDb().update(
      table,
      {'owner_uid': ownerUid},
      where: "owner_uid = ''",
    );
  }

  Database _requireDb() {
    final db = _db;
    if (db == null) {
      throw StateError(
        'Local database has not been initialized. Call LocalDb.instance.init() first.',
      );
    }
    return db;
  }

  void _log(String message, {StackTrace? stackTrace}) {
    developer.log(message, name: 'LocalDb', stackTrace: stackTrace);
  }
}
