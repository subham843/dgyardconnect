import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/constants/analytics_events.dart';
import '../../core/constants/payment_job_copy.dart';
import '../../core/constants/route_names.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/legal_constants.dart';
import '../../core/theme/dealer_ui_tokens.dart';
import '../../shared/models/job_model.dart';
import '../../shared/services/analytics_service.dart';
import '../../shared/services/firestore_service.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.jobId, required this.amount});
  final String jobId;
  final double amount;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _loading = true;
  bool _paying = false;
  String? _error;
  String? _orderId;
  String? _keyId;
  int? _amountInPaise;
  Razorpay? _razorpay;
  String _preferredMethod = 'auto';
  String? _primaryAccountType;

  JobModel? _job;
  double _amountToShow = 0;
  bool _amountAdjustedFromJob = false;

  String get _amountLabel => '₹${_amountToShow.toStringAsFixed(0)}';

  @override
  void initState() {
    super.initState();
    _amountToShow = widget.amount;
    if (!kIsWeb) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    }
    _runInit();
  }

  Future<void> _runInit() async {
    final jobOk = await _loadAndValidateJob();
    if (!jobOk || !mounted) {
      setState(() => _loading = false);
      return;
    }
    await Future.wait([_loadPrimaryAccountAndMethod(), _createOrder()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<bool> _loadAndValidateJob() async {
    if (!FirestoreService.isAvailable || Firebase.apps.isEmpty) {
      setState(() => _error = AppConstants.errorGeneric);
      return false;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _error = AppConstants.errorGeneric);
      return false;
    }
    try {
      final doc = await FirestoreService.jobs().doc(widget.jobId).get();
      if (!doc.exists) {
        setState(() => _error = PaymentJobCopy.jobNotFound);
        return false;
      }
      final job = JobModel.fromFirestore(doc);
      if (job.dealerId != uid) {
        setState(() => _error = PaymentJobCopy.notJobOwner);
        return false;
      }
      if (job.status != JobStatus.paymentPending) {
        setState(() => _error = PaymentJobCopy.jobNotPayable);
        return false;
      }
      final serverAmount =
          job.technicianPayoutAmount ?? job.agreedAmount ?? widget.amount;
      final mismatch = (serverAmount - widget.amount).abs() > 0.009;
      if (!mounted) return false;
      setState(() {
        _job = job;
        _amountToShow = serverAmount;
        _amountAdjustedFromJob = mismatch;
      });
      return true;
    } catch (_) {
      setState(() => _error = AppConstants.errorGeneric);
      return false;
    }
  }

  @override
  void dispose() {
    _razorpay?.clear();
    super.dispose();
  }

  Future<void> _createOrder() async {
    if (Firebase.apps.isEmpty) {
      if (mounted) {
        setState(() => _error = AppConstants.errorGeneric);
      }
      return;
    }
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('createRazorpayOrder')
          .call({'jobId': widget.jobId});
      final data = result.data as Map<dynamic, dynamic>?;
      if (data != null && data['orderId'] != null) {
        if (mounted) {
          setState(() {
            _orderId = data['orderId'] as String;
            _keyId = data['keyId'] as String?;
            _amountInPaise = data['amountInPaise'] as int?;
          });
        }
        return;
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('not configured') || msg.contains('Razorpay')) {
        await _lockPaymentLegacy();
        return;
      }
    }
    await _lockPaymentLegacy();
  }

  Future<void> _lockPaymentLegacy() async {
    try {
      await FirebaseFunctions.instance.httpsCallable('lockJobPayment').call({
        'jobId': widget.jobId,
      });
      await AnalyticsService.logEvent(
        AnalyticsEvents.paymentCompleted,
        params: {
          AnalyticsEvents.paramJobId: widget.jobId,
          AnalyticsEvents.paramMethod: 'legacy',
          AnalyticsEvents.paramAmount: _amountToShow,
        },
      );
      if (mounted) {
        await _showPaymentSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '${AppConstants.errorGeneric} $e';
        });
      }
    }
  }

  Future<void> _loadPrimaryAccountAndMethod() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || Firebase.apps.isEmpty) return;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final preferred = userDoc.data()?['preferredRazorpayMethod'] as String?;
      final primaryId =
          userDoc.data()?['primarySettlementAccountId'] as String?;
      String? primaryType;
      if (primaryId != null && primaryId.isNotEmpty) {
        final accountDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('settlement_accounts')
            .doc(primaryId)
            .get();
        primaryType = accountDoc.data()?['type'] as String?;
      }
      if (!mounted) return;
      setState(() {
        _primaryAccountType = primaryType;
        _preferredMethod = (preferred != null && preferred.isNotEmpty)
            ? preferred
            : _methodFromAccountType(primaryType);
      });
    } catch (_) {}
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    if (!mounted) return;
    setState(() => _paying = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('lockJobPayment').call({
        'jobId': widget.jobId,
        'razorpay_order_id': response.orderId,
        'razorpay_payment_id': response.paymentId,
        'razorpay_signature': response.signature,
      });
      await AnalyticsService.logEvent(
        AnalyticsEvents.paymentCompleted,
        params: {
          AnalyticsEvents.paramJobId: widget.jobId,
          AnalyticsEvents.paramMethod: 'razorpay',
          AnalyticsEvents.paramAmount: _amountToShow,
        },
      );
      if (mounted) {
        setState(() => _paying = false);
        await _showPaymentSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _paying = false);
        await _showPaymentFailedDialog(
          '${PaymentJobCopy.verificationFailedPrefix}$e',
        );
      }
    }
  }

  Future<void> _onPaymentError(PaymentFailureResponse response) async {
    if (mounted) {
      setState(() => _paying = false);
      final detail = response.message?.trim();
      await _showPaymentFailedDialog(
        detail != null && detail.isNotEmpty
            ? '${PaymentJobCopy.paymentNotCompletedBody}\n\n($detail)'
            : PaymentJobCopy.paymentNotCompletedBody,
      );
    }
  }

  Future<void> _showPaymentSuccessDialog() async {
    if (!mounted) return;
    final jobRef = _job?.displayId ?? widget.jobId;
    await showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Payment received'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(PaymentJobCopy.paymentRecorded(jobRef)),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) {
                context.go('/dealer/jobs/${widget.jobId}/bidding');
              }
            },
            child: const Text(PaymentJobCopy.viewJob),
          ),
        ],
      ),
    );
  }

  Future<void> _showPaymentFailedDialog(String message) async {
    if (!mounted) return;
    final body = message.trim().isEmpty
        ? PaymentJobCopy.paymentNotCompletedBody
        : message;
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text(PaymentJobCopy.paymentNotCompletedTitle),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(body),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(PaymentJobCopy.tryAgain),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmJobPaymentDialog() async {
    final job = _job;
    if (job == null) return false;
    final jobRef = job.displayId;
    final serviceLine = (job.title != null && job.title!.trim().isNotEmpty)
        ? job.title!.trim()
        : 'On-site service job';
    final locationLine = (job.address != null && job.address!.trim().isNotEmpty)
        ? job.address!.trim()
        : 'See job details for work site';
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text(PaymentJobCopy.confirmDialogTitle),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            PaymentJobCopy.confirmDialogBody(
              jobRef: jobRef,
              amountLabel: _amountLabel,
              serviceLine: serviceLine,
              locationLine: locationLine,
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(PaymentJobCopy.goBackAction),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(PaymentJobCopy.confirmPayAction),
          ),
        ],
      ),
    );
    return result == true;
  }

  String _methodFromAccountType(String? type) {
    switch (type) {
      case 'vpa':
        return 'upi';
      case 'card':
        return 'card';
      case 'bank_account':
        return 'netbanking';
      default:
        return 'auto';
    }
  }

  String _razorpayDescription() {
    final job = _job;
    final ref = job?.displayId ?? widget.jobId;
    final title = (job?.title ?? '').trim();
    final part = title.isNotEmpty ? title : 'On-site service';
    // Keep well under typical gateway limits
    var s = 'D.G.Yard Connect — Job $ref — $part — on-site service';
    if (s.length > 220) {
      s = s.substring(0, 217).trimRight();
      s = '$s…';
    }
    return s;
  }

  Future<void> _startRazorpayAfterConfirm() async {
    final ok = await _showConfirmJobPaymentDialog();
    if (!ok || !mounted) return;
    _openRazorpay();
  }

  Future<void> _startLegacyAfterConfirm() async {
    final ok = await _showConfirmJobPaymentDialog();
    if (!ok || !mounted) return;
    setState(() => _paying = true);
    await _lockPaymentLegacy();
    if (mounted) setState(() => _paying = false);
  }

  void _openRazorpay() {
    if (_keyId == null ||
        _orderId == null ||
        _amountInPaise == null ||
        _razorpay == null) {
      return;
    }
    setState(() => _paying = true);
    final options = {
      'key': _keyId,
      'amount': _amountInPaise,
      'order_id': _orderId,
      'name': 'D.G.Yard Connect',
      'description': _razorpayDescription(),
      if (_preferredMethod != 'auto') 'method': _preferredMethod,
    };
    _razorpay!.open(options);
  }

  Future<void> _setPreferredMethod(String method) async {
    setState(() => _preferredMethod = method);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || Firebase.apps.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'preferredRazorpayMethod': method,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  ObstructingPreferredSizeWidget _navBar() {
    return CupertinoNavigationBar(
      middle: const Text(PaymentJobCopy.screenTitle),
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => context.pop(),
        child: const Icon(CupertinoIcons.back),
      ),
      border: const Border(bottom: BorderSide(color: Color(0x1A000000))),
    );
  }

  Widget _sheetCard({required Widget child}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: DealerUiTokens.border.withValues(alpha: 0.65),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  Widget _jobSummarySection() {
    final job = _job;
    if (job == null) return const SizedBox.shrink();
    final posted = job.createdAt != null
        ? DateFormat.yMMMd().format(job.createdAt!.toLocal())
        : '—';
    final service = (job.title != null && job.title!.trim().isNotEmpty)
        ? job.title!.trim()
        : 'On-site service job';
    final location = (job.address != null && job.address!.trim().isNotEmpty)
        ? job.address!.trim()
        : 'See job details for work site';

    TextStyle labelStyle = const TextStyle(
      fontSize: 12,
      color: DealerUiTokens.textSecondary,
      fontWeight: FontWeight.w600,
    );
    TextStyle valueStyle = const TextStyle(
      fontSize: 14,
      color: DealerUiTokens.textPrimary,
      height: 1.3,
    );

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: labelStyle),
          const SizedBox(height: 4),
          Text(value, style: valueStyle),
        ],
      ),
    );

    return _sheetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            PaymentJobCopy.sectionJobHeading,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: DealerUiTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          row(PaymentJobCopy.labelJobRef, job.displayId),
          row(PaymentJobCopy.labelService, service),
          row(PaymentJobCopy.labelWorkLocation, location),
          row(PaymentJobCopy.labelPostedOn, posted),
          row(PaymentJobCopy.labelYourRole, PaymentJobCopy.roleDealer),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final useRazorpay = !kIsWeb && _orderId != null;

    return CupertinoPageScaffold(
      navigationBar: _navBar(),
      backgroundColor: DealerUiTokens.pageBg,
      child: SafeArea(
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_loading)
                const Expanded(
                  child: Center(child: CupertinoActivityIndicator(radius: 14)),
                )
              else if (_error != null)
                Expanded(
                  child: Center(
                    child: _sheetCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: DealerUiTokens.textPrimary,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 14),
                          CupertinoButton.filled(
                            onPressed: () =>
                                context.go(RouteNames.dealerMyJobs),
                            child: const Text('Back to jobs'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else ...[
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _sheetCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                PaymentJobCopy.subtitle,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: DealerUiTokens.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                LegalConstants.paymentDisclaimer,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: DealerUiTokens.textSecondary
                                      .withValues(alpha: 0.9),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _jobSummarySection(),
                        const SizedBox(height: 14),
                        if (_amountAdjustedFromJob)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              PaymentJobCopy.amountMismatchHint,
                              style: const TextStyle(
                                fontSize: 12,
                                color: DealerUiTokens.textSecondary,
                              ),
                            ),
                          ),
                        _sheetCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                PaymentJobCopy.sectionAmountHeading,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: DealerUiTokens.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _amountLabel,
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: DealerUiTokens.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                PaymentJobCopy.labelWhatPaymentIsFor,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: DealerUiTokens.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                PaymentJobCopy.amountReasonEscrowBooking,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: DealerUiTokens.textPrimary,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _sheetCard(
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                PaymentJobCopy.sectionEscrowHeading,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: DealerUiTokens.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                PaymentJobCopy.escrowBody,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: DealerUiTokens.textPrimary,
                                  height: 1.35,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                PaymentJobCopy.settlementNote,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: DealerUiTokens.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                PaymentJobCopy.refundNote,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: DealerUiTokens.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _sheetCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                useRazorpay
                                    ? PaymentJobCopy.razorpayCheckoutNote
                                    : PaymentJobCopy.legacyCheckoutLabel,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: DealerUiTokens.textSecondary,
                                ),
                              ),
                              if (useRazorpay) ...[
                                const SizedBox(height: 12),
                                Text(
                                  _primaryAccountType == null
                                      ? 'Choose UPI, card, or net banking in the next step.'
                                      : 'Primary settlement account: ${_primaryAccountType == 'vpa'
                                            ? 'UPI'
                                            : _primaryAccountType == 'card'
                                            ? 'Card'
                                            : 'Bank Account'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: DealerUiTokens.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                CupertinoSlidingSegmentedControl<String>(
                                  groupValue: _preferredMethod,
                                  children: const {
                                    'auto': Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text('Auto'),
                                    ),
                                    'upi': Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text('UPI'),
                                    ),
                                    'card': Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text('Card'),
                                    ),
                                    'netbanking': Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text('Banking'),
                                    ),
                                  },
                                  onValueChanged: (v) {
                                    if (v != null) _setPreferredMethod(v);
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _paying
                              ? null
                              : () => context.push(
                                  RouteNames.supportFaqForRole('dealer'),
                                ),
                          child: const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              PaymentJobCopy.helpLinkLabel,
                              style: TextStyle(
                                fontSize: 14,
                                color: CupertinoColors.activeBlue,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                CupertinoButton.filled(
                  onPressed: _paying
                      ? null
                      : useRazorpay
                      ? _startRazorpayAfterConfirm
                      : _startLegacyAfterConfirm,
                  child: _paying
                      ? const CupertinoActivityIndicator(radius: 12)
                      : Text(
                          useRazorpay
                              ? PaymentJobCopy.primaryPayButton(_amountLabel)
                              : PaymentJobCopy.completePaymentForJob,
                        ),
                ),
                const SizedBox(height: 10),
                CupertinoButton(
                  onPressed: _paying ? null : () => context.pop(),
                  child: const Text(PaymentJobCopy.notNow),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
