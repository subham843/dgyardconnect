// Back-compat export — use [CalculatorPage] with initialFamilySlug.
export 'calculator_page.dart' show CalculatorPage;

import 'calculator_page.dart';

@Deprecated('Use CalculatorPage(initialFamilySlug: slug) instead')
class CalculatorDetailPage extends CalculatorPage {
  const CalculatorDetailPage({super.key, required String familySlug})
      : super(initialFamilySlug: familySlug);
}