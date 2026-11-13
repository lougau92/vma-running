@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:vma_running/runtime/runtime_probe_web.dart' as probe;

@JS('window.matchMedia')
external JSFunction get _matchMedia;
@JS('window.matchMedia')
external set _matchMedia(JSFunction value);
@JS('Object.defineProperty')
external JSObject _defineProperty(
  JSObject target,
  String key,
  JSObject descriptor,
);
@JS('navigator')
external JSObject get _navigator;

void main() {
  test('browser display-mode changes and Safari standalone are detected', () {
    final original = _matchMedia;
    addTearDown(() {
      _matchMedia = original;
      _defineProperty(
        _navigator,
        'standalone',
        {'value': false, 'configurable': true}.jsify() as JSObject,
      );
    });
    var mode = 'browser';
    final listeners = <JSFunction>[];
    _matchMedia =
        ((String query) =>
                {
                      'matches': query == '(display-mode: $mode)',
                      'addEventListener': ((String event, JSFunction listener) {
                        listeners.add(listener);
                      }).toJS,
                      'removeEventListener':
                          ((String event, JSFunction listener) {
                            listeners.remove(listener);
                          }).toJS,
                    }.jsify()
                    as JSObject)
            .toJS;
    expect(probe.readEnvironment().displayMode, 'browser');
    expect(probe.readEnvironment().isWeb, isTrue);
    var changes = 0;
    final stop = probe.watchEnvironment(() => changes++);
    expect(listeners, hasLength(4));
    mode = 'standalone';
    listeners.first.callAsFunction(null, null);
    expect(changes, 1);
    expect(probe.readEnvironment().displayMode, 'standalone');
    mode = 'fullscreen';
    expect(probe.readEnvironment().displayMode, 'fullscreen');
    stop();
    expect(listeners, isEmpty);
    mode = 'browser';
    _defineProperty(
      _navigator,
      'standalone',
      {'value': true, 'configurable': true}.jsify() as JSObject,
    );
    expect(probe.readEnvironment().displayMode, 'standalone');
    mode = 'fullscreen';
    expect(
      probe.readEnvironment().displayMode,
      'fullscreen',
      reason: 'Safari fallback must not override an explicit display mode',
    );
  });
}
