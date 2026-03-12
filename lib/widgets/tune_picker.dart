import 'package:flutter/material.dart';
import '../models/alarm_model.dart';
import '../services/audio_service.dart';
import '../services/custom_tune_service.dart';
import '../utils/theme.dart';

class TunePicker extends StatefulWidget {
  final String title;
  final List<AlarmTune> tunes; // preloaded tunes
  final AlarmTune selectedTune;
  final ValueChanged<AlarmTune> onSelected;

  const TunePicker({
    super.key,
    required this.title,
    required this.tunes,
    required this.selectedTune,
    required this.onSelected,
  });

  @override
  State<TunePicker> createState() => _TunePickerState();
}

class _TunePickerState extends State<TunePicker> {
  final _audio = AudioService();
  String? _playingId;
  List<AlarmTune> _customTunes = [];
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _loadCustomTunes();
  }

  @override
  void dispose() {
    _audio.stop();
    super.dispose();
  }

  Future<void> _loadCustomTunes() async {
    final tunes = await CustomTuneService.loadCustomTunes();
    if (mounted) setState(() => _customTunes = tunes);
  }

  Future<void> _importTune() async {
    setState(() => _isImporting = true);
    try {
      final tune = await CustomTuneService.importMP3();
      if (tune != null && mounted) {
        await _loadCustomTunes();
        widget.onSelected(tune); // auto-select the imported tune
        _showSnack('Added "${tune.name}"');
      }
    } catch (e) {
      if (mounted) _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _importMultiple() async {
    setState(() => _isImporting = true);
    try {
      final tunes = await CustomTuneService.importMultipleMP3s();
      if (tunes.isNotEmpty && mounted) {
        await _loadCustomTunes();
        widget.onSelected(tunes.first);
        _showSnack('Added ${tunes.length} tune${tunes.length > 1 ? 's' : ''}');
      }
    } catch (e) {
      if (mounted) _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _deleteTune(AlarmTune tune) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "${tune.name}"?', style: AppTheme.headlineLarge),
        content: Text(
          'This will remove the tune from your library. Alarms using it will fall back to the default tune.',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _audio.stop();
      await CustomTuneService.deleteTune(tune.id);
      await _loadCustomTunes();

      // If the deleted tune was selected, fall back to first preloaded
      if (widget.selectedTune.id == tune.id) {
        widget.onSelected(widget.tunes.first);
      }

      if (mounted) _showSnack('Deleted "${tune.name}"');
    }
  }

  Future<void> _renameTune(AlarmTune tune) async {
    final controller = TextEditingController(text: tune.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Rename Tune', style: AppTheme.headlineLarge),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppTheme.headlineMedium,
          decoration: InputDecoration(
            hintText: 'Tune name',
            hintStyle: AppTheme.bodyLarge.copyWith(color: AppTheme.textMuted),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.cardBorder),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.accentOrange),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text('Save', style: TextStyle(color: AppTheme.accentOrange)),
          ),
        ],
      ),
    );

    controller.dispose();

    if (newName != null && newName.trim().isNotEmpty && newName.trim() != tune.name) {
      final updated = await CustomTuneService.renameTune(tune.id, newName.trim());
      if (updated != null) {
        await _loadCustomTunes();
        if (widget.selectedTune.id == tune.id) {
          widget.onSelected(updated);
        }
      }
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.error : AppTheme.accentTeal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allTunes = [...widget.tunes, ..._customTunes];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header with import button ─────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title.toUpperCase(),
                style: AppTheme.labelLarge,
              ),
              Row(
                children: [
                  if (_customTunes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        '${_customTunes.length} custom',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.accentPurple,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  _ImportButton(
                    isImporting: _isImporting,
                    onTap: _importTune,
                    onLongPress: _importMultiple,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ── Tune list ─────────────────────────────────
        ...allTunes.map((tune) {
          final isSelected = tune.id == widget.selectedTune.id;
          final isPlaying = _playingId == tune.id;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => widget.onSelected(tune),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.accentOrange.withOpacity(0.1)
                      : AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.accentOrange.withOpacity(0.5)
                        : AppTheme.cardBorder,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Selection indicator
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? AppTheme.accentOrange
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.accentOrange
                              : AppTheme.textMuted,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 14),

                    // Tune name + custom badge
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tune.name,
                            style: AppTheme.headlineMedium.copyWith(
                              color: isSelected
                                  ? AppTheme.accentOrange
                                  : AppTheme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (tune.isCustom) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentPurple.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'MY TUNE',
                                    style: AppTheme.labelLarge.copyWith(
                                      fontSize: 8,
                                      color: AppTheme.accentPurple,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                if (tune.originalFileName != null) ...[
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      tune.originalFileName!,
                                      style: AppTheme.bodyMedium.copyWith(
                                        fontSize: 10,
                                        color: AppTheme.textMuted,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Custom tune actions (rename / delete)
                    if (tune.isCustom) ...[
                      GestureDetector(
                        onTap: () => _renameTune(tune),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceGlow,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            color: AppTheme.textMuted,
                            size: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _deleteTune(tune),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: AppTheme.error.withOpacity(0.7),
                            size: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],

                    // Play/preview button
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
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isPlaying
                              ? AppTheme.accentTeal.withOpacity(0.2)
                              : AppTheme.surfaceGlow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isPlaying
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                          color: isPlaying
                              ? AppTheme.accentTeal
                              : AppTheme.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        // ── Empty custom state hint ───────────────────
        if (_customTunes.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: GestureDetector(
              onTap: _importTune,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceGlow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.accentPurple.withOpacity(0.2),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline_rounded,
                      color: AppTheme.accentPurple.withOpacity(0.6),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Import your own MP3s',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.accentPurple.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Animated import button with loading state
class _ImportButton extends StatelessWidget {
  final bool isImporting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ImportButton({
    required this.isImporting,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isImporting ? null : onTap,
      onLongPress: isImporting ? null : onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.accentPurple.withOpacity(isImporting ? 0.05 : 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.accentPurple.withOpacity(isImporting ? 0.1 : 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isImporting)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.accentPurple,
                ),
              )
            else
              const Icon(
                Icons.file_upload_outlined,
                size: 15,
                color: AppTheme.accentPurple,
              ),
            const SizedBox(width: 6),
            Text(
              isImporting ? 'Importing...' : 'Add MP3',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.accentPurple,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
