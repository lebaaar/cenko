import 'package:cenko/shared/services/deal_text_matcher_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dealTextMatcherServiceProvider = Provider<DealTextMatcherService>((ref) {
  return const DealTextMatcherService();
});
