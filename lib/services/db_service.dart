import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/reading.dart';

class DBService {
  double baseLoad(String ch) {
    switch (ch) {
      case 'GF_SOCKETS':
        return 200;
      case 'FF_SOCKETS':
        return 300;
      case 'GF_LIGHTS':
        return 40;
      case 'FF_LIGHTS':
        return 30;
      default:
        return 100;
    }
  }

  static final DBService instance = DBService._();
  DBService._();

  static Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ecowatt.db');
    print('EcoWatt DB path: $path');

    return openDatabase(
      path,
      version: 2,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE readings(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            channel TEXT NOT NULL,
            ts TEXT NOT NULL,
            currentA REAL NOT NULL,
            powerW REAL NOT NULL,
            alertType TEXT NOT NULL
          )
        ''');

        await database.execute('''
          CREATE TABLE monthly_bills(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            month INTEGER NOT NULL,
            year INTEGER NOT NULL,
            energyKwh REAL NOT NULL,
            estimatedRs REAL NOT NULL,
            createdAt TEXT NOT NULL,
            UNIQUE(month, year)
          )
        ''');
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await database.execute('''
            CREATE TABLE IF NOT EXISTS monthly_bills(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              month INTEGER NOT NULL,
              year INTEGER NOT NULL,
              energyKwh REAL NOT NULL,
              estimatedRs REAL NOT NULL,
              createdAt TEXT NOT NULL,
              UNIQUE(month, year)
            )
          ''');
        }
      },
    );
  }

  Future<void> insertReading(Reading r) async {
    final database = await db;
    await database.insert('readings', r.toMap());
  }

  Future<List<Reading>> latestReadings({int limit = 200}) async {
    final database = await db;
    final rows = await database.query(
      'readings',
      orderBy: 'ts DESC',
      limit: limit,
    );
    return rows.map((m) => Reading.fromMap(m)).toList();
  }

  Future<List<Reading>> readingsSince(DateTime since,
      {int limit = 4000}) async {
    final database = await db;
    final sinceIso = since.toIso8601String();

    final rows = await database.query(
      'readings',
      where: 'ts >= ?',
      whereArgs: [sinceIso],
      orderBy: 'ts ASC',
      limit: limit,
    );

    return rows.map((m) => Reading.fromMap(m)).toList();
  }

  Future<Map<String, double>> sumPowerByChannelSince(DateTime since) async {
    final database = await db;
    final sinceIso = since.toIso8601String();

    final rows = await database.rawQuery('''
      SELECT channel, SUM(powerW) AS sumP
      FROM readings
      WHERE ts >= ?
      GROUP BY channel
    ''', [sinceIso]);

    final out = <String, double>{};
    for (final r in rows) {
      final ch = r['channel'] as String;
      final sumP = (r['sumP'] as num?)?.toDouble() ?? 0.0;
      out[ch] = sumP;
    }
    return out;
  }

  Future<List<Reading>> readingsBetween(DateTime start, DateTime end) async {
    final database = await db;

    final startIso = start.toIso8601String();
    final endIso = end.toIso8601String();

    final rows = await database.query(
      'readings',
      where: 'ts >= ? AND ts < ?',
      whereArgs: [startIso, endIso],
      orderBy: 'ts ASC',
    );

    return rows.map((m) => Reading.fromMap(m)).toList();
  }

  Future<List<Reading>> getAllReadings() async {
    final database = await db;

    final rows = await database.query(
      'readings',
      orderBy: 'ts DESC',
    );

    return rows.map((m) => Reading.fromMap(m)).toList();
  }

  Future<void> upsertMonthlyBill({
    required int month,
    required int year,
    required double energyKwh,
    required double estimatedRs,
  }) async {
    final database = await db;

    await database.insert(
      'monthly_bills',
      {
        'month': month,
        'year': year,
        'energyKwh': energyKwh,
        'estimatedRs': estimatedRs,
        'createdAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MonthlyBill>> getLast12MonthlyBills() async {
    final database = await db;

    final rows = await database.query(
      'monthly_bills',
      orderBy: 'year ASC, month ASC',
    );

    final bills = rows.map((m) => MonthlyBill.fromMap(m)).toList();

    if (bills.length <= 12) return bills;

    return bills.sublist(bills.length - 12);
  }

  Future<int> countMonthlyBills() async {
    final database = await db;

    final result = await database.rawQuery(
      'SELECT COUNT(*) AS count FROM monthly_bills',
    );

    return (result.first['count'] as int?) ?? 0;
  }

  Future<void> clearReadings() async {
    final database = await db;
    await database.delete('readings');
  }
}

class MonthlyBill {
  final int month;
  final int year;
  final double energyKwh;
  final double estimatedRs;

  MonthlyBill({
    required this.month,
    required this.year,
    required this.energyKwh,
    required this.estimatedRs,
  });

  factory MonthlyBill.fromMap(Map<String, Object?> map) {
    return MonthlyBill(
      month: map['month'] as int,
      year: map['year'] as int,
      energyKwh: (map['energyKwh'] as num).toDouble(),
      estimatedRs: (map['estimatedRs'] as num).toDouble(),
    );
  }
}
