import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/deal_text_matcher_service.dart';

final dealTextMatcherServiceProvider = Provider<DealTextMatcherService>((ref) {
  return const DealTextMatcherService();
});
