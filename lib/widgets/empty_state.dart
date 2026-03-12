import 'package:flutter/material.dart';
import '../utils/theme.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accentOrange.withOpacity(0.15),
                    AppTheme.accentAmber.withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: AppTheme.accentOrange.withOpacity(0.2),
                ),
              ),
              child: Icon(
                Icons.alarm_add_rounded,
                size: 44,
                color: AppTheme.accentOrange.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'No Alarms Yet',
              style: AppTheme.displayMedium,
            ),
            const SizedBox(height: 10),
            Text(
              'Create your first interval alarm to\nget started with timed reminders.',
              style: AppTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
