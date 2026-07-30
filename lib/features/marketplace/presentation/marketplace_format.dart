import 'package:intl/intl.dart';

String marketplaceFormatInr(int pricePaise) {
  final rupees = pricePaise / 100.0;
  return NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: pricePaise % 100 == 0 ? 0 : 2,
  ).format(rupees);
}
