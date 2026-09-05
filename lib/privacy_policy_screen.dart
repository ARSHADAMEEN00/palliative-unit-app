import 'package:flutter/material.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key, this.supportEmail, this.supportPhone});

  final String? supportEmail;
  final String? supportPhone;

  @override
  Widget build(BuildContext context) {
    final contacts = [
      if (supportEmail?.trim().isNotEmpty ?? false) supportEmail!.trim(),
      if (supportPhone?.trim().isNotEmpty ?? false) supportPhone!.trim(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Privacy & Data Use'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            Text(
              'Last updated 4 September 2026',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            const _PolicySection(
              title: 'Who this app is for',
              body:
                  'Palliative App is a restricted care-management tool for authorised staff of participating palliative-care organisations. The organisation that issued your account controls the patient and staff records entered in the app.',
            ),
            const _PolicySection(
              title: 'Data handled by the app',
              body:
                  'Depending on the modules your organisation enables, the app handles staff account details; patient identity, contact and demographic details; diagnoses, symptoms, vital signs, medicines, assessments, care plans, visit notes, signatures and selected clinical images; and operational records for volunteers, social support, equipment, inventory and billing administration.',
            ),
            const _PolicySection(
              title: 'Why data is used',
              body:
                  'Data is used to authenticate authorised staff, maintain care records, coordinate home visits and services, manage medicines and equipment, create reports, administer access, and keep the service reliable and secure. The app does not include advertising or third-party analytics SDKs.',
            ),
            const _PolicySection(
              title: 'Device permissions',
              body:
                  'Microphone access is requested only when you start speech-to-text. The app keeps the recognised text, not an audio recording; the speech-recognition service installed on the device may process audio under its own terms. Camera or photo access is used only when you choose to attach an image. Bluetooth access supports compatible audio accessories during dictation.',
            ),
            const _PolicySection(
              title: 'Storage and disclosure',
              body:
                  'Records are sent to the organisation’s service over encrypted HTTPS connections. A limited assessment draft and recent history may be cached in the app’s private device storage so work can be resumed. Login credentials are stored using platform-protected encrypted storage. Records may be accessed by authorised staff and by infrastructure providers acting for the service. Data is not sold.',
            ),
            const _PolicySection(
              title: 'Retention, correction and deletion',
              body:
                  'The organisation that issued your account sets retention periods and may have legal duties to retain clinical records. Contact your unit administrator or support contact to request access, correction or deletion. Requests are handled subject to applicable healthcare, record-keeping and other legal requirements. Signing out removes the saved login credential from this device.',
            ),
            const _PolicySection(
              title: 'Medical-purpose notice',
              body:
                  'This software records and organises information for care teams. It is not a medical device and does not diagnose, treat, cure or prevent any medical condition. Users should rely on qualified healthcare professionals for medical advice, diagnosis and treatment.',
            ),
            _PolicySection(
              title: 'Contact',
              body: contacts.isEmpty
                  ? 'Contact the palliative-care organisation or administrator that issued your account for privacy questions or data requests.'
                  : 'For privacy questions or data requests, contact your unit support team: ${contacts.join(' • ')}.',
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
