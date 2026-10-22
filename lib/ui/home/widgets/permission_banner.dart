import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../state/permission_controller.dart';

/// Asks for notification permission in context, with a reason, instead of a
/// cold prompt on first launch. Hidden once notifications are allowed.
class PermissionBanner extends ConsumerWidget {
  const PermissionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(permissionControllerProvider).value;
    if (status == null || status == ReminderPermission.granted) return const SizedBox.shrink();

    final denied = status == ReminderPermission.denied;
    final text = Theme.of(context).textTheme;
    final controller = ref.read(permissionControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.sm, AppSpace.md),
          child: Row(
            children: [
              const Icon(Icons.notifications_active_outlined, color: AppColors.primaryDark),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(denied ? 'Reminders are off' : 'Turn on reminders', style: text.titleSmall),
                    const SizedBox(height: AppSpace.xxs),
                    Text(
                      denied
                          ? 'Notifications are blocked for this app. Allow them in system settings.'
                          : 'Get a nudge at your scheduled times so you hit your goal.',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: denied ? controller.openSystemSettings : controller.request,
                child: Text(denied ? 'Settings' : 'Allow'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
