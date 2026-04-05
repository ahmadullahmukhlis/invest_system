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
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS customers (
            id TEXT PRIMARY KEY,
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
    );
  }

  Future<List<Customer>> getAllCustomers() async {
    final rows = await _db!.query('customers', orderBy: 'updated_at DESC');
    return rows.map((row) => Customer.fromMap(row)).toList();
  }

  Future<Customer?> getCustomerById(String id) async {
    final rows =
        await _db!.query('customers', where: 'id = ?', whereArgs: [id]);
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

  Future<List<Customer>> getDirtyCustomers() async {
    final rows = await _db!.query('customers', where: 'dirty = 1');
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

  Future<List<Product>> getAllProducts() async {
    final rows = await _db!.query('products', orderBy: 'updated_at DESC');
    return rows.map((row) => Product.fromMap(row)).toList();
  }

  Future<Product?> getProductById(String id) async {
    final rows =
        await _db!.query('products', where: 'id = ?', whereArgs: [id]);
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

  Future<List<Product>> getDirtyProducts() async {
    final rows = await _db!.query('products', where: 'dirty = 1');
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

  Future<List<Vendor>> getAllVendors() async {
    final rows = await _db!.query('vendors', orderBy: 'updated_at DESC');
    return rows.map((row) => Vendor.fromMap(row)).toList();
  }

  Future<Vendor?> getVendorById(String id) async {
    final rows =
        await _db!.query('vendors', where: 'id = ?', whereArgs: [id]);
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

  Future<List<Vendor>> getDirtyVendors() async {
    final rows = await _db!.query('vendors', where: 'dirty = 1');
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

  Future<List<Purchase>> getAllPurchases() async {
    final rows = await _db!.query('purchases', orderBy: 'updated_at DESC');
    return rows.map((row) => Purchase.fromMap(row)).toList();
  }

  Future<Purchase?> getPurchaseById(String id) async {
    final rows =
        await _db!.query('purchases', where: 'id = ?', whereArgs: [id]);
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

  Future<List<Purchase>> getDirtyPurchases() async {
    final rows = await _db!.query('purchases', where: 'dirty = 1');
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
}
