import 'package:flutter/material.dart';

import '../../../features/admin/widgets/admin_embedded_scaffold.dart';
import '../../../core/constants/route_names.dart';

/// Bilingual (Hindi + English) guide for AI Business OS.
class AdminAiOsHowToUseScreen extends StatefulWidget {
  const AdminAiOsHowToUseScreen({
    super.key,
    this.embedded = false,
    this.onNavigateRoute,
  });

  final bool embedded;
  final ValueChanged<String>? onNavigateRoute;

  @override
  State<AdminAiOsHowToUseScreen> createState() => _AdminAiOsHowToUseScreenState();
}

class _AdminAiOsHowToUseScreenState extends State<AdminAiOsHowToUseScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _go(String route) => widget.onNavigateRoute?.call(route);

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: 'How to use / कैसे इस्तेमाल करें',
      embedded: widget.embedded,
      body: Column(
        children: [
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'हिंदी'),
              Tab(text: 'English'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _GuideList(
                  locale: 'hi',
                  onOpenModule: _go,
                ),
                _GuideList(
                  locale: 'en',
                  onOpenModule: _go,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideList extends StatelessWidget {
  const _GuideList({required this.locale, required this.onOpenModule});

  final String locale;
  final ValueChanged<String> onOpenModule;

  bool get _hi => locale == 'hi';

  @override
  Widget build(BuildContext context) {
    final sections = _sections;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: sections.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              _hi
                  ? 'DG.YARD AI Business OS — पूरा ग्राहक चक्र: लीड → बातचीत → कोटेशन → प्रोजेक्ट → सपोर्ट। नीचे हर मॉड्यूल का सरल तरीका लिखा है।'
                  : 'DG.YARD AI Business OS covers the full customer cycle: lead → conversation → quote → project → support. Below is a simple guide for each module.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        }
        final s = sections[i - 1];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: Icon(s.icon, color: s.color),
            title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(s.subtitle),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(s.body, style: Theme.of(context).textTheme.bodyMedium),
              ),
              if (s.route != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonal(
                    onPressed: () => onOpenModule(s.route!),
                    child: Text(_hi ? 'मॉड्यूल खोलें' : 'Open module'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  List<_GuideSection> get _sections {
    if (_hi) {
      return [
        _GuideSection(
          icon: Icons.play_circle_outline,
          color: const Color(0xFF4F46E5),
          title: 'शुरू कैसे करें',
          subtitle: 'पहली बार सेटअप',
          body:
              '1) ऊपर Admin में “AI Business OS” चुनें।\n'
              '2) Settings में कंपनी नाम, ब्रांड रंग और टीम मेंबर्स जोड़ें।\n'
              '3) Super Admin हो तो Tenant switcher से DG.YARD / अन्य कंपनी चुनें।\n'
              '4) Knowledge Base में CCTV / Networking आदि के दस्तावेज़ डालें — WhatsApp AI और Proposal इन्हीं से जवाब बनाते हैं।\n'
              '5) फिर Leads में लीड जोड़ें या CSV इम्पोर्ट करें।',
          route: RouteNames.adminAiOsSettings,
        ),
        _GuideSection(
          icon: Icons.leaderboard_rounded,
          color: const Color(0xFFF59E0B),
          title: 'लीड मैनेजमेंट',
          subtitle: 'लीड जोड़ना, CSV, AI Qualify',
          body:
              '• “Add Lead” से नाम, फोन, ईमेल, कंपनी, स्रोत भरें।\n'
              '• “Import CSV” — हेडर: full_name,email,phone,company_name,requirements\n'
              '• डुप्लिकेट फोन/ईमेल स्किप हो जाते हैं।\n'
              '• लीड पर टैप → “AI Qualify” से Hot/Warm/Cold स्कोर।\n'
              '• “Convert to deal” से CRM डील बनती है।',
          route: RouteNames.adminAiOsLeads,
        ),
        _GuideSection(
          icon: Icons.people_rounded,
          color: const Color(0xFF0EA5E9),
          title: 'AI CRM',
          subtitle: 'Contacts, Companies, Deals Kanban',
          body:
              '• Contacts / Companies टैब में ग्राहक मास्टर रखें।\n'
              '• Deals Kanban में स्टेज बदलने के लिए डील पर Long-press करें।\n'
              '• जीती (Won) डील से Projects बना सकते हैं।',
          route: RouteNames.adminAiOsCrm,
        ),
        _GuideSection(
          icon: Icons.chat_bubble_rounded,
          color: const Color(0xFF10B981),
          title: 'WhatsApp AI',
          subtitle: 'बातचीत और AI जवाब',
          body:
              '• नई Conversation बनाएं या “Simulate inbound” से टेस्ट मैसेज डालें।\n'
              '• बाईं सूची से चैट चुनें, नीचे टाइप करके भेजें।\n'
              '• “AI reply” Knowledge Base से जवाब तैयार करता है।\n'
              '• असली Meta WhatsApp के लिए Settings में टोकन (बाद में) और webhook URL लगाएँ।',
          route: RouteNames.adminAiOsWhatsapp,
        ),
        _GuideSection(
          icon: Icons.campaign_rounded,
          color: const Color(0xFFEC4899),
          title: 'Campaign Manager',
          subtitle: 'CSV से व्हाट्सऐप कैंपेन',
          body:
              '• Campaign बनाएँ, मैसेज/टेम्पलेट चुनें, recipients CSV चिपकाएँ।\n'
              '• Opt-outs टैब में नंबर ब्लॉक करें — Launch पर वे स्किप होंगे।\n'
              '• “Launch” से मैसेज कतार में जाते हैं; Voice फॉलो-अप भी चालू कर सकते हैं।',
          route: RouteNames.adminAiOsCampaigns,
        ),
        _GuideSection(
          icon: Icons.menu_book_rounded,
          color: const Color(0xFF6366F1),
          title: 'Knowledge Base',
          subtitle: 'AI का ज्ञान',
          body:
              '• Collection चुनें (cctv, networking, software…) और दस्तावेज़ जोड़ें।\n'
              '• “Reindex” से चंक्स बनते हैं (Qdrant बाद में कनेक्ट)।\n'
              '• यही डेटा WhatsApp AI और Proposal में इस्तेमाल होता है।',
          route: RouteNames.adminAiOsKnowledge,
        ),
        _GuideSection(
          icon: Icons.request_quote_rounded,
          color: const Color(0xFF3B82F6),
          title: 'Quotation & BOQ',
          subtitle: 'CCTV बिल ऑफ क्वांटिटी',
          body:
              '• “CCTV BOQ” → कैमरे, NVR, केबल, HDD, लेबर भरें।\n'
              '• GST सहित लाइनें अपने आप बनती हैं।\n'
              '• डील/लीड लिंक कर सकते हैं; “Draft proposal” से प्रस्ताव बनाएँ।',
          route: RouteNames.adminAiOsQuotations,
        ),
        _GuideSection(
          icon: Icons.description_rounded,
          color: const Color(0xFF14B8A6),
          title: 'Proposal Generator',
          subtitle: 'AI प्रस्ताव',
          body:
              '• “AI draft” → डील / लीड / कोटेशन चुनें।\n'
              '• टेम्पलेट + KB से मार्कडाउन प्रस्ताव बनता है — एडिट करके Mark sent करें।',
          route: RouteNames.adminAiOsProposals,
        ),
        _GuideSection(
          icon: Icons.calculate_rounded,
          color: const Color(0xFF059669),
          title: 'Website & App Estimator',
          subtitle: 'अनुमानित कीमत',
          body:
              '• पेज/प्लेटफ़ॉर्म, ई-कॉमर्स, एडमिन, SEO चुनें — लाइव टोटल दिखेगा।\n'
              '• Save के बाद “To proposal” से प्रस्ताव बना सकते हैं।',
          route: RouteNames.adminAiOsEstimator,
        ),
        _GuideSection(
          icon: Icons.engineering_rounded,
          color: const Color(0xFF0891B2),
          title: 'Projects & Tickets',
          subtitle: 'एक्सक्यूशन और सपोर्ट',
          body:
              'Projects: Won डील से प्रोजेक्ट बनाएँ — milestones/tasks जोड़ें, स्टेटस बदलें।\n'
              'Tickets: प्राथमिकता + SLA + प्रोजेक्ट/असाइनी; कमेंट जोड़ें; स्टेटस मेनू से अपडेट करें।',
          route: RouteNames.adminAiOsProjects,
        ),
        _GuideSection(
          icon: Icons.phone_rounded,
          color: const Color(0xFF8B5CF6),
          title: 'Voice & Marketing',
          subtitle: 'कॉल और विज्ञापन कॉपी',
          body:
              'Voice: कॉल कतार में डालें, लीड लिंक करें, “Simulate complete” से ट्रांसक्रिप्ट/CRM अपडेट।\n'
              'Marketing: ब्रीफ लिखें → Generate → हेडलाइन/CTA देखें।',
          route: RouteNames.adminAiOsVoice,
        ),
        _GuideSection(
          icon: Icons.payments_rounded,
          color: const Color(0xFF64748B),
          title: 'Billing, Reports, Marketplace',
          subtitle: 'SaaS पैकेजिंग',
          body:
              'Billing: प्लान बदलें, इनवॉइस बनाएँ, Activate/Suspend।\n'
              'Reports: लीड, डील, टिकट, प्रोजेक्ट, कैंपेन KPI।\n'
              'Marketplace: टेम्पलेट/KB पैक Install करें।',
          route: RouteNames.adminAiOsBilling,
        ),
      ];
    }

    return [
      _GuideSection(
        icon: Icons.play_circle_outline,
        color: const Color(0xFF4F46E5),
        title: 'Getting started',
        subtitle: 'First-time setup',
        body:
            '1) Select the “AI Business OS” chip in Admin.\n'
            '2) In Settings, set company name, brand colours, and add team members.\n'
            '3) Super Admins can switch tenants (DG.YARD is the default).\n'
            '4) Add Knowledge Base docs (CCTV, networking, etc.) — WhatsApp AI and Proposals use them.\n'
            '5) Add leads manually or import CSV.',
        route: RouteNames.adminAiOsSettings,
      ),
      _GuideSection(
        icon: Icons.leaderboard_rounded,
        color: const Color(0xFFF59E0B),
        title: 'Lead Management',
        subtitle: 'Add, CSV import, AI Qualify',
        body:
            '• Use Add Lead for name, phone, email, company, source.\n'
            '• CSV header: full_name,email,phone,company_name,requirements\n'
            '• Duplicate phone/email rows are skipped.\n'
            '• Open a lead → AI Qualify for Hot/Warm/Cold.\n'
            '• Convert to deal creates CRM contact + deal.',
        route: RouteNames.adminAiOsLeads,
      ),
      _GuideSection(
        icon: Icons.people_rounded,
        color: const Color(0xFF0EA5E9),
        title: 'AI CRM',
        subtitle: 'Contacts, Companies, Deals Kanban',
        body:
            '• Maintain contacts and companies in the first two tabs.\n'
            '• Long-press a deal card to move pipeline stages.\n'
            '• Won deals can become Projects.',
        route: RouteNames.adminAiOsCrm,
      ),
      _GuideSection(
        icon: Icons.chat_bubble_rounded,
        color: const Color(0xFF10B981),
        title: 'WhatsApp AI',
        subtitle: 'Conversations & AI replies',
        body:
            '• Create a conversation or Simulate inbound for testing.\n'
            '• Select a thread, type replies, or tap AI reply (uses Knowledge Base).\n'
            '• For live Meta WhatsApp, configure tokens and the webhook URL later.',
        route: RouteNames.adminAiOsWhatsapp,
      ),
      _GuideSection(
        icon: Icons.campaign_rounded,
        color: const Color(0xFFEC4899),
        title: 'Campaign Manager',
        subtitle: 'CSV WhatsApp campaigns',
        body:
            '• Create a campaign, set message/template, paste recipient CSV.\n'
            '• Opt-outs are skipped on Launch.\n'
            '• Optional voice follow-up queues AI Voice calls.',
        route: RouteNames.adminAiOsCampaigns,
      ),
      _GuideSection(
        icon: Icons.menu_book_rounded,
        color: const Color(0xFF6366F1),
        title: 'Knowledge Base',
        subtitle: 'Content for AI',
        body:
            '• Pick a collection and add documents.\n'
            '• Reindex builds chunks (Qdrant-ready).\n'
            '• Used by WhatsApp AI replies and proposal drafts.',
        route: RouteNames.adminAiOsKnowledge,
      ),
      _GuideSection(
        icon: Icons.request_quote_rounded,
        color: const Color(0xFF3B82F6),
        title: 'Quotation & BOQ',
        subtitle: 'CCTV bill of quantities',
        body:
            '• CCTV BOQ wizard calculates cameras, NVR, switches, cable, storage, accessories, labour + GST.\n'
            '• Link a deal/lead; draft a proposal from the quote.',
        route: RouteNames.adminAiOsQuotations,
      ),
      _GuideSection(
        icon: Icons.description_rounded,
        color: const Color(0xFF14B8A6),
        title: 'Proposal Generator',
        subtitle: 'AI proposals',
        body:
            '• AI draft from deal / lead / quotation + KB template.\n'
            '• Edit markdown, then Mark sent.',
        route: RouteNames.adminAiOsProposals,
      ),
      _GuideSection(
        icon: Icons.calculate_rounded,
        color: const Color(0xFF059669),
        title: 'Website & App Estimator',
        subtitle: 'Indicative pricing',
        body:
            '• Answer the questionnaire for a live total.\n'
            '• Save, then convert To proposal when ready.',
        route: RouteNames.adminAiOsEstimator,
      ),
      _GuideSection(
        icon: Icons.engineering_rounded,
        color: const Color(0xFF0891B2),
        title: 'Projects & Tickets',
        subtitle: 'Delivery & support',
        body:
            'Projects: create from won deals; manage milestones and tasks.\n'
            'Tickets: set priority, SLA, project, assignee; add comments; update status.',
        route: RouteNames.adminAiOsProjects,
      ),
      _GuideSection(
        icon: Icons.phone_rounded,
        color: const Color(0xFF8B5CF6),
        title: 'Voice & Marketing',
        subtitle: 'Calls and ad copy',
        body:
            'Voice: queue a call with script + lead; Simulate complete updates CRM.\n'
            'Marketing: enter a brief → Generate headline/CTA copy.',
        route: RouteNames.adminAiOsVoice,
      ),
      _GuideSection(
        icon: Icons.payments_rounded,
        color: const Color(0xFF64748B),
        title: 'Billing, Reports, Marketplace',
        subtitle: 'SaaS packaging',
        body:
            'Billing: change plan, create invoices, activate/suspend.\n'
            'Reports: funnel and ops KPIs.\n'
            'Marketplace: install template/KB packs for the tenant.',
        route: RouteNames.adminAiOsBilling,
      ),
    ];
  }
}

class _GuideSection {
  const _GuideSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.body,
    this.route,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String body;
  final String? route;
}
