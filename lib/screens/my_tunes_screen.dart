import 'dart:io';
import 'package:flutter/material.dart';
import '../models/alarm_model.dart';
import '../services/audio_service.dart';
import '../services/custom_tune_service.dart';
import '../utils/theme.dart';

class MyTunesScreen extends StatefulWidget {
  const MyTunesScreen({super.key});

  @override
  State<MyTunesScreen> createState() => _MyTunesScreenState();
}

class _MyTunesScreenState extends State<MyTunesScreen> {
  List<AlarmTune> _customTunes = [];
  bool _isLoading = true;
  bool _isImporting = false;
  String _storageSize = '';
  final _audio = AudioService();
  String? _playingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _audio.stop();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final tunes = await CustomTuneService.loadCustomTunes();
    final size = await CustomTuneService.getStorageSize();
    if (mounted) {
      setState(() {
        _customTunes = tunes;
        _storageSize = size;
        _isLoading = false;
      });
    }
  }

  Future<void> _import() async {
    setState(() => _isImporting = true);
    try {
      final tunes = await CustomTuneService.importMultipleMP3s();
      if (tunes.isNotEmpty && mounted) {
        _showSnack('Added ${tunes.length} tune${tunes.length > 1 ? 's' : ''}');
      }
    } catch (e) {
      if (mounted) _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
        _load();
      }
    }
  }

  Future<void> _delete(AlarmTune tune) async {
    await _audio.stop();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "${tune.name}"?', style: AppTheme.headlineLarge),
        content: Text(
          'This tune will be removed permanently.',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await CustomTuneService.deleteTune(tune.id);
      _showSnack('Deleted "${tune.name}"');
      _load();
    }
  }

  Future<void> _rename(AlarmTune tune) async {
    final controller = TextEditingController(text: tune.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Rename', style: AppTheme.headlineLarge),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppTheme.headlineMedium,
          decoration: InputDecoration(
            hintText: 'Tune name',
            hintStyle: AppTheme.bodyLarge.copyWith(color: AppTheme.textMuted),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.accentOrange),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child:
                Text('Save', style: TextStyle(color: AppTheme.accentOrange)),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName != null && newName.trim().isNotEmpty) {
      await CustomTuneService.renameTune(tune.id, newName.trim());
      _load();
    }
  }

  Future<void> _deleteAll() async {
    if (_customTunes.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete all custom tunes?', style: AppTheme.headlineLarge),
        content: Text(
          'This will remove all ${_customTunes.length} custom tunes permanently.',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete All', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _audio.stop();
      await CustomTuneService.deleteAllTunes();
      _showSnack('All custom tunes deleted');
      _load();
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.error : AppTheme.accentTeal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('My Tunes',
            style: AppTheme.displayMedium.copyWith(fontSize: 20)),
        actions: [
          if (_customTunes.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep_rounded,
                  color: AppTheme.error.withOpacity(0.7)),
              onPressed: _deleteAll,
              tooltip: 'Delete all',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accentOrange))
          : _customTunes.isEmpty
              ? _buildEmptyState()
              : _buildTunesList(),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.accentPurple, Color(0xFF6D28D9)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentPurple.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _isImporting ? null : _import,
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: _isImporting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.file_upload_outlined, size: 22),
          label: Text(
            _isImporting ? 'Importing...' : 'Import tunes',
            style: AppTheme.headlineMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppTheme.accentPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: AppTheme.accentPurple.withOpacity(0.2),
                ),
              ),
              child: Icon(
                Icons.library_music_rounded,
                size: 40,
                color: AppTheme.accentPurple.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text('No Custom Tunes', style: AppTheme.displayMedium),
            const SizedBox(height: 10),
            Text(
              'Import your own audio files to use\nas alarm and reminder tunes.',
              style: AppTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              Platform.isIOS
                  ? 'Supports MP3, WAV, AAC, M4A\nMax 10MB per file'
                  : 'Supports MP3, WAV, AAC, M4A, OGG\nMax 10MB per file',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textMuted,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTunesList() {
    return Column(
      children: [
        // Storage info bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          color: AppTheme.surfaceGlow,
          child: Row(
            children: [
              const Icon(Icons.storage_rounded,
                  size: 16, color: AppTheme.textMuted),
              const SizedBox(width: 8),
              Text(
                '${_customTunes.length} tunes · $_storageSize',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            itemCount: _customTunes.length,
            itemBuilder: (context, index) {
              final tune = _customTunes[index];
              final isPlaying = _playingId == tune.id;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isPlaying
                        ? AppTheme.accentPurple.withOpacity(0.08)
                        : AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isPlaying
                          ? AppTheme.accentPurple.withOpacity(0.3)
                          : AppTheme.cardBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Play button
                      GestureDetector(
                        onTap: () async {
                          if (isPlaying) {
                            await _audio.stop();
                            setState(() => _playingId = null);
                          } else {
                            setState(() => _playingId = tune.id);
                            await _audio.playTune(tune);
                            Future.delayed(const Duration(seconds: 5), () {
                              if (mounted && _playingId == tune.id) {
                                setState(() => _playingId = null);
                              }
                            });
                          }
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: isPlaying
                                ? const LinearGradient(
                                    colors: [
                                      AppTheme.accentPurple,
                                      Color(0xFF6D28D9)
                                    ],
                                  )
                                : null,
                            color: isPlaying ? null : AppTheme.surfaceGlow,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isPlaying
                                ? Icons.stop_rounded
                                : Icons.play_arrow_rounded,
                            color: isPlaying
                                ? Colors.white
                                : AppTheme.textSecondary,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tune.name,
                              style: AppTheme.headlineMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (tune.originalFileName != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                tune.originalFileName!,
                                style: AppTheme.bodyMedium.copyWith(
                                  fontSize: 11,
                                  color: AppTheme.textMuted,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Actions
                      IconButton(
                        icon: const Icon(Icons.edit_rounded,
                            size: 18, color: AppTheme.textMuted),
                        onPressed: () => _rename(tune),
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded,
                            size: 18, color: AppTheme.error.withOpacity(0.7)),
                        onPressed: () => _delete(tune),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
