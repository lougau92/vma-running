import 'dart:js_interop';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;

import 'runtime_environment.dart' show RuntimeEnvironment;

@JS('location.assign')
external void _assignLocation(String url);

Future<bool> openBrowserPage(Uri url) async {
  _assignLocation(url.toString());
  return true;
}

@JS('history.state')
external JSAny? get _historyState;

@JS('history.replaceState')
external void _replaceState(JSAny? state, String title, String url);

String? takeBrowserQueryParameter(String name) {
  final current = Uri.base;
  final query = Map<String, String>.of(current.queryParameters);
  final value = query.remove(name);
  if (value == null) return null;
  _replaceState(
    _historyState,
    '',
    current.replace(queryParameters: query).toString(),
  );
  return value;
}

@JS('window.matchMedia')
external _MediaQuery _matchMedia(String query);

@JS('navigator.userAgent')
external String get _userAgent;

String? feedbackBrowserFamily() {
  final agent = _userAgent;
  if (agent.contains('Firefox/') || agent.contains('FxiOS/')) return 'Firefox';
  if (agent.contains('Edg/') ||
      agent.contains('EdgiOS/') ||
      agent.contains('EdgA/')) {
    return 'Edge';
  }
  if (agent.contains('Chrome/') || agent.contains('CriOS/')) return 'Chrome';
  if (agent.contains('Safari/') && agent.contains('Version/')) return 'Safari';
  return 'Unknown';
}

@JS('navigator.maxTouchPoints')
external int? get _maxTouchPoints;

@JS('navigator.standalone')
external bool? get _iosStandalone;

extension type _MediaQuery(JSObject _) implements JSObject {
  external bool get matches;
  external void addEventListener(String event, JSFunction listener);
  external void removeEventListener(String event, JSFunction listener);
}

const _modes = [
  'window-controls-overlay',
  'fullscreen',
  'standalone',
  'minimal-ui',
];

RuntimeEnvironment readEnvironment() => RuntimeEnvironment(
  platform: defaultTargetPlatform,
  isWeb: true,
  maxTouchPoints: _maxTouchPoints ?? 0,
  displayMode: _modes.firstWhere(
    (mode) => _matchMedia('(display-mode: $mode)').matches,
    orElse: () => (_iosStandalone ?? false) ? 'standalone' : 'browser',
  ),
);

void Function() watchEnvironment(void Function() onChanged) {
  final listener = ((JSAny? event) => onChanged()).toJS;
  final queries = _modes
      .map((mode) => _matchMedia('(display-mode: $mode)'))
      .toList();
  for (final query in queries) {
    query.addEventListener('change', listener);
  }
  return () {
    for (final query in queries) {
      query.removeEventListener('change', listener);
    }
  };
}
