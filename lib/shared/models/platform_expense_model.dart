import 'package:cloud_firestore/cloud_firestore.dart';

class PlatformExpenseModel {
  PlatformExpenseModel({
    required this.id,
    required this.expenseTitle,
    required this.expenseCategory,
    required this.expenseAmount,
    this.expenseDate,
    this.expenseNotes,
    this.createdAt,
  });

  final String id;
  final String expenseTitle;
  final String expenseCategory;
  final double expenseAmount;
  final DateTime? expenseDate;
  final String? expenseNotes;
  final DateTime? createdAt;

  factory PlatformExpenseModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return PlatformExpenseModel(
      id: doc.id,
      expenseTitle: d['expenseTitle'] as String? ?? '',
      expenseCategory: d['expenseCategory'] as String? ?? 'Miscellaneous',
      expenseAmount: (d['expenseAmount'] as num?)?.toDouble() ?? 0,
      expenseDate: (d['expenseDate'] as Timestamp?)?.toDate(),
      expenseNotes: d['expenseNotes'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Standard expense categories for admin.
abstract final class ExpenseCategories {
  static const String serverCost = 'Server Cost';
  static const String marketing = 'Marketing';
  static const String employeeSalary = 'Employee Salary';
  static const String paymentGatewayFees = 'Payment Gateway Fees';
  static const String miscellaneous = 'Miscellaneous';

  static const List<String> all = [
    serverCost,
    marketing,
    employeeSalary,
    paymentGatewayFees,
    miscellaneous,
  ];
}
