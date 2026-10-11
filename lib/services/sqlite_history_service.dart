import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/match_record.dart';

class SqliteHistoryService {
  static SqliteHistoryService? _instance;
  factory SqliteHistoryService() {
    _instance ??= SqliteHistoryService._();
    return _instance!;
  }
  SqliteHistoryService._();

  static const String _dbName = 'game_history.db';
  static const int _dbVersion = 1;
  static const String _tableName = 'matches';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        winnerLabel TEXT NOT NULL,
        playerNames TEXT NOT NULL,
        playerIsAI TEXT NOT NULL,
        playedAt TEXT NOT NULL,
        stars INTEGER NOT NULL DEFAULT 1,
        statusText TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('CREATE INDEX idx_playedAt ON $_tableName(playedAt DESC)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Future migrations can be added here
    }
  }

  Future<int> insertMatchRecord(MatchRecord record) async {
    final db = await database;
    return await db.insert(_tableName, record.toJson());
  }

  Future<List<MatchRecord>> getAllMatches({int limit = 200}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      orderBy: 'playedAt DESC',
      limit: limit,
    );

    return maps.map((map) => MatchRecord.fromJson(map)).toList();
  }

  Future<MatchRecord?> getMatchById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return MatchRecord.fromJson(maps.first);
  }

  Future<int> deleteMatchRecord(int id) async {
    final db = await database;
    return await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> clearAllHistory() async {
    final db = await database;
    return await db.delete(_tableName);
  }

  Future<int> getHistoryCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  Future<void> migrateFromSharedPrefs(List<MatchRecord> records) async {
    final db = await database;
    final batch = db.batch();
    for (final record in records) {
      batch.insert(_tableName, record.toJson());
    }
    await batch.commit(noResult: true);
  }
}