import 'package:flutter/foundation.dart' show defaultTargetPlatform;

import 'runtime_environment.dart' show RuntimeEnvironment;

RuntimeEnvironment readEnvironment() =>
    RuntimeEnvironment(platform: defaultTargetPlatform, isWeb: false);

void Function() watchEnvironment(void Function() onChanged) => () {};
