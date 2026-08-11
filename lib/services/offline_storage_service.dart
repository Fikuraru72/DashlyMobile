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
      version: 4,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createTables(db);
      },
    );
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS race_summaries (
        eventId INTEGER PRIMARY KEY,
        eventName TEXT,
        elapsedDurationSeconds INTEGER,
        totalDistanceKm REAL,
        avgSpeedKmh REAL,
        maxSpeedKmh REAL,
        elevationGainM REAL,
        finalRank INTEGER,
        totalParticipants INTEGER,
        updatedAt TEXT
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

  static Future<void> saveRaceSummary({
    required int eventId,
    required String eventName,
    required Duration elapsedDuration,
    required double totalDistanceKm,
    required double avgSpeedKmh,
    required double maxSpeedKmh,
    required double elevationGainM,
    int finalRank = 0,
    int totalParticipants = 0,
  }) async {
    final db = await database;
    await db.insert(
      'race_summaries',
      {
        'eventId': eventId,
        'eventName': eventName,
        'elapsedDurationSeconds': elapsedDuration.inSeconds,
        'totalDistanceKm': totalDistanceKm,
        'avgSpeedKmh': avgSpeedKmh,
        'maxSpeedKmh': maxSpeedKmh,
        'elevationGainM': elevationGainM,
        'finalRank': finalRank,
        'totalParticipants': totalParticipants,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print('💾 [OfflineStorage] Saved race summary locally for eventId: $eventId');
  }

  static Future<Map<String, dynamic>?> getRaceSummary(int eventId) async {
    try {
      final db = await database;
      final results = await db.query('race_summaries', where: 'eventId = ?', whereArgs: [eventId]);
      if (results.isNotEmpty) {
        return results.first;
      }
    } catch (e) {
      print('OfflineStorage: Failed to fetch race summary: $e');
    }
    return null;
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
