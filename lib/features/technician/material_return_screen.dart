import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../shared/chat_screen.dart' as shared_chat;
import '../../shared/services/firestore_service.dart';
import '../../shared/services/storage_service.dart';
import '../../shared/widgets/fullscreen_image_viewer.dart';
import '../../shared/widgets/technician_glass_kit.dart';

/// Material return flow: technician adds material details, dealer sets handover location
class MaterialReturnScreen extends StatefulWidget {
  const MaterialReturnScreen({super.key, required this.jobId});
  final String jobId;

  @override
  State<MaterialReturnScreen> createState() => _MaterialReturnScreenState();
}

class _MaterialReturnScreenState extends State<MaterialReturnScreen> {
  final List<_MaterialReturnItem> _items = [];
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _addPhotoForItem(int index) async {
    setState(() => _loading = true);
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 50,
      );
      if (xfile == null || !mounted) {
        setState(() => _loading = false);
        return;
      }
      double? lat;
      double? lng;
      try {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission != LocationPermission.denied &&
            permission != LocationPermission.deniedForever) {
          Position? pos;
          try {
            pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 10),
              ),
            );
          } catch (_) {
            pos = await Geolocator.getLastKnownPosition();
          }
          if (pos != null) {
            lat = pos.latitude;
            lng = pos.longitude;
          }
        }
      } catch (_) {}
      if (mounted) {
        setState(() {
          final item = _items[index];
          _items[index] = _MaterialReturnItem(
            name: item.name,
            qty: item.qty,
            filePath: xfile.path,
            latitude: lat,
            longitude: lng,
          );
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
        setState(() => _loading = false);
      }
    }
  }

  void _addItem() {
    final name = _nameController.text.trim();
    final qty = int.tryParse(_qtyController.text.trim()) ?? 1;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter material name')),
      );
      return;
    }
    setState(() {
      _items.add(_MaterialReturnItem(name: name, qty: qty));
      _nameController.clear();
      _qtyController.text = '1';
    });
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  Future<void> _submitReturn() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one material')),
      );
      return;
    }
    final itemsWithPhoto = _items.where((i) => i.filePath != null || i.photoUrl != null).length;
    if (itemsWithPhoto < _items.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add photo for each material')),
      );
      return;
    }
    if (!StorageService.isAvailable || !FirestoreService.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Firebase is not configured.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final materialReturnItems = <Map<String, dynamic>>[];
      for (var i = 0; i < _items.length; i++) {
        final item = _items[i];
        String? photoUrl = item.photoUrl;
        if (photoUrl == null && item.filePath != null) {
          final file = File(item.filePath!);
          photoUrl = await StorageService.uploadMaterialReturnPhoto(
            jobId: widget.jobId,
            index: i,
            file: file,
          );
          if (photoUrl == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Upload failed. Please try again.')),
              );
              setState(() => _loading = false);
            }
            return;
          }
        }
        final m = <String, dynamic>{
          'name': item.name,
          'qty': item.qty,
        };
        if (photoUrl != null) m['photoUrl'] = photoUrl;
        if (item.latitude != null) m['latitude'] = item.latitude;
        if (item.longitude != null) m['longitude'] = item.longitude;
        materialReturnItems.add(m);
      }
      await FirestoreService.jobs().doc(widget.jobId).update({
        'materialReturnRequested': true,
        'materialReturnItems': materialReturnItems,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Material return requested. Waiting for dealer to set handover location.')),
        );
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _callDealer(BuildContext context) async {
    if (Firebase.apps.isEmpty) return;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connecting...')),
      );
      final result = await FirebaseFunctions.instance
          .httpsCallable('initMaskedCall')
          .call({'jobId': widget.jobId});
      if (context.mounted) {
        final msg = (result.data is Map && (result.data as Map)['message'] != null)
            ? (result.data as Map)['message'] as String
            : 'Call initiated.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Call failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: TechnicianGlassAppBar(
        title: 'Need material return',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go('/technician/jobs/${widget.jobId}/finish'),
        ),
      ),
      body: TechnicianGlassBackground(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.jobs().doc(widget.jobId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data() ?? {};
          final materialReturnRequested = data['materialReturnRequested'] == true;
          final handoverLoc = data['materialHandoverLocation'];
          final hasHandover = handoverLoc != null && handoverLoc is GeoPoint;
          final jobStatus = data['status'] as String? ?? '';
          final jobComplete = jobStatus == 'pending_dealer_confirm' || jobStatus == 'completed';

          if (materialReturnRequested && !hasHandover) {
            return _WaitingForDealerContent(
              jobId: widget.jobId,
              onChat: () => shared_chat.showChatPopup(context, widget.jobId),
              onCall: () => _callDealer(context),
            );
          }
          // Dealer set location but job not complete: wait for job OTP first
          if (materialReturnRequested && hasHandover && !jobComplete) {
            return _WaitingForJobCompleteOtpContent(
              jobId: widget.jobId,
              onCall: () => _callDealer(context),
            );
          }
          if (materialReturnRequested && hasHandover && jobComplete) {
            return _HandoverSetContent(
              jobId: widget.jobId,
              jobData: data,
              onCall: () => _callDealer(context),
            );
          }
          return _AddMaterialsForm(
            jobId: widget.jobId,
            items: _items,
            loading: _loading,
            nameController: _nameController,
            qtyController: _qtyController,
            onAddItem: _addItem,
            onRemoveItem: _removeItem,
            onAddPhoto: _addPhotoForItem,
            onSubmit: _submitReturn,
          );
        },
      )),
    );
  }
}

