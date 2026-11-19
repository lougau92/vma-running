import 'package:flutter/foundation.dart' show defaultTargetPlatform;

import 'runtime_environment.dart' show RuntimeEnvironment;

RuntimeEnvironment readEnvironment() =>
    RuntimeEnvironment(platform: defaultTargetPlatform, isWeb: false);

void Function() watchEnvironment(void Function() onChanged) => () {};

void openBrowserPage(String url) {
  throw UnsupportedError('Browser navigation is available on the web');
}

String? takeBrowserQueryParameter(String name) => null;
