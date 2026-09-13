import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'connect_account.dart';

/// Полноэкранный экран подключения учётной записи. Раньше был тесный
/// bottom-sheet — на телефоне он занимал пол-экрана и выглядел куце; плюс
/// диалоги показывались на уже закрытом контексте шита и коннект «молчал».
Future<void> openAddAccount(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const AddAccountScreen()),
  );
}

class AddAccountScreen extends ConsumerStatefulWidget {
  const AddAccountScreen({super.key});

  @override
  ConsumerState<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends ConsumerState<AddAccountScreen> {
  /// Вход, который сейчас ждёт браузер: второй не запускаем, плитки неактивны.
  OAuthApp? _signingIn;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.accConnectAccount)),
      body: ListView(
        children: [
          if (_signingIn != null) const LinearProgressIndicator(),
          _SectionHeader(l10n.accSectionCalendars),
          _oauthTile(Icons.event, 'Google', OAuthApp.google,
              (svc) => svc.connectGoogle()),
          _oauthTile(Icons.business, 'Microsoft 365 / Outlook',
              OAuthApp.microsoft, (svc) => svc.connectMicrosoft()),
          _tile(Icons.cloud_outlined, 'Yandex (CalDAV)', l10n.accAppPassword,
              () => _openForm(context, _ProviderKind.caldav)),
          _tile(Icons.dns_outlined, 'Exchange (EWS)', l10n.accLoginPassword,
              () => _openForm(context, _ProviderKind.ews)),
          const Divider(height: 32),
          _SectionHeader(l10n.accSectionVideoMeetings),
          _oauthTile(Icons.videocam_outlined, 'Yandex Telemost',
              OAuthApp.telemost,
              (svc) => svc.connectTelemost().then((_) => 'Telemost')),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String title, String sub, VoidCallback? onTap,
          {Widget? trailing}) =>
      ListTile(
        leading: CircleAvatar(child: Icon(icon, size: 18)),
        title: Text(title),
        subtitle: Text(sub),
        trailing: trailing ?? const Icon(Icons.chevron_right),
        enabled: onTap != null,
        onTap: onTap,
      );

  Widget _oauthTile(IconData icon, String title, OAuthApp app,
      Future<String> Function(ConnectAccountService svc) connect) {
    return _tile(
      icon,
      title,
      L10n.of(context).accSignInBrowser,
      _signingIn == null ? () => _oauth(app, connect) : null,
      trailing: _signingIn == app
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
          : null,
    );
  }

  static String _appName(OAuthApp app) => switch (app) {
        OAuthApp.google => 'Google',
        OAuthApp.microsoft => 'Microsoft',
        OAuthApp.telemost => 'Telemost',
      };

  /// OAuth-провайдеры (Google/Microsoft/Telemost): открываем браузер, ждём вход.
  Future<void> _oauth(OAuthApp app,
      Future<String> Function(ConnectAccountService svc) connect) async {
    if (_signingIn != null) return;
    final l10n = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final svc = ref.read(connectAccountServiceProvider);
    final name = _appName(app);

    // Без OAuth-клиента браузер не откроется. Раньше экран всё равно писал
    // «завершите вход в открывшемся браузере…», и вход выглядел зависшим.
    if (svc.missingOAuthClientKeys(app).isNotEmpty) {
      final saved = await _askOAuthClient(svc, app, name);
      if (!saved || !mounted) return;
    }

    setState(() => _signingIn = app);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
        content: Text(l10n.accCompleteSignIn(name)),
        duration: const Duration(seconds: 10)));
    try {
      final who = await connect(svc);
      // Снекбары становятся в очередь: без hide результат ждал бы, пока
      // «завершите вход…» отвисит свои 10 секунд, и вход выглядел бы зависшим.
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(l10n.accConnected(who))));
      if (mounted) setState(() => _signingIn = null);
      if (nav.canPop()) nav.pop();
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
          content: Text(l10n.accFailed(e.toString())),
          duration: const Duration(seconds: 12)));
      if (mounted) setState(() => _signingIn = null);
    }
  }

  /// Диалог «вход не настроен в этой сборке» с вводом своего OAuth-клиента.
  /// true — клиент сохранён в keyring, можно начинать вход.
  Future<bool> _askOAuthClient(
      ConnectAccountService svc, OAuthApp app, String name) async {
    final withSecret = ConnectAccountService.oauthClientKeys(app).length > 1;
    final client = await showDialog<({String id, String secret})>(
      context: context,
      builder: (_) => _OAuthClientDialog(name: name, withSecret: withSecret),
    );
    if (client == null) return false;
    await svc.saveOAuthClient(app,
        clientId: client.id, clientSecret: withSecret ? client.secret : null);
    return true;
  }

  Future<void> _openForm(BuildContext context, _ProviderKind kind) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _CredentialFormScreen(kind: kind)),
    );
  }
}

