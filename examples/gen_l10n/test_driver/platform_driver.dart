import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) {
    // Called only after the binding confirms every assertion passed. The marker
    // is set at the end of the business test, so an empty/ skipped suite fails.
    if (data?['completedPlatformTests'] != 1) {
      throw StateError('The platform acceptance test did not complete.');
    }
    stdout.writeln('LOCALISYNC_IOS_ACCEPTANCE=${jsonEncode({'passed': 1})}');
  },
);
