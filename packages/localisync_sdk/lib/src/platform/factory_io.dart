import 'verification_io.dart';
import 'package:localisync_sdk/core.dart';
import 'cache_io.dart';
import 'preparer_io.dart';

DeliveryCache createCache() => FileDeliveryCache();
ContentPreparer createPreparer() => const PlatformContentPreparer();

DeliveryVerification createVerification() => const IsolateVerification();
