import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cryptography/cryptography.dart';
import 'app_localizations.dart';
import 'remote_asset_loader.dart';

class ClubCommunicationsPage extends StatefulWidget {
  const ClubCommunicationsPage({super.key, required this.loader});

  final RemoteAssetLoader loader;

  @override
  State<ClubCommunicationsPage> createState() =>
      _ClubCommunicationsPageState();
}

class _ClubCommunicationsPageState extends State<ClubCommunicationsPage> {
  static const _remoteUrl =
      'https://raw.githubusercontent.com/lougau92/vma-running/refs/heads/main/assets/communications/messages.json';
  static const _assetPath = 'assets/communications/messages.json';
  static String? _sessionPassword;
  static List<_Message>? _sessionMessages;

  late Future<_CommsResult> _future;
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _cachedPassword;
  List<_Message>? _messages;
  String? _errorText;
  String? _lastNoticeKey;
  bool _unlocking = false;
  bool _autoTried = false;

  @override
  void initState() {
    super.initState();
    _cachedPassword = _sessionPassword;
    _messages = _sessionMessages;
    _future = _load();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<_CommsResult> _load({bool forceRefresh = false}) async {
    final result = await widget.loader.loadText(
      remoteUrl: _remoteUrl,
      assetPath: _assetPath,
      forceRefresh: forceRefresh,
    );

    final payload = _EncryptedPayload.fromJson(jsonDecode(result.data));
    return _CommsResult(
      payload: payload,
      noticeKey: _noticeKeyFor(result, forceRefresh),
    );
  }

  Future<void> _refresh({bool forceRefresh = true}) async {
    final next = _load(forceRefresh: forceRefresh);
    setState(() {
      _future = next;
      _messages = null;
      _errorText = null;
      _lastNoticeKey = null;
      _autoTried = false;
    });
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return FutureBuilder<_CommsResult>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              '${strings.communicationsLoadError}: ${snapshot.error}',
              textAlign: TextAlign.center,
            ),
          );
        }
        if (!snapshot.hasData) {
          return Center(child: Text(strings.noData));
        }

        final data = snapshot.data!;
        _notifyIfNeeded(data.noticeKey);
        if (_cachedPassword != null &&
            _messages == null &&
            !_autoTried &&
            !_unlocking) {
          _autoTried = true;
          _autoUnlockWithCached(data.payload);
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _buildHeader(strings, data.payload),
              const SizedBox(height: 12),
              if (_messages == null) _buildPasswordCard(strings, data.payload),
              if (_messages != null && _messages!.isEmpty) ...[
                const SizedBox(height: 12),
                Center(child: Text(strings.noData)),
              ],
              if (_messages != null && _messages!.isNotEmpty) ...[
                const SizedBox(height: 12),
                ..._messages!.map((msg) => _buildMessageCard(msg)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(AppLocalizations strings, _EncryptedPayload payload) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.communicationsTitle,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          strings.communicationsPasswordPrompt,
          style: theme.textTheme.bodyMedium,
        ),
        if (payload.passwordHint?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(
            '${strings.communicationsPasswordHint}: ${payload.passwordHint}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _buildPasswordCard(
    AppLocalizations strings,
    _EncryptedPayload payload,
  ) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              enabled: !_unlocking,
              decoration: InputDecoration(
                labelText: strings.communicationsPasswordLabel,
                hintText: strings.communicationsPasswordPlaceholder,
                errorText: _errorText,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  tooltip: _obscurePassword
                      ? strings.communicationsPasswordLabel
                      : strings.communicationsUnlock,
                  onPressed: () => setState(
                    () => _obscurePassword = !_obscurePassword,
                  ),
                ),
              ),
              onSubmitted: (value) => _attemptUnlock(payload, value),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _unlocking
                    ? null
                    : () => _attemptUnlock(
                          payload,
                          _passwordController.text,
                        ),
                icon: const Icon(Icons.lock_open),
                label: Text(strings.communicationsUnlock),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              strings.communicationsPrivacyNote,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageCard(_Message message) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    message.title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (message.publishedAt != null)
                  Text(
                    message.publishedAt!,
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              message.summary,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message.body,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  void _attemptUnlock(
    _EncryptedPayload payload,
    String password,
  ) async {
    final strings = AppLocalizations.of(context);
    final trimmed = password.trim();
    if (trimmed.isEmpty) {
      setState(() => _errorText = strings.communicationsInvalidPassword);
      return;
    }

    setState(() {
      _unlocking = true;
      _errorText = null;
      _autoTried = true;
    });

    try {
      final messages = await payload.decrypt(trimmed);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _unlocking = false;
        _errorText = null;
        _cachedPassword = trimmed;
        _sessionPassword = trimmed;
        _sessionMessages = messages;
        _autoTried = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = strings.communicationsInvalidPassword;
        _unlocking = false;
        _messages = null;
        _cachedPassword = null;
        _sessionPassword = null;
        _sessionMessages = null;
      });
    }
  }

  void _notifyIfNeeded(String? noticeKey) {
    if (noticeKey == null || noticeKey == _lastNoticeKey || !mounted) return;
    _lastNoticeKey = noticeKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final strings = AppLocalizations.of(context);
      final message = strings[noticeKey];
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  String? _noticeKeyFor(RemoteLoadResult result, bool forceRefresh) {
    if (result.origin == RemoteLoadOrigin.cache && forceRefresh) {
      return 'communicationsUsedCache';
    }
    if (result.origin == RemoteLoadOrigin.asset) {
      return 'communicationsUsedFallback';
    }
    return null;
  }

  Future<void> _autoUnlockWithCached(_EncryptedPayload payload) async {
    if (_cachedPassword == null || _messages != null) return;
    try {
      final unlocked = await payload.decrypt(_cachedPassword!);
      if (!mounted) return;
      setState(() {
        _messages = unlocked;
        _errorText = null;
        _sessionMessages = unlocked;
        _sessionPassword = _cachedPassword;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cachedPassword = null;
        _sessionPassword = null;
        _sessionMessages = null;
      });
    }
  }
}

class _CommsResult {
  const _CommsResult({required this.payload, this.noticeKey});

  final _EncryptedPayload payload;
  final String? noticeKey;
}

class _EncryptedPayload {
  const _EncryptedPayload({
    required this.messages,
    required this.version,
    this.kdf,
    this.legacyKeyCheck,
    this.legacyMessages,
    this.passwordHint,
  });

  factory _EncryptedPayload.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as int? ?? 1;
    if (json.containsKey('kdf')) {
      final rawMessages = json['messages'] as List<dynamic>? ?? [];
      return _EncryptedPayload(
        version: version,
        passwordHint: json['passwordHint'] as String?,
        kdf: _KdfConfig.fromJson(json['kdf'] as Map<String, dynamic>),
        messages: rawMessages
            .map((item) => _EncryptedMessage.fromJson(
                  item as Map<String, dynamic>,
                ))
            .toList(growable: false),
      );
    }

    // Legacy XOR format (v1)
    final rawMessages = json['messages'] as List<dynamic>? ?? [];
    return _EncryptedPayload(
      version: version,
      passwordHint: json['passwordHint'] as String?,
      legacyKeyCheck: json['keyCheck'] as String?,
      legacyMessages: rawMessages
          .map((item) => _LegacyEncryptedMessage.fromJson(
                item as Map<String, dynamic>,
              ))
          .toList(growable: false),
      messages: const [],
    );
  }

  final int version;
  final String? passwordHint;
  final List<_EncryptedMessage> messages;
  final _KdfConfig? kdf;
  final String? legacyKeyCheck;
  final List<_LegacyEncryptedMessage>? legacyMessages;

  Future<List<_Message>> decrypt(String password) async {
    if (kdf != null) {
      final key = await _deriveKey(password, kdf!);
      final algorithm = AesGcm.with256bits();

      return Future.wait(
        messages.map((m) => m.decrypt(key, algorithm)),
        eagerError: true,
      );
    }

    // Legacy XOR fallback.
    if (legacyKeyCheck == null || legacyMessages == null) {
      throw const FormatException('Invalid payload');
    }
    final validation = _xorDecode(legacyKeyCheck!, password);
    if (validation != 'club-communications-ok') {
      throw const FormatException('Invalid password');
    }
    return legacyMessages!
        .map((m) => m.decryptLegacy(password))
        .toList(growable: false);
  }
}

