import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

/// Full-screen camera scanner; pops with first decoded QR/barcode string, or null if cancelled.
///
/// - Requests [Permission.camera] before opening the scanner (avoids plugin permission deadlocks).
/// - Uses [MobileScannerController] with `autoStart: false` and starts after a short delay so the
///   route / [FlutterFragmentActivity] lifecycle is stable (fixes endless "Starting camera…" on some phones).
class MarketplaceBarcodeScanScreen extends StatefulWidget {
  const MarketplaceBarcodeScanScreen({super.key});

  @override
  State<MarketplaceBarcodeScanScreen> createState() => _MarketplaceBarcodeScanScreenState();
}

class _MarketplaceBarcodeScanScreenState extends State<MarketplaceBarcodeScanScreen> {
  MobileScannerController? _controller;
  bool _done = false;

  _CamGate _gate = _CamGate.checking;

  /// Bumped to force a fresh [MobileScanner] subtree when retrying the camera session.
  int _cameraSession = 0;

  @override
  void initState() {
    super.initState();
    _initCameraGate();
  }

  Future<void> _initCameraGate() async {
    if (kIsWeb) {
      _controller = _buildController();
      if (mounted) setState(() => _gate = _CamGate.ready);
      return;
    }
    try {
      var status = await Permission.camera.status;
      if (!status.isGranted) {
        status = await Permission.camera.request();
      }
      if (!mounted) return;
      if (status.isGranted) {
        _controller = _buildController();
        setState(() => _gate = _CamGate.ready);
      } else {
        setState(() => _gate = _CamGate.denied);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MarketplaceBarcodeScanScreen camera permission: $e');
      }
      if (mounted) setState(() => _gate = _CamGate.denied);
    }
  }

  Future<void> _retryPermission() async {
    setState(() => _gate = _CamGate.checking);
    await _controller?.dispose();
    _controller = null;
    await _initCameraGate();
  }

  /// Fewer formats = faster ML Kit / pipeline init on low-end devices.
  MobileScannerController _buildController() {
    return MobileScannerController(
      autoStart: false,
      detectionSpeed: DetectionSpeed.unrestricted,
      formats: const [
        BarcodeFormat.qrCode,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
      ],
    );
  }

  Future<void> _hardRestartCamera() async {
    final c = _controller;
    if (c == null) return;
    try {
      if (c.value.isRunning) {
        await c.stop();
      }
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    await _controller?.dispose();
    _controller = null;
    _cameraSession++;
    _controller = _buildController();
    setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    final list = capture.barcodes;
    if (list.isEmpty) return;
    final raw = list.first.rawValue;
    if (raw == null || raw.trim().isEmpty) return;
    _done = true;
    if (mounted) {
      Navigator.of(context).pop<String>(raw.trim());
    }
  }

  void _onDetectError(Object error, StackTrace stackTrace) {
    if (kDebugMode) {
      debugPrint('MarketplaceBarcodeScanScreen onDetectError: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan QR or barcode'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop<String?>(null),
        ),
      ),
      body: switch (_gate) {
        _CamGate.checking => _GateMessage(
            title: kIsWeb ? 'Opening scanner' : 'Camera permission',
            subtitle: kIsWeb ? 'Loading…' : 'Requesting access to the camera…',
          ),
        _CamGate.denied => _DeniedBody(
            onRetry: _retryPermission,
            onClose: () => Navigator.of(context).pop<String?>(null),
          ),
        _CamGate.ready => _buildScanner(context),
      },
    );
  }

  Widget _buildScanner(BuildContext context) {
    final c = _controller;
    if (c == null) {
      return const _GateMessage(
        title: 'Scanner',
        subtitle: 'Preparing…',
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: _DeferredStartScanner(
            key: ValueKey<int>(_cameraSession),
            controller: c,
            onDetect: _onDetect,
            onDetectError: _onDetectError,
            onHardRestart: _hardRestartCamera,
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 32,
          child: SafeArea(
            child: Material(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Point the camera at a QR code or barcode. The value will be filled in uppercase.',
                  style: TextStyle(color: Colors.white, height: 1.35),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _CamGate { checking, denied, ready }

/// Starts the [MobileScannerController] after attach + short delay (see [MobileScannerController.autoStart]).
class _DeferredStartScanner extends StatefulWidget {
  const _DeferredStartScanner({
    super.key,
    required this.controller,
    required this.onDetect,
    required this.onDetectError,
    required this.onHardRestart,
  });

  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  final void Function(Object, StackTrace) onDetectError;
  final Future<void> Function() onHardRestart;

  @override
  State<_DeferredStartScanner> createState() => _DeferredStartScannerState();
}

class _DeferredStartScannerState extends State<_DeferredStartScanner> {
  Timer? _stuckTimer;
  bool _showStuckHint = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerTick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _kickoffStart());
  }

  Future<void> _kickoffStart() async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    // Arm before await start(): if the platform channel never completes, we still show Retry.
    _armStuckTimer();
    try {
      await widget.controller.start();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('MarketplaceBarcodeScanScreen controller.start failed: $e\n$st');
      }
      if (mounted) setState(() {});
    }
  }

  void _onControllerTick() {
    final v = widget.controller.value;
    if (v.isInitialized || v.error != null) {
      _stuckTimer?.cancel();
      if (_showStuckHint && mounted) {
        setState(() => _showStuckHint = false);
      }
    }
  }

  void _armStuckTimer() {
    _stuckTimer?.cancel();
    _stuckTimer = Timer(const Duration(seconds: 18), () {
      if (!mounted) return;
      final v = widget.controller.value;
      if (!v.isInitialized && v.error == null) {
        setState(() => _showStuckHint = true);
      }
    });
  }

  @override
  void dispose() {
    _stuckTimer?.cancel();
    widget.controller.removeListener(_onControllerTick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: MobileScanner(
            controller: widget.controller,
            fit: BoxFit.cover,
            useAppLifecycleState: false,
            onDetect: widget.onDetect,
            onDetectError: widget.onDetectError,
            placeholderBuilder: (_) => const ColoredBox(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Starting camera…',
                      style: TextStyle(color: Colors.white70),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Point at a QR code or barcode',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            errorBuilder: (context, error) {
              final detailsMessage = error.errorDetails?.message?.trim() ?? '';
              return ColoredBox(
                color: Colors.black,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          error.errorCode.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, height: 1.4),
                        ),
                        if (detailsMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              detailsMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
                            ),
                          ),
                        const SizedBox(height: 28),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop<String?>(null),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_showStuckHint)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.82),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.camera_outdoor_rounded, color: Colors.white70, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Camera preview is taking too long',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        kIsWeb
                            ? 'Check browser camera permission, then try again.'
                            : 'Close other apps using the camera, or tap Retry to restart the scanner.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.75), height: 1.35),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () async {
                          setState(() => _showStuckHint = false);
                          await widget.onHardRestart();
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry camera'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop<String?>(null),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GateMessage extends StatelessWidget {
  const _GateMessage({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeniedBody extends StatelessWidget {
  const _DeniedBody({required this.onRetry, required this.onClose});

  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 56),
              const SizedBox(height: 20),
              const Text(
                'Camera access is required to scan QR codes and barcodes.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, height: 1.4, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                kIsWeb
                    ? 'Allow the camera when your browser asks, or check site permissions in the address bar.'
                    : 'Tap Allow on the system dialog, or enable Camera in app settings.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), height: 1.35, fontSize: 13),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
              if (!kIsWeb) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    await openAppSettings();
                  },
                  child: const Text('Open app settings'),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: onClose,
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
