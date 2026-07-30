import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';



import '../../core/constants/route_names.dart';

import '../web_public/v2/v2_colors.dart';

import '../web_public/v2/v2_text.dart';

import '../web_public/v2/widgets/v2_button.dart';

import '../web_public/v2/widgets/v2_footer.dart';

import '../web_public/widgets/public_floating_menu.dart';

import '../web_public/v2/widgets/v2_paper_surface.dart';



class DataDeletionScreen extends StatelessWidget {

  const DataDeletionScreen({super.key});



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

                child: Text(

                  'User Data Deletion - D.G Yard Connect',

                  style: V2Text.h3(context),

                ),

              ),

              const SizedBox(height: 18),

              _step('Effective date', '05 May 2026'),

              _step(

                'In-app deletion (recommended)',

                '1) Sign in to D.G Yard Connect  2) Open Settings  3) Tap Delete Account  4) Confirm request.',

              ),

              _step(

                'Deletion via email (alternative)',

                'If you cannot access your account, send a request to support@dgyard.com with your registered phone/email for identity verification.',

              ),

              const SizedBox(height: 12),

              _step(

                'What gets deleted',

                'We delete or anonymize personal account data where legally and technically permitted, including profile-linked non-essential records.',

              ),

              _step(

                'What may be retained',

                'Some records may be retained for legal compliance, fraud prevention, financial reconciliation, and dispute/audit obligations.',

              ),

              _step(

                'Processing timeline',

                'Acknowledgement is usually sent within 3-7 business days. Final deletion is usually completed within 30 days, subject to verification and legal requirements.',

              ),

              _step(

                'Support contact',

                'Email: support@dgyard.com | Phone: +91 82989 55009 | Address: Piska More, Ratu Road, Ranchi - 834005, Jharkhand, India.',

              ),

              const SizedBox(height: 16),

              Wrap(

                spacing: 10,

                runSpacing: 10,

                children: [

                  V2Button(

                    label: 'Privacy Policy',

                    onPressed: () => context.go(RouteNames.webPrivacyPolicy),

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



  Widget _step(String title, String content) {

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