/// Ввод своего OAuth-клиента. Контроллеры живут вместе с диалогом: анимация
/// закрытия ещё перестраивает поля, освобождать их раньше нельзя.
class _OAuthClientDialog extends StatefulWidget {
  const _OAuthClientDialog({required this.name, required this.withSecret});
  final String name;
  final bool withSecret;

  @override
  State<_OAuthClientDialog> createState() => _OAuthClientDialogState();
}

class _OAuthClientDialogState extends State<_OAuthClientDialog> {
  final _id = TextEditingController();
  final _secret = TextEditingController();

  @override
  void dispose() {
    _id.dispose();
    _secret.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return AlertDialog(
      title: Text(l10n.accOAuthNotConfiguredTitle(widget.name)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.accOAuthNotConfiguredBody(widget.name)),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('oauth-client-id'),
              controller: _id,
              decoration: InputDecoration(labelText: l10n.accOAuthClientId),
            ),
            if (widget.withSecret)
              TextField(
                key: const ValueKey('oauth-client-secret'),
                controller: _secret,
                obscureText: true,
                decoration:
                    InputDecoration(labelText: l10n.accOAuthClientSecret),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.accCancel),
        ),
        ListenableBuilder(
          listenable: Listenable.merge([_id, _secret]),
          builder: (context, _) {
            final ready = _id.text.trim().isNotEmpty &&
                (!widget.withSecret || _secret.text.trim().isNotEmpty);
            return FilledButton(
              onPressed: ready
                  ? () => Navigator.of(context)
                      .pop((id: _id.text, secret: _secret.text))
                  : null,
              child: Text(l10n.accSaveAndSignIn),
            );
          },
        ),
      ],
    );
  }
}

enum _ProviderKind { caldav, ews }

/// Полноэкранная форма ввода реквизитов для парольных провайдеров.
class _CredentialFormScreen extends ConsumerStatefulWidget {
  const _CredentialFormScreen({required this.kind});
  final _ProviderKind kind;

  @override
  ConsumerState<_CredentialFormScreen> createState() =>
      _CredentialFormScreenState();
}

class _CredentialFormScreenState extends ConsumerState<_CredentialFormScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _host = TextEditingController(text: 'caldav.yandex.ru');
  final _port = TextEditingController(text: '8443');
  final _ewsUrl = TextEditingController();
  final _user = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  bool get _isCaldav => widget.kind == _ProviderKind.caldav;

  @override
  void dispose() {
    for (final c in [_email, _pass, _host, _port, _ewsUrl, _user]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = L10n.of(context);
    if (_email.text.trim().isEmpty || _pass.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.accFillEmailPassword)));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final svc = ref.read(connectAccountServiceProvider);
      if (_isCaldav) {
        await svc.connectCaldav(
          email: _email.text.trim(),
          appPassword: _pass.text,
          host: _host.text.trim().isEmpty ? 'caldav.yandex.ru' : _host.text.trim(),
          port: int.tryParse(_port.text) ?? 8443,
        );
      } else {
        await svc.connectEws(
          email: _email.text.trim(),
          password: _pass.text,
          ewsUrl: _ewsUrl.text.trim().isEmpty ? null : _ewsUrl.text.trim(),
          user: _user.text.trim().isEmpty ? null : _user.text.trim(),
        );
      }
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.accConnected(_email.text.trim()))));
      nav.pop(); // форма
      if (nav.canPop()) nav.pop(); // экран выбора провайдера
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.accFailed(e.toString()))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Scaffold(
      appBar: AppBar(
          title: Text(_isCaldav ? 'Yandex / CalDAV' : 'Exchange (EWS)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            decoration: InputDecoration(
                labelText: l10n.accEmail,
                prefixIcon: const Icon(Icons.alternate_email)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pass,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: _isCaldav ? l10n.accAppPassword : l10n.accPassword,
              prefixIcon: const Icon(Icons.key_outlined),
              helperText: _isCaldav ? l10n.accAppPasswordHelper : null,
              helperMaxLines: 2,
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_isCaldav)
            Row(children: [
              Expanded(
                flex: 3,
                child: TextField(
                    controller: _host,
                    decoration: InputDecoration(labelText: l10n.accHost)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                    controller: _port,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l10n.accPort)),
              ),
            ])
          else ...[
            TextField(
              controller: _ewsUrl,
              decoration: InputDecoration(
                  labelText: l10n.accEwsUrlLabel,
                  hintText: 'https://mail.example.org/EWS/Exchange.asmx'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _user,
              decoration: InputDecoration(
                  labelText: l10n.accLoginIfDifferent,
                  hintText: r'DOMAIN\user'),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.link),
            label: Text(_busy ? l10n.accConnecting : l10n.accConnect),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(title.toUpperCase(),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary)),
      );
}
