import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/marketplace_seller_request_repository.dart';
import '../../data/marketplace_seller_request_service.dart';
import '../../domain/marketplace_seller_order_request.dart';
import '../marketplace_format.dart';
import '../widgets/marketplace_premium_shell.dart';

class MarketplaceSellerRequestDetailScreen extends StatefulWidget {
  const MarketplaceSellerRequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<MarketplaceSellerRequestDetailScreen> createState() => _MarketplaceSellerRequestDetailScreenState();
}

class _MarketplaceSellerRequestDetailScreenState extends State<MarketplaceSellerRequestDetailScreen> {
  final _repo = MarketplaceSellerRequestRepository();
  MarketplaceSellerOrderRequest? _request;
  bool _loading = true;
  String? _error;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.requestId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'invalid';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _repo.getRequest(widget.requestId);
      if (!mounted) return;
      setState(() {
        _request = r;
        _loading = false;
        _error = r == null ? 'missing' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'error';
      });
    }
  }

  Future<void> _respond(bool accept) async {
    if (_acting || _request == null || _request!.status != 'open') return;
    setState(() => _acting = true);
    try {
      await MarketplaceSellerRequestService.respond(requestId: widget.requestId, accept: accept);
      if (!mounted) return;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(accept ? 'Accepted' : 'Rejected')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(MarketplaceSellerRequestService.messageForFunctionsException(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MarketplacePremiumShell(
      appBar: AppBar(title: const Text('Request Detail')),
      body: Column(
        children: [
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (widget.requestId.isEmpty) {
      return const Center(child: Text('Invalid request'));
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error == 'missing'
                ? 'Request not found or access denied.'
                : 'Could not load this request.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    final r = _request!;
    final canRespond = r.status == 'open';
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(r.titleSnapshot, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        _row(context, 'Order ref', r.orderId),
        _row(context, 'Line ref', r.lineId),
        _row(context, 'Catalog SKU', r.catalogProductId),
        _row(context, 'Quantity', '${r.quantity}'),
        _row(context, 'Unit price', marketplaceFormatInr(r.unitPricePaise)),
        _row(context, 'Line total', marketplaceFormatInr(r.lineTotalPaise)),
        _row(context, 'Status', r.status),
        if (canRespond) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _acting ? null : () => _respond(false),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _acting ? null : () => _respond(true),
                  child: _acting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Accept'),
                ),
              ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 16),
          Text(
            'This request is closed. Ops will continue fulfilment on their side.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.4),
          ),
        ],
      ],
    );
  }

  static Widget _row(BuildContext context, String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(k, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          ),
          Expanded(child: Text(v, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
