import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // ── Launch helpers ─────────────────────────────────────────────────────────
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link.')),
        );
      }
    }
  }

  Future<void> _sendEmail() async {
    final subject = Uri.encodeComponent(_subjectController.text.trim());
    final body    = Uri.encodeComponent(_messageController.text.trim());

    if (subject.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in both subject and message.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _sending = true);

    // Replace with your actual support email
    final mailUrl =
        'mailto:abcdspade@gmail.com?subject=$subject&body=$body';

    await _launchUrl(mailUrl);
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.secondary,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero ──────────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: AppShadows.primary,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('How can we help?',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            )),
                        const SizedBox(height: 6),
                        Text(
                          'Reach out to us anytime.\nWe\'re here to assist you.',
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.80),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.headphones,
                        color: Colors.white, size: 26),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Quick Contact ─────────────────────────────────────────────────
            Text('Quick Contact', style: AppTextStyles.h2),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _buildContactCard(
                    icon:    LucideIcons.phone,
                    label:   'Call Us',
                    value:   '(077) 123-4567',
                    color:   AppColors.success,
                    bgColor: AppColors.successLight,
                    onTap:   () => _launchUrl('tel:+6377123456'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildContactCard(
                    icon:    LucideIcons.facebook,
                    label:   'Facebook',
                    value:   'City of Laoag',
                    color:   const Color(0xFF1877F2),
                    bgColor: const Color(0xFFE7F0FD),
                    onTap:   () => _launchUrl('https://facebook.com'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildContactCard(
                    icon:    LucideIcons.mail,
                    label:   'Email',
                    value:   'support@laoag.gov.ph',
                    color:   AppColors.primary,
                    bgColor: AppColors.cardBg,
                    onTap:   () => _launchUrl(
                        'mailto:support@laoag.gov.ph'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildContactCard(
                    icon:    LucideIcons.mapPin,
                    label:   'Visit Us',
                    value:   'City Hall, Laoag',
                    color:   AppColors.warning,
                    bgColor: AppColors.warningLight,
                    onTap:   () => _launchUrl(
                        'https://maps.google.com/?q=Laoag+City+Hall'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ── FAQ Section ───────────────────────────────────────────────────
            Text('Frequently Asked Questions', style: AppTextStyles.h2),
            const SizedBox(height: 14),

            _buildFaq(
              question: 'How long does it take to process a request?',
              answer:
                  'Processing time varies per service. Most requests are completed within 3–5 business days. You will be notified via the app when your status changes.',
            ),
            _buildFaq(
              question: 'What documents do I need to upload?',
              answer:
                  'Required documents depend on the service type. When you select a service, the app will list all required files before you submit.',
            ),
            _buildFaq(
              question: 'How do I track my request?',
              answer:
                  'Go to the Requests tab or History page to see the real-time status of all your submitted requests.',
            ),
            _buildFaq(
              question: 'Can I cancel a submitted request?',
              answer:
                  'Once submitted, requests cannot be cancelled through the app. Please contact our support team directly for assistance.',
            ),

            const SizedBox(height: 28),

            // ── Send Message Form ─────────────────────────────────────────────
            Text('Send Us a Message', style: AppTextStyles.h2),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                children: [
                  _buildTextField(
                    controller: _subjectController,
                    label:      'Subject',
                    hint:       'e.g. Issue with my request',
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _messageController,
                    label:      'Message',
                    hint:       'Describe your concern...',
                    maxLines:   4,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _sending ? null : () {
                        HapticFeedback.lightImpact();
                        _sendEmail();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.lg)),
                        elevation: 0,
                      ),
                      child: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(LucideIcons.send, size: 16),
                                const SizedBox(width: 8),
                                Text('Send Message',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    )),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Contact card ───────────────────────────────────────────────────────────
  Widget _buildContactCard({
    required IconData icon,
    required String   label,
    required String   value,
    required Color    color,
    required Color    bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: AppTextStyles.caption
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(value,
                style: AppTextStyles.small.copyWith(color: AppColors.muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // ── FAQ tile ───────────────────────────────────────────────────────────────
  Widget _buildFaq({required String question, required String answer}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: ExpansionTile(
        tilePadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        childrenPadding:
            const EdgeInsets.fromLTRB(18, 0, 18, 16),
        iconColor: AppColors.primary,
        collapsedIconColor: AppColors.muted,
        title: Text(question,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            )),
        children: [
          Text(answer,
              style: AppTextStyles.small.copyWith(
                color: AppColors.muted,
                height: 1.6,
              )),
        ],
      ),
    );
  }

  // ── Text field ─────────────────────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
              letterSpacing: 2.0,
            )),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines:   maxLines,
          style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(
            hintText:  hint,
            hintStyle: GoogleFonts.inter(
                color: AppColors.muted, fontSize: 13),
            filled:    true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide(
                  color: Colors.black.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide(
                  color: Colors.black.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: const BorderSide(
                  color: AppColors.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}