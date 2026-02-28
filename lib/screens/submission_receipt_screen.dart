import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class SubmissionReceiptScreen extends StatelessWidget {
  const SubmissionReceiptScreen({super.key});

  final List<Map<String, dynamic>> receiptData = const [
    { 'label': 'Request ID', 'val': '000085752237' },
    { 'label': 'Time', 'val': '25-02-2023, 13:22:16' },
    { 'label': 'Send to', 'val': 'Bank Transfer' },
    { 'label': 'Sender Name', 'val': 'Antonio Roberto' },
    { 'label': 'Status', 'val': 'pending', 'isStatus': true },
    { 'label': 'Admin Fee', 'val': 'IDR 193.00' },
  ];

  @override
  Widget build(BuildContext context) {
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
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 20))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success Badge
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(LucideIcons.checkCircle2, color: Colors.green, size: 24),
                ),
                
                const SizedBox(height: 24),
                
                Text('Submission Success!'.toUpperCase(), 
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black.withOpacity(0.4), letterSpacing: 2.0)
                ),
                const SizedBox(height: 4),
                Text('Request Title Here', 
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: -0.5)
                ),
                
                const SizedBox(height: 32),
                
                // Receipt Items
                Container(
                  padding: const EdgeInsets.only(top: 24),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.black.withOpacity(0.05)))),
                  child: Column(
                    children: receiptData.map((item) => _buildReceiptItem(item)).toList(),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      elevation: 10,
                      shadowColor: AppColors.primary.withOpacity(0.3),
                    ),
                    child: Text('CONTINUE', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2.0)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptItem(Map<String, dynamic> item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(item['label'].toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black.withOpacity(0.3), letterSpacing: -0.5)),
          Text(item['val'].toUpperCase(), 
            style: GoogleFonts.inter(
              fontSize: 10, 
              fontWeight: FontWeight.w900, 
              color: item['isStatus'] == true ? AppColors.primary : Colors.black,
              letterSpacing: -0.5
            )
          ),
        ],
      ),
    );
  }
}
