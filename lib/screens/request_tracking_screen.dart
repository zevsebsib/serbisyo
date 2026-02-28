import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';

class RequestTrackingScreen extends StatelessWidget {
  const RequestTrackingScreen({super.key});

  final List<Map<String, dynamic>> steps = const [
    { 'label': 'Submitted', 'status': 'completed', 'date': '24-02-2023, 10:00 AM' },
    { 'label': 'Pending?', 'status': 'current', 'date': 'In Progress' },
    { 'label': 'Approved?', 'status': 'pending' },
    { 'label': 'Processing?', 'status': 'pending' },
    { 'label': 'Ready for Pick Up?', 'status': 'pending' },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Request Status'),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          children: [
            // Request Header
            Column(
              children: [
                Text('Service Request Title'.toUpperCase(), 
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black.withOpacity(0.4), letterSpacing: 2.0)
                ),
                const SizedBox(height: 16),
                Container(
                  width: 80,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.fileText, color: Colors.white, size: 40),
                      const SizedBox(height: 4),
                      Text('FILE', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white.withOpacity(0.6))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('Request ID: #000000000000'.toUpperCase(), 
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 1.0)
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            Container(height: 1, color: Colors.black.withOpacity(0.05), width: double.infinity),
            const SizedBox(height: 40),
            
            // Stepper
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: steps.length,
              itemBuilder: (context, idx) {
                final step = steps[idx];
                final bool isLast = idx == steps.length - 1;
                
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Step Indicator & Line
                      Column(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: step['status'] == 'completed' ? AppColors.primary : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: step['status'] == 'pending' ? Colors.black.withOpacity(0.05) : AppColors.primary,
                                width: 4
                              ),
                              boxShadow: step['status'] == 'completed' 
                                ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] 
                                : null,
                            ),
                            child: Center(
                              child: step['status'] == 'completed' 
                                ? const Icon(LucideIcons.checkCircle2, color: Colors.white, size: 24)
                                : Text('${idx + 1}', 
                                    style: GoogleFonts.inter(
                                      fontSize: 12, 
                                      fontWeight: FontWeight.w900, 
                                      color: step['status'] == 'current' ? AppColors.primary : Colors.black.withOpacity(0.1)
                                    )
                                  ),
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: Colors.black.withOpacity(0.05),
                                margin: const EdgeInsets.symmetric(vertical: 4),
                              ),
                            ),
                        ],
                      ),
                      
                      const SizedBox(width: 24),
                      
                      // Step Content
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.only(top: 8, bottom: 32),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(step['label'], 
                                    style: GoogleFonts.inter(
                                      fontSize: 14, 
                                      fontWeight: FontWeight.w900, 
                                      color: step['status'] == 'pending' ? Colors.black.withOpacity(0.2) : Colors.black
                                    )
                                  ),
                                  if (step['date'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(step['date'], 
                                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black.withOpacity(0.3), letterSpacing: -0.5)
                                      ),
                                    ),
                                ],
                              ),
                              Text(
                                step['status'] == 'completed' ? 'DONE' : 
                                step['status'] == 'current' ? 'IN PROGRESS' : 'PENDING',
                                style: GoogleFonts.inter(
                                  fontSize: 10, 
                                  fontWeight: FontWeight.w900, 
                                  color: step['status'] == 'completed' ? Colors.green : 
                                         step['status'] == 'current' ? AppColors.primary : 
                                         Colors.black.withOpacity(0.2),
                                  letterSpacing: -0.5
                                )
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(selectedIndex: 1),
    );
  }
}
