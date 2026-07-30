import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import '../../core/constants/service_completion_constants.dart';
import '../../core/theme/app_colors.dart';

/// Public verification page for Service Completion Record (no login required).
/// Opened via /verify?recordId=xxx (e.g. from QR scan).
class ServiceRecordVerifyScreen extends StatefulWidget {
  const ServiceRecordVerifyScreen({super.key, required this.recordId});

  final String recordId;

  @override
  State<ServiceRecordVerifyScreen> createState() => _ServiceRecordVerifyScreenState();
}

class _ServiceRecordVerifyScreenState extends State<ServiceRecordVerifyScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (widget.recordId.isEmpty) {
      setState(() {
        _error = 'Missing record ID';
        _loading = false;
      });
      return;
    }
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getServiceRecordVerification')
          .call<Map<String, dynamic>>({'recordId': widget.recordId});
      if (mounted) {
        setState(() {
          _data = result.data;
          _error = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst(RegExp(r'^.*Exception:\s*'), '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.symmetric(
      horizontal: (MediaQuery.of(context).size.width > 600) ? 32 : 20,
      vertical: 24,
    );
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: _loading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Verifying record…',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              )
            : _error != null
                ? Padding(
                    padding: padding,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 64, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'Verification failed',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() {
                              _loading = true;
                              _error = null;
                            });
                            _fetch();
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: padding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 20),
                        Center(
                          child: Column(
                            children: [
                              Text(
                                ServiceCompletionConstants.platformHeader,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Record verification',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _row('Record ID', _data!['recordId']?.toString() ?? '—'),
                                _row('Job ID', _data!['jobId']?.toString() ?? '—'),
                                _row('Completion status', _data!['completionStatus']?.toString() ?? '—'),
                                _row('Warranty status', _data!['warrantyStatus']?.toString() ?? '—'),
                                if (_data!['completionDate'] != null)
                                  _row(
                                    'Completion date',
                                    _formatDate(_data!['completionDate']),
                                  ),
                                if (_data!['serviceType'] != null)
                                  _row('Service type', _data!['serviceType']?.toString() ?? '—'),
                                if (_data!['dealerName'] != null)
                                  _row('Dealer', _data!['dealerName']?.toString() ?? '—'),
                                if (_data!['technicianName'] != null)
                                  _row('Technician', _data!['technicianName']?.toString() ?? '—'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.verified, color: Colors.green.shade700, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'This record was verified via D.G.Yard Connect.',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.green.shade900,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          ServiceCompletionConstants.platformDisclaimer,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  String _formatDate(dynamic value) {
    if (value == null) return '—';
    try {
      final dt = DateTime.parse(value.toString());
      return DateFormat('dd MMM yyyy, HH:mm').format(dt);
    } catch (_) {
      return value.toString();
    }
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
