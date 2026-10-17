import 'package:flutter_test/flutter_test.dart';
import '../../../tool/real_world_sms_suite.dart' as suite;

void main() {
  test(
    'curated SMS cases preserve amounts and merchant/account extraction',
    suite.main,
  );
}
