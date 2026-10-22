import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = 'Loading'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: label,
        child: const SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 32),
            const SizedBox(height: AppSpace.md),
            Text(message, style: text.bodyMedium, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpace.md),
              TextButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.title, required this.message, this.icon = Icons.water_drop_outlined});

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xl, horizontal: AppSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 32),
          const SizedBox(height: AppSpace.sm),
          Text(title, style: text.titleSmall, textAlign: TextAlign.center),
          const SizedBox(height: AppSpace.xs),
          Text(message, style: text.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Uppercase section label with a short underline, as on the Settings screen.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xl, AppSpace.lg, AppSpace.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.inkMuted, letterSpacing: 0.6),
            ),
            const SizedBox(height: AppSpace.xs),
            Container(width: 44, height: 1.5, color: AppColors.line),
          ],
        ),
      ),
    );
  }
}

/// Shows a user-facing message for an exception without leaking internals.
String friendlyError(Object error) {
  final text = error.toString();
  if (text.startsWith('Exception') || text.contains('DatabaseException') || text.length > 140) {
    return 'Something went wrong. Please try again.';
  }
  return text.replaceFirst('Bad state: ', '');
}
