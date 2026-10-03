import 'package:localisync_sdk/core.dart';
import 'cache_web.dart';

DeliveryCache createCache() => IndexedDbDeliveryCache();
ContentPreparer createPreparer() => const CooperativePreparer();

DeliveryVerification createVerification() => const CooperativeVerification();
