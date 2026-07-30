import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';



import '../../core/constants/route_names.dart';

import '../web_public/v2/v2_colors.dart';

import '../web_public/v2/v2_text.dart';

import '../web_public/v2/widgets/v2_button.dart';

import '../web_public/v2/widgets/v2_footer.dart';

import '../web_public/widgets/public_floating_menu.dart';

import '../web_public/v2/widgets/v2_paper_surface.dart';



class PrivacyPolicyScreen extends StatelessWidget {

  const PrivacyPolicyScreen({super.key});



  static const _topPad = 24.0;



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: V2Colors.saasBg,

      body: Stack(

        children: [

          ListView(

            padding: EdgeInsets.fromLTRB(20, _topPad, 20, PublicFloatingMenu.contentBottomInset(context)),

            children: [

              V2PaperSurface(

                padding: const EdgeInsets.all(16),

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(

                      'Privacy Policy - D.G Yard Connect',

                      style: V2Text.h3(context),

                    ),

                    const SizedBox(height: 6),

                    Text('Effective date: 05 May 2026', style: V2Text.body()),

                  ],

                ),

              ),

              const SizedBox(height: 18),

              _section(

                '1. App Information',

                'Controller: D.G.Yard | Phone: +91 82989 55009 | Email: support@dgyard.com | Address: Piska More, Ratu Road, Ranchi - 834005, Jharkhand, India.',

              ),

              _section(

                '2. Data We Collect',

                'We may collect account details (name, phone, email), service/job data, device and technical information, location (when allowed), uploaded photos/documents, and payment references needed for platform operations.',

              ),

              _section(

                '3. How We Use Data',

                'We use data to provide service workflows, authenticate users, coordinate dealers and technicians, communicate updates, process payments, improve reliability, and support fraud prevention/legal compliance.',

              ),

              _section(

                '4. Data Sharing',

                'We may share relevant data with assigned technicians/dealers, payment gateway providers, analytics/infrastructure providers, and legal authorities where required. We do not sell personal data.',

              ),

              _section(

                '5. Security Measures',

                'We use encrypted transit (HTTPS/TLS), access controls, secure authentication, and monitored cloud infrastructure. While no method is 100% secure, we continuously improve protections.',

              ),

              _section(

                '6. Data Retention',

                'We retain data only as long as necessary for service delivery, legal obligations, dispute handling, fraud prevention, and financial reconciliation.',

              ),

              _section(

                '7. Your Rights',

                'You can request access, correction, or deletion of your personal data. You can also manage device permissions like location/camera from device settings.',

              ),

              _section(

                '8. Account and Data Deletion',

                'You can delete your account from app settings (Settings > Delete Account) or request deletion via support@dgyard.com. See the Data Deletion page for full steps.',

              ),

              _section(

                '9. Children\'s Privacy',

                'D.G Yard Connect is not intended for children under 13. We do not knowingly collect children\'s personal data.',

              ),

              _section(

                '10. Policy Updates',

                'We may update this policy from time to time. Material updates are reflected by changing the effective date and may be notified in-app when required.',

              ),

              _section(

                '11. Contact Details',

                'Email: support@dgyard.com | Phone: +91 82989 55009 | Address: Piska More, Ratu Road, Ranchi - 834005, Jharkhand, India.',

              ),

              const SizedBox(height: 16),

              Wrap(

                spacing: 10,

                runSpacing: 10,

                children: [

                  V2Button(

                    label: 'Data Deletion',

                    onPressed: () => context.go(RouteNames.webDataDeletion),

                  ),

                  V2Button(

                    label: 'Back to Home',

                    variant: V2BtnVariant.outline,

                    onPressed: () => context.go(RouteNames.publicHome),

                  ),

                ],

              ),

              const SizedBox(height: 40),

              const V2Footer(),

            ],

          ),


        ],

      ),

    );

  }



  Widget _section(String title, String content) {

    return Padding(

      padding: const EdgeInsets.only(bottom: 12),

      child: V2PaperSurface(

        padding: const EdgeInsets.all(14),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Text(title, style: V2Text.bodyEmph()),

            const SizedBox(height: 6),

            Text(content, style: V2Text.body()),

          ],

        ),

      ),

    );

  }

}

