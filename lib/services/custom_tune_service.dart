import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/alarm_model.dart';

/// Manages user-imported custom MP3 tunes.
/// Files are copied into the app's documents directory so they persist
/// independently of the original file location.
class CustomTuneService {
  static const String _storageKey = 'custom_tunes';
  static const String _tunesDirName = 'custom_tunes';
  static const _uuid = Uuid();

  // ── Get the custom tunes directory ──────────────────────────
  static Future<Directory> _getTunesDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final tunesDir = Directory('${appDir.path}/$_tunesDirName');
    if (!await tunesDir.exists()) {
      await tunesDir.create(recursive: true);
    }
    return tunesDir;
  }

  // ── Load all saved custom tunes ─────────────────────────────
  static Future<List<AlarmTune>> loadCustomTunes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final tunes = jsonList.map((j) => AlarmTune.fromJson(j)).toList();

      // Validate that all files still exist
      final validTunes = <AlarmTune>[];
      for (final tune in tunes) {
        if (await File(tune.assetPath).exists()) {
          validTunes.add(tune);
        }
      }

      // Save back only valid tunes if some were cleaned up
      if (validTunes.length != tunes.length) {
        await _saveTunesList(validTunes);
      }

      return validTunes;
    } catch (e) {
      return [];
    }
  }

  // ── Import an MP3 from the device ───────────────────────────
  static Future<AlarmTune?> importMP3() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'aac', 'm4a', 'ogg'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return null;

      final pickedFile = result.files.first;
      if (pickedFile.path == null) return null;

      final sourceFile = File(pickedFile.path!);
      if (!await sourceFile.exists()) return null;

      // Validate file size (max 10MB)
      final fileSize = await sourceFile.length();
      if (fileSize > 10 * 1024 * 1024) {
        throw Exception('File too large. Maximum size is 10MB.');
      }

      // Generate unique ID and copy file to app storage
      final tuneId = 'custom_${_uuid.v4().replaceAll('-', '').substring(0, 12)}';
      final extension = pickedFile.extension ?? 'mp3';
      final tunesDir = await _getTunesDir();
      final destPath = '${tunesDir.path}/$tuneId.$extension';

      await sourceFile.copy(destPath);

      // Create the tune object
      final tuneName = _cleanFileName(pickedFile.name);
      final tune = AlarmTune(
        id: tuneId,
        name: tuneName,
        assetPath: destPath,
        isCustom: true,
        originalFileName: pickedFile.name,
      );

      // Add to stored list
      final tunes = await loadCustomTunes();
      tunes.add(tune);
      await _saveTunesList(tunes);

      return tune;
    } catch (e) {
      rethrow;
    }
  }

  // ── Import multiple MP3s at once ────────────────────────────
  static Future<List<AlarmTune>> importMultipleMP3s() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'aac', 'm4a', 'ogg'],
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return [];

      final imported = <AlarmTune>[];
      final tunes = await loadCustomTunes();

      for (final pickedFile in result.files) {
        if (pickedFile.path == null) continue;

        final sourceFile = File(pickedFile.path!);
        if (!await sourceFile.exists()) continue;

        final fileSize = await sourceFile.length();
        if (fileSize > 10 * 1024 * 1024) continue; // Skip files > 10MB

        final tuneId =
            'custom_${_uuid.v4().replaceAll('-', '').substring(0, 12)}';
        final extension = pickedFile.extension ?? 'mp3';
        final tunesDir = await _getTunesDir();
        final destPath = '${tunesDir.path}/$tuneId.$extension';

        await sourceFile.copy(destPath);

        final tune = AlarmTune(
          id: tuneId,
          name: _cleanFileName(pickedFile.name),
          assetPath: destPath,
          isCustom: true,
          originalFileName: pickedFile.name,
        );

        tunes.add(tune);
        imported.add(tune);
      }

      await _saveTunesList(tunes);
      return imported;
    } catch (e) {
      return [];
    }
  }

  // ── Rename a custom tune ────────────────────────────────────
  static Future<AlarmTune?> renameTune(String tuneId, String newName) async {
    final tunes = await loadCustomTunes();
    final index = tunes.indexWhere((t) => t.id == tuneId);
    if (index == -1) return null;

    final updated = AlarmTune(
      id: tunes[index].id,
      name: newName.trim(),
      assetPath: tunes[index].assetPath,
      isCustom: true,
      originalFileName: tunes[index].originalFileName,
    );

    tunes[index] = updated;
    await _saveTunesList(tunes);
    return updated;
  }

  // ── Delete a custom tune ────────────────────────────────────
  static Future<bool> deleteTune(String tuneId) async {
    final tunes = await loadCustomTunes();
    final index = tunes.indexWhere((t) => t.id == tuneId);
    if (index == -1) return false;

    // Delete the actual file
    final file = File(tunes[index].assetPath);
    if (await file.exists()) {
      await file.delete();
    }

    tunes.removeAt(index);
    await _saveTunesList(tunes);
    return true;
  }

  // ── Delete all custom tunes ─────────────────────────────────
  static Future<void> deleteAllTunes() async {
    final tunesDir = await _getTunesDir();
    if (await tunesDir.exists()) {
      await tunesDir.delete(recursive: true);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  // ── Get storage size of all custom tunes ────────────────────
  static Future<String> getStorageSize() async {
    final tunes = await loadCustomTunes();
    int totalBytes = 0;
    for (final tune in tunes) {
      final file = File(tune.assetPath);
      if (await file.exists()) {
        totalBytes += await file.length();
      }
    }
    if (totalBytes < 1024) return '$totalBytes B';
    if (totalBytes < 1024 * 1024) return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
    return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ── Private helpers ─────────────────────────────────────────
  static Future<void> _saveTunesList(List<AlarmTune> tunes) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(tunes.map((t) => t.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }

  /// Clean up file name for display: remove extension, replace underscores/dashes
  static String _cleanFileName(String fileName) {
    // Remove extension
    final lastDot = fileName.lastIndexOf('.');
    String name = lastDot > 0 ? fileName.substring(0, lastDot) : fileName;

    // Replace underscores and dashes with spaces
    name = name.replaceAll(RegExp(r'[_\-]'), ' ');

    // Title case
    name = name.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');

    return name.trim();
  }
}
