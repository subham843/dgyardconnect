/// AI Business OS domain models — aligned with `bos_*` Supabase schema.

const String kBosDefaultTenantId = 'b0000000-0000-4000-8000-000000000001';

class BosTenant {
  BosTenant({
    required this.id,
    required this.name,
    required this.slug,
    required this.status,
    required this.createdAt,
    this.planId,
    this.logoUrl,
    this.brandPrimary,
    this.brandAccent,
    this.settings,
    this.gstin,
    this.businessType,
    this.contactEmail,
    this.contactPhone,
    this.addressLine,
    this.deletedAt,
  });

  final String id;
  final String name;
  final String slug;
  final String status;
  final String? planId;
  final String? logoUrl;
  final String? brandPrimary;
  final String? brandAccent;
  final Map<String, dynamic>? settings;
  final String? gstin;
  final String? businessType;
  final String? contactEmail;
  final String? contactPhone;
  final String? addressLine;
  final DateTime createdAt;
  final DateTime? deletedAt;

  factory BosTenant.fromMap(Map<String, dynamic> map) => BosTenant(
        id: map['id'] as String,
        name: map['name'] as String,
        slug: map['slug'] as String? ?? '',
        status: map['status'] as String? ?? 'trial',
        planId: map['plan_id'] as String?,
        logoUrl: map['logo_url'] as String?,
        brandPrimary: map['brand_primary'] as String?,
        brandAccent: map['brand_accent'] as String?,
        settings: map['settings'] is Map
            ? Map<String, dynamic>.from(map['settings'] as Map)
            : null,
        gstin: map['gstin'] as String?,
        businessType: map['business_type'] as String?,
        contactEmail: map['contact_email'] as String?,
        contactPhone: map['contact_phone'] as String?,
        addressLine: map['address_line'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        deletedAt: map['deleted_at'] == null
            ? null
            : DateTime.parse(map['deleted_at'] as String),
      );
}

class BosDepartment {
  BosDepartment({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.createdAt,
    this.code,
    this.isActive = true,
    this.deletedAt,
  });

  final String id;
  final String tenantId;
  final String name;
  final String? code;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? deletedAt;

  factory BosDepartment.fromMap(Map<String, dynamic> map) => BosDepartment(
        id: map['id'] as String,
        tenantId: map['tenant_id'] as String,
        name: map['name'] as String,
        code: map['code'] as String?,
        isActive: map['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(map['created_at'] as String),
        deletedAt: map['deleted_at'] == null
            ? null
            : DateTime.parse(map['deleted_at'] as String),
      );
}

class BosTenantInvite {
  BosTenantInvite({
    required this.id,
    required this.tenantId,
    required this.email,
    required this.role,
    required this.token,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    this.departmentId,
    this.invitedByUid,
  });

  final String id;
  final String tenantId;
  final String email;
  final String role;
  final String token;
  final String status;
  final String? departmentId;
  final String? invitedByUid;
  final DateTime expiresAt;
  final DateTime createdAt;