class _AddMaterialsForm extends StatelessWidget {
  const _AddMaterialsForm({
    required this.jobId,
    required this.items,
    required this.loading,
    required this.nameController,
    required this.qtyController,
    required this.onAddItem,
    required this.onRemoveItem,
    required this.onAddPhoto,
    required this.onSubmit,
  });
  final String jobId;
  final List<_MaterialReturnItem> items;
  final bool loading;
  final TextEditingController nameController;
  final TextEditingController qtyController;
  final VoidCallback onAddItem;
  final void Function(int) onRemoveItem;
  final void Function(int) onAddPhoto;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add materials to return. Each item needs a photo (camera only, geo-tagged).',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
            const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Material name',
                    hintText: 'e.g. Cable, Switch',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextFormField(
                  controller: qtyController,
                  decoration: const InputDecoration(labelText: 'Qty'),
                  keyboardType: TextInputType.number,
                ),
              ),
              IconButton(
                onPressed: onAddItem,
                icon: const Icon(Icons.add_circle),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (items.isNotEmpty) ...[
            Text('Materials to return', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...List.generate(items.length, (i) {
              final item = items[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${item.name} x${item.qty}'),
                              if (item.filePath != null || item.photoUrl != null)
                                Padding(
                                  padding: const EdgeInsets.only(right: 10.0),
                                  child: SizedBox(
                                    height: 60,
                                    width: 60,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: GestureDetector(
                                        onTap: () => TappableImage.show(context,
                                            url: item.photoUrl,
                                            filePath: item.filePath,
                                            latitude: item.latitude,
                                            longitude: item.longitude),
                                        child: item.filePath != null
                                            ? Image.file(
                                                File(item.filePath!),
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) =>
                                                    const Icon(Icons.broken_image),
                                              )
                                            : Image.network(
                                                item.photoUrl!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) =>
                                                    const Icon(Icons.broken_image),
                                              ),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                OutlinedButton.icon(
                                  onPressed: loading ? null : () => onAddPhoto(i),
                                  icon: const Icon(Icons.camera_alt, size: 18),
                                  label: const Text('Add photo'),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => onRemoveItem(i),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                );
            }),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: loading ? null : onSubmit,
              icon: const Icon(Icons.send),
              label: const Text('Return material'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WaitingForDealerContent extends StatelessWidget {
  const _WaitingForDealerContent({
    required this.jobId,
    required this.onChat,
    required this.onCall,
  });
  final String jobId;
  final VoidCallback onChat;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Icon(Icons.hourglass_empty, size: 64, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6)),
          const SizedBox(height: 24),
          Text(
            'Waiting for dealer to set return location',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            'Dealer will set the location where you need to return the materials. You can chat or call to follow up.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onChat,
                  icon: const Icon(Icons.chat),
                  label: const Text('Chat with dealer'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCall,
                  icon: const Icon(Icons.phone),
                  label: const Text('Call'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shown when dealer has set return location but technician has not completed job OTP yet.
/// Return details/map hidden until job complete OTP is entered.
/// Get OTP button: sends OTP to customer, shows OTP dialog on technician mobile. No navigation to finish screen.
class _WaitingForJobCompleteOtpContent extends StatefulWidget {
  const _WaitingForJobCompleteOtpContent({
    required this.jobId,
    required this.onCall,
  });
  final String jobId;
  final VoidCallback onCall;

  @override
  State<_WaitingForJobCompleteOtpContent> createState() => _WaitingForJobCompleteOtpContentState();
}

class _WaitingForJobCompleteOtpContentState extends State<_WaitingForJobCompleteOtpContent> {
  bool _loading = false;

  Future<void> _sendJobCompleteOtp() async {
    setState(() => _loading = true);
    try {
      final result = await FirebaseFunctions.instance.httpsCallable('sendOtp').call({
        'jobId': widget.jobId,
        'purpose': 'job_complete',
      });
      final data = result.data;
      final devOtp = data is Map ? data['devOtp'] as String? : null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              devOtp != null
                  ? 'OTP: $devOtp (SMS/FCM se nahi aaya to yahi use karein)'
                  : 'OTP sent to customer.',
            ),
            duration: const Duration(seconds: 8),
          ),
        );
        _showVerifyOtpDialog(devOtp: devOtp);
      }
    } catch (e) {
      if (mounted) {
        final msg = e is FirebaseFunctionsException
            ? (e.message ?? e.code)
            : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $msg')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showVerifyOtpDialog({String? devOtp}) {
    final codeController = TextEditingController(text: devOtp ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter OTP'),
        content: TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(
            labelText: 'OTP code',
            hintText: devOtp != null ? 'OTP yahan dikh raha hai' : '6 digits (customer ke paas bheja gaya)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.isEmpty) return;
              try {
                await FirebaseFunctions.instance.httpsCallable('verifyOtp').call({
                  'jobId': widget.jobId,
                  'purpose': 'job_complete',
                  'code': code,
                });
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) {
                  await FirestoreService.jobs().doc(widget.jobId).update({
                    'status': 'pending_dealer_confirm',
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('OTP verified. Return details ab dikhenge.')),
                    );
                    // Stay on material return – StreamBuilder will rebuild and show _HandoverSetContent
                  }
                }
              } catch (e) {
                if (ctx.mounted) {
                  final msg = e is FirebaseFunctionsException
                      ? (e.message ?? e.code)
                      : e.toString();
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Verification failed: $msg')),
                  );
                }
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Icon(Icons.location_on, size: 64, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6)),
          const SizedBox(height: 24),
          Text(
            'Dealer ne return location set kar diya hai',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            'Waiting for job complete OTP. Button par click karein – OTP customer ko jayega, aap OTP dal kar verify karein. OTP dalne ke baad return details dikhenge.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _loading ? null : _sendJobCompleteOtp,
            icon: const Icon(Icons.sms_outlined),
            label: const Text('Get job finish OTP'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: widget.onCall,
            icon: const Icon(Icons.phone),
            label: const Text('Call dealer'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ],
      ),
    );
  }
}

class _HandoverSetContent extends StatefulWidget {
  const _HandoverSetContent({
    required this.jobId,
    required this.jobData,
    required this.onCall,
  });
  final String jobId;
  final Map<String, dynamic> jobData;
  final VoidCallback onCall;

  @override
  State<_HandoverSetContent> createState() => _HandoverSetContentState();
}

class _HandoverSetContentState extends State<_HandoverSetContent> {
  bool _loading = false;
  final Map<int, String> _afterPhotoUrls = {};

  Future<void> _addAfterPhoto(int index) async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 50,
      );
      if (xfile == null || !mounted) return;
      double? lat;
      double? lng;
      try {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission != LocationPermission.denied &&
            permission != LocationPermission.deniedForever) {
          Position? pos;
          try {
            pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 10),
              ),
            );
          } catch (_) {
            pos = await Geolocator.getLastKnownPosition();
          }
          if (pos != null) {
            lat = pos.latitude;
            lng = pos.longitude;
          }
        }
      } catch (_) {}
      final file = File(xfile.path);
      final url = await StorageService.uploadMaterialReturnAfterPhoto(
        jobId: widget.jobId,
        index: index,
        file: file,
      );
      if (url != null && mounted) {
        setState(() => _afterPhotoUrls[index] = url);
        final items = List<Map<String, dynamic>>.from(
            (widget.jobData['materialReturnItems'] as List<dynamic>?) ?? []);
        if (index < items.length) {
          final update = {...items[index], 'afterPhotoUrl': url};
          if (lat != null) update['afterPhotoLat'] = lat;
          if (lng != null) update['afterPhotoLng'] = lng;
          items[index] = update;
          await FirestoreService.jobs().doc(widget.jobId).update({
            'materialReturnItems': items,
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _requestOtp() async {
    setState(() => _loading = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('sendOtp').call({
        'jobId': widget.jobId,
        'purpose': 'material_return_confirm',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP sent to dealer.')),
        );
        _showVerifyOtpDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showVerifyOtpDialog() {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter OTP'),
        content: TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'OTP code',
            hintText: '6 digits (sent to dealer)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.isEmpty) return;
              try {
                await FirebaseFunctions.instance.httpsCallable('verifyOtp').call({
                  'jobId': widget.jobId,
                  'purpose': 'material_return_confirm',
                  'code': code,
                });
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) {
                  await FirestoreService.jobs().doc(widget.jobId).update({
                    'status': 'pending_dealer_confirm',
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Material return confirmed. Job submitted.')),
                    );
                    context.go('/technician/jobs/${widget.jobId}');
                  }
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Verification failed: $e')),
                  );
                }
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToReturnLocation() async {
    final loc = widget.jobData['materialHandoverLocation'];
    if (loc is! GeoPoint) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${loc.latitude},${loc.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final items = (widget.jobData['materialReturnItems'] as List<dynamic>?) ?? [];
    final addr = widget.jobData['materialHandoverAddress'] as String? ?? 'Return location';
    final atHandover = widget.jobData['executionPhase'] == 'at_handover';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Return material at', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(addr, style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Materials to return – Add after image for each', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...List.generate(items.length, (i) {
            final m = items[i] as Map<String, dynamic>;
            final afterUrl = _afterPhotoUrls[i] ?? m['afterPhotoUrl'] as String?;
            final afterLat = (m['afterPhotoLat'] as num?)?.toDouble();
            final afterLng = (m['afterPhotoLng'] as num?)?.toDouble();
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${m['name'] ?? ''} x${m['qty'] ?? 1}'),
                    const SizedBox(height: 8),
                    if (afterUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 10.0),
                        child: SizedBox(
                          height: 80,
                          width: 80,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: GestureDetector(
                              onTap: () => TappableImage.show(context,
                                  url: afterUrl,
                                  latitude: afterLat,
                                  longitude: afterLng),
                              child: Image.network(afterUrl, fit: BoxFit.cover),
                            ),
                          ),
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: () => _addAfterPhoto(i),
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: const Text('Add after image'),
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              final allHaveAfter = items.asMap().entries.every((e) {
                final m = e.value as Map;
                return _afterPhotoUrls.containsKey(e.key) || m['afterPhotoUrl'] != null;
              });
              if (allHaveAfter && !_loading) {
                _requestOtp();
              } else if (!allHaveAfter) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Add after image for each material')),
                );
              }
            },
            icon: const Icon(Icons.sms_outlined),
            label: const Text('Get return confirm OTP'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
          if (!atHandover) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _navigateToReturnLocation,
              icon: const Icon(Icons.navigation),
              label: const Text('Get return direction'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (widget.jobData['status'] != 'completed')
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => shared_chat.showChatPopup(context, widget.jobId),
                    icon: const Icon(Icons.chat),
                    label: const Text('Chat'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              if (widget.jobData['status'] != 'completed') const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onCall,
                  icon: const Icon(Icons.phone),
                  label: const Text('Call'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MaterialReturnItem {
  _MaterialReturnItem({
    required this.name,
    required this.qty,
    this.filePath,
    this.latitude,
    this.longitude,
  }) : photoUrl = null;
  final String name;
  final int qty;
  final String? filePath;
  final String? photoUrl;
  final double? latitude;
  final double? longitude;
}
