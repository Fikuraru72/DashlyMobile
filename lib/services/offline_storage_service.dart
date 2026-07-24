import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:battery_plus/battery_plus.dart';

class OfflineStorageService {
  static Database? _database;
  static const String tableName = 'offline_locations';
  static final Battery _battery = Battery();

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final path = join(docsDir.path, 'dashly_offline.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await _createTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await db.execute('DROP TABLE IF EXISTS $tableName');
        await _createTable(db);
      },
    );
  }

  static Future<void> _createTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableName (
        msg_id TEXT PRIMARY KEY,
        eventId INTEGER,
        userId INTEGER,
        lat REAL,
        lng REAL,
        speed REAL,
        altitude REAL,
        status TEXT,
        isAnomaly INTEGER,
        captured_at TEXT,
        battery INTEGER
      )
    ''');
  }

  static Future<void> saveLocation({
    required String msgId,
    required int eventId,
    required int userId,
    required double lat,
    required double lng,
    required double speed,
    required double altitude,
    required String status,
    required bool isAnomaly,
    required DateTime timestamp,
  }) async {
    final db = await database;
    int? batteryLevel;
    try {
      batteryLevel = await _battery.batteryLevel;
    } catch (e) {
      print('OfflineStorage: Failed to get battery level: $e');
    }

    await db.insert(
      tableName,
      {
        'msg_id': msgId,
        'eventId': eventId,
        'userId': userId,
        'lat': lat,
        'lng': lng,
        'speed': speed,
        'altitude': altitude,
        'status': status,
        'isAnomaly': isAnomaly ? 1 : 0,
        'captured_at': timestamp.toIso8601String(),
        if (batteryLevel != null) 'battery': batteryLevel,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print('💾 [OfflineStorage] Saved location locally. Waiting for connection...');
  }

  static Future<List<Map<String, dynamic>>> getOfflineLocations() async {
    final db = await database;
    return await db.query(tableName, orderBy: 'captured_at ASC');
  }

  static Future<void> clearOfflineLocations() async {
    final db = await database;
    await db.delete(tableName);
    print('🧹 [OfflineStorage] Cleared synchronized data.');
  }
}
