import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/supabase/supabase_auth_service.dart';
import '../../../features/admin/widgets/admin_embedded_scaffold.dart';
import '../data/bos_repository.dart';
import '../domain/bos_models.dart';
import '../domain/bos_permissions.dart';
import 'bos_audio_play_stub.dart'
    if (dart.library.html) 'bos_audio_play_web.dart';

class AdminAiOsSettingsScreen extends StatefulWidget {
  const AdminAiOsSettingsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminAiOsSettingsScreen> createState() => _AdminAiOsSettingsScreenState();
}

class _AdminAiOsSettingsScreenState extends State<AdminAiOsSettingsScreen> {
  final _repo = BosRepository();
  List<BosTenant> _allTenants = [];
  BosTenant? _currentTenant;
  List<BosTenantMember> _members = [];
  List<BosDepartment> _departments = [];
  List<BosTenantInvite> _invites = [];
  List<Map<String, dynamic>> _audit = [];
  Map<String, dynamic>? _settingsRow;
  bool _loading = true;
  bool _aiAutoEngage = true;
  String _aiChannel = 'both';
  String _smsProvider = 'stub';
  String _emailProvider = 'stub';
  String _voiceProvider = 'stub';
  String _aiAgentName = 'DG.YARD Sales Agent';
  String _aiLanguage = 'hinglish';
  String _aiTone = 'friendly';
  String _waHint = '';
  String _voiceKeysHint = '';
  final _voiceHints = <String, String>{};
  String _businessType = 'cctv_integrator';
  bool get _isSuperadmin => SupabaseAuthService.instance.currentJwtIsSuperadmin;
  bool _testingDial = false;
  bool _verifyingKeys = false;
  bool _previewingTts = false;
  String? _webhookTwilio;
  String? _webhookExotel;
  String? _webhookTelnyx;
  final _ttsPreviewCtrl = TextEditingController(
    text: 'Namaste, DG.YARD se call aa raha hai. Aapke enquiry ke baare mein baat karni thi.',
  );
  final _inboundGreetingCtrl = TextEditingController(
    text: 'Namaste, DG.YARD mein aapka swagat hai. Please hold — hum aapki madad ke liye yahan hain.',
  );
  final _telnyxPublicKeyCtrl = TextEditingController();
  bool _autoCallbackMissed = true;

