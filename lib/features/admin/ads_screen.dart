import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../shared/services/firestore_service.dart';
import '../../shared/services/storage_service.dart';

class AdminAdsScreen extends StatefulWidget {
  const AdminAdsScreen({super.key});

  @override
  State<AdminAdsScreen> createState() => _AdminAdsScreenState();
}

class _AdminAdsScreenState extends State<AdminAdsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ads / Promotions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _showAddAdSheet,
          ),
        ],
      ),
      body: !FirestoreService.isAvailable
          ? const Center(child: Text('Firestore not available'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.ads()
                  .orderBy('order')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.campaign_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No ads yet',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to add image or video ads',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _showAddAdSheet,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Ad'),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final startRaw = data['startDate'];
                    final endRaw = data['endDate'];
                    DateTime? startDate;
                    DateTime? endDate;
                    if (startRaw is Timestamp) startDate = startRaw.toDate();
                    if (endRaw is Timestamp) endDate = endRaw.toDate();
                    if (startRaw is String) startDate = DateTime.tryParse(startRaw);
                    if (endRaw is String) endDate = DateTime.tryParse(endRaw);

                    return _AdListItem(
                      id: doc.id,
                      type: data['type'] as String? ?? 'image',
                      url: data['url'] as String? ?? '',
                      title: data['title'] as String?,
                      link: data['link'] as String?,
                      showInStatus: data['showInStatus'] as bool? ?? true,
                      showInHomeBanner: data['showInHomeBanner'] as bool? ?? false,
                      showInSponsored: data['showInSponsored'] as bool? ?? true,
                      targetRole: data['targetRole'] as String? ?? 'all',
                      statusTapCount: (data['statusTapCount'] as num?)?.toInt() ?? 0,
                      statusViewCount: (data['statusViewCount'] as num?)?.toInt() ?? 0,
                      statusLinkOpenCount: (data['statusLinkOpenCount'] as num?)?.toInt() ?? 0,
                      order: (data['order'] as num?)?.toInt() ?? index,
                      active: data['active'] as bool? ?? true,
                      startDate: startDate,
                      endDate: endDate,
                      onEdit: () => _showEditAdSheet(doc),
                      onDelete: () => _deleteAd(doc.id),
                    );
                  },
                );
              },
            ),
    );
  }

  void _showAddAdSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddEditAdSheet(
        onSave: (type, url, title, description, link, ctaText, order, startDate, endDate, showInStatus, showInHomeBanner, showInSponsored, targetRole) async {
          Navigator.pop(ctx);
          await _addAd(type, url, title, description, link, ctaText, order, startDate, endDate, showInStatus, showInHomeBanner, showInSponsored, targetRole);
        },
      ),
    );
  }

  void _showEditAdSheet(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final startRaw = data['startDate'];
    final endRaw = data['endDate'];
    DateTime? startDate;
    DateTime? endDate;
    if (startRaw is Timestamp) startDate = startRaw.toDate();
    if (endRaw is Timestamp) endDate = endRaw.toDate();
    if (startRaw is String) startDate = DateTime.tryParse(startRaw);
    if (endRaw is String) endDate = DateTime.tryParse(endRaw);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddEditAdSheet(
        initialType: data['type'] as String? ?? 'image',
        initialUrl: data['url'] as String? ?? '',
        initialTitle: data['title'] as String?,
        initialDescription: data['description'] as String?,
        initialLink: data['link'] as String?,
        initialCtaText: data['ctaText'] as String?,
        initialOrder: (data['order'] as num?)?.toInt() ?? 0,
        initialStartDate: startDate,
        initialEndDate: endDate,
        initialShowInStatus: data['showInStatus'] as bool? ?? true,
        initialShowInHomeBanner: data['showInHomeBanner'] as bool? ?? false,
        initialShowInSponsored: data['showInSponsored'] as bool? ?? true,
        initialTargetRole: data['targetRole'] as String? ?? 'all',
        onSave: (type, url, title, description, link, ctaText, order, startDate, endDate, showInStatus, showInHomeBanner, showInSponsored, targetRole) async {
          Navigator.pop(ctx);
          await _updateAd(doc.id, type, url, title, description, link, ctaText, order, startDate, endDate, showInStatus, showInHomeBanner, showInSponsored, targetRole);
        },
      ),
    );
  }

  Future<void> _addAd(
    String type,
    String url,
    String? title,
    String? description,
    String? link,
    String? ctaText,
    int order,
    DateTime? startDate,
    DateTime? endDate,
    bool showInStatus,
    bool showInHomeBanner,
    bool showInSponsored,
    String targetRole,
  ) async {
    if (type == 'link' && (link == null || link.trim().isEmpty) && url.isEmpty) {
      _showSnack('Link URL is required for link type');
      return;
    }
    if (type != 'link' && url.isEmpty) {
      _showSnack('Media URL is required');
      return;
    }
    try {
      final effectiveSponsored =
          (showInStatus || showInHomeBanner) ? false : showInSponsored;
      await FirestoreService.ads().add({
        'type': type,
        'url': url,
        'title': title ?? '',
        'description': description ?? '',
        'link': link ?? '',
        'ctaText': ctaText ?? '',
        'order': order,
        'active': true,
        'showInStatus': showInStatus,
        'showInHomeBanner': showInHomeBanner,
        'showInSponsored': effectiveSponsored,
        'targetRole': targetRole,
        'startDate': startDate != null ? Timestamp.fromDate(startDate) : null,
        'endDate': endDate != null ? Timestamp.fromDate(endDate) : null,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) _showSnack('Ad added');
    } catch (e) {
      if (mounted) _showSnack('Failed: $e');
    }
  }

  Future<void> _updateAd(
    String id,
    String type,
    String url,
    String? title,
    String? description,
    String? link,
    String? ctaText,
    int order,
    DateTime? startDate,
    DateTime? endDate,
    bool showInStatus,
    bool showInHomeBanner,
    bool showInSponsored,
    String targetRole,
  ) async {
    if (type == 'link' && (link == null || link.trim().isEmpty) && url.isEmpty) {
      _showSnack('Link URL is required for link type');
      return;
    }
    if (type != 'link' && url.isEmpty) {
      _showSnack('Media URL is required');
      return;
    }
    try {
      final effectiveSponsored =
          (showInStatus || showInHomeBanner) ? false : showInSponsored;
      await FirestoreService.ads().doc(id).update({
        'type': type,
        'url': url,
        'title': title ?? '',
        'description': description ?? '',
        'link': link ?? '',
        'ctaText': ctaText ?? '',
        'order': order,
        'showInStatus': showInStatus,
        'showInHomeBanner': showInHomeBanner,
        'showInSponsored': effectiveSponsored,
        'targetRole': targetRole,
        'startDate': startDate != null ? Timestamp.fromDate(startDate) : null,
        'endDate': endDate != null ? Timestamp.fromDate(endDate) : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) _showSnack('Ad updated');
    } catch (e) {
      if (mounted) _showSnack('Failed: $e');
    }
  }

  Future<void> _deleteAd(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Ad'),
        content: const Text('Are you sure you want to delete this ad?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirestoreService.ads().doc(id).delete();
      if (mounted) _showSnack('Ad deleted');
    } catch (e) {
      if (mounted) _showSnack('Failed: $e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _AdListItem extends StatelessWidget {
  const _AdListItem({
    required this.id,
    required this.type,
    required this.url,
    this.title,
    this.link,
    required this.showInStatus,
    required this.showInHomeBanner,
    required this.showInSponsored,
    required this.targetRole,
    required this.statusTapCount,
    required this.statusViewCount,
    required this.statusLinkOpenCount,
    required this.order,
    required this.active,
    this.startDate,
    this.endDate,
    required this.onEdit,
    required this.onDelete,
  });

  final String id;
  final String type;
  final String url;
  final String? title;
  final String? link;
  final bool showInStatus;
  final bool showInHomeBanner;
  final bool showInSponsored;
  final String targetRole;
  final int statusTapCount;
  final int statusViewCount;
  final int statusLinkOpenCount;
  final int order;
  final bool active;
  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dateStr = <String>[];
    if (startDate != null) dateStr.add('From ${DateFormat.yMMMd().format(startDate!)}');
    if (endDate != null) dateStr.add('To ${DateFormat.yMMMd().format(endDate!)}');
    final dateSub = dateStr.join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: SizedBox(
          width: 56,
          height: 56,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: type == 'video'
                ? Container(
                    color: Colors.grey.shade200,
                    child: Icon(Icons.videocam, color: Colors.grey.shade600),
                  )
                : CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    errorWidget: (context, url, error) => Icon(Icons.broken_image, color: Colors.grey.shade400),
                  ),
          ),
        ),
        title: Text(
          title ?? (type == 'video' ? 'Video Ad' : (type == 'link' ? 'Link Ad' : 'Image Ad')),
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [
            type.toUpperCase(),
            showInStatus ? 'Status Reel' : 'Carousel',
            showInHomeBanner ? 'Home Banner' : 'No Banner',
            showInSponsored ? 'Sponsored' : 'No Sponsored',
            'Role: ${targetRole.toUpperCase()}',
            'Order: $order',
            'Taps: $statusTapCount',
            'Views: $statusViewCount',
            'Link opens: $statusLinkOpenCount',
            active ? 'Active' : 'Inactive',
            if (dateSub.isNotEmpty) dateSub,
          ].join(' · '),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}

class _AddEditAdSheet extends StatefulWidget {
  const _AddEditAdSheet({
    this.initialType = 'image',
    this.initialUrl = '',
    this.initialTitle,
    this.initialDescription,
    this.initialLink,
    this.initialCtaText,
    this.initialOrder = 0,
    this.initialStartDate,
    this.initialEndDate,
    this.initialShowInStatus = true,
    this.initialShowInHomeBanner = false,
    this.initialShowInSponsored = true,
    this.initialTargetRole = 'all',
    required this.onSave,
  });

  final String initialType;
  final String initialUrl;
  final String? initialTitle;
  final String? initialDescription;
  final String? initialLink;
  final String? initialCtaText;
  final int initialOrder;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final bool initialShowInStatus;
  final bool initialShowInHomeBanner;
  final bool initialShowInSponsored;
  final String initialTargetRole;
  final void Function(
    String type,
    String url,
    String? title,
    String? description,
    String? link,
    String? ctaText,
    int order,
    DateTime? startDate,
    DateTime? endDate,
    bool showInStatus,
    bool showInHomeBanner,
    bool showInSponsored,
    String targetRole,
  ) onSave;

  @override
  State<_AddEditAdSheet> createState() => _AddEditAdSheetState();
}

class _AddEditAdSheetState extends State<_AddEditAdSheet> {
  late String _type;
  late TextEditingController _urlController;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _linkController;
  late TextEditingController _ctaTextController;
  late TextEditingController _orderController;
  DateTime? _startDate;
  DateTime? _endDate;
  late bool _showInStatus;
  late bool _showInHomeBanner;
  late bool _showInSponsored;
  late String _targetRole;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _urlController = TextEditingController(text: widget.initialUrl);
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _descriptionController = TextEditingController(text: widget.initialDescription ?? '');
    _linkController = TextEditingController(text: widget.initialLink ?? '');
    _ctaTextController = TextEditingController(text: widget.initialCtaText ?? '');
    _orderController = TextEditingController(text: widget.initialOrder.toString());
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
    _showInStatus = widget.initialShowInStatus;
    _showInHomeBanner = widget.initialShowInHomeBanner;
    _showInSponsored = widget.initialShowInSponsored;
    _targetRole = widget.initialTargetRole;
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? (_startDate ?? DateTime.now()).add(const Duration(days: 30)),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    _ctaTextController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    setState(() => _uploading = true);
    try {
      final picker = ImagePicker();
      if (_type == 'video') {
        final xfile = await picker.pickVideo(source: ImageSource.gallery);
        if (xfile == null || !mounted) {
          setState(() => _uploading = false);
          return;
        }
        final bytes = await xfile.readAsBytes();
        if (!mounted) {
          setState(() => _uploading = false);
          return;
        }
        final url = await StorageService.uploadAdAsset(
          type: 'video',
          bytes: bytes,
          contentType: 'video/mp4',
        );
        if (url != null && mounted) {
          _urlController.text = url;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video uploaded')));
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload failed. Check storage rules.')));
        }
      } else {
        final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
        if (xfile == null || !mounted) {
          setState(() => _uploading = false);
          return;
        }
        final bytes = await xfile.readAsBytes();
        if (!mounted) {
          setState(() => _uploading = false);
          return;
        }
        final contentType = xfile.mimeType ?? 'image/jpeg';
        final url = await StorageService.uploadAdAsset(
          type: 'image',
          bytes: bytes,
          contentType: contentType,
        );
        if (url != null && mounted) {
          _urlController.text = url;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image uploaded')));
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload failed. Check storage rules.')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
    if (mounted) setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.initialUrl.isEmpty ? 'Add Ad' : 'Edit Ad',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'image', label: Text('Image'), icon: Icon(Icons.image)),
                ButtonSegment(value: 'video', label: Text('Video'), icon: Icon(Icons.videocam)),
                ButtonSegment(value: 'link', label: Text('Link'), icon: Icon(Icons.link_rounded)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Upload guidelines',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _type == 'image'
                        ? '• Size: 1200×675 px (16:9) recommended\n• Format: JPEG, PNG\n• Max file size: 2 MB'
                        : (_type == 'video'
                            ? '• Size: 1080×608 px (16:9) recommended\n• Format: MP4\n• Max duration: 30 seconds'
                            : '• Add any valid URL: Facebook, Instagram, YouTube, website, etc.\n• Use https:// links only'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      height: 1.5,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'URL (or upload below)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: (_uploading || _type == 'link') ? null : _pickAndUpload,
                  child: _uploading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Upload'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _linkController,
              decoration: const InputDecoration(
                labelText: 'Link URL (optional - tap to open)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctaTextController,
              decoration: const InputDecoration(
                labelText: 'CTA button text (e.g. Explore, Apply Now)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              value: _showInStatus,
              onChanged: (value) => setState(() {
                _showInStatus = value;
                if (value) _showInSponsored = false;
              }),
              title: const Text('Show in top status reels'),
              subtitle: const Text('Appears above hero section on dealer/technician home.'),
            ),
            SwitchListTile.adaptive(
              value: _showInHomeBanner,
              onChanged: (value) => setState(() {
                _showInHomeBanner = value;
                if (value) _showInSponsored = false;
              }),
              title: const Text('Show above shortcuts (full width banner)'),
              subtitle: const Text('If multiple are selected, they auto-slide from down to up.'),
            ),
            SwitchListTile.adaptive(
              value: _showInSponsored,
              onChanged: (value) => setState(() {
                _showInSponsored = value;
                if (value) {
                  _showInStatus = false;
                  _showInHomeBanner = false;
                }
              }),
              title: const Text('Show in sponsored ads section'),
              subtitle: const Text('Controls visibility in the old sponsored carousel.'),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('All users')),
                ButtonSegment(value: 'dealer', label: Text('Dealer')),
                ButtonSegment(value: 'technician', label: Text('Technician')),
              ],
              selected: {_targetRole},
              onSelectionChanged: (s) => setState(() => _targetRole = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _orderController,
              decoration: const InputDecoration(
                labelText: 'Order / Priority (0, 1, 2...)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickStartDate,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      _startDate != null
                          ? DateFormat.yMMMd().format(_startDate!)
                          : 'Start date',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickEndDate,
                    icon: const Icon(Icons.event, size: 18),
                    label: Text(
                      _endDate != null
                          ? DateFormat.yMMMd().format(_endDate!)
                          : 'End date',
                    ),
                  ),
                ),
              ],
            ),
            if (_startDate != null || _endDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Optional: ads only show within date range',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _openPreview,
              icon: const Icon(Icons.preview_rounded),
              label: const Text('Preview full screen'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                final order = int.tryParse(_orderController.text) ?? 0;
                widget.onSave(
                  _type,
                  _urlController.text.trim(),
                  _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
                  _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
                  _linkController.text.trim().isEmpty ? null : _linkController.text.trim(),
                  _ctaTextController.text.trim().isEmpty ? null : _ctaTextController.text.trim(),
                  order,
                  _startDate,
                  _endDate,
                  _showInStatus,
                  _showInHomeBanner,
                  _showInSponsored,
                  _targetRole,
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _openPreview() {
    final type = _type;
    final url = _urlController.text.trim();
    final link = _linkController.text.trim();
    final title = _titleController.text.trim();
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog.fullscreen(
        child: _AdminStatusPreviewScreen(
          type: type,
          url: url,
          link: link,
          title: title,
        ),
      ),
    );
  }
}

class _AdminStatusPreviewScreen extends StatelessWidget {
  const _AdminStatusPreviewScreen({
    required this.type,
    required this.url,
    required this.link,
    required this.title,
  });

  final String type;
  final String url;
  final String link;
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = type.toLowerCase();
    final effectiveLink = link.isNotEmpty ? link : url;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: t == 'video'
                  ? _AdminPreviewVideo(url: url)
                  : (t == 'link'
                      ? _AdminPreviewLink(url: effectiveLink)
                      : Center(
                          child: CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.contain,
                            errorWidget: (_, _, _) => const Icon(
                              Icons.broken_image_rounded,
                              color: Colors.white70,
                              size: 44,
                            ),
                          ),
                        )),
            ),
            Positioned(
              top: 12,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
            if (title.isNotEmpty)
              Positioned(
                left: 14,
                right: 14,
                bottom: 20,
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AdminPreviewVideo extends StatefulWidget {
  const _AdminPreviewVideo({required this.url});
  final String url;

  @override
  State<_AdminPreviewVideo> createState() => _AdminPreviewVideoState();
}

class _AdminPreviewVideoState extends State<_AdminPreviewVideo> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.url.isNotEmpty) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() {});
          _controller!.play();
        });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return Center(
      child: AspectRatio(
        aspectRatio: c.value.aspectRatio == 0 ? 9 / 16 : c.value.aspectRatio,
        child: VideoPlayer(c),
      ),
    );
  }
}

class _AdminPreviewLink extends StatefulWidget {
  const _AdminPreviewLink({required this.url});
  final String url;

  @override
  State<_AdminPreviewLink> createState() => _AdminPreviewLinkState();
}

class _AdminPreviewLinkState extends State<_AdminPreviewLink> {
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    final uri = Uri.tryParse(widget.url);
    if (uri != null && uri.hasScheme) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Center(
        child: Text(
          'Invalid URL',
          style: TextStyle(color: Colors.white),
        ),
      );
    }
    return WebViewWidget(controller: _controller!);
  }
}
