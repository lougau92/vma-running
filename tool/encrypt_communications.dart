import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// Encrypt communications with AES-256-GCM + PBKDF2(salt, iterations, SHA-256).
///
/// Input format (plaintext):
/// {
///   "version": 1,
///   "passwordHint": "optional",
///   "messages": [
///     {"id": "note-1", "title": "...", "summary": "...", "body": "...", "publishedAt": "2025-12-18"}
///   ]
/// }
///
/// Output format (encrypted):
/// {
///   "version": 2,
///   "passwordHint": "...",
///   "kdf": {"salt": "<b64>", "iterations": 120000, "hash": "sha256"},
///   "messages": [
///     {"id": "note-1", "publishedAt": "2025-12-18", "nonce": "<b64>", "cipher": "<b64>", "tag": "<b64>"}
///   ]
/// }
///
/// Usage:
/// dart run tool/encrypt_communications.dart \
///   --input assets/communications/raw_messages.json \
///   --output assets/communications/messages.json \
///   --password "your-password" \
///   --password-hint "ask a coach"
Future<void> main(List<String> args) async {
  final options = _Args.parse(args);
  if (options == null) {
    _printUsage();
    exit(64);
  }

  final inputFile = File(options.input);
  if (!inputFile.existsSync()) {
    stderr.writeln('Input file not found: ${options.input}');
    exit(66);
  }

  final raw = jsonDecode(await inputFile.readAsString()) as Map<String, dynamic>;
  final plaintextMessages =
      (raw['messages'] as List<dynamic>? ?? []).map((e) => _PlainMessage.fromJson(e as Map<String, dynamic>)).toList();

  final salt = _randomBytes(16);
  final kdf = _KdfConfig(
    salt: salt,
    iterations: options.iterations ?? 120000,
    hash: 'sha256',
  );

  final key = await _deriveKey(options.password, kdf);
  final algorithm = AesGcm.with256bits();

  final encryptedMessages = <Map<String, dynamic>>[];
  for (final msg in plaintextMessages) {
    final nonce = _randomBytes(12);
    final secretBox = await algorithm.encrypt(
      utf8.encode(jsonEncode(msg.payload)),
      secretKey: key,
      nonce: nonce,
    );
    encryptedMessages.add({
      'id': msg.id,
      'publishedAt': msg.publishedAt,
      'nonce': base64.encode(nonce),
      'cipher': base64.encode(secretBox.cipherText),
      'tag': base64.encode(secretBox.mac.bytes),
    });
  }

  final output = {
    'version': 2,
    'passwordHint': options.passwordHint ?? raw['passwordHint'],
    'kdf': {
      'salt': base64.encode(salt),
      'iterations': kdf.iterations,
      'hash': kdf.hash,
    },
    'messages': encryptedMessages,
  };

  final outputFile = File(options.output);
  await outputFile.writeAsString(const JsonEncoder.withIndent('  ').convert(output));
  stdout.writeln(
    'Encrypted ${encryptedMessages.length} messages to ${options.output} '
    '(salt=${output['kdf']['salt']}, iterations=${kdf.iterations}).',
  );
}

class _PlainMessage {
  const _PlainMessage({
    required this.id,
    required this.title,
    required this.summary,
    required this.body,
    this.publishedAt,
  });

  factory _PlainMessage.fromJson(Map<String, dynamic> json) {
    return _PlainMessage(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      body: json['body'] as String? ?? '',
      publishedAt: json['publishedAt'] as String?,
    );
  }

  final String id;
  final String title;
  final String summary;
  final String body;
  final String? publishedAt;

  Map<String, String?> get payload => {
        'title': title,
        'summary': summary,
        'body': body,
      };
}

class _Args {
  _Args({
    required this.input,
    required this.output,
    required this.password,
    this.passwordHint,
    this.iterations,
  });

  final String input;
  final String output;
  final String password;
  final String? passwordHint;
  final int? iterations;

  static _Args? parse(List<String> args) {
    String? input;
    String? output;
    String? password;
    String? passwordHint;
    int? iterations;

    for (int i = 0; i < args.length; i++) {
      final arg = args[i];
      String? next() => i + 1 < args.length ? args[i + 1] : null;
      switch (arg) {
        case '--input':
        case '-i':
          input = next();
          i++;
          break;
        case '--output':
        case '-o':
          output = next();
          i++;
          break;
        case '--password':
        case '-p':
          password = next();
          i++;
          break;
        case '--password-hint':
        case '-h':
          passwordHint = next();
          i++;
          break;
        case '--iterations':
          final val = next();
          i++;
          if (val != null) iterations = int.tryParse(val);
          break;
        case '--help':
        case '-?':
          return null;
      }
    }

    if (input == null || output == null || password == null) return null;
    return _Args(
      input: input,
      output: output,
      password: password,
      passwordHint: passwordHint,
      iterations: iterations,
    );
  }
}

class _KdfConfig {
  _KdfConfig({
    required this.salt,
    required this.iterations,
    required this.hash,
  });

  final List<int> salt;
  final int iterations;
  final String hash;
}

List<int> _randomBytes(int length) {
  final rnd = Random.secure();
  return List<int>.generate(length, (_) => rnd.nextInt(256));
}

Future<SecretKey> _deriveKey(String password, _KdfConfig kdf) {
  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: kdf.iterations,
    bits: 256,
  );
  return pbkdf2.deriveKey(
    secretKey: SecretKey(utf8.encode(password)),
    nonce: kdf.salt,
  );
}

void _printUsage() {
  stdout.writeln('Usage: dart run tool/encrypt_communications.dart '
      '--input <raw.json> --output <encrypted.json> --password <secret> '
      '[--password-hint \"hint\"] [--iterations 120000]');
}