  factory BosTenantInvite.fromMap(Map<String, dynamic> map) => BosTenantInvite(
        id: map['id'] as String,
        tenantId: map['tenant_id'] as String,
        email: map['email'] as String,
        role: map['role'] as String,
        token: map['token'] as String,
        status: map['status'] as String? ?? 'pending',
        departmentId: map['department_id'] as String?,
        invitedByUid: map['invited_by_uid'] as String?,
        expiresAt: DateTime.parse(map['expires_at'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class BosTenantMember {
  BosTenantMember({
    required this.id,
    required this.tenantId,
    required this.firebaseUid,
    required this.role,
    required this.createdAt,
    this.displayName,
    this.email,
    this.phone,
    this.departmentId,
    this.isActive = true,
    this.deletedAt,
  });

  final String id;
  final String tenantId;
  final String firebaseUid;
  final String role;
  final String? displayName;
  final String? email;
  final String? phone;
  final String? departmentId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? deletedAt;

  factory BosTenantMember.fromMap(Map<String, dynamic> map) => BosTenantMember(
        id: map['id'] as String,
        tenantId: map['tenant_id'] as String,
        firebaseUid: map['firebase_uid'] as String,
        role: map['role'] as String,
        displayName: map['display_name'] as String?,
        email: map['email'] as String?,
        phone: map['phone'] as String?,
        departmentId: map['department_id'] as String?,
        isActive: map['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(map['created_at'] as String),
        deletedAt: map['deleted_at'] == null
            ? null
            : DateTime.parse(map['deleted_at'] as String),
      );
}

class BosLead {
  BosLead({
    required this.id,
    required this.tenantId,
    required this.createdAt,
    this.source,
    this.stage,
    this.score,
    this.fullName,
    this.email,
    this.phone,
    this.companyName,
    this.requirements,
    this.aiSummary,
    this.aiNextQuestions,
    this.ownerFirebaseUid,
    this.contactId,
    this.companyId,
    this.nextFollowUpAt,
    this.meta,
    this.deletedAt,
  });

  final String id;
  final String tenantId;
  final String? source;
  final String? stage;
  final String? score; // hot | warm | cold
  final String? fullName;
  final String? email;
  final String? phone;
  final String? companyName;
  final String? requirements;
  final String? aiSummary;
  final List<dynamic>? aiNextQuestions;
  final String? ownerFirebaseUid;
  final String? contactId;
  final String? companyId;
  final DateTime? nextFollowUpAt;
  final Map<String, dynamic>? meta;
  final DateTime createdAt;
  final DateTime? deletedAt;

  String get displayName =>
      (fullName != null && fullName!.trim().isNotEmpty) ? fullName!.trim() : (email ?? phone ?? 'Lead');

  bool get handoverReady => meta?['handover_ready'] == true;
  bool get doNotCall => meta?['do_not_call'] == true || meta?['dnd'] == true;
  String? get aiRecommendation => meta?['ai_recommendation']?.toString();
  String? get intent => meta?['intent']?.toString();

  factory BosLead.fromMap(Map<String, dynamic> map) => BosLead(
        id: map['id'] as String,
        tenantId: map['tenant_id'] as String,
        source: map['source'] as String?,
        stage: map['stage'] as String?,
        score: map['score'] as String?,
        fullName: map['full_name'] as String?,
        email: map['email'] as String?,
        phone: map['phone'] as String?,
        companyName: map['company_name'] as String?,
        requirements: map['requirements'] as String?,
        aiSummary: map['ai_summary'] as String?,
        aiNextQuestions: map['ai_next_questions'] as List?,
        ownerFirebaseUid: map['owner_firebase_uid'] as String?,
        contactId: map['contact_id'] as String?,
        companyId: map['company_id'] as String?,
        nextFollowUpAt: map['next_follow_up_at'] == null
            ? null
            : DateTime.parse(map['next_follow_up_at'] as String),
        meta: map['meta'] is Map
            ? Map<String, dynamic>.from(map['meta'] as Map)
            : null,
        createdAt: DateTime.parse(map['created_at'] as String),
        deletedAt: map['deleted_at'] == null
            ? null
            : DateTime.parse(map['deleted_at'] as String),
      );
}

class BosContact {
  BosContact({
    required this.id,
    required this.tenantId,
    required this.createdAt,
    this.firstName,
    this.lastName,
    this.fullName,
    this.email,
    this.phone,
    this.companyId,
    this.title,
    this.deletedAt,
  });

  final String id;
  final String tenantId;
  final String? firstName;
  final String? lastName;
  final String? fullName;
  final String? email;
  final String? phone;
  final String? companyId;
  final String? title;
  final DateTime createdAt;
  final DateTime? deletedAt;

  String get displayName {
    if (fullName != null && fullName!.trim().isNotEmpty) return fullName!.trim();
    final parts = [firstName, lastName].whereType<String>().where((e) => e.isNotEmpty);
    if (parts.isNotEmpty) return parts.join(' ');
    return email ?? phone ?? 'Contact';
  }

  factory BosContact.fromMap(Map<String, dynamic> map) => BosContact(
        id: map['id'] as String,
        tenantId: map['tenant_id'] as String,
        firstName: map['first_name'] as String?,
        lastName: map['last_name'] as String?,
        fullName: map['full_name'] as String?,
        email: map['email'] as String?,
        phone: map['phone'] as String?,
        companyId: map['company_id'] as String?,
        title: map['title'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        deletedAt: map['deleted_at'] == null
            ? null
            : DateTime.parse(map['deleted_at'] as String),
      );
}

class BosCompany {
  BosCompany({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.createdAt,
    this.industry,
    this.website,
    this.phone,
    this.email,
    this.address,
    this.deletedAt,
  });

  final String id;
  final String tenantId;
  final String name;
  final String? industry;
  final String? website;
  final String? phone;
  final String? email;
  final String? address;
  final DateTime createdAt;
  final DateTime? deletedAt;

  factory BosCompany.fromMap(Map<String, dynamic> map) => BosCompany(
        id: map['id'] as String,
        tenantId: map['tenant_id'] as String,
        name: map['name'] as String,
        industry: map['industry'] as String?,
        website: map['website'] as String?,
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        address: map['address'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        deletedAt: map['deleted_at'] == null
            ? null
            : DateTime.parse(map['deleted_at'] as String),
      );
}

class BosPipelineStage {
  BosPipelineStage({
    required this.id,
    required this.tenantId,
    required this.code,
    required this.label,
    required this.sortOrder,
    this.isWon = false,
    this.isLost = false,
  });

  final String id;
  final String tenantId;
  final String code;
  final String label;
  final int sortOrder;
  final bool isWon;
  final bool isLost;

  factory BosPipelineStage.fromMap(Map<String, dynamic> map) => BosPipelineStage(
        id: map['id'] as String,
        tenantId: map['tenant_id'] as String,
        code: map['code'] as String,
        label: map['label'] as String,
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
        isWon: map['is_won'] as bool? ?? false,
        isLost: map['is_lost'] as bool? ?? false,
      );
}

class BosDeal {
  BosDeal({
    required this.id,
    required this.tenantId,
    required this.title,
    required this.createdAt,
    this.stage,
    this.amountPaise = 0,
    this.currency = 'INR',
    this.probability = 0,
    this.contactId,
    this.companyId,
    this.leadId,
    this.ownerFirebaseUid,
    this.expectedCloseAt,
    this.deletedAt,
  });

  final String id;
  final String tenantId;
  final String title;
  final String? stage;
  final int amountPaise;
  final String currency;
  final int probability;
  final String? contactId;
  final String? companyId;
  final String? leadId;
  final String? ownerFirebaseUid;
  final DateTime? expectedCloseAt;
  final DateTime createdAt;
  final DateTime? deletedAt;

  double get amountRupees => amountPaise / 100.0;

  factory BosDeal.fromMap(Map<String, dynamic> map) {
    final meta = map['meta'] is Map ? Map<String, dynamic>.from(map['meta'] as Map) : null;
    final prob = (map['probability'] as num?)?.toInt() ??
        (meta?['probability'] as num?)?.toInt() ??
        0;
    return BosDeal(
        id: map['id'] as String,
        tenantId: map['tenant_id'] as String,
        title: map['title'] as String,
        stage: map['stage'] as String?,
        amountPaise: (map['amount_paise'] as num?)?.toInt() ?? 0,
        currency: map['currency'] as String? ?? 'INR',
        probability: prob,
        contactId: map['contact_id'] as String?,
        companyId: map['company_id'] as String?,
        leadId: map['lead_id'] as String?,
        ownerFirebaseUid: map['owner_firebase_uid'] as String?,
        expectedCloseAt: map['expected_close_at'] == null
            ? null
            : DateTime.parse(map['expected_close_at'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
        deletedAt: map['deleted_at'] == null
            ? null
            : DateTime.parse(map['deleted_at'] as String),
      );
  }
}

class BosActivity {
  BosActivity({
    required this.id,
    required this.tenantId,
    required this.activityType,
    required this.createdAt,
    this.subject,
    this.body,
    this.leadId,
    this.dealId,
    this.contactId,
    this.createdBy,
    this.dueAt,
    this.completedAt,
    this.assignedTo,
  });

  final String id;
  final String tenantId;
  final String activityType;
  final String? subject;
  final String? body;
  final String? leadId;
  final String? dealId;
  final String? contactId;
  final String? createdBy;
  final DateTime? dueAt;
  final DateTime? completedAt;
  final String? assignedTo;
  final DateTime createdAt;

  bool get isOpenTask => dueAt != null && completedAt == null;

  factory BosActivity.fromMap(Map<String, dynamic> map) => BosActivity(
        id: map['id'] as String,
        tenantId: map['tenant_id'] as String,
        activityType: map['activity_type'] as String? ?? 'note',
        subject: map['subject'] as String?,
        body: map['body'] as String?,
        leadId: map['lead_id'] as String?,
        dealId: map['deal_id'] as String?,
        contactId: map['contact_id'] as String?,
        createdBy: map['created_by'] as String?,
        dueAt: map['due_at'] == null ? null : DateTime.tryParse(map['due_at'] as String),
        completedAt: map['completed_at'] == null
            ? null
            : DateTime.tryParse(map['completed_at'] as String),
        assignedTo: map['assigned_to'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class BosConversation {
  BosConversation({
    required this.id,
    required this.tenantId,
    required this.createdAt,
    this.channel,
    this.phone,
    this.status,
    this.leadId,
    this.contactId,
    this.lastMessageAt,
    this.aiEnabled = true,
    this.unreadCount = 0,
  });

  final String id;
  final String tenantId;
  final String? channel;
  final String? phone;
  final String? status;
  final String? leadId;
  final String? contactId;
  final DateTime? lastMessageAt;
  final bool aiEnabled;
  final int unreadCount;
  final DateTime createdAt;

  factory BosConversation.fromMap(Map<String, dynamic> map) => BosConversation(
        id: map['id'] as String,
        tenantId: map['tenant_id'] as String,
        channel: map['channel'] as String?,
        phone: map['phone'] as String?,
        status: map['status'] as String?,
        leadId: map['lead_id'] as String?,
        contactId: map['contact_id'] as String?,
        lastMessageAt: map['last_message_at'] == null
            ? null
            : DateTime.parse(map['last_message_at'] as String),
        aiEnabled: map['ai_enabled'] as bool? ?? true,
        unreadCount: (map['unread_count'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class BosMessage {
  BosMessage({
    required this.id,
    required this.tenantId,
    required this.conversationId,
    required this.direction,
    required this.createdAt,
    this.body,
    this.status,
    this.meta,
  });

  final String id;
  final String tenantId;
  final String conversationId;
  final String direction;
  final String? body;
  final String? status;
  final DateTime createdAt;
  final Map<String, dynamic>? meta;

  List<Map<String, dynamic>> get citations {
    final raw = meta?['citations'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  factory BosMessage.fromMap(Map<String, dynamic> map) => BosMessage(
        id: map['id'] as String,
        tenantId: map['tenant_id'] as String,
        conversationId: map['conversation_id'] as String,
        direction: map['direction'] as String? ?? 'inbound',
        body: map['body'] as String?,
        status: map['status'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        meta: map['meta'] is Map ? Map<String, dynamic>.from(map['meta'] as Map) : null,
      );
}

class BosCampaign {
  BosCampaign({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.createdAt,
    this.channel,
    this.status,
    this.templateName,
    this.templateId,
    this.messageBody,
    this.triggerVoice = false,
    this.sentCount = 0,
    this.failedCount = 0,
    this.skippedOptOut = 0,
    this.segment,
    this.scheduledAt,
  });

  final String id;
  final String tenantId;
  final String name;
  final String? channel;
  final String? status;
  final String? templateName;
  final String? templateId;
  final String? messageBody;
  final bool triggerVoice;
  final int sentCount;
  final int failedCount;
  final int skippedOptOut;
  final Map<String, dynamic>? segment;
  final DateTime? scheduledAt;
  final DateTime createdAt;

  String get segmentPreset => '${segment?['preset'] ?? ''}';

  factory BosCampaign.fromMap(Map<String, dynamic> map) => BosCampaign(
        id: map['id'] as String,
        tenantId: map['tenant_id'] as String,
        name: map['name'] as String,
        channel: map['channel'] as String?,
        status: map['status'] as String?,
        templateName: map['template_name'] as String?,
        templateId: map['template_id'] as String?,
        messageBody: map['message_body'] as String?,
        triggerVoice: map['trigger_voice'] as bool? ?? false,
        sentCount: (map['sent_count'] as num?)?.toInt() ?? 0,
        failedCount: (map['failed_count'] as num?)?.toInt() ?? 0,
        skippedOptOut: (map['skipped_opt_out'] as num?)?.toInt() ?? 0,
        segment: map['segment'] is Map
            ? Map<String, dynamic>.from(map['segment'] as Map)
            : null,
        scheduledAt: map['scheduled_at'] == null
            ? null
            : DateTime.tryParse(map['scheduled_at'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class BosKbDocument {
  BosKbDocument({
    required this.id,
    required this.tenantId,
    required this.title,
    required this.createdAt,
    this.collection,
    this.body,
    this.sourceUrl,
    this.isActive = true,
    this.reindexStatus = 'idle',
    this.chunkCount = 0,
    this.lastReindexedAt,
  });

  final String id;
  final String tenantId;
  final String title;
  final String? collection;
  final String? body;
  final String? sourceUrl;
  final bool isActive;
  final String reindexStatus;
  final int chunkCount;
  final DateTime? lastReindexedAt;
  final DateTime createdAt;

  factory BosKbDocument.fromMap(Map<String, dynamic> map) => BosKbDocument(
        id: map['id'] as String,
        tenantId: map['tenant_id'] as String,
        title: map['title'] as String,
        collection: map['collection'] as String?,
        body: map['body'] as String?,
        sourceUrl: map['source_url'] as String?,
        isActive: map['is_active'] as bool? ?? true,
        reindexStatus: map['reindex_status'] as String? ?? 'idle',
        chunkCount: (map['chunk_count'] as num?)?.toInt() ?? 0,
        lastReindexedAt: map['last_reindexed_at'] == null
            ? null
            : DateTime.parse(map['last_reindexed_at'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class BosWaTemplate {
  BosWaTemplate({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.body,
    this.language = 'en',
    this.channel = 'whatsapp',
    this.isActive = true,
  });

  final String id;
  final String tenantId;
  final String name;
  final String body;
  final String language;
  final String channel;
  final bool isActive;

  factory BosWaTemplate.fromMap(Map<String, dynamic> map) => BosWaTemplate(
        id: map['id'] as String,
        tenantId: map['tenant_id'] as String,
        name: map['name'] as String,
        body: map['body'] as String,
        language: map['language'] as String? ?? 'en',
        channel: map['channel'] as String? ?? 'whatsapp',
        isActive: map['is_active'] as bool? ?? true,
      );
}

class BosQuotation {
  BosQuotation({
    required this.id,
    required this.tenantId,
    required this.createdAt,
    this.quoteNumber,
    this.title,
    this.status,
    this.totalPaise = 0,
    this.subtotalPaise = 0,
    this.taxPaise = 0,
    this.currency = 'INR',
    this.notes,
  });

  final String id;
  final String tenantId;
  final String? quoteNumber;
  final String? title;
  final String? status;
  final int totalPaise;
  final int subtotalPaise;
  final int taxPaise;
  final String currency;
  final String? notes;
  final DateTime createdAt;

  factory BosQuotation.fromMap(Map<String, dynamic> map) => BosQuotation(
        id: map['id'] as String,
        tenantId: map['tenant_id'] as String,
        quoteNumber: map['quote_number'] as String?,
        title: map['title'] as String?,
        status: map['status'] as String?,
        totalPaise: (map['total_paise'] as num?)?.toInt() ?? 0,
        subtotalPaise: (map['subtotal_paise'] as num?)?.toInt() ?? 0,
        taxPaise: (map['tax_paise'] as num?)?.toInt() ?? 0,
        currency: map['currency'] as String? ?? 'INR',
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class BosProposal {
  BosProposal({
    required this.id,
    required this.tenantId,
    required this.title,
    required this.createdAt,
    this.status,
    this.bodyMarkdown,
    this.pdfUrl,
  });

  final String id;
  final String tenantId;
  final String title;
  final String? status;
  final String? bodyMarkdown;
  final String? pdfUrl;
  final DateTime createdAt;

  factory BosProposal.fromMap(Map<String, dynamic> map) => BosProposal(
        id: map['id'] as String,
        tenantId: map['tenant_id'] as String,
        title: map['title'] as String,
        status: map['status'] as String?,
        bodyMarkdown: map['body_markdown'] as String?,
        pdfUrl: map['pdf_url'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class BosEstimate {
  BosEstimate({
    required this.id,
    required this.tenantId,
    required this.title,
    required this.createdAt,
    this.estimateType,
    this.totalPaise = 0,
    this.answers,
    this.breakdown,
    this.leadId,
    this.dealId,
    this.proposalId,
    this.status,
  });

  final String id;
  final String tenantId;
  final String title;
  final String? estimateType;
  final int totalPaise;
  final Map<String, dynamic>? answers;
  final Map<String, dynamic>? breakdown;
  final String? leadId;
  final String? dealId;
  final String? proposalId;
  final String? status;
  final DateTime createdAt;

  factory BosEstimate.fromMap(Map<String, dynamic> map) => BosEstimate(
        id: map['id'] as String,
        tenantId: map['tenant_id'] as String,
        title: map['title'] as String,
        estimateType: map['estimate_type'] as String?,
        totalPaise: (map['total_paise'] as num?)?.toInt() ?? 0,
        answers: map['answers'] is Map
            ? Map<String, dynamic>.from(map['answers'] as Map)
            : null,
        breakdown: map['breakdown'] is Map
            ? Map<String, dynamic>.from(map['breakdown'] as Map)
            : null,
        leadId: map['lead_id'] as String?,
        dealId: map['deal_id'] as String?,
        proposalId: map['proposal_id'] as String?,
        status: map['status'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class BosProject {
  BosProject({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.createdAt,
    this.status,
    this.dealId,
    this.companyId,
    this.ownerFirebaseUid,
  });

  final String id;
  final String tenantId;
  final String name;
  final String? status;
  final String? dealId;
  final String? companyId;
  final String? ownerFirebaseUid;
  final DateTime createdAt;

  factory BosProject.fromMap(Map<String, dynamic> map) => BosProject(
        id: map['id'] as String,
        tenantId: map['tenant_id'] as String,
        name: map['name'] as String,
        status: map['status'] as String?,
        dealId: map['deal_id'] as String?,
        companyId: map['company_id'] as String?,
        ownerFirebaseUid: map['owner_firebase_uid'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class BosTicket {
  BosTicket({
    required this.id,
    required this.tenantId,
    required this.subject,
    required this.createdAt,
    this.description,
    this.status,
    this.priority,
    this.projectId,
    this.contactId,
    this.assigneeFirebaseUid,
  });

  final String id;
  final String tenantId;
  final String subject;
  final String? description;
  final String? status;
  final String? priority;
  final String? projectId;
  final String? contactId;
  final String? assigneeFirebaseUid;
  final DateTime createdAt;

  factory BosTicket.fromMap(Map<String, dynamic> map) => BosTicket(
        id: map['id'] as String,
        tenantId: map['tenant_id'] as String,
        subject: map['subject'] as String,
        description: map['description'] as String?,
        status: map['status'] as String?,
        priority: map['priority'] as String?,
        projectId: map['project_id'] as String?,
        contactId: map['contact_id'] as String?,
        assigneeFirebaseUid: map['assignee_firebase_uid'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class BosVoiceCall {
  BosVoiceCall({
    required this.id,
    required this.tenantId,
    required this.createdAt,
    this.phone,
    this.direction,
    this.status,
    this.transcript,
    this.durationSec,
    this.leadId,
    this.script,
    this.outcome,
    this.crmUpdated = false,
    this.scheduledAt,
    this.provider,
    this.meta,
    this.deletedAt,
  });

  final String id;
  final String tenantId;
  final String? phone;
  final String? direction;
  final String? status;
  final String? transcript;
  final int? durationSec;
  final String? leadId;
  final String? script;
  final String? outcome;
  final bool crmUpdated;
  final DateTime? scheduledAt;
  final String? provider;
  final Map<String, dynamic>? meta;
  final DateTime createdAt;
  final DateTime? deletedAt;

  bool get isOpen => status == 'queued' || status == 'ringing' || status == 'in_progress';
  bool get isInbound => direction == 'inbound' || meta?['inbound'] == true;
  String? get aiSummary => meta?['summary']?.toString();
  String? get nextAction => meta?['next_action']?.toString();
  String get voiceProviderLabel =>
      (meta?['voice_provider'] ?? provider ?? 'stub').toString();
  bool get dialSim => meta?['dial_sim'] == true;
  String? get sttProvider => meta?['stt_provider']?.toString();
  bool get sttLive => sttProvider != null && meta?['stt_sim'] != true;
  String? get recordingUrl =>
      (meta?['recording_url'] ?? meta?['audio_url'])?.toString();
  String? get providerCallId => meta?['provider_call_id']?.toString();

  factory BosVoiceCall.fromMap(Map<String, dynamic> map) {
    final meta = map['meta'] is Map ? Map<String, dynamic>.from(map['meta'] as Map) : null;
    DateTime? scheduled;
    final raw = map['scheduled_at'] ?? meta?['scheduled_at'];
    if (raw is String && raw.isNotEmpty) {
      scheduled = DateTime.tryParse(raw);
    }
    DateTime? deleted;
    final del = map['deleted_at'];
    if (del is String && del.isNotEmpty) deleted = DateTime.tryParse(del);
    return BosVoiceCall(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      phone: map['phone'] as String?,
      direction: map['direction'] as String?,
      status: map['status'] as String?,
      transcript: map['transcript'] as String?,
      durationSec: (map['duration_sec'] as num?)?.toInt(),
      leadId: map['lead_id'] as String?,
      script: map['script'] as String?,
      outcome: map['outcome'] as String?,
      crmUpdated: map['crm_updated'] as bool? ?? false,
      scheduledAt: scheduled,
      provider: map['provider'] as String?,
      meta: meta,
      createdAt: DateTime.parse(map['created_at'] as String),
      deletedAt: deleted,
    );
  }
}

class BosMarketingCampaign {
  BosMarketingCampaign({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.createdAt,
    this.channel,
    this.status,
    this.brief,
  });

  final String id;
  final String tenantId;
  final String name;
  final String? channel;
  final String? status;
  final String? brief;
  final DateTime createdAt;

  factory BosMarketingCampaign.fromMap(Map<String, dynamic> map) =>
      BosMarketingCampaign(
        id: map['id'] as String,
        tenantId: map['tenant_id'] as String,
        name: map['name'] as String,
        channel: map['channel'] as String?,
        status: map['status'] as String?,
        brief: map['brief'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class BosPlan {
  BosPlan({
    required this.id,
    required this.code,
    required this.name,
    required this.priceMonthlyPaise,
    this.description,
    this.isActive = true,
    this.features = const {},
    this.limits = const {},
  });

  final String id;
  final String code;
  final String name;
  final String? description;
  final int priceMonthlyPaise;
  final bool isActive;
  final Map<String, dynamic> features;
  final Map<String, dynamic> limits;

  List<String> get featureModules {
    final raw = features['modules'];
    if (raw is List) {
      return raw.map((e) => '$e').where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  factory BosPlan.fromMap(Map<String, dynamic> map) => BosPlan(
        id: map['id'] as String,
        code: map['code'] as String,
        name: map['name'] as String,
        description: map['description'] as String?,
        priceMonthlyPaise: (map['price_monthly_paise'] as num?)?.toInt() ?? 0,
        isActive: map['is_active'] as bool? ?? true,
        features: map['features'] is Map
            ? Map<String, dynamic>.from(map['features'] as Map)
            : const {},
        limits: map['limits'] is Map
            ? Map<String, dynamic>.from(map['limits'] as Map)
            : const {},
      );
}

class BosSubscription {
  BosSubscription({
    required this.id,
    required this.tenantId,
    required this.planId,
    required this.status,
    this.currentPeriodEnd,
  });

  final String id;
  final String tenantId;
  final String planId;
  final String status;
  final DateTime? currentPeriodEnd;

  factory BosSubscription.fromMap(Map<String, dynamic> map) => BosSubscription(
        id: map['id'] as String,
        tenantId: map['tenant_id'] as String,
        planId: map['plan_id'] as String,
        status: map['status'] as String? ?? 'trialing',
        currentPeriodEnd: map['current_period_end'] == null
            ? null
            : DateTime.parse(map['current_period_end'] as String),
      );
}

class BosMarketplaceItem {
  BosMarketplaceItem({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.category,
    this.isActive = true,
  });

  final String id;
  final String code;
  final String name;
  final String? description;
  final String? category;
  final bool isActive;

  factory BosMarketplaceItem.fromMap(Map<String, dynamic> map) =>
      BosMarketplaceItem(
        id: map['id'] as String,
        code: map['code'] as String,
        name: map['name'] as String,
        description: map['description'] as String?,
        category: map['category'] as String?,
        isActive: map['is_active'] as bool? ?? true,
      );
}