class _EncryptedMessage {
  const _EncryptedMessage({
    required this.id,
    required this.nonce,
    required this.cipher,
    required this.tag,
    this.publishedAt,
  });

  factory _EncryptedMessage.fromJson(Map<String, dynamic> json) {
    return _EncryptedMessage(
      id: json['id'] as String? ?? '',
      nonce: json['nonce'] as String,
      cipher: json['cipher'] as String,
      tag: json['tag'] as String,
      publishedAt: json['publishedAt'] as String?,
    );
  }

  final String id;
  final String nonce;
  final String cipher;
  final String tag;
  final String? publishedAt;

  Future<_Message> decrypt(
    SecretKey key,
    Cipher algorithm,
  ) async {
    final nonce = base64.decode(this.nonce);
    final cipherBytes = base64.decode(cipher);
    final tagBytes = base64.decode(tag);
    final secretBox = SecretBox(
      cipherBytes,
      nonce: nonce,
      mac: Mac(tagBytes),
    );

    final clear = await algorithm.decrypt(
      secretBox,
      secretKey: key,
    );
    final decoded =
        jsonDecode(utf8.decode(clear)) as Map<String, dynamic>? ?? {};
    final title = decoded['title'] as String? ?? '';
    final summary = decoded['summary'] as String? ?? '';
    final body = decoded['body'] as String? ?? '';

    return _Message(
      id: id,
      title: title,
      summary: summary,
      body: body,
      publishedAt: publishedAt,
    );
  }
}

