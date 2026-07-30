import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/platform_expense_model.dart';
import '../../shared/services/firestore_service.dart';

class AdminExpensesScreen extends StatelessWidget {
  const AdminExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Expenses'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go(RouteNames.adminFinance)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.platformExpenses().orderBy('expenseDate', descending: true).limit(200).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No expenses recorded.'),
                  const SizedBox(height: 16),
                  FilledButton.icon(onPressed: () => _showAddDialog(context), icon: const Icon(Icons.add), label: const Text('Add Expense')),
                ],
              ),
            );
          }
          final dateFormat = DateFormat('dd MMM yyyy');
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final e = PlatformExpenseModel.fromFirestore(docs[index]);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(e.expenseTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${e.expenseCategory} · ${e.expenseDate != null ? dateFormat.format(e.expenseDate!) : "—"}'),
                  trailing: Text('₹${e.expenseAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  static void _showAddDialog(BuildContext context) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String category = ExpenseCategories.miscellaneous;
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                  items: ExpenseCategories.all.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => category = v ?? category),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Date'),
                  subtitle: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d != null) setState(() => selectedDate = d);
                  },
                ),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final amount = double.tryParse(amountController.text);
                if (title.isEmpty || amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter title and valid amount')));
                  return;
                }
                Navigator.pop(ctx);
                await FirestoreService.platformExpenses().add({
                  'expenseTitle': title,
                  'expenseCategory': category,
                  'expenseAmount': amount,
                  'expenseDate': Timestamp.fromDate(selectedDate),
                  'expenseNotes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense added')));
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
