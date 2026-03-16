import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class SubmissionReceiptScreen extends StatelessWidget {
  const SubmissionReceiptScreen({super.key});

  String _formatDate(dynamic value) {
    if (value == null) return '—';

    DateTime? dt;

    // Handle ISO string — this is what service_form_screen.dart sends
    if (value is String) {
      try {
        dt = DateTime.parse(value);
      } catch (_) {
        return value;
      }
    } else if (value is DateTime) {
      dt = value;
    }

    if (dt == null) return value.toString();

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h      = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m      = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    // ── Read args from ModalRoute ──────────────────────────────────
    final args = ModalRoute.of(context)?.settings.arguments
        as Map<String, dynamic>?;

    final requestId   = args?['requestId']   as String? ?? '';
    final trackingId  = args?['trackingId']  as String? ?? '';
    final serviceName = args?['serviceName'] as String? ?? 'Service Request';
    final createdAt   = args?['createdAt'];

    // Tracking ID display
    final shortId = trackingId.isNotEmpty
        ? trackingId
        : requestId.isNotEmpty
            ? '#${requestId.length > 8 ? requestId.substring(0, 8).toUpperCase() : requestId.toUpperCase()}'
            : '—';

    // Date display
    final dateStr = createdAt != null
        ? _formatDate(createdAt)
        : _formatDate(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(48),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                // ── Success badge ────────────────────────────────────
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.checkCircle2,
                      color: Colors.green, size: 32),
                ),

                const SizedBox(height: 24),

                Text(
                  'SUBMISSION SUCCESSFUL',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black.withValues(alpha: 0.4),
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  serviceName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 28),

                // ── Tracking ID box ──────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color:
                            AppColors.primary.withValues(alpha: 0.20)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'YOUR TRACKING ID',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        shortId,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Copy button
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(
                              ClipboardData(text: shortId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Tracking ID copied!',
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600)),
                              backgroundColor: AppColors.primary,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(10)),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.primary
                                .withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.copy,
                                  size: 12, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text('Copy ID',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Receipt rows ─────────────────────────────────────
                Container(
                  padding: const EdgeInsets.only(top: 20),
                  decoration: BoxDecoration(
                    border: Border(
                        top: BorderSide(
                            color:
                                Colors.black.withValues(alpha: 0.06))),
                  ),
                  child: Column(
                    children: [
                      _receiptRow('SERVICE', serviceName),
                      _receiptRow('SUBMITTED', dateStr),
                      // ✅ Updated from 'PENDING' to 'SUBMITTED'
                      // to match unified status system
                      _receiptRow('STATUS', 'SUBMITTED',
                          valueColor: const Color(0xFF5C6BC0)),
                      _receiptRow('REQUEST ID', shortId),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Info tip ─────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color:
                            AppColors.warning.withValues(alpha: 0.30)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(LucideIcons.info,
                          size: 14, color: AppColors.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Save your Tracking ID. You can use it to monitor '
                          'your request status in the History section.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.warning,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── Track Request button ─────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pushReplacementNamed(
                      '/requests/track',
                      arguments: {'requestId': requestId},
                    ),
                    icon: const Icon(LucideIcons.searchCheck, size: 16),
                    label: Text('TRACK MY REQUEST',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1.5,
                        )),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                      elevation: 0,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Back to Home button ──────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.of(context).pushReplacementNamed('/'),
                    style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(
                          color: Colors.black.withValues(alpha: 0.12)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                    ),
                    child: Text('Back to Home',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Colors.black.withValues(alpha: 0.6),
                        )),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.black.withValues(alpha: 0.30),
                letterSpacing: 0.5,
              )),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: valueColor ?? Colors.black,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}