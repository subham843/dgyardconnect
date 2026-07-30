// Contact Page — V2 design system.

import 'package:flutter/material.dart';

import '../../v2/v2_colors.dart';
import '../../v2/v2_text.dart';
import '../../v2/v2_tokens.dart';
import '../../v2/widgets/v2_button.dart';
import '../../widgets/public_floating_menu.dart';
import '../../v2/widgets/v2_footer.dart';
import '../../v2/widgets/v2_paper_surface.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  final _scroll = ScrollController();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _scroll.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);

    return Scaffold(
      backgroundColor: V2Colors.saasBg,
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scroll,
            child: Column(
              children: [
                _ContactHero(v: v),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    v.gutter,
                    v.r<double>(xs: 32, md: 48),
                    v.gutter,
                    0,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: V2.maxContentWidth),
                    child: v.isDesktop
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildContactInfo(v)),
                              SizedBox(width: v.r<double>(xs: 24, md: 32)),
                              Expanded(flex: 2, child: _buildContactForm(v)),
                            ],
                          )
                        : Column(
                            children: [
                              _buildContactInfo(v),
                              SizedBox(height: v.r<double>(xs: 24, md: 32)),
                              _buildContactForm(v),
                            ],
                          ),
                  ),
                ),
                const V2Footer(),
                SizedBox(height: PublicFloatingMenu.contentBottomInset(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo(V2Responsive v) {
    return Column(
      children: [
        _InfoCard(
          icon: Icons.email_outlined,
          title: 'Email',
          value: 'info@dgyard.com',
        ),
        SizedBox(height: v.r<double>(xs: 16, md: 20)),
        _InfoCard(
          icon: Icons.phone_outlined,
          title: 'Phone',
          value: '+91 XXX XXX XXXX',
        ),
        SizedBox(height: v.r<double>(xs: 16, md: 20)),
        _InfoCard(
          icon: Icons.location_on_outlined,
          title: 'Address',
          value: 'Location details',
        ),
      ],
    );
  }

  Widget _buildContactForm(V2Responsive v) {
    return V2PaperSurface(
      padding: EdgeInsets.all(v.r<double>(xs: 20, md: 28)),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Send us a message', style: V2Text.h3(context)),
            SizedBox(height: v.r<double>(xs: 20, md: 28)),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'Your name'),
              validator: (value) => value?.isEmpty == true ? 'Required' : null,
            ),
            SizedBox(height: v.r<double>(xs: 16, md: 20)),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email', hintText: 'your@email.com'),
              keyboardType: TextInputType.emailAddress,
              validator: (value) => value?.isEmpty == true ? 'Required' : null,
            ),
            SizedBox(height: v.r<double>(xs: 16, md: 20)),
            TextFormField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'How can we help you?',
              ),
              maxLines: 5,
              validator: (value) => value?.isEmpty == true ? 'Required' : null,
            ),
            SizedBox(height: v.r<double>(xs: 24, md: 28)),
            V2Button(
              label: 'Send Message',
              icon: Icons.send_rounded,
              size: V2BtnSize.lg,
              expand: true,
              onPressed: () {
                if (_formKey.currentState?.validate() == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message sent! (Demo)')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactHero extends StatelessWidget {
  const _ContactHero({required this.v});

  final V2Responsive v;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        v.gutter,
        v.r<double>(xs: 108, md: 128),
        v.gutter,
        v.r<double>(xs: 40, md: 56),
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [V2Colors.ink, Color(0xFF1E3A5F)],
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: V2.maxContentWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact Us',
              style: V2Text.h1(context, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              'We\'re here to help',
              style: V2Text.bodyLg(context, color: Colors.white.withValues(alpha: 0.78)),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return V2PaperSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(icon, size: 32, color: V2Colors.ember),
          const SizedBox(height: 12),
          Text(title, style: V2Text.h3(context)),
          const SizedBox(height: 6),
          Text(value, style: V2Text.body(), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}