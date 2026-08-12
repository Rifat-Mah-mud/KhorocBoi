import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/app_providers.dart';
import '../services/google_backup_service.dart';
import '../theme/app_theme.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backup = ref.watch(backupStateProvider);
    final account = backup.account;
    final lastSync = backup.lastSyncedAt;
    final busy = backup.status == BackupSyncStatus.signingIn ||
        backup.status == BackupSyncStatus.syncing;

    return Scaffold(
      appBar: AppBar(title: const Text('Google Backup')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            'Keep your expense history safe',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in once with Google. After that, every change is backed up '
            'automatically to a private Drive folder. Reinstall the app, sign '
            'in with the same Gmail, and your full history is restored.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.white
                  : AppColors.darkSurfaceLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.secondaryContainer,
                  backgroundImage: account?.photoUrl != null
                      ? NetworkImage(account!.photoUrl!)
                      : null,
                  child: account?.photoUrl == null
                      ? const Icon(Icons.cloud_outlined, color: AppColors.primary)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account?.displayName ?? 'Not signed in',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        account?.email ?? 'Connect Google to enable backup',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            lastSync == null
                ? 'Last sync: never'
                : 'Last sync: ${DateFormat('d MMM yyyy, h:mm a').format(lastSync)}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          if (backup.message != null) ...[
            const SizedBox(height: 12),
            Text(
              backup.message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: backup.status == BackupSyncStatus.error
                        ? AppColors.error
                        : AppColors.lushGreen,
                  ),
            ),
          ],
          const SizedBox(height: 24),
          if (account == null)
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () => ref.read(googleBackupServiceProvider).signIn(),
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(busy ? 'Signing in…' : 'Sign in with Google'),
            )
          else ...[
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      await ref
                          .read(googleBackupServiceProvider)
                          .syncNow(force: true);
                      ref.read(tabsVersionProvider.notifier).state++;
                    },
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: Text(busy ? 'Syncing…' : 'Sync now'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => ref.read(googleBackupServiceProvider).signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ],
      ),
    );
  }
}