  final _nameCtrl = TextEditingController();
  final _primaryCtrl = TextEditingController();
  final _accentCtrl = TextEditingController();
  final _openaiCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _gstinCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _logoCtrl = TextEditingController();
  final _waPhoneIdCtrl = TextEditingController();
  final _waTokenCtrl = TextEditingController();
  final _smsKeyCtrl = TextEditingController();
  final _smsSenderCtrl = TextEditingController();
  final _emailKeyCtrl = TextEditingController();
  final _emailFromCtrl = TextEditingController();
  final _voiceKeyCtrl = TextEditingController();
  final _voiceTokenCtrl = TextEditingController();
  final _voiceSidCtrl = TextEditingController();
  final _voiceNumberCtrl = TextEditingController();
  final _voicePrivateKeyCtrl = TextEditingController();
  final _voiceTestPhoneCtrl = TextEditingController();
  final _sarvamKeyCtrl = TextEditingController();
  final _smsSidCtrl = TextEditingController();
  final _workStartCtrl = TextEditingController(text: '9');
  final _workEndCtrl = TextEditingController(text: '20');
  final _aiAgentNameCtrl = TextEditingController(text: 'DG.YARD Sales Agent');

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _primaryCtrl.dispose();
    _accentCtrl.dispose();
    _openaiCtrl.dispose();
    _whatsappCtrl.dispose();
    _gstinCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _logoCtrl.dispose();
    _waPhoneIdCtrl.dispose();
    _waTokenCtrl.dispose();
    _smsKeyCtrl.dispose();
    _smsSenderCtrl.dispose();
    _emailKeyCtrl.dispose();
    _emailFromCtrl.dispose();
    _voiceKeyCtrl.dispose();
    _voiceTokenCtrl.dispose();
    _voiceSidCtrl.dispose();
    _voiceNumberCtrl.dispose();
    _voicePrivateKeyCtrl.dispose();
    _voiceTestPhoneCtrl.dispose();
    _sarvamKeyCtrl.dispose();
    _smsSidCtrl.dispose();
    _workStartCtrl.dispose();
    _workEndCtrl.dispose();
    _aiAgentNameCtrl.dispose();
    _ttsPreviewCtrl.dispose();
    _inboundGreetingCtrl.dispose();
    _telnyxPublicKeyCtrl.dispose();
    super.dispose();
  }

  String _deptName(String? id) {
    if (id == null) return '—';
    for (final d in _departments) {
      if (d.id == id) return d.name;
    }
    return '—';
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    final tenantId = await _repo.activeTenantId;
    final tenant = await _repo.getTenant(tenantId);
    final members = await _repo.listMembers(tenantId);
    final allTenants = await _repo.listTenants();
    final settings = await _repo.getTenantSettingsRow(tenantId);
    final audit = BosPermissions.canViewAudit ? await _repo.listAuditLog(limit: 40) : <Map<String, dynamic>>[];
    final depts = await _repo.listDepartments(tenantId: tenantId);
    final invites = BosPermissions.canManageMembers
        ? await _repo.listInvites(tenantId: tenantId)
        : <BosTenantInvite>[];
    await _repo.refreshFeatureFlags();
    if (mounted) {
      _currentTenant = tenant;
      _members = members;
      _allTenants = allTenants;
      _settingsRow = settings;
      _audit = audit;
      _departments = depts;
      _invites = invites;
      _nameCtrl.text = tenant?.name ?? '';
      _primaryCtrl.text = tenant?.brandPrimary ?? '#0F172A';
      _accentCtrl.text = tenant?.brandAccent ?? '#2563EB';
      _gstinCtrl.text = tenant?.gstin ?? '';
      _phoneCtrl.text = tenant?.contactPhone ?? '';
      _emailCtrl.text = tenant?.contactEmail ?? '';
      _addressCtrl.text = tenant?.addressLine ?? '';
      _logoCtrl.text = tenant?.logoUrl ?? '';
      _businessType = tenant?.businessType ?? 'cctv_integrator';
      final keys = settings?['api_keys_placeholder'];
      if (keys is Map) {
        _openaiCtrl.text = '${keys['openai'] ?? ''}';
        _whatsappCtrl.text = '${keys['whatsapp'] ?? ''}';
      }
      final apiCfg = settings?['api_config'];
      if (apiCfg is Map) {
        final wa = apiCfg['whatsapp'];
        if (wa is Map) _waPhoneIdCtrl.text = '${wa['phone_number_id'] ?? ''}';
        final sms = apiCfg['sms'];
        if (sms is Map) {
          _smsSenderCtrl.text = '${sms['sender_id'] ?? ''}';
          if (sms['provider'] != null) _smsProvider = '${sms['provider']}';
        }
        final em = apiCfg['email'];
        if (em is Map) {
          _emailFromCtrl.text = '${em['from'] ?? ''}';
          if (em['provider'] != null) _emailProvider = '${em['provider']}';
        }
        final vo = apiCfg['voice'];
        if (vo is Map) {
          _voiceNumberCtrl.text = '${vo['number'] ?? ''}';
          if (vo['provider'] != null) _voiceProvider = '${vo['provider']}';
          if (vo['inbound_greeting'] != null && '${vo['inbound_greeting']}'.isNotEmpty) {
            _inboundGreetingCtrl.text = '${vo['inbound_greeting']}';
          }
          _autoCallbackMissed = vo['auto_callback_missed'] != false;
        }
      }
      final settingsJson = settings?['settings'];
      if (settingsJson is Map) {
        final ai = settingsJson['ai_sales'];
        if (ai is Map) {
          _aiAutoEngage = ai['auto_engage'] != false;
          _aiChannel = '${ai['channel'] ?? 'both'}';
          _smsProvider = '${ai['sms_provider'] ?? _smsProvider}';
          _emailProvider = '${ai['email_provider'] ?? _emailProvider}';
          _voiceProvider = '${ai['voice_provider'] ?? _voiceProvider}';
          final hours = ai['working_hours'];
          if (hours is Map) {
            _workStartCtrl.text = '${hours['start'] ?? 9}';
            _workEndCtrl.text = '${hours['end'] ?? 20}';
          }
        }
        final agent = settingsJson['ai_agent'];
        if (agent is Map) {
          _aiAgentName = '${agent['name'] ?? _aiAgentName}';
          _aiAgentNameCtrl.text = _aiAgentName;
          _aiLanguage = '${agent['language'] ?? _aiLanguage}';
          _aiTone = '${agent['tone'] ?? _aiTone}';
        }
      }
      try {
        final masked = await _repo.getTenantApiConfig(tenantId: tenantId);
        final secrets = masked['api_secrets_masked'];
        if (secrets is Map) {
          final wa = secrets['whatsapp'];
          if (wa is Map && wa['access_token'] is Map) {
            _waHint = '${(wa['access_token'] as Map)['hint'] ?? ''}';
          } else if (secrets['whatsapp'] is Map && (secrets['whatsapp'] as Map)['set'] == true) {
            _waHint = '${(secrets['whatsapp'] as Map)['hint'] ?? 'set'}';
          }
          _voiceHints.clear();
          final voice = secrets['voice'];
          if (voice is Map) {
            for (final e in voice.entries) {
              if (e.value is Map) {
                final nested = Map<String, dynamic>.from(e.value as Map);
                final parts = <String>[];
                for (final f in nested.entries) {
                  if (f.value is Map && (f.value as Map)['set'] == true) {
                    parts.add('${f.key}:${(f.value as Map)['hint'] ?? 'set'}');
                  }
                }
                if (parts.isNotEmpty) _voiceHints['${e.key}'] = parts.join(' · ');
              }
            }
            _voiceKeysHint = _voiceHints[_voiceProvider] ??
                (_voiceHints.isEmpty ? '' : 'saved: ${_voiceHints.keys.join(", ")}');
          }
          final sarvam = secrets['sarvam'];
          if (sarvam is Map && sarvam['api_key'] is Map) {
            // hint only — field stays empty for replace
          }
        }
      } catch (_) { /* optional */ }
      try {
        _webhookTwilio = await _repo.voiceWebhookUrl(provider: 'twilio');
        _webhookExotel = await _repo.voiceWebhookUrl(provider: 'exotel');
        _webhookTelnyx = await _repo.voiceWebhookUrl(provider: 'telnyx');
      } catch (_) {}
      setState(() => _loading = false);
    }
  }

  Future<void> _copyWebhook(String? url, String label) async {
    if (url == null || url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label webhook URL copied')),
    );
  }

  Future<void> _previewTts() async {
    if (!BosPermissions.canManageSettings && !BosPermissions.canEdit) {
      _denied();
      return;
    }
    final text = _ttsPreviewCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _previewingTts = true);
    try {
      final r = await _repo.previewVoiceTts(
        text: text,
        language: _aiLanguage == 'en' ? 'en-IN' : 'hi-IN',
      );
      if (!mounted) return;
      if (r['sim'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${r['note'] ?? 'Stub TTS — set Sarvam API key'}')),
        );
        return;
      }
      final b64 = r['audio_base64']?.toString();
      if (b64 == null || b64.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No audio returned from Sarvam')),
        );
        return;
      }
      playBase64Audio(b64, contentType: '${r['content_type'] ?? 'audio/wav'}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Playing Sarvam TTS preview…')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _previewingTts = false);
    }
  }

  Future<void> _verifyVoiceKeys() async {
    if (!BosPermissions.canManageSettings && !BosPermissions.canEdit) {
      _denied();
      return;
    }
    setState(() => _verifyingKeys = true);
    try {
      await _saveProfile();
      final r = await _repo.verifyVoiceProvider(provider: _voiceProvider);
      if (!mounted) return;
      final live = r['live'] == true || r['ok'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            live
                ? 'Verify OK · ${r['provider']} credentials look valid'
                : 'Verify failed · ${r['error'] ?? r['provider']}',
          ),
          backgroundColor: live ? Colors.teal : Colors.orange.shade800,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _verifyingKeys = false);
    }
  }

  Future<void> _testVoiceDial() async {
    if (!BosPermissions.canCreate && !BosPermissions.canEdit) {
      _denied();
      return;
    }
    final phone = _voiceTestPhoneCtrl.text.trim().isNotEmpty
        ? _voiceTestPhoneCtrl.text.trim()
        : _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter test phone (or tenant contact phone)')),
      );
      return;
    }
    setState(() => _testingDial = true);
    try {
      await _saveProfile();
      final id = await _repo.createVoiceCall({
        'phone': phone,
        'status': 'queued',
        'direction': 'outbound',
        'provider': _voiceProvider,
        'script': 'DG.YARD test dial from Settings.',
        'scheduled_at': DateTime.now().toIso8601String(),
        'meta': {'source': 'settings_test_dial'},
      });
      final dial = await _repo.dialVoiceCall(id);
      if (!mounted) return;
      final sim = dial['sim'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sim
                ? 'Test dial stub — check ${_voiceProvider} secrets (sim=true)'
                : 'Live dial via ${dial['provider']} · status ${dial['status']}',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _testingDial = false);
    }
  }

  Future<void> _switchTenant(String tenantId) async {
    await _repo.setActiveTenantId(tenantId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Switched tenant — JWT re-exchanged for $tenantId')),
      );
    }
    await _loadSettings();
  }

  Future<void> _saveProfile() async {
    if (!BosPermissions.canManageSettings && !BosPermissions.canEdit) {
      _denied();
      return;
    }
    final t = _currentTenant;
    if (t == null) return;
    await _repo.updateTenant(t.id, {
      'name': _nameCtrl.text.trim(),
      'brand_primary': _primaryCtrl.text.trim(),
      'brand_accent': _accentCtrl.text.trim(),
      'gstin': _gstinCtrl.text.trim().isEmpty ? null : _gstinCtrl.text.trim(),
      'business_type': _businessType,
      'contact_email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      'contact_phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      'address_line': _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      'logo_url': _logoCtrl.text.trim().isEmpty ? null : _logoCtrl.text.trim(),
    });
    final workStart = int.tryParse(_workStartCtrl.text.trim()) ?? 9;
    final workEnd = int.tryParse(_workEndCtrl.text.trim()) ?? 20;
    await _repo.upsertTenantSettings(
      tenantId: t.id,
      settings: {
        ...?(_settingsRow?['settings'] as Map<String, dynamic>?),
        'timezone': 'Asia/Kolkata',
        'ai_agent': {
          'name': _aiAgentNameCtrl.text.trim().isEmpty ? 'DG.YARD Sales Agent' : _aiAgentNameCtrl.text.trim(),
          'language': _aiLanguage,
          'tone': _aiTone,
          'knowledge': 'bos_kb_documents',
        },
        'ai_sales': {
          'auto_engage': _aiAutoEngage,
          'channel': _aiChannel,
          'follow_up_days': [1, 3, 7, 15],
          'hot_handover': true,
          'working_hours': {'start': workStart, 'end': workEnd, 'tz': 'Asia/Kolkata'},
          'voice_provider': _voiceProvider,
          'sms_provider': _smsProvider,
          'email_provider': _emailProvider,
          'sequence': [
            {'day': 0, 'type': 'first_contact', 'channel': 'whatsapp'},
            {'day': 1, 'type': 'reminder', 'channel': 'sms'},
            {'day': 3, 'type': 'product_details', 'channel': 'email'},
            {'day': 7, 'type': 'offer', 'channel': 'whatsapp'},
            {'day': 15, 'type': 'reactivation', 'channel': 'email'},
          ],
          'thresholds': {'hot': 70, 'warm': 40},
        },
      },
      apiConfig: {
        'whatsapp': {
          'provider': 'meta',
          'phone_number_id': _waPhoneIdCtrl.text.trim(),
        },
        'sms': {
          'provider': _smsProvider,
          'sender_id': _smsSenderCtrl.text.trim(),
        },
        'email': {
          'provider': _emailProvider,
          'from': _emailFromCtrl.text.trim(),
        },
        'voice': {
          'provider': _voiceProvider,
          'number': _voiceNumberCtrl.text.trim(),
          'inbound_greeting': _inboundGreetingCtrl.text.trim(),
          'auto_callback_missed': _autoCallbackMissed,
        },
      },
      apiKeysPlaceholder: {
        'openai': _openaiCtrl.text.trim(),
        'whatsapp': _whatsappCtrl.text.trim(),
      },
    );
    final secrets = <String, dynamic>{};
    if (_waTokenCtrl.text.trim().isNotEmpty) {
      secrets['whatsapp'] = {'access_token': _waTokenCtrl.text.trim()};
    }
    if (_smsKeyCtrl.text.trim().isNotEmpty || _smsSidCtrl.text.trim().isNotEmpty) {
      secrets['sms'] = {
        if (_smsKeyCtrl.text.trim().isNotEmpty) 'api_key': _smsKeyCtrl.text.trim(),
        if (_smsSidCtrl.text.trim().isNotEmpty) 'account_sid': _smsSidCtrl.text.trim(),
      };
    }
    if (_emailKeyCtrl.text.trim().isNotEmpty) {
      secrets['email'] = {'api_key': _emailKeyCtrl.text.trim()};
    }
    if (_voiceKeyCtrl.text.trim().isNotEmpty ||
        _voiceTokenCtrl.text.trim().isNotEmpty ||
        _voiceSidCtrl.text.trim().isNotEmpty ||
        _voiceNumberCtrl.text.trim().isNotEmpty ||
        _voicePrivateKeyCtrl.text.trim().isNotEmpty ||
        _telnyxPublicKeyCtrl.text.trim().isNotEmpty) {
      // Per-provider bucket: api_secrets.voice.exotel / .twilio / .plivo / ...
      final providerKey = _voiceProvider == 'stub' ? 'exotel' : _voiceProvider;
      final nested = <String, dynamic>{
        if (_voiceNumberCtrl.text.trim().isNotEmpty) 'number': _voiceNumberCtrl.text.trim(),
      };
      switch (providerKey) {
        case 'twilio':
          if (_voiceSidCtrl.text.trim().isNotEmpty) {
            nested['account_sid'] = _voiceSidCtrl.text.trim();
          }
          if (_voiceKeyCtrl.text.trim().isNotEmpty) {
            nested['auth_token'] = _voiceKeyCtrl.text.trim();
          }
          break;
        case 'plivo':
          if (_voiceSidCtrl.text.trim().isNotEmpty) nested['auth_id'] = _voiceSidCtrl.text.trim();
          if (_voiceKeyCtrl.text.trim().isNotEmpty) {
            nested['auth_token'] = _voiceKeyCtrl.text.trim();
          }
          break;
        case 'vonage':
          if (_voiceKeyCtrl.text.trim().isNotEmpty) nested['api_key'] = _voiceKeyCtrl.text.trim();
          if (_voiceTokenCtrl.text.trim().isNotEmpty) {
            nested['api_secret'] = _voiceTokenCtrl.text.trim();
          }
          if (_voiceSidCtrl.text.trim().isNotEmpty) {
            nested['application_id'] = _voiceSidCtrl.text.trim();
          }
          if (_voicePrivateKeyCtrl.text.trim().isNotEmpty) {
            nested['private_key'] = _voicePrivateKeyCtrl.text.trim();
          }
          break;
        case 'knowlarity':
          if (_voiceKeyCtrl.text.trim().isNotEmpty) nested['api_key'] = _voiceKeyCtrl.text.trim();
          if (_voiceTokenCtrl.text.trim().isNotEmpty) {
            nested['authorization'] = _voiceTokenCtrl.text.trim();
          }
          if (_voiceSidCtrl.text.trim().isNotEmpty) {
            nested['k_number'] = _voiceSidCtrl.text.trim();
          }
          break;
        case 'myoperator':
          if (_voiceKeyCtrl.text.trim().isNotEmpty) nested['api_key'] = _voiceKeyCtrl.text.trim();
          if (_voiceTokenCtrl.text.trim().isNotEmpty) {
            nested['secret'] = _voiceTokenCtrl.text.trim();
          }
          if (_voiceSidCtrl.text.trim().isNotEmpty) {
            nested['company_id'] = _voiceSidCtrl.text.trim();
          }
          break;
        case 'telnyx':
          if (_voiceKeyCtrl.text.trim().isNotEmpty) nested['api_key'] = _voiceKeyCtrl.text.trim();
          if (_voiceSidCtrl.text.trim().isNotEmpty) {
            nested['connection_id'] = _voiceSidCtrl.text.trim();
          }
          if (_telnyxPublicKeyCtrl.text.trim().isNotEmpty) {
            nested['public_key'] = _telnyxPublicKeyCtrl.text.trim();
          }
          break;
        default: // exotel
          if (_voiceKeyCtrl.text.trim().isNotEmpty) nested['api_key'] = _voiceKeyCtrl.text.trim();
          if (_voiceTokenCtrl.text.trim().isNotEmpty) {
            nested['api_token'] = _voiceTokenCtrl.text.trim();
          }
          if (_voiceSidCtrl.text.trim().isNotEmpty) {
            nested['account_sid'] = _voiceSidCtrl.text.trim();
          }
      }
      if (nested.isNotEmpty) {
        secrets['voice'] = {providerKey: nested};
      }
    }
    if (_openaiCtrl.text.trim().isNotEmpty) {
      secrets['openai'] = {'api_key': _openaiCtrl.text.trim()};
    }
    if (_sarvamKeyCtrl.text.trim().isNotEmpty) {
      secrets['sarvam'] = {'api_key': _sarvamKeyCtrl.text.trim()};
    }
    if (secrets.isNotEmpty) {
      await _repo.upsertTenantApiConfig(apiSecrets: secrets);
      _waTokenCtrl.clear();
      _smsKeyCtrl.clear();
      _smsSidCtrl.clear();
      _emailKeyCtrl.clear();
      _voiceKeyCtrl.clear();
      _voiceTokenCtrl.clear();
      _voiceSidCtrl.clear();
      _voicePrivateKeyCtrl.clear();
      _telnyxPublicKeyCtrl.clear();
      _openaiCtrl.clear();
      _sarvamKeyCtrl.clear();
    }
    await _repo.writeAuditLog(
      action: 'tenant.settings_update',
      entityType: 'bos_tenants',
      entityId: t.id,
    );
    if (mounted) {
      final telnyxSaved = _voiceProvider == 'telnyx' && secrets.containsKey('voice');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            telnyxSaved
                ? 'Settings saved — Telnyx keys cleared from form (masked hints refresh)'
                : 'Settings saved',
          ),
        ),
      );
    }
    _loadSettings();
  }

  void _denied() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You do not have permission for this action')),
    );
  }

  String _inviteLink(String token) {
    final base = Uri.base.origin;
    return '$base${RouteNames.adminAiOsAcceptInvite}?token=$token';
  }

  Future<void> _showInviteDialog() async {
    if (!BosPermissions.canManageMembers) {
      _denied();
      return;
    }
    final emailCtrl = TextEditingController();
    var role = 'sales';
    String? deptId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Invite by email'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email *'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'owner', child: Text('Owner')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    DropdownMenuItem(value: 'sales', child: Text('Sales')),
                    DropdownMenuItem(value: 'agent', child: Text('Agent')),
                    DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
                  ],
                  onChanged: (v) => setDialogState(() => role = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: deptId,
                  decoration: const InputDecoration(labelText: 'Department'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ..._departments.map(
                      (d) => DropdownMenuItem(value: d.id, child: Text(d.name)),
                    ),
                  ],
                  onChanged: (v) => setDialogState(() => deptId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Create invite')),
          ],
        ),
      ),
    );

    if (confirmed == true && emailCtrl.text.trim().isNotEmpty) {
      try {
        final result = await _repo.createInvite(
          email: emailCtrl.text.trim(),
          role: role,
          departmentId: deptId,
          tenantId: _currentTenant?.id,
        );
        final link = (result.email['link'] as String?)?.isNotEmpty == true
            ? result.email['link'] as String
            : _inviteLink(result.invite.token);
        await Clipboard.setData(ClipboardData(text: link));
        if (!mounted) return;
        final sent = result.email['sent'] == true;
        final sim = result.email['sim'] == true;
        final emailStatus = sent
            ? 'Email sent to ${result.invite.email}'
            : sim
                ? 'Email stub (no Resend key) — link copied'
                : 'Invite created — link copied'
                    '${result.email['error'] != null ? ' · ${result.email['error']}' : ''}';
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(sent ? 'Invite emailed' : 'Invite link ready'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emailStatus),
                const SizedBox(height: 12),
                SelectableText(link),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: link));
                  Navigator.pop(c);
                },
                child: const Text('Copy & close'),
              ),
            ],
          ),
        );
        _loadSettings();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }
  }

  Future<void> _showAddMemberDialog() async {
    if (!BosPermissions.canManageMembers) {
      _denied();
      return;
    }
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final uidCtrl = TextEditingController();
    var role = 'sales';
    String? deptId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add existing user'),
          content: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: uidCtrl, decoration: const InputDecoration(labelText: 'Firebase UID *')),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Display name')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'owner', child: Text('Owner')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    DropdownMenuItem(value: 'sales', child: Text('Sales')),
                    DropdownMenuItem(value: 'agent', child: Text('Agent')),
                    DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
                  ],
                  onChanged: (v) => setDialogState(() => role = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: deptId,
                  decoration: const InputDecoration(labelText: 'Department'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ..._departments.map(
                      (d) => DropdownMenuItem(value: d.id, child: Text(d.name)),
                    ),
                  ],
                  onChanged: (v) => setDialogState(() => deptId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Add')),
          ],
        ),
      ),
    );

    if (confirmed == true && _currentTenant != null && uidCtrl.text.trim().isNotEmpty) {
      await _repo.addMember(
        tenantId: _currentTenant!.id,
        firebaseUid: uidCtrl.text.trim(),
        role: role,
        email: emailCtrl.text.isEmpty ? null : emailCtrl.text,
        displayName: nameCtrl.text.isEmpty ? null : nameCtrl.text,
        departmentId: deptId,
      );
      _loadSettings();
    }
  }

  Future<void> _showCreateDepartmentDialog() async {
    if (!BosPermissions.canManageMembers) {
      _denied();
      return;
    }
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('New department'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name *')),
            TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Code')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      await _repo.createDepartment(
        name: nameCtrl.text.trim(),
        code: codeCtrl.text.trim().isEmpty ? null : codeCtrl.text.trim(),
        tenantId: _currentTenant?.id,
      );
      _loadSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bosRole = SupabaseAuthService.instance.activeBosRole ?? BosPermissions.role;
    final bosTenant = SupabaseAuthService.instance.activeBosTenantId;

    return AdminEmbeddedScaffold(
      title: 'Admin & Settings',
      embedded: widget.embedded,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: Text('Session role: $bosRole'),
                    subtitle: Text(
                      'JWT tenant: ${bosTenant ?? '—'} · app_role: '
                      '${SupabaseAuthService.jwtAppRole(SupabaseAuthService.instance.accessToken) ?? '—'}',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_isSuperadmin && _allTenants.isNotEmpty) ...[
                  const Text('Tenant switcher (Super Admin)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _currentTenant?.id,
                    items: _allTenants
                        .map((t) => DropdownMenuItem(value: t.id, child: Text('${t.name} (${t.slug})')))
                        .toList(),
                    onChanged: (id) {
                      if (id != null) _switchTenant(id);
                    },
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 24),
                ],
                const Text('Tenant profile', style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Company name')),
                DropdownButtonFormField<String>(
                  initialValue: _businessType,
                  decoration: const InputDecoration(labelText: 'Business type', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'cctv_integrator', child: Text('CCTV / Security')),
                    DropdownMenuItem(value: 'education', child: Text('Education')),
                    DropdownMenuItem(value: 'retail', child: Text('Retail')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) => setState(() => _businessType = v ?? 'cctv_integrator'),
                ),
                TextField(controller: _gstinCtrl, decoration: const InputDecoration(labelText: 'GSTIN')),
                TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Contact mobile')),
                TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Contact email')),
                TextField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Address')),
                TextField(controller: _logoCtrl, decoration: const InputDecoration(labelText: 'Logo URL')),
                TextField(controller: _primaryCtrl, decoration: const InputDecoration(labelText: 'Brand primary')),
                TextField(controller: _accentCtrl, decoration: const InputDecoration(labelText: 'Brand accent')),
                const SizedBox(height: 16),
                const Text('API management (per company)', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  'Tokens save via Edge (masked after save). Global env used if empty.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
                TextField(
                  controller: _waPhoneIdCtrl,
                  decoration: const InputDecoration(labelText: 'WhatsApp Phone Number ID'),
                ),
                TextField(
                  controller: _waTokenCtrl,
                  decoration: InputDecoration(
                    labelText: _waHint.isEmpty
                        ? 'WhatsApp access token (paste to update)'
                        : 'WhatsApp token (set $_waHint — paste to replace)',
                  ),
                  obscureText: true,
                ),
                TextField(
                  controller: _openaiCtrl,
                  decoration: const InputDecoration(
                    labelText: 'OpenAI API key (tenant — embeddings/AI reply)',
                  ),
                  obscureText: true,
                ),
                TextField(
                  controller: _smsSenderCtrl,
                  decoration: const InputDecoration(labelText: 'SMS sender ID / From'),
                ),
                TextField(
                  controller: _smsSidCtrl,
                  decoration: const InputDecoration(labelText: 'Twilio Account SID (SMS)'),
                  obscureText: true,
                ),
                TextField(
                  controller: _smsKeyCtrl,
                  decoration: const InputDecoration(labelText: 'SMS API key / Auth token (paste to update)'),
                  obscureText: true,
                ),
                TextField(
                  controller: _emailFromCtrl,
                  decoration: const InputDecoration(labelText: 'Email from address'),
                ),
                TextField(
                  controller: _emailKeyCtrl,
                  decoration: const InputDecoration(labelText: 'Email API key (paste to update)'),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                const Text('AI Voice providers', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  'Har provider ke secrets alag save hote hain (voice.exotel / voice.twilio / …). '
                  'Active provider choose karke uske keys paste karo.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
                if (_voiceHints.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 4),
                    child: Text(
                      'Saved: ${_voiceHints.entries.map((e) => '${e.key}(${e.value})').join(' · ')}',
                      style: TextStyle(color: Colors.teal.shade800, fontSize: 12),
                    ),
                  ),
                DropdownButtonFormField<String>(
                  initialValue: _voiceProvider,
                  decoration: const InputDecoration(
                    labelText: 'Active voice provider',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'stub', child: Text('Stub (simulate)')),
                    DropdownMenuItem(value: 'exotel', child: Text('Exotel')),
                    DropdownMenuItem(value: 'twilio', child: Text('Twilio')),
                    DropdownMenuItem(value: 'telnyx', child: Text('Telnyx')),
                    DropdownMenuItem(value: 'plivo', child: Text('Plivo')),
                    DropdownMenuItem(value: 'vonage', child: Text('Vonage (Nexmo)')),
                    DropdownMenuItem(value: 'knowlarity', child: Text('Knowlarity')),
                    DropdownMenuItem(value: 'myoperator', child: Text('MyOperator')),
                  ],
                  onChanged: BosPermissions.canManageSettings || BosPermissions.canEdit
                      ? (v) => setState(() {
                            _voiceProvider = v ?? 'stub';
                            _voiceKeysHint = _voiceHints[_voiceProvider] ?? '';
                          })
                      : null,
                ),
                if (_voiceKeysHint.isNotEmpty)
                  Text(
                    'Current provider keys: $_voiceKeysHint (paste to replace)',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                TextField(
                  controller: _voiceNumberCtrl,
                  decoration: InputDecoration(
                    labelText: _voiceProvider == 'twilio' ||
                            _voiceProvider == 'plivo' ||
                            _voiceProvider == 'telnyx'
                        ? 'Caller ID / From number (E.164)'
                        : 'Voice caller number (ExoPhone / DID / agent)',
                  ),
                ),
                if (_voiceProvider == 'exotel' || _voiceProvider == 'stub') ...[
                  TextField(
                    controller: _voiceSidCtrl,
                    decoration: const InputDecoration(labelText: 'Exotel Account SID'),
                    obscureText: true,
                  ),
                  TextField(
                    controller: _voiceKeyCtrl,
                    decoration: const InputDecoration(labelText: 'Exotel API key'),
                    obscureText: true,
                  ),
                  TextField(
                    controller: _voiceTokenCtrl,
                    decoration: const InputDecoration(labelText: 'Exotel API token'),
                    obscureText: true,
                  ),
                ],
                if (_voiceProvider == 'twilio') ...[
                  TextField(
                    controller: _voiceSidCtrl,
                    decoration: const InputDecoration(labelText: 'Twilio Account SID'),
                    obscureText: true,
                  ),
                  TextField(
                    controller: _voiceKeyCtrl,
                    decoration: const InputDecoration(labelText: 'Twilio Auth Token'),
                    obscureText: true,
                  ),
                ],
                if (_voiceProvider == 'telnyx') ...[
                  TextField(
                    controller: _voiceKeyCtrl,
                    decoration: const InputDecoration(labelText: 'Telnyx API key'),
                    obscureText: true,
                  ),
                  TextField(
                    controller: _voiceSidCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Telnyx Connection ID (Voice API / Call Control app)',
                    ),
                  ),
                  if ((_voiceHints['telnyx'] ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'Saved Telnyx secrets: ${_voiceHints['telnyx']} '
                        '(fields clear after save — paste only to replace)',
                        style: TextStyle(color: Colors.teal.shade800, fontSize: 12),
                      ),
                    ),
                  TextField(
                    controller: _telnyxPublicKeyCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Telnyx public key (optional webhook verify)',
                      hintText: 'Base64 Ed25519 public key from Mission Control',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  Text(
                    '1) Mission Control → Auth → API Key\n'
                    '2) Voice → Call Control Applications → Connection ID\n'
                    '3) Assign a Telnyx number + Outbound Voice Profile\n'
                    '4) Paste webhook URL below (also sent on each dial)\n'
                    '5) Optional: paste Public Key to verify webhook signatures\n'
                    'Dial uses record-from-answer; answered calls speak your script automatically.\n'
                    'Inbound: call.initiated → answer + greeting + lead.',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          const ClipboardData(text: 'https://portal.telnyx.com/#/app/call-control/applications'),
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Telnyx Call Control apps URL copied — open in browser'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Copy Mission Control Call Control URL'),
                    ),
                  ),
                ],
                if (_voiceProvider == 'plivo') ...[
                  TextField(
                    controller: _voiceSidCtrl,
                    decoration: const InputDecoration(labelText: 'Plivo Auth ID'),
                    obscureText: true,
                  ),
                  TextField(
                    controller: _voiceKeyCtrl,
                    decoration: const InputDecoration(labelText: 'Plivo Auth Token'),
                    obscureText: true,
                  ),
                ],
                if (_voiceProvider == 'vonage') ...[
                  TextField(
                    controller: _voiceKeyCtrl,
                    decoration: const InputDecoration(labelText: 'Vonage API key'),
                    obscureText: true,
                  ),
                  TextField(
                    controller: _voiceTokenCtrl,
                    decoration: const InputDecoration(labelText: 'Vonage API secret'),
                    obscureText: true,
                  ),
                  TextField(
                    controller: _voiceSidCtrl,
                    decoration: const InputDecoration(labelText: 'Vonage Application ID'),
                    obscureText: true,
                  ),
                  TextField(
                    controller: _voicePrivateKeyCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Vonage private key PEM (RS256 JWT)',
                    ),
                    obscureText: true,
                  ),
                ],
                if (_voiceProvider == 'knowlarity') ...[
                  TextField(
                    controller: _voiceKeyCtrl,
                    decoration: const InputDecoration(labelText: 'Knowlarity x-api-key'),
                    obscureText: true,
                  ),
                  TextField(
                    controller: _voiceTokenCtrl,
                    decoration: const InputDecoration(labelText: 'Authorization header (optional)'),
                    obscureText: true,
                  ),
                  TextField(
                    controller: _voiceSidCtrl,
                    decoration: const InputDecoration(labelText: 'k_number / SR number'),
                  ),
                ],
                if (_voiceProvider == 'myoperator') ...[
                  TextField(
                    controller: _voiceKeyCtrl,
                    decoration: const InputDecoration(labelText: 'MyOperator API token'),
                    obscureText: true,
                  ),
                  TextField(
                    controller: _voiceTokenCtrl,
                    decoration: const InputDecoration(labelText: 'Secret (optional)'),
                    obscureText: true,
                  ),
                  TextField(
                    controller: _voiceSidCtrl,
                    decoration: const InputDecoration(labelText: 'Company ID (optional)'),
                  ),
                ],
                TextField(
                  controller: _sarvamKeyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Sarvam API key (STT + TTS preview)',
                  ),
                  obscureText: true,
                ),
                TextField(
                  controller: _ttsPreviewCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'TTS preview script (Hinglish/Hindi)',
                    border: OutlineInputBorder(),
                  ),
                ),
                TextField(
                  controller: _inboundGreetingCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Inbound call greeting (Telnyx/Exotel answer)',
                    border: OutlineInputBorder(),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto-queue callback on missed inbound'),
                  subtitle: const Text('Creates outbound follow-up ~5 min later'),
                  value: _autoCallbackMissed,
                  onChanged: (BosPermissions.canManageSettings || BosPermissions.canEdit)
                      ? (v) => setState(() => _autoCallbackMissed = v)
                      : null,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _voiceTestPhoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Test dial phone (+91…)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: (BosPermissions.canManageSettings || BosPermissions.canEdit)
                          ? _saveProfile
                          : null,
                      child: const Text('Save settings'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _verifyingKeys ||
                              !(BosPermissions.canManageSettings || BosPermissions.canEdit)
                          ? null
                          : _verifyVoiceKeys,
                      icon: _verifyingKeys
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.verified_user_outlined),
                      label: Text(_verifyingKeys ? 'Verifying…' : 'Verify keys'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _testingDial ||
                              !(BosPermissions.canManageSettings ||
                                  BosPermissions.canEdit ||
                                  BosPermissions.canCreate)
                          ? null
                          : _testVoiceDial,
                      icon: _testingDial
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.phone_forwarded),
                      label: Text(_testingDial ? 'Dialing…' : 'Test dial'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _previewingTts ||
                              !(BosPermissions.canManageSettings || BosPermissions.canEdit)
                          ? null
                          : _previewTts,
                      icon: _previewingTts
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.record_voice_over),
                      label: Text(_previewingTts ? 'TTS…' : 'Preview TTS'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Voice webhooks (paste in provider console)', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  'Status + recording callbacks → bos-voice-webhook (auto STT + inbound lead).',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
                if (_webhookTwilio != null)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Twilio status/recording URL'),
                    subtitle: Text(_webhookTwilio!, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () => _copyWebhook(_webhookTwilio, 'Twilio'),
                    ),
                  ),
                if (_webhookExotel != null)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Exotel status/recording URL'),
                    subtitle: Text(_webhookExotel!, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () => _copyWebhook(_webhookExotel, 'Exotel'),
                    ),
                  ),
                if (_webhookTelnyx != null)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Telnyx webhook URL'),
                    subtitle: Text(_webhookTelnyx!, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () => _copyWebhook(_webhookTelnyx, 'Telnyx'),
                    ),
                  ),
                const SizedBox(height: 24),
                const Text('AI Sales Agent', style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(
                  controller: _aiAgentNameCtrl,
                  decoration: const InputDecoration(labelText: 'Agent name'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _aiLanguage,
                  decoration: const InputDecoration(labelText: 'Language', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'hinglish', child: Text('Hinglish')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                  ],
                  onChanged: (v) => setState(() => _aiLanguage = v ?? 'hinglish'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _aiTone,
                  decoration: const InputDecoration(labelText: 'Tone', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'friendly', child: Text('Friendly')),
                    DropdownMenuItem(value: 'professional', child: Text('Professional')),
                    DropdownMenuItem(value: 'concise', child: Text('Concise')),
                  ],
                  onChanged: (v) => setState(() => _aiTone = v ?? 'friendly'),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _workStartCtrl,
                        decoration: const InputDecoration(labelText: 'Work start hour'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _workEndCtrl,
                        decoration: const InputDecoration(labelText: 'Work end hour'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.menu_book_outlined),
                  title: const Text('Knowledge base'),
                  subtitle: const Text('Tenant-scoped docs feed this AI agent'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // ignore: use_build_context_synchronously
                  },
                ),
                Text(
                  'Open Knowledge from the AI OS menu to upload catalog/FAQ for this company only.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto-engage new leads'),
                  subtitle: const Text('Qualify + WhatsApp/voice on lead create'),
                  value: _aiAutoEngage,
                  onChanged: BosPermissions.canManageSettings || BosPermissions.canEdit
                      ? (v) => setState(() => _aiAutoEngage = v)
                      : null,
                ),
                DropdownButtonFormField<String>(
                  initialValue: _aiChannel,
                  decoration: const InputDecoration(
                    labelText: 'First-touch channel',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
                    DropdownMenuItem(value: 'voice', child: Text('Voice call')),
                    DropdownMenuItem(value: 'both', child: Text('WhatsApp + Voice')),
                  ],
                  onChanged: BosPermissions.canManageSettings || BosPermissions.canEdit
                      ? (v) => setState(() => _aiChannel = v ?? 'both')
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _smsProvider,
                  decoration: const InputDecoration(
                    labelText: 'SMS provider (Edge secret)',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'stub', child: Text('Stub (queued / sent_sim)')),
                    DropdownMenuItem(value: 'twilio', child: Text('Twilio (live when secrets set)')),
                  ],
                  onChanged: BosPermissions.canManageSettings || BosPermissions.canEdit
                      ? (v) => setState(() => _smsProvider = v ?? 'stub')
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _emailProvider,
                  decoration: const InputDecoration(
                    labelText: 'Email provider (Edge secret)',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'stub', child: Text('Stub (queued / sent_sim)')),
                    DropdownMenuItem(value: 'resend', child: Text('Resend (live when secrets set)')),
                  ],
                  onChanged: BosPermissions.canManageSettings || BosPermissions.canEdit
                      ? (v) => setState(() => _emailProvider = v ?? 'stub')
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  'Voice provider + secrets upar “AI Voice providers” section mein hain. '
                  'Follow-up sequence: Day0 WA → Day1 SMS → Day3 Email → Day7 WA → Day15 Email. '
                  'Public chat: /ai-os/chat.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Text('Departments', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (BosPermissions.canManageMembers)
                      TextButton.icon(
                        onPressed: _showCreateDepartmentDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                      ),
                  ],
                ),
                if (_departments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No departments'),
                  )
                else
                  ..._departments.map(
                    (d) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.apartment_outlined, size: 20),
                      title: Text(d.name),
                      subtitle: Text(d.code ?? ''),
                      trailing: BosPermissions.canManageMembers
                          ? IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () async {
                                await _repo.softDeleteDepartment(d.id);
                                _loadSettings();
                              },
                            )
                          : null,
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Members', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (BosPermissions.canManageMembers) ...[
                      TextButton.icon(
                        onPressed: _showInviteDialog,
                        icon: const Icon(Icons.mail_outline),
                        label: const Text('Invite'),
                      ),
                      TextButton.icon(
                        onPressed: _showAddMemberDialog,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Add UID'),
                      ),
                    ],
                  ],
                ),
                if (_members.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No members yet'),
                  ),
                ..._members.map(
                  (m) => ListTile(
                    leading: Icon(
                      m.isActive ? Icons.person : Icons.person_off,
                      color: m.isActive ? null : Colors.grey,
                    ),
                    title: Text(m.displayName ?? m.firebaseUid),
                    subtitle: Text(
                      '${m.role} · ${_deptName(m.departmentId)} · ${m.email ?? m.firebaseUid}'
                      '${m.isActive ? '' : ' · inactive'}',
                    ),
                    trailing: BosPermissions.canManageMembers
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DropdownButton<String?>(
                                value: _departments.any((d) => d.id == m.departmentId)
                                    ? m.departmentId
                                    : null,
                                hint: const Text('Dept'),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('None')),
                                  ..._departments.map(
                                    (d) => DropdownMenuItem(value: d.id, child: Text(d.name)),
                                  ),
                                ],
                                onChanged: (dept) async {
                                  await _repo.updateMemberDepartment(m.id, dept);
                                  _loadSettings();
                                },
                              ),
                              const SizedBox(width: 8),
                              DropdownButton<String>(
                                value: m.role,
                                items: const [
                                  DropdownMenuItem(value: 'owner', child: Text('Owner')),
                                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                                  DropdownMenuItem(value: 'sales', child: Text('Sales')),
                                  DropdownMenuItem(value: 'agent', child: Text('Agent')),
                                  DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
                                ],
                                onChanged: (role) async {
                                  if (role == null) return;
                                  await _repo.updateMemberRole(m.id, role);
                                  _loadSettings();
                                },
                              ),
                              if (m.isActive)
                                IconButton(
                                  tooltip: 'Deactivate',
                                  icon: const Icon(Icons.person_remove_outlined),
                                  onPressed: () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        title: const Text('Deactivate member?'),
                                        content: Text(m.displayName ?? m.firebaseUid),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(c, false),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.pop(c, true),
                                            child: const Text('Deactivate'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (ok == true) {
                                      await _repo.deactivateMember(m.id);
                                      _loadSettings();
                                    }
                                  },
                                ),
                            ],
                          )
                        : Text(m.role),
                  ),
                ),
                if (BosPermissions.canManageMembers) ...[
                  const SizedBox(height: 16),
                  const Text('Pending invites', style: TextStyle(fontWeight: FontWeight.bold)),
                  if (_invites.where((i) => i.status == 'pending').isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No pending invites'),
                    )
                  else
                    ..._invites.where((i) => i.status == 'pending').map(
                      (inv) => ListTile(
                        dense: true,
                        title: Text(inv.email),
                        subtitle: Text('${inv.role} · expires ${inv.expiresAt.toIso8601String().substring(0, 10)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Copy link',
                              icon: const Icon(Icons.link),
                              onPressed: () async {
                                final link = _inviteLink(inv.token);
                                await Clipboard.setData(ClipboardData(text: link));
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Invite link copied')),
                                  );
                                }
                              },
                            ),
                            IconButton(
                              tooltip: 'Revoke',
                              icon: const Icon(Icons.cancel_outlined),
                              onPressed: () async {
                                await _repo.revokeInvite(inv.id);
                                _loadSettings();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                if (BosPermissions.canViewAudit) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Text('Audit log', style: TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final rows = await _repo.listAuditLog(limit: 40);
                          if (mounted) setState(() => _audit = rows);
                        },
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                  if (_audit.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No audit events yet'),
                    )
                  else
                    ..._audit.map((row) {
                      final action = '${row['action'] ?? ''}';
                      final entity = '${row['entity_type'] ?? '—'}';
                      final uid = '${row['firebase_uid'] ?? '—'}';
                      final at = '${row['created_at'] ?? ''}';
                      final shortAt =
                          at.length >= 19 ? at.substring(0, 19).replaceFirst('T', ' ') : at;
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.history, size: 20),
                        title: Text(action),
                        subtitle: Text('$entity · $uid · $shortAt'),
                      );
                    }),
                ],
              ],
            ),
    );
  }
}
