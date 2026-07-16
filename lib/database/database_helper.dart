import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../core/constants.dart';
import '../models/employee.dart';
import '../models/recording_metadata.dart';

/// Singleton wrapper around the local SQLite database.
///
/// Two tables:
///  - `employee`   : local login cache (employeeId, name, password hash)
///  - `recordings` : one row per call recording with full metadata
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);
    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ${AppConstants.tableEmployee} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employeeId TEXT UNIQUE NOT NULL,
        employeeName TEXT NOT NULL,
        password TEXT NOT NULL,
        loginTime TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableRecordings} (
        id TEXT PRIMARY KEY,
        employeeId TEXT NOT NULL,
        employeeName TEXT,
        phoneNumber TEXT,
        callType TEXT NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT,
        duration INTEGER DEFAULT 0,
        latitude REAL,
        longitude REAL,
        address TEXT,
        fileName TEXT NOT NULL,
        recordingPath TEXT NOT NULL,
        uploaded INTEGER DEFAULT 0,
        uploadStatus TEXT DEFAULT 'pending',
        uploadAttempts INTEGER DEFAULT 0
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_recordings_employee ON ${AppConstants.tableRecordings}(employeeId)',
    );
    await db.execute(
      'CREATE INDEX idx_recordings_startTime ON ${AppConstants.tableRecordings}(startTime)',
    );
  }

  // ---------------- Employee ----------------

  Future<int> upsertEmployee(Employee employee) async {
    final db = await database;
    return db.insert(
      AppConstants.tableEmployee,
      employee.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Employee?> getEmployeeById(String employeeId) async {
    final db = await database;
    final rows = await db.query(
      AppConstants.tableEmployee,
      where: 'employeeId = ?',
      whereArgs: [employeeId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Employee.fromMap(rows.first);
  }

  // ---------------- Recordings ----------------

  Future<int> insertRecording(RecordingMetadata metadata) async {
    final db = await database;
    final map = metadata.toMap()..['employeeName'] = metadata.employeeName;
    return db.insert(
      AppConstants.tableRecordings,
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateRecording(RecordingMetadata metadata) async {
    final db = await database;
    return db.update(
      AppConstants.tableRecordings,
      metadata.toMap(),
      where: 'id = ?',
      whereArgs: [metadata.id],
    );
  }

  Future<int> deleteRecording(String id) async {
    final db = await database;
    return db.delete(
      AppConstants.tableRecordings,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<RecordingMetadata>> getRecordings({
    String? employeeId,
    DateTime? fromDate,
    DateTime? toDate,
    UploadStatus? uploadStatus,
    String? searchQuery,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];

    if (employeeId != null) {
      where.add('employeeId = ?');
      args.add(employeeId);
    }
    if (fromDate != null) {
      where.add('startTime >= ?');
      args.add(fromDate.toIso8601String());
    }
    if (toDate != null) {
      where.add('startTime <= ?');
      args.add(toDate.toIso8601String());
    }
    if (uploadStatus != null) {
      where.add('uploadStatus = ?');
      args.add(uploadStatus.name);
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      where.add('(phoneNumber LIKE ? OR fileName LIKE ? OR address LIKE ?)');
      final q = '%${searchQuery.trim()}%';
      args.addAll([q, q, q]);
    }

    final rows = await db.query(
      AppConstants.tableRecordings,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'startTime DESC',
    );

    return rows.map((r) => RecordingMetadata.fromMap(r)).toList();
  }

  Future<List<RecordingMetadata>> getPendingUploads() async {
    final db = await database;
    final rows = await db.query(
      AppConstants.tableRecordings,
      where: 'uploadStatus = ? OR uploadStatus = ?',
      whereArgs: [UploadStatus.pending.name, UploadStatus.failed.name],
    );
    return rows.map((r) => RecordingMetadata.fromMap(r)).toList();
  }
}
