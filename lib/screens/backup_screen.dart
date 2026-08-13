import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/app_providers.dart';
import '../services/cloud_sync_service.dart';
import '../theme/app_theme.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  bool _obscureCode = true;

  @override
  void initState() {
    super.initState();
    final email = ref.read(backupStateProvider).email;
    if (email != null) {
      _emailController.text = email;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String label,
    required String hint,
    required IconData prefix,
    Widget? suffix,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.lushBorder),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(prefix),
      suffixIcon: suffix,
      filled: true,
      fillColor: Theme.of(context).brightness == Brightness.light
          ? Colors.white
          : AppColors.darkSurfaceLowest,
      border: border,
      enabledBorder: border,
    );
  }

  Future<void> _connect() async {
    await ref.read(cloudSyncServiceProvider).connect(
          email: _emailController.text,
          code: _codeController.text,
        );
    if (!mounted) return;
    ref.read(tabsVersionProvider.notifier).state++;
  }

  Future<void> _syncNow() async {
    await ref.read(cloudSyncServiceProvider).syncNow(force: true);
    if (!mounted) return;
    ref.read(tabsVersionProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context) {
    final backup = ref.watch(backupStateProvider);
    final connected = backup.isConnected;
    final lastSync = backup.lastSyncedAt;
    final busy = backup.status == BackupSyncStatus.connecting ||
        backup.status == BackupSyncStatus.syncing;

    return Scaffold(
      appBar: AppBar(title: const Text('Cloud Sync')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            'Keep your expense history safe',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Set an email and a passcode once. After that, every change is '
            'backed up automatically. Reinstall the app, enter the same email '
            'and passcode, and your full history is restored.',
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
                  child: Icon(
                    connected ? Icons.cloud_done_outlined : Icons.cloud_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        connected ? 'Sync enabled' : 'Not connected',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        connected
                            ? backup.email!
                            : 'Save email and passcode to enable backup',
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
          if (!connected) ...[
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              enabled: !busy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: _fieldDecoration(
                context,
                label: 'Email',
                hint: 'you@example.com',
                prefix: Icons.email_outlined,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              enabled: !busy,
              obscureText: _obscureCode,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: busy ? null : (_) => _connect(),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _fieldDecoration(
                context,
                label: 'Passcode',
                hint: 'At least 4 digits',
                prefix: Icons.lock_outline,
                suffix: IconButton(
                  onPressed: () =>
                      setState(() => _obscureCode = !_obscureCode),
                  icon: Icon(
                    _obscureCode
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: busy ? null : _connect,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_sync),
              label: Text(busy ? 'Saving…' : 'Save & sync'),
            ),
          ] else ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: busy ? null : _syncNow,
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
                  : () => ref.read(cloudSyncServiceProvider).disconnect(),
              icon: const Icon(Icons.link_off),
              label: const Text('Disconnect'),
            ),
          ],
        ],
      ),
    );
  }
}
