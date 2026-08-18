import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/entities/history_stats.dart';
import '../../domain/entities/transcription_record.dart';
import '../../domain/repositories/history_repository.dart';

class HistoryRepositoryImpl implements HistoryRepository {
  static const _historyFileName = 'history.json';
  static const _statsFileName = 'history_stats.json';
  static const _audioDirName = 'history_audio';

  Future<Directory> _appSupportDir() async => getApplicationSupportDirectory();

  Future<File> _historyFile() async {
    final dir = await _appSupportDir();
    return File('${dir.path}/$_historyFileName');
  }

  Future<File> _statsFile() async {
    final dir = await _appSupportDir();
    return File('${dir.path}/$_statsFileName');
  }

  Future<Directory> _audioDir() async {
    final dir = await _appSupportDir();
    final audioDir = Directory('${dir.path}/$_audioDirName');
    if (!audioDir.existsSync()) audioDir.createSync(recursive: true);
    return audioDir;
  }

  @override
  Future<List<TranscriptionRecord>> getRecords() async {
    final file = await _historyFile();
    if (!file.existsSync()) return [];
    try {
      final raw = await file.readAsString();
      final list = jsonDecode(raw) as List<dynamic>;
      final records = list
          .map((e) => TranscriptionRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      // Newest first
      records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return records;
    } catch (e) {
      print('[HistoryRepository] Failed to parse history.json: $e');
      return [];
    }
  }

  Future<void> _saveRecords(List<TranscriptionRecord> records) async {
    final file = await _historyFile();
    final json = jsonEncode(records.map((r) => r.toJson()).toList());
    await file.writeAsString(json);
  }

  @override
  Future<void> addRecord(TranscriptionRecord record) async {
    final records = await getRecords();
    // Insert at front (already sorted newest-first from getRecords)
    records.insert(0, record);
    await _saveRecords(records);
  }

  @override
  Future<void> deleteRecord(String id) async {
    final records = await getRecords();
    final target = records.firstWhere(
      (r) => r.id == id,
      orElse: () => throw StateError('Record $id not found'),
    );
    // Delete audio file if it exists
    if (target.audioPath != null) {
      final f = File(target.audioPath!);
      if (f.existsSync()) await f.delete();
    }
    records.removeWhere((r) => r.id == id);
    await _saveRecords(records);
  }

  @override
  Future<void> clearAll() async {
    final records = await getRecords();
    for (final r in records) {
      if (r.audioPath != null) {
        final f = File(r.audioPath!);
        if (f.existsSync()) await f.delete();
      }
    }
    final file = await _historyFile();
    if (file.existsSync()) await file.delete();
    // Remove audio dir contents but keep dir
    final audioDir = await _audioDir();
    if (audioDir.existsSync()) {
      for (final entry in audioDir.listSync()) {
        await entry.delete();
      }
    }
    await resetStats();
  }

  @override
  Future<void> purgeExpiredRecords(int retentionDays) async {
    final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
    final records = await getRecords();
    final expired = records.where((r) => r.createdAt.isBefore(cutoff)).toList();
    if (expired.isEmpty) return;

    for (final r in expired) {
      if (r.audioPath != null) {
        final f = File(r.audioPath!);
        if (f.existsSync()) await f.delete();
      }
    }
    final remaining = records
        .where((r) => r.createdAt.isAfter(cutoff) || r.createdAt == cutoff)
        .toList();
    await _saveRecords(remaining);
    print('[HistoryRepository] Purged ${expired.length} expired records.');
  }

  @override
  Future<String?> moveAudioFile(String srcPath) async {
    final srcFile = File(srcPath);
    if (!srcFile.existsSync()) return null;

    final audioDir = await _audioDir();
    final filename = srcFile.uri.pathSegments.last;
    final destPath = '${audioDir.path}/$filename';

    try {
      await srcFile.rename(destPath);
    } catch (_) {
      // Cross-filesystem fallback
      await srcFile.copy(destPath);
      await srcFile.delete();
    }
    return destPath;
  }

  @override
  Future<HistoryStats> getStats() async {
    final file = await _statsFile();
    if (!file.existsSync()) return HistoryStats.zero;
    try {
      final raw = await file.readAsString();
      return HistoryStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return HistoryStats.zero;
    }
  }

  @override
  Future<void> accumulateStats(TranscriptionRecord record) async {
    final current = await getStats();
    final updated = current.addRecord(record.costUsd);
    final file = await _statsFile();
    await file.writeAsString(jsonEncode(updated.toJson()));
  }

  @override
  Future<void> resetStats() async {
    final file = await _statsFile();
    if (file.existsSync()) await file.delete();
  }
}
