import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalDb {
  LocalDb._();

  static final LocalDb instance = LocalDb._();
  Database? _db;

  Future<void> init() async {
    if (_db != null) return;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'invest_system.db');
    _db = await openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        await _createTables(db);
        await _ensureColumns(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createTables(db);
        await _ensureColumns(db);
      },
    );
  }

  Future<void> _createTables(Database db) async {
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
  }

  Future<void> _ensureColumns(Database db) async {
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
  }

  Future<void> _addColumnIfMissing(
    Database db,
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
    final rows = await _db!.query(
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
    final rows = await _db!.query(
      table,
      where: ownerUid == null ? 'id = ?' : 'id = ? AND owner_uid = ?',
      whereArgs: ownerUid == null ? [id] : [id, ownerUid],
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> upsert(String table, Map<String, Object?> data) async {
    await _db!.insert(
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
    final rows = await _db!.query(
      table,
      where: all ? 'dirty = 1' : 'dirty = 1 AND owner_uid = ?',
      whereArgs: all ? null : [ownerUid],
    );
    return rows;
  }

  Future<void> markClean(String table, String id) async {
    await _db!.update(
      table,
      {'dirty': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(String table, String id) async {
    await _db!.delete(
      table,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> claimUnowned(String table, String ownerUid) async {
    await _db!.update(
      table,
      {'owner_uid': ownerUid},
      where: "owner_uid = ''",
    );
  }
}
