import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/accounts_config.dart';
import '../../app/providers.dart';
import '../../data/secure/credential_source.dart';
import '../../domain/models/account.dart';
import '../../domain/models/calendar.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/refresh_policy.dart';
import '../../l10n/app_localizations.dart';
import 'add_account_sheet.dart';
import 'connect_account.dart';

/// Экран учётных записей (FR-A): список УЗ, статусы, календари с тумблерами
/// видимости, удаление, добавление.
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final calendarsAsync = ref.watch(calendarsStreamProvider);
    final calendars = calendarsAsync.value ?? const <Calendar>[];

    return Scaffold(
      appBar: AppBar(title: Text(L10n.of(context).accTitle)),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(L10n.of(context).accError(e.toString()))),
        data: (accounts) => ListView(
          children: [
            for (final acc in accounts)
              _AccountTile(
                account: acc,
                calendars: calendars
                    .where((c) => c.accountId == acc.id)
                    .toList(),
              ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                onPressed: () => openAddAccount(context),
                icon: const Icon(Icons.add),
                label: Text(L10n.of(context).accAddAccount),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile({required this.account, required this.calendars});
  final Account account;
  final List<Calendar> calendars;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    return ExpansionTile(
      leading: _providerIcon(account.provider),
      title: Text(account.displayName),
      subtitle: Text(
        '${account.email} · ${_statusLabel(context, account.status)}',
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (v) async {
          if (v == 'delete') {
            await ref.read(accountRepositoryProvider).deleteAccount(account.id);
            // Убрать и из accounts.json, иначе вернётся при следующем старте.
            await removeConfiguredAccount(account.id);
          } else if (v == 'password') {
            await _changePassword(context, ref);
          } else if (v == 'reconnect') {
            await _reconnect(context, ref);
          }
        },
        itemBuilder: (_) => [
          if (_usesPassword(account.provider))
            PopupMenuItem(
              value: 'password',
              child: Text(l10n.accChangePassword),
            ),
          if (_usesOAuth(account.provider))
            PopupMenuItem(value: 'reconnect', child: Text(l10n.accReconnect)),
          PopupMenuItem(value: 'delete', child: Text(l10n.accDelete)),
        ],
      ),
      children: [
        if (!account.isHealthy &&
            (account.lastError?.trim().isNotEmpty ?? false))
          ListTile(
            dense: true,
            leading: const Icon(Icons.error_outline, size: 20),
            title: SelectableText(l10n.accFailed(account.lastError!.trim())),
            // Отозванный токен (invalid_grant) лечится только новым входом,
            // и кнопка нужна прямо на ошибке: иначе остаётся «удалить и
            // завести заново», то есть потерять настройки записи.
            trailing: _usesOAuth(account.provider)
                ? TextButton(
                    onPressed: () => _reconnect(context, ref),
                    child: Text(l10n.accReconnect),
                  )
                : null,
          ),
        // Расписание автообновления этого аккаунта (FR-A10).
        ListTile(
          dense: true,
          leading: const Icon(Icons.sync, size: 20),
          title: Text(l10n.accAutoRefresh),
          trailing: DropdownButton<int?>(
            value: account.refresh.mode == RefreshMode.manual
                ? null
                : account.refresh.interval.inMinutes,
            onChanged: (m) {
              final policy = m == null
                  ? const RefreshPolicy(mode: RefreshMode.manual)
                  : RefreshPolicy(
                      mode: RefreshMode.interval,
                      interval: Duration(minutes: m),
                    );
              ref
                  .read(accountRepositoryProvider)
                  .setRefresh(account.id, policy);
            },
            items: [
              DropdownMenuItem(value: null, child: Text(l10n.accManual)),
              DropdownMenuItem(value: 1, child: Text(l10n.accMinutes(1))),
              DropdownMenuItem(value: 5, child: Text(l10n.accMinutes(5))),
              DropdownMenuItem(value: 10, child: Text(l10n.accMinutes(10))),
              DropdownMenuItem(value: 15, child: Text(l10n.accMinutes(15))),
              DropdownMenuItem(value: 30, child: Text(l10n.accMinutes(30))),
              DropdownMenuItem(value: 60, child: Text(l10n.accHour1)),
            ],
          ),
        ),
        const Divider(height: 1),
        for (final c in calendars)
          ListTile(
            dense: true,
            leading: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Color(c.color),
                shape: BoxShape.circle,
              ),
            ),
            title: Text(c.name),
            trailing: c.visible
                ? null
                : Text(
                    l10n.accHidden,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
          ),
        if (calendars.isEmpty)
          ListTile(dense: true, title: Text(l10n.accNoCalendars)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            l10n.accVisibilityHint,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
      ],
    );
  }

  /// Провайдеры, работающие по паролю (в отличие от OAuth-токенов).
  static bool _usesPassword(ProviderType p) =>
      p == ProviderType.caldav || p == ProviderType.ews;

  /// Провайдеры со входом через браузер — их и можно переподключить.
  static bool _usesOAuth(ProviderType p) =>
      p == ProviderType.google || p == ProviderType.graph;

  /// Повторный вход для СУЩЕСТВУЮЩЕЙ записи: id, календари и настройки
  /// остаются, меняется только токен. Вход не тем ящиком отвергается, новая
  /// запись при этом не заводится.
  Future<void> _reconnect(BuildContext context, WidgetRef ref) async {
    final l10n = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(l10n.accCompleteSignIn(account.displayName)),
      duration: const Duration(seconds: 10),
    ));
    try {
      final who =
          await ref.read(connectAccountServiceProvider).reconnect(account);
      // Снекбары становятся в очередь: без hide результат ждал бы, пока
      // подсказка отвисит свои 10 секунд, и вход выглядел бы зависшим.
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(l10n.accConnected(who))));
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.accFailed(e.toString())),
        duration: const Duration(seconds: 12),
      ));
    }
  }

  /// Диалог ввода нового пароля → запись в secrets.env → пересоздание
  /// провайдеров и немедленный синк, чтобы аккаунт снова подключился.
  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final l10n = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final pass = await showDialog<String>(
      context: context,
      builder: (ctx) => _PasswordDialog(email: account.email),
    );
    if (pass == null || pass.isEmpty) return;

    final varName = account.provider == ProviderType.ews
        ? CredentialSource.ewsPasswordVar(account.email)
        : CredentialSource.caldavPasswordVar(account.email);
    await writeSecret(varName, pass);
    // Сбрасываем кэш провайдеров, чтобы новый пароль подхватился, и синкаем.
    ref.invalidate(providerRegistryProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.accPasswordSaved),
        duration: const Duration(seconds: 2),
      ),
    );
    await ref.read(syncTriggerProvider)();
  }

  Widget _providerIcon(ProviderType p) {
    final icon = switch (p) {
      ProviderType.google => Icons.event,
      ProviderType.graph => Icons.business,
      ProviderType.caldav => Icons.cloud_outlined,
      ProviderType.ews => Icons.dns_outlined,
    };
    return CircleAvatar(child: Icon(icon, size: 18));
  }

  String _statusLabel(BuildContext context, AccountStatus s) {
    final l10n = L10n.of(context);
    return switch (s) {
      AccountStatus.ok => l10n.accStatusOk,
      AccountStatus.authError => l10n.accStatusAuthError,
      AccountStatus.needsReconnect => l10n.accStatusNeedsReconnect,
      AccountStatus.syncError => l10n.accStatusSyncError,
      AccountStatus.offline => l10n.accStatusOffline,
    };
  }
}

/// Диалог ввода нового пароля учётной записи (CalDAV app-password / EWS).
class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.email});
  final String email;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return AlertDialog(
      title: Text(l10n.accNewPassword),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.email,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: _obscure,
            onSubmitted: (v) => Navigator.pop(context, v),
            decoration: InputDecoration(
              labelText: l10n.accPassword,
              helperText: l10n.accCaldavPasswordHelper,
              helperMaxLines: 2,
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.accCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(l10n.accSave),
        ),
      ],
    );
  }
}
