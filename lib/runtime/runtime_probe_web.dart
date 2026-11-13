import 'dart:js_interop';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;

import 'runtime_environment.dart' show RuntimeEnvironment;

@JS('window.matchMedia')
external _MediaQuery _matchMedia(String query);

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
