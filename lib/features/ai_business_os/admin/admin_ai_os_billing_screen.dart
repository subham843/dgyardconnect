import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_auth_service.dart';
import '../../../features/admin/widgets/admin_embedded_scaffold.dart';
import '../../shop/data/shop_razorpay_launcher.dart';
import '../data/bos_repository.dart';
import '../domain/bos_models.dart';
import '../domain/bos_permissions.dart';

class AdminAiOsBillingScreen extends StatefulWidget {
  const AdminAiOsBillingScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminAiOsBillingScreen> createState() => _AdminAiOsBillingScreenState();
}

class _AdminAiOsBillingScreenState extends State<AdminAiOsBillingScreen> {
  final _repo = BosRepository();
  List<BosPlan> _plans = [];
  BosSubscription? _sub;
  BosTenant? _tenant;
  List<Map<String, dynamic>> _invoices = [];
  Map<String, dynamic>? _usage;
  Map<String, dynamic>? _mrr;
  bool _loading = true;
  bool _paying = false;
  bool get _isSuperadmin => SupabaseAuthService.instance.currentJwtIsSuperadmin;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final tid = await _repo.activeTenantId;
    final plans = await _repo.listPlans();
    final sub = await _repo.getSubscription(tid);
    final invoices = await _repo.listInvoices(tid);
    final tenant = await _repo.getTenant(tid);
    Map<String, dynamic>? usage;
    Map<String, dynamic>? mrr;
    try {
      usage = await _repo.usageSummary();
    } catch (_) {}
    if (_isSuperadmin) {
      try {
        mrr = await _repo.mrrOverview();
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _plans = plans;
        _sub = sub;
        _invoices = invoices;
        _tenant = tenant;
        _usage = usage;
        _mrr = mrr;
        _loading = false;
      });
    }
  }

  String _rupees(num paise) => '₹${(paise / 100).toStringAsFixed(0)}';

  Future<void> _payForPlan(BosPlan plan) async {
    if (!BosPermissions.canManageSettings) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You do not have permission to change plans')),
        );
      }
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final taxable = plan.priceMonthlyPaise;
        final gst = (taxable * 18 / 100).round();
        final total = taxable + gst;
        return AlertDialog(
          title: Text('Upgrade to ${plan.name}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Taxable: ${_rupees(taxable)}'),
              Text('GST 18% (CGST+SGST): ${_rupees(gst)}'),
              const SizedBox(height: 8),
              Text('Total: ${_rupees(total)}/mo', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Pay with Razorpay')),
          ],
        );
      },
    );
    if (ok != true) return;

    setState(() => _paying = true);
    try {
      final checkout = await _repo.createBillingCheckout(plan.id);
      if (checkout['free'] == true) {
        await _repo.refreshFeatureFlags();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Plan ${checkout['plan']} activated (no charge)')),
          );
        }
        await _load();
        return;
      }

      final invoiceId = '${checkout['invoiceId']}';
      final keyId = '${checkout['keyId']}';
      final orderId = '${checkout['razorpayOrderId']}';
      final amountPaise = (checkout['amountPaise'] as num?)?.toInt() ?? 0;

      await ShopRazorpayLauncher.open(
        keyId: keyId,
        razorpayOrderId: orderId,
        amountPaise: amountPaise,
        name: 'DG.YARD AI Business OS',
        description: '${plan.name} subscription',
        onSuccess: ({
          required String orderId,
          required String paymentId,
          required String signature,
        }) async {
          try {
            await _repo.verifyBillingPayment(
              invoiceId: invoiceId,
              razorpayOrderId: orderId,
              razorpayPaymentId: paymentId,
              razorpaySignature: signature,
            );
            await _repo.refreshFeatureFlags();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Payment successful — plan activated')),
              );
            }
            await _load();
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
            }
          } finally {
            if (mounted) setState(() => _paying = false);
          }
        },
        onFailure: (msg) {
          if (mounted) {
            setState(() => _paying = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _paying = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _superadminForcePlan(BosPlan plan) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Force switch to ${plan.name}?'),
        content: const Text('Super Admin only — no Razorpay charge.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Force')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.billingAction('change_plan', planId: plan.id);
      await _repo.billingAction('record_usage', metric: 'plan_change');
      await _repo.refreshFeatureFlags();
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _createInvoice() async {
    try {
      final result = await _repo.billingAction('create_invoice', markPaid: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Invoice ${result['invoice_number']} · ${_rupees((result['amount_paise'] as num?) ?? 0)} incl. GST',
            ),
          ),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _setStatus(String status) async {
    try {
      await _repo.billingAction('set_status', status: status);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totals = (_usage?['totals'] is Map)
        ? Map<String, dynamic>.from(_usage!['totals'] as Map)
        : <String, dynamic>{};
    final limits = (_usage?['limits'] is Map)
        ? Map<String, dynamic>.from(_usage!['limits'] as Map)
        : <String, dynamic>{};
    final overLimitMetrics = <String>[];
    for (final e in totals.entries) {
      final lim = limits[e.key];
      if (lim is! num || lim < 0) continue;
      final used = (e.value is num) ? (e.value as num).toDouble() : 0.0;
      if (used >= lim) overLimitMetrics.add(e.key);
    }

    return AdminEmbeddedScaffold(
      title: 'Subscription & Billing',
      embedded: widget.embedded,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createInvoice,
        icon: const Icon(Icons.receipt_long),
        label: const Text('GST Invoice'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Tenant: ${_tenant?.name ?? '—'} · ${_tenant?.status ?? '—'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text('Subscription: ${_sub?.status ?? 'none'}'),
                if (_paying) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                  const Text('Waiting for Razorpay…'),
                ],
                if (_isSuperadmin) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => _setStatus('active'),
                        child: const Text('Activate'),
                      ),
                      OutlinedButton(
                        onPressed: () => _setStatus('suspended'),
                        child: const Text('Suspend'),
                      ),
                      OutlinedButton(
                        onPressed: () => _setStatus('trial'),
                        child: const Text('Trial'),
                      ),
                    ],
                  ),
                ],
                if (_isSuperadmin && _mrr != null) ...[
                  const SizedBox(height: 20),
                  Text('Platform MRR (Super Admin)', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _rupees((_mrr!['mrr_paise'] as num?) ?? 0),
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo,
                                ),
                          ),
                          Text(
                            'Active: ${_mrr!['active_subscriptions'] ?? 0} · '
                            'Trialing: ${_mrr!['trialing_subscriptions'] ?? 0}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  ...(((_mrr!['tenants'] as List?) ?? []).take(12)).map((raw) {
                    final t = Map<String, dynamic>.from(raw as Map);
                    return ListTile(
                      dense: true,
                      title: Text('${t['tenant_name'] ?? t['slug'] ?? t['tenant_id']}'),
                      subtitle: Text('${t['plan'] ?? '—'} · ${t['sub_status']}'),
                      trailing: Text(_rupees((t['price_monthly_paise'] as num?) ?? 0)),
                    );
                  }),
                ],
                const SizedBox(height: 16),
                const Text('Plans', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  'Pay & upgrade runs Razorpay (amount includes 18% GST).',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                ..._plans.map(
                  (p) => ListTile(
                    title: Text(p.name),
                    subtitle: Text(p.description ?? p.code),
                    trailing: Wrap(
                      spacing: 6,
                      children: [
                        FilledButton.tonal(
                          onPressed: _paying ? null : () => _payForPlan(p),
                          child: Text('${_rupees(p.priceMonthlyPaise)}+GST'),
                        ),
                        if (_isSuperadmin)
                          TextButton(
                            onPressed: () => _superadminForcePlan(p),
                            child: const Text('Force'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Usage (30 days)', style: TextStyle(fontWeight: FontWeight.bold)),
                if (overLimitMetrics.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Card(
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Plan limit reached: ${overLimitMetrics.join(', ')}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Upgrade below to unlock higher quotas for AI replies, campaigns, seats, and voice.',
                            style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.tonal(
                            onPressed: _paying || _plans.isEmpty
                                ? null
                                : () => _payForPlan(_plans.last),
                            child: const Text('Upgrade plan'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (totals.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No usage events yet'),
                  )
                else
                  ...totals.entries.map((e) {
                    final limit = limits[e.key];
                    final used = (e.value is num) ? (e.value as num).toDouble() : 0.0;
                    final limNum = limit is num ? limit.toDouble() : null;
                    final over = limNum != null && limNum >= 0 && used >= limNum;
                    final limLabel = limit == null
                        ? ''
                        : (limit is num && limit < 0)
                            ? ' · unlimited'
                            : ' · limit $limit';
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        over ? Icons.warning_amber : Icons.speed,
                        size: 20,
                        color: over ? Colors.orange : null,
                      ),
                      title: Text(e.key),
                      trailing: Text(
                        '${e.value}$limLabel',
                        style: TextStyle(
                          fontWeight: over ? FontWeight.w600 : null,
                          color: over ? Colors.orange.shade900 : null,
                        ),
                      ),
                    );
                  }),
                if (limits.isNotEmpty && totals.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Plan limits: $limits', style: TextStyle(color: Colors.grey.shade700)),
                  ),
                const SizedBox(height: 16),
                const Text('Invoices (GST)', style: TextStyle(fontWeight: FontWeight.bold)),
                if (_invoices.isEmpty) const Text('No invoices yet'),
                ..._invoices.map((inv) {
                  final taxable = (inv['taxable_paise'] as num?) ?? 0;
                  final cgst = (inv['cgst_paise'] as num?) ?? 0;
                  final sgst = (inv['sgst_paise'] as num?) ?? 0;
                  final total = (inv['amount_paise'] as num?) ?? 0;
                  final rate = inv['gst_rate_pct'] ?? 18;
                  return ListTile(
                    title: Text('${inv['invoice_number'] ?? inv['id']}'),
                    subtitle: Text(
                      '${inv['status']} · taxable ${_rupees(taxable)} · '
                      'CGST/SGST ${_rupees(cgst + sgst)} ($rate%) · total ${_rupees(total)}',
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
