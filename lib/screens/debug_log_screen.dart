import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/debug_log_service.dart';
import '../utils/theme.dart';

class DebugLogScreen extends StatefulWidget {
  const DebugLogScreen({super.key});

  @override
  State<DebugLogScreen> createState() => _DebugLogScreenState();
}

class _DebugLogScreenState extends State<DebugLogScreen> {
  List<String> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final logs = await DebugLogService.getLogs();
    setState(() {
      _logs = logs.reversed.toList(); // newest first
      _loading = false;
    });
  }

  Future<void> _clear() async {
    await DebugLogService.clear();
    setState(() => _logs = []);
  }

  void _copy() {
    final text = _logs.reversed.join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs copied to clipboard')),
    );
  }

  Color _categoryColor(String log) {
    if (log.contains('[ERROR]') || log.contains('ERROR')) return AppTheme.accentRose;
    if (log.contains('[CALLBACK]')) return AppTheme.accentTeal;
    if (log.contains('[SCHEDULE]')) return AppTheme.accentOrange;
    if (log.contains('[NOTIF]')) return AppTheme.accentBlue;
    if (log.contains('[CANCEL]')) return AppTheme.accentAmber;
    if (log.contains('[AUDIO]')) return AppTheme.accentPurple;
    return AppTheme.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnight,
      appBar: AppBar(
        backgroundColor: AppTheme.deepNavy,
        title: Text(
          'DEBUG LOGS',
          style: AppTheme.labelLarge.copyWith(letterSpacing: 3, fontSize: 12),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 20),
            onPressed: _copy,
            tooltip: 'Copy all',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.accentRose),
            onPressed: _clear,
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentOrange))
          : _logs.isEmpty
              ? Center(
                  child: Text(
                    'No logs yet.\nTap the speaker to run a test.',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.textMuted),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _logs.length,
                  itemBuilder: (_, i) {
                    final log = _logs[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.cardDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Text(
                        log,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: _categoryColor(log),
                          height: 1.4,
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
