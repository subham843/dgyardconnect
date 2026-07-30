import '../../../../core/bootstrap/firebase_auth_safe.dart';
import '../shop/widgets/store_atoms.dart';

/// Calculator pricing privacy — guests see masked amounts until they sign in.
abstract final class CalculatorPricePrivacy {
  static bool get canSeePrices => FirebaseAuthSafe.isSignedIn;

  /// Masked placeholder used for unit, line, and total prices.
  static const masked = '₹xxx';

  static String format(double? amount) {
    if (!canSeePrices) return masked;
    if (amount == null) return 'Price on request';
    return formatINR(amount);
  }

  static String formatOrDash(double amount) {
    if (!canSeePrices) return masked;
    if (amount <= 0) return '—';
    return formatINR(amount);
  }
}