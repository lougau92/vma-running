import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:url_launcher/url_launcher.dart';

import 'runtime_environment.dart' show RuntimeEnvironment;

RuntimeEnvironment readEnvironment() =>
    RuntimeEnvironment(platform: defaultTargetPlatform, isWeb: false);

void Function() watchEnvironment(void Function() onChanged) => () {};

Future<bool> openBrowserPage(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);

String? takeBrowserQueryParameter(String name) => null;

String? feedbackBrowserFamily() => null;
