import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'customer.dart';
import 'product.dart';
import 'vendor.dart';
import 'purchase.dart';

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
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS customers (
            id TEXT PRIMARY KEY,
            owner_uid TEXT NOT NULL,
            name TEXT NOT NULL,
            phone TEXT NOT NULL,
            email TEXT NOT NULL,
            address TEXT NOT NULL,
            company TEXT NOT NULL,
            notes TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            dirty INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS products (
            id TEXT PRIMARY KEY,
            owner_uid TEXT NOT NULL,
            name TEXT NOT NULL,
            sku TEXT NOT NULL,
            category TEXT NOT NULL,
            unit TEXT NOT NULL,
            price REAL NOT NULL,
            cost REAL NOT NULL,
            stock REAL NOT NULL,
            notes TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            dirty INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS vendors (
            id TEXT PRIMARY KEY,
            owner_uid TEXT NOT NULL,
            name TEXT NOT NULL,
            phone TEXT NOT NULL,
            email TEXT NOT NULL,
            address TEXT NOT NULL,
            company TEXT NOT NULL,
            notes TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            dirty INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS purchases (
            id TEXT PRIMARY KEY,
            owner_uid TEXT NOT NULL,
            vendor_name TEXT NOT NULL,
            reference TEXT NOT NULL,
            total REAL NOT NULL,
            status TEXT NOT NULL,
            notes TEXT NOT NULL,
            purchased_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            dirty INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS customers (
            id TEXT PRIMARY KEY,
            owner_uid TEXT NOT NULL,
            name TEXT NOT NULL,
            phone TEXT NOT NULL,
            email TEXT NOT NULL,
            address TEXT NOT NULL,
            company TEXT NOT NULL,
            notes TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            dirty INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS products (
            id TEXT PRIMARY KEY,
            owner_uid TEXT NOT NULL,
            name TEXT NOT NULL,
            sku TEXT NOT NULL,
            category TEXT NOT NULL,
            unit TEXT NOT NULL,
            price REAL NOT NULL,
            cost REAL NOT NULL,
            stock REAL NOT NULL,
            notes TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            dirty INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS vendors (
            id TEXT PRIMARY KEY,
            owner_uid TEXT NOT NULL,
            name TEXT NOT NULL,
            phone TEXT NOT NULL,
            email TEXT NOT NULL,
            address TEXT NOT NULL,
            company TEXT NOT NULL,
            notes TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            dirty INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS purchases (
            id TEXT PRIMARY KEY,
            owner_uid TEXT NOT NULL,
            vendor_name TEXT NOT NULL,
            reference TEXT NOT NULL,
            total REAL NOT NULL,
            status TEXT NOT NULL,
            notes TEXT NOT NULL,
            purchased_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            dirty INTEGER NOT NULL
          )
        ''');
        await _addColumnIfMissing(db, 'customers', 'owner_uid', "TEXT NOT NULL DEFAULT ''");
        await _addColumnIfMissing(db, 'products', 'owner_uid', "TEXT NOT NULL DEFAULT ''");
        await _addColumnIfMissing(db, 'vendors', 'owner_uid', "TEXT NOT NULL DEFAULT ''");
        await _addColumnIfMissing(db, 'purchases', 'owner_uid', "TEXT NOT NULL DEFAULT ''");
      },
    );
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

  Future<List<Customer>> getAllCustomers({
    String? ownerUid,
    bool all = false,
  }) async {
    final rows = await _db!.query(
      'customers',
      where: all ? null : 'owner_uid = ?',
      whereArgs: all ? null : [ownerUid],
      orderBy: 'updated_at DESC',
    );
    return rows.map((row) => Customer.fromMap(row)).toList();
  }

  Future<Customer?> getCustomerById(String id, {String? ownerUid}) async {
    final rows = await _db!.query(
      'customers',
      where: ownerUid == null ? 'id = ?' : 'id = ? AND owner_uid = ?',
      whereArgs: ownerUid == null ? [id] : [id, ownerUid],
    );
    if (rows.isEmpty) return null;
    return Customer.fromMap(rows.first);
  }

  Future<void> upsertCustomer(Customer customer) async {
    await _db!.insert(
      'customers',
      customer.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Customer>> getDirtyCustomers({
    String? ownerUid,
    bool all = false,
  }) async {
    final rows = await _db!.query(
      'customers',
      where: all ? 'dirty = 1' : 'dirty = 1 AND owner_uid = ?',
      whereArgs: all ? null : [ownerUid],
    );
    return rows.map((row) => Customer.fromMap(row)).toList();
  }

  Future<void> markCustomerClean(String id) async {
    await _db!.update(
      'customers',
      {'dirty': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> claimUnownedCustomers(String ownerUid) async {
    await _db!.update(
      'customers',
      {'owner_uid': ownerUid},
      where: "owner_uid = ''",
    );
  }

  Future<List<Product>> getAllProducts({
    String? ownerUid,
    bool all = false,
  }) async {
    final rows = await _db!.query(
      'products',
      where: all ? null : 'owner_uid = ?',
      whereArgs: all ? null : [ownerUid],
      orderBy: 'updated_at DESC',
    );
    return rows.map((row) => Product.fromMap(row)).toList();
  }

  Future<Product?> getProductById(String id, {String? ownerUid}) async {
    final rows = await _db!.query(
      'products',
      where: ownerUid == null ? 'id = ?' : 'id = ? AND owner_uid = ?',
      whereArgs: ownerUid == null ? [id] : [id, ownerUid],
    );
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  Future<void> upsertProduct(Product product) async {
    await _db!.insert(
      'products',
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Product>> getDirtyProducts({
    String? ownerUid,
    bool all = false,
  }) async {
    final rows = await _db!.query(
      'products',
      where: all ? 'dirty = 1' : 'dirty = 1 AND owner_uid = ?',
      whereArgs: all ? null : [ownerUid],
    );
    return rows.map((row) => Product.fromMap(row)).toList();
  }

  Future<void> markProductClean(String id) async {
    await _db!.update(
      'products',
      {'dirty': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> claimUnownedProducts(String ownerUid) async {
    await _db!.update(
      'products',
      {'owner_uid': ownerUid},
      where: "owner_uid = ''",
    );
  }

  Future<List<Vendor>> getAllVendors({
    String? ownerUid,
    bool all = false,
  }) async {
    final rows = await _db!.query(
      'vendors',
      where: all ? null : 'owner_uid = ?',
      whereArgs: all ? null : [ownerUid],
      orderBy: 'updated_at DESC',
    );
    return rows.map((row) => Vendor.fromMap(row)).toList();
  }

  Future<Vendor?> getVendorById(String id, {String? ownerUid}) async {
    final rows = await _db!.query(
      'vendors',
      where: ownerUid == null ? 'id = ?' : 'id = ? AND owner_uid = ?',
      whereArgs: ownerUid == null ? [id] : [id, ownerUid],
    );
    if (rows.isEmpty) return null;
    return Vendor.fromMap(rows.first);
  }

  Future<void> upsertVendor(Vendor vendor) async {
    await _db!.insert(
      'vendors',
      vendor.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Vendor>> getDirtyVendors({
    String? ownerUid,
    bool all = false,
  }) async {
    final rows = await _db!.query(
      'vendors',
      where: all ? 'dirty = 1' : 'dirty = 1 AND owner_uid = ?',
      whereArgs: all ? null : [ownerUid],
    );
    return rows.map((row) => Vendor.fromMap(row)).toList();
  }

  Future<void> markVendorClean(String id) async {
    await _db!.update(
      'vendors',
      {'dirty': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> claimUnownedVendors(String ownerUid) async {
    await _db!.update(
      'vendors',
      {'owner_uid': ownerUid},
      where: "owner_uid = ''",
    );
  }

  Future<List<Purchase>> getAllPurchases({
    String? ownerUid,
    bool all = false,
  }) async {
    final rows = await _db!.query(
      'purchases',
      where: all ? null : 'owner_uid = ?',
      whereArgs: all ? null : [ownerUid],
      orderBy: 'updated_at DESC',
    );
    return rows.map((row) => Purchase.fromMap(row)).toList();
  }

  Future<Purchase?> getPurchaseById(String id, {String? ownerUid}) async {
    final rows = await _db!.query(
      'purchases',
      where: ownerUid == null ? 'id = ?' : 'id = ? AND owner_uid = ?',
      whereArgs: ownerUid == null ? [id] : [id, ownerUid],
    );
    if (rows.isEmpty) return null;
    return Purchase.fromMap(rows.first);
  }

  Future<void> upsertPurchase(Purchase purchase) async {
    await _db!.insert(
      'purchases',
      purchase.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Purchase>> getDirtyPurchases({
    String? ownerUid,
    bool all = false,
  }) async {
    final rows = await _db!.query(
      'purchases',
      where: all ? 'dirty = 1' : 'dirty = 1 AND owner_uid = ?',
      whereArgs: all ? null : [ownerUid],
    );
    return rows.map((row) => Purchase.fromMap(row)).toList();
  }

  Future<void> markPurchaseClean(String id) async {
    await _db!.update(
      'purchases',
      {'dirty': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> claimUnownedPurchases(String ownerUid) async {
    await _db!.update(
      'purchases',
      {'owner_uid': ownerUid},
      where: "owner_uid = ''",
    );
  }
}