class _LegacyEncryptedMessage {
  const _LegacyEncryptedMessage({
    required this.id,
    required this.cipherTitle,
    required this.cipherSummary,
    required this.cipherBody,
    this.publishedAt,
  });

  factory _LegacyEncryptedMessage.fromJson(Map<String, dynamic> json) {
    return _LegacyEncryptedMessage(
      id: json['id'] as String? ?? '',
      cipherTitle: json['cipherTitle'] as String,
      cipherSummary: json['cipherSummary'] as String,
      cipherBody: json['cipherBody'] as String,
      publishedAt: json['publishedAt'] as String?,
    );
  }

  final String id;
  final String cipherTitle;
  final String cipherSummary;
  final String cipherBody;
  final String? publishedAt;

  _Message decryptLegacy(String password) {
    return _Message(
      id: id,
      title: _xorDecode(cipherTitle, password),
      summary: _xorDecode(cipherSummary, password),
      body: _xorDecode(cipherBody, password),
      publishedAt: publishedAt,
    );
  }
}

class _Message {
  const _Message({
    required this.id,
    required this.title,
    required this.summary,
    required this.body,
    this.publishedAt,
  });

  final String id;
  final String title;
  final String summary;
  final String body;
  final String? publishedAt;
}

class _KdfConfig {
  const _KdfConfig({
    required this.salt,
    required this.iterations,
    required this.hash,
  });

  factory _KdfConfig.fromJson(Map<String, dynamic> json) {
    return _KdfConfig(
      salt: base64.decode(json['salt'] as String),
      iterations: json['iterations'] as int? ?? 120000,
      hash: json['hash'] as String? ?? 'sha256',
    );
  }

  final List<int> salt;
  final int iterations;
  final String hash;
}

String _xorDecode(String base64Input, String password) {
  final encrypted = base64.decode(base64Input);
  final key = utf8.encode(password);
  final decoded = List<int>.generate(
    encrypted.length,
    (i) => encrypted[i] ^ key[i % key.length],
    growable: false,
  );
  return utf8.decode(decoded);
}

Future<SecretKey> _deriveKey(String password, _KdfConfig config) {
  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: config.iterations,
    bits: 256,
  );
  return pbkdf2.deriveKey(
    secretKey: SecretKey(utf8.encode(password)),
    nonce: config.salt,
  );
}
