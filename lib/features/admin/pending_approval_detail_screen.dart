import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/user_model.dart';
import '../../shared/services/firestore_service.dart';

class PendingApprovalDetailScreen extends StatelessWidget {
  const PendingApprovalDetailScreen({super.key, required this.uid});

  final String uid;

  static const _bgLight = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        backgroundColor: _bgLight,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Pending approval details', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.pop()),
        ),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Registration details', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.users().doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          final doc = snapshot.data!;
          final user = UserModel.fromFirestore(doc);
          final data = doc.data() ?? {};
          return _DetailBody(doc: doc, user: user, data: data);
        },
      ),
    );
  }

  static String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

/// Loads sectors + sector sub-options then shows all registration details with resolved names.
class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.doc,
    required this.user,
    required this.data,
  });

  final DocumentSnapshot<Map<String, dynamic>> doc;
  final UserModel user;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_MasterDataMaps>(
      future: _loadMasterData(),
        builder: (context, asyncSnap) {
        if (asyncSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final maps = asyncSnap.data ?? _MasterDataMaps.empty();
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionCard(
                title: 'Basic information',
                children: [
                  _DetailRow(label: 'Name', value: user.displayName),
                  _DetailRow(label: 'Email', value: user.email ?? '—'),
                  _DetailRow(
                    label: 'Phone',
                    value: (user.profile?['phone'] as String?) ?? '—',
                  ),
                  _DetailRow(
                    label: 'House no. / Flat no. / Shop no.',
                    value: (user.profile?['houseFlatShopNumber'] as String?) ?? '—',
                  ),
                  _DetailRow(
                    label: 'Building / Apartment',
                    value: (user.profile?['buildingApartment'] as String?) ?? '—',
                  ),
                  _DetailRow(
                    label: 'Landmark',
                    value: (user.profile?['landmark'] as String?) ?? '—',
                  ),
                  _DetailRow(
                    label: 'Role',
                    value: user.role == AppRole.dealer ? 'Dealer' : 'Technician',
                  ),
                  _DetailRow(
                    label: 'Registered at',
                    value: user.createdAt != null
                        ? PendingApprovalDetailScreen._formatDate(user.createdAt!)
                        : '—',
                  ),
                ],
              ),
              if (user.role == AppRole.dealer) ...[
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Dealer sectors (selected at registration)',
                  children: [
                    _DetailRow(
                      label: 'Category / Subcategory',
                      value: _dealerSectorsDisplay(user.dealerSectors, maps.subOptionLabels),
                    ),
                  ],
                ),
              ],
              if (user.role == AppRole.technician) ...[
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Skills (selected at registration)',
                  children: [
                    _DetailRow(
                      label: 'Skills',
                      value: _skillsDisplay(data['skills'], maps.subOptionLabels, maps.skillLabels),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Service area',
                children: _serviceAreaRows(data['serviceArea'] as Map<String, dynamic>?),
              ),
              _kycSection(context, data),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _approve(context, doc.reference),
                      icon: const Icon(Icons.check, size: 20),
                      label: const Text('Approve'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _reject(context, doc.reference),
                      icon: const Icon(Icons.close, size: 20),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<_MasterDataMaps> _loadMasterData() async {
    final sectorSnap = await FirestoreService.sectors().get();
    final subSnap = await FirestoreService.sectorSubOptions().get();
    final skillsSnap = await FirestoreService.skills().get();
    final sectorNames = <String, String>{};
    for (final d in sectorSnap.docs) {
      sectorNames[d.id] = d.data()['name'] as String? ?? d.id;
    }
    final sectorIds = sectorNames.keys.toSet();
    final subOptionLabels = <String, String>{};
    for (final d in subSnap.docs) {
      final id = d.id;
      final name = d.data()['name'] as String? ?? id;
      final sectorId = d.data()['sectorId'] as String? ?? '';
      final sectorName = sectorIds.contains(sectorId) ? sectorNames[sectorId]! : sectorId;
      subOptionLabels[id] = '$name ($sectorName)';
    }
    final skillLabels = <String, String>{};
    for (final d in skillsSnap.docs) {
      skillLabels[d.id] = d.data()['title'] as String? ?? d.id;
    }
    return _MasterDataMaps(sectorNames: sectorNames, subOptionLabels: subOptionLabels, skillLabels: skillLabels);
  }

  static String _dealerSectorsDisplay(List<String>? ids, Map<String, String> sectorNames) {
    if (ids == null || ids.isEmpty) return 'None';
    return ids.map((id) => sectorNames[id] ?? id).join(', ');
  }

  static String _skillsDisplay(dynamic skills, Map<String, String> subOptionLabels, Map<String, String> skillLabels) {
    if (skills == null) return 'None';
    final list = skills is List ? skills : <dynamic>[];
    if (list.isEmpty) return 'None';
    return list.map((s) {
      final id = s is Map ? (s['sectorSubOptionId'] ?? s.toString()) : s.toString();
      return skillLabels[id] ?? subOptionLabels[id] ?? id;
    }).join(', ');
  }

  List<Widget> _serviceAreaRows(Map<String, dynamic>? serviceArea) {
    if (serviceArea == null || serviceArea.isEmpty) {
      return [const _DetailRow(label: 'Service area', value: 'Not set')];
    }
    final lat = serviceArea['latitude'];
    final lng = serviceArea['longitude'];
    final radius = serviceArea['radiusKm'];
    final addressLabel = serviceArea['addressLabel'] as String?;
    final city = serviceArea['city'] as String?;
    final state = serviceArea['state'] as String?;
    final pincode = serviceArea['pincode'] as String?;
    final rows = <Widget>[
      _DetailRow(label: 'Center latitude', value: lat?.toString() ?? '—'),
      _DetailRow(label: 'Center longitude', value: lng?.toString() ?? '—'),
      _DetailRow(label: 'Radius (km)', value: radius?.toString() ?? '—'),
    ];
    if (addressLabel != null && addressLabel.isNotEmpty) {
      rows.add(_DetailRow(label: 'Area / Locality', value: addressLabel));
    }
    if (city != null && city.isNotEmpty) {
      rows.add(_DetailRow(label: 'City', value: city));
    }
    if (state != null && state.isNotEmpty) {
      rows.add(_DetailRow(label: 'State', value: state));
    }
    if (pincode != null && pincode.isNotEmpty) {
      rows.add(_DetailRow(label: 'Pincode', value: pincode));
    }
    return rows;
  }

  Widget _kycSection(BuildContext context, Map<String, dynamic> data) {
    final status = data['kycStatus'] as String?;
    final docs = data['kycDocuments'] as List?;
    if (status == null && (docs == null || docs.isEmpty)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: _SectionCard(
        title: 'KYC',
        children: [
          if (status != null) _DetailRow(label: 'Status', value: status),
          if (docs != null && docs.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Documents', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            ...docs.map((e) {
              final url = e is Map ? (e['url'] ?? e['downloadUrl']) : e.toString();
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SelectableText(
                  url,
                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Future<void> _approve(BuildContext context, DocumentReference<Map<String, dynamic>> ref) async {
    await ref.update({'approved': true});
    if (context.mounted) context.pop();
  }

  Future<void> _reject(BuildContext context, DocumentReference<Map<String, dynamic>> ref) async {
    await ref.update({'approved': false});
    if (context.mounted) context.pop();
  }
}

class _MasterDataMaps {
  _MasterDataMaps({required this.sectorNames, required this.subOptionLabels, required this.skillLabels});
  factory _MasterDataMaps.empty() => _MasterDataMaps(sectorNames: {}, subOptionLabels: {}, skillLabels: {});
  final Map<String, String> sectorNames;
  final Map<String, String> subOptionLabels;
  final Map<String, String> skillLabels;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  static const _cardBorder = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: SelectableText(value, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
