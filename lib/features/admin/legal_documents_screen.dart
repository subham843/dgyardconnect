import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/legal_constants.dart';
import '../../core/constants/route_names.dart';

/// Admin: list legal documents. Tap to edit content in Firestore.
class AdminLegalDocumentsScreen extends StatelessWidget {
  const AdminLegalDocumentsScreen({super.key});

  static const List<MapEntry<String, String>> _items = [
    MapEntry(LegalConstants.termsOfService, 'Terms of Service'),
    MapEntry(LegalConstants.privacyPolicy, 'Privacy Policy'),
    MapEntry(LegalConstants.cancellationPolicy, 'Cancellation Policy'),
    MapEntry(LegalConstants.refundPolicy, 'Refund Policy'),
    MapEntry(LegalConstants.technicianAgreement, 'Technician Agreement'),
    MapEntry(LegalConstants.dealerAgreement, 'Dealer Agreement'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Legal documents'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.adminHome),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: _items.map((e) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(e.value),
              subtitle: const Text('Tap to edit content in Firestore'),
              trailing: const Icon(Icons.edit),
              onTap: () => context.push(
                RouteNames.adminLegalDocumentEdit(e.key),
                extra: e.value,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
