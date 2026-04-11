import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  REQUIREMENTS MAP
//  Source: Laoag City Citizens' Charter (2020, 1st Edition)
// ─────────────────────────────────────────────────────────────────────────────
const Map<String, List<String>> _serviceRequirements = {

  // ── CITY MAYOR – ADMINISTRATIVE DIVISION ────────────────────────────────

  /// Citizens' Charter p.13-14 · Provision of Consumer Assistance
  /// Covers: recommendation letters, referrals, fund-raising, street closure, streamers
  'Provision of Consumer Assistance': [
    'Bio-Data or Curriculum Vitae (for Recommendation Letter)',
    'Transcript of Records (for Recommendation Letter)',
    'Copy of Civil Service Eligibility, if any (for Recommendation Letter)',
    'Barangay Clearance',
    'Certificate of Indigency (for Referral to Health Services)',
    'Clinical Diagnosis or Doctor\'s Referral (for Referral to Health Services)',
    'Letter Request stating purpose, date, place, and size '
        '(for Streamers / Fund-Raising / Street Closure)',
  ],

  /// Citizens' Charter p.15-16 · Issuance of Certificate of Good Moral Character
  'Issuance of Certificate of Good Moral Character': [
    'Birth Certificate (PSA copy) — for Scholarship applicants',
    'Certificate of Residency from the Barangay Chairman — for Scholarship applicants',
    'Barangay Clearance — for Local/Overseas Employment applicants',
    'Police Clearance — for Local/Overseas Employment applicants',
    'Prosecutor\'s Clearance — for Local/Overseas Employment applicants',
    'Court Clearance — for Local/Overseas Employment applicants',
    'NBI Clearance — for Local/Overseas Employment applicants',
  ],

  /// Citizens' Charter p.16-18 · Granting of Permit for the Use of Government Facilities and Equipment
  'Permit for Use of Government Facilities and Equipment': [
    'Letter Request addressed to the City Mayor '
        '(specify: facility/equipment to be used, purpose, time, and date)',
    'Official Receipt showing payment of fees (from the Office of the City Treasurer)',
  ],

  /// Citizens' Charter p.18-20 · Receipt of Complaints
  'Receipt of Complaints': [
    'Letter of Complaint addressed to the City Mayor',
  ],

  // ── OFFICE OF THE CITY CIVIL REGISTRAR ──────────────────────────────────

  /// Citizens' Charter p.247 · Registration of Live Birth, Death and Marriage
  'Registration of Live Birth, Death, and Marriage': [
    'Duly Accomplished Certificate (Municipal Form No. 102 for Birth / '
        'No. 103 for Death / No. 97 for Marriage)',
    'Marriage Certificate of Parents — PSA copy (for Live Birth)',
    'Medical Certificate signed by attending physician (for Death)',
    'Marriage License (for Marriage)',
    'Valid ID of the Informant / Both Parties',
  ],

  /// Citizens' Charter p.248 · Late Registration
  'Late Registration of Birth, Death or Marriage': [
    'Duly Accomplished Certificate of Live Birth / Death / Marriage',
    'Affidavit of Late Registration',
    'Earliest School Records — Form 137 or Report Card (for Birth)',
    'Baptismal Certificate, if available (for Birth)',
    'Marriage Certificate of Parents — PSA copy (for Birth)',
    'Medical Certificate, if available (for Death)',
    'Valid ID of the Informant / Both Parties',
  ],

  /// Citizens' Charter p.251 · Application for Marriage License
  'Application for Marriage-License': [
    'Birth Certificates of Both Parties (PSA copy)',
    'Certificate of No Marriage (CENOMAR) from PSA',
    'Community Tax Certificates of Both Parties',
    'Parental Consent or Advice (if applicant is 18–24 years old)',
    'Pre-Marriage Orientation and Counseling (PMOC) Certificate',
    'Certificate of Legal Capacity (for foreign nationals, if applicable)',
    '1 pc. 2x2 ID Picture of Each Party',
  ],

  /// Citizens' Charter p.253 · Out-of-Town Registration / Reporting
  'Out-of-Town Registration / Reporting': [
    'Original Civil Registry Document to be reported',
    'Supporting Documents related to the document being reported',
    'Valid ID of the Registrant or Representative',
  ],

  /// Citizens' Charter p.255 · Registration of Legal Instruments
  'Registration of Legal Instruments': [
    'Duly Accomplished Legal Instrument',
    'Court Order or Decision, if applicable',
    'Valid ID of the Applicant',
  ],

  /// Citizens' Charter p.264 · Issuance of Certified Machine Copy
  'Issuance of Certified Machine Copy': [
    'Letter Request or Accomplished Request Form',
    'Valid ID of the Requesting Party',
  ],

  // ── OFFICE OF THE CITY COMMUNITY AFFAIRS OFFICER ────────────────────────

  /// Citizens' Charter p.55-56 · Local Employment Referral (for Applicants)
  'Local Employment Referral (Applicants)': [
    'Curriculum Vitae / Resume with 2x2 ID Picture',
    'Transcript of Records or Graduation Certificate',
    'Form 138 — for High School Graduates',
    'Barangay Clearance',
  ],

  /// Citizens' Charter p.56-57 · Local Employment Referral (for Employers)
  'Local Employment Referral (Employers)': [
    'Company / Employer Profile',
    'List of Job Vacancies and Positions',
    'Number of Persons to be Hired',
    'Qualification Requirements of Applicants',
    'List of Required Documents to be Submitted by Applicants',
  ],

  /// Citizens' Charter p.58-60 · SPES Program
  'SPES Program': [
    'Photocopy of Birth Certificate or any document showing age '
        '(must be 15–30 years old)',
    'Photocopy of latest Income Tax Return (ITR) of parents/guardian '
        'OR Certificate of Indigence from Barangay/DSWD '
        'OR Certificate of Low Income from the Barangay or CSWD',
    'Proof of passing grade — Class Card or Form 138 of the previous semester '
        '(for Students)',
    'Certification as Out-of-School Youth issued by DSWD/CSWD '
        '(for OSY applicants)',
  ],

  /// Citizens' Charter p.61-62 · Livelihood Assistance (Animal Dispersal)
  'Livelihood Assistance (Animal Dispersal)': [
    'Letter Request or Barangay Resolution',
    'City Mayor\'s Approval of the Request',
  ],

  /// Citizens' Charter p.64-65 · Sama-Summer Together Program
  'Sama-Summer Together Program': [
    'Certificate of Residency from the Barangay Chairman',
    'Photocopy of Birth Certificate',
    'Consent of Parent or Guardian',
  ],
};

const List<String> _defaultRequirements = [
  'Barangay Clearance',
  'Valid ID',
  'Proof of Residency',
];

// ─────────────────────────────────────────────────────────────────────────────
class ServiceFormScreen extends StatefulWidget {
  final String? serviceName;
  final String? category;
  final String? department;
  final String? departmentId;

  const ServiceFormScreen({
    super.key,
    this.serviceName,
    this.category,
    this.department,
    this.departmentId,
  });

  @override
  State<ServiceFormScreen> createState() =>
      _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  static const String _cloudName    = 'dmsgbxyzh';
  static const String _uploadPreset = 'serbisyo_alisto';

  late final List<String> _requirements;

  final Map<int, File> _uploadedFiles = {};
  final Map<int, bool> _isUploading   = {};
  bool _isSubmitting = false;

  int    get _uploadCount => _uploadedFiles.length;
  bool   get _allUploaded =>
      _uploadCount == _requirements.length;
  double get _progress    =>
      _requirements.isEmpty
          ? 0
          : _uploadCount / _requirements.length;

  @override
  void initState() {
    super.initState();
    _requirements =
        _serviceRequirements[widget.serviceName] ??
            _defaultRequirements;
  }

  String _generateTrackingId() {
    final now   = DateTime.now();
    final year  = now.year.toString().substring(2);
    final month = now.month.toString().padLeft(2, '0');
    final day   = now.day.toString().padLeft(2, '0');
    final rand  =
        (now.millisecondsSinceEpoch % 10000)
            .toString()
            .padLeft(4, '0');
    return 'SA-$year$month$day-$rand';
  }

  Future<void> _pickFile(int index) async {
    setState(() => _isUploading[index] = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result != null &&
          result.files.single.path != null) {
        setState(() {
          _uploadedFiles[index] =
              File(result.files.single.path!);
        });
      }
    } finally {
      setState(() => _isUploading[index] = false);
    }
  }

  void _removeFile(int index) =>
      setState(() => _uploadedFiles.remove(index));

  Future<String> _uploadToCloudinary(
      File file, String docName) async {
    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/auto/upload');

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder']        = 'serbisyo_alisto'
      ..fields['public_id']     =
          '${docName.toLowerCase().replaceAll(' ', '_')}_'
          '${DateTime.now().millisecondsSinceEpoch}'
      ..files.add(
          await http.MultipartFile.fromPath('file', file.path));

    final streamed  = await request.send();
    final body      = await streamed.stream.bytesToString();
    final jsonData  =
        jsonDecode(body) as Map<String, dynamic>;

    if (streamed.statusCode == 200) {
      return jsonData['secure_url'] as String;
    } else {
      final error =
          jsonData['error']?['message'] ?? 'Unknown error';
      throw Exception('Cloudinary upload failed: $error');
    }
  }

  Future<void> _handleSubmit() async {
    if (!_allUploaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(LucideIcons.alertCircle,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(
                'Please upload all ${_requirements.length} required documents.'),
          ]),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(AppRadius.md)),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppRadius.lg)),
        title: Text('Submit request?',
            style: AppTextStyles.h2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are submitting a request for:',
                style: AppTextStyles.bodyMuted),
            const SizedBox(height: 8),
            Text(
              widget.serviceName ?? 'Service',
              style: AppTextStyles.body.copyWith(
                color:      AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text('This cannot be undone once submitted.',
                style: AppTextStyles.small),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style:
                    TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                      AppRadius.md)),
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _isSubmitting = true);

    try {
      final user       =
          FirebaseAuth.instance.currentUser!;
      final requestRef = FirebaseFirestore.instance
          .collection('requests')
          .doc();
      final trackingId = _generateTrackingId();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Text('Uploading documents...'),
            ]),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 60),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                    AppRadius.md)),
          ),
        );
      }

      final Map<String, String> documentUrls = {};
      for (final entry in _uploadedFiles.entries) {
        final docName = _requirements[entry.key];
        final url =
            await _uploadToCloudinary(entry.value, docName);
        documentUrls[docName] = url;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      String citizenName =
          user.displayName ?? user.email ?? 'Unknown';
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          citizenName =
              userDoc.data()?['fullName'] ?? citizenName;
        }
      } catch (_) {}

      // Ensure request always carries both department and departmentId.
      final category = (widget.category ?? '').trim();
      final fallbackDeptByCategory = {
        'mayor': 'City Administration Office',
        'civil': 'Office of the City Civil Registrar',
        'community': 'Office of the City Community Affairs',
      };
      final resolvedDepartment = (widget.department ?? '').trim().isNotEmpty
          ? widget.department!.trim()
          : (fallbackDeptByCategory[category] ?? 'Unassigned');

      var resolvedDepartmentId = (widget.departmentId ?? '').trim();
      if (resolvedDepartmentId.isEmpty && resolvedDepartment != 'Unassigned') {
        try {
          final deptSnap = await FirebaseFirestore.instance
              .collection('departments')
              .where('name', isEqualTo: resolvedDepartment)
              .limit(1)
              .get();
          if (deptSnap.docs.isNotEmpty) {
            resolvedDepartmentId = deptSnap.docs.first.id;
          }
        } catch (_) {}
      }

      // ── FIX: status is now 'submitted' to match admin pipeline ──
      // Previously saved as 'pending' which is a different step
      // in the workflow and caused the admin stepper/filter mismatch.
      await requestRef.set({
        // Identification
        'trackingId':   trackingId,
        'userId':       user.uid,
        'citizenName':  citizenName,
        'citizenEmail': user.email ?? '',

        // Service info — department passed from services_screen
        'serviceName':  widget.serviceName ?? 'Unknown Service',
        'category':     category.isNotEmpty ? category : 'General',
        'department':   resolvedDepartment,
        'departmentId': resolvedDepartmentId,

        // ── FIX: was 'pending', now 'submitted' ──────────────────
        'status':             'submitted',
        'verificationStatus': 'unverified',
        'priority':           'MEDIUM',

        // Documents
        'requirementsUploaded': _requirements,
        'documentUrls':         documentUrls,
        'missingDocuments':     [],
        'finalDocumentUrl':     '',

        // Assignment
        'assignedTo': '',
        'assignedBy': '',
        'assignedAt': null,

        // Rejection
        'rejectionReason': '',

        // ── FIX: status history entry also updated to 'submitted' ─
        'statusHistory': [
          {
            'status':    'submitted',
            'note':      'Request submitted by citizen.',
            'updatedBy': user.uid,
            'updatedAt': Timestamp.now(),
          }
        ],

        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        '/submission_receipt',
        arguments: {
          'requestId':   requestRef.id,
          'trackingId':  trackingId,
          'serviceName': widget.serviceName ?? 'Service',
          'createdAt':   DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Submission failed: ${e.toString()}'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                  AppRadius.md)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  18, 4, 18, 120),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  _buildProgressCard(),
                  const SizedBox(height: 20),
                  Text('Required Documents',
                      style: AppTextStyles.h2),
                  const SizedBox(height: 6),
                  Text(
                      'Upload all documents below to proceed.',
                      style: AppTextStyles.bodyMuted),
                  const SizedBox(height: 14),
                  ...List.generate(_requirements.length,
                      _buildRequirementTile),
                  const SizedBox(height: 28),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          const BottomNav(selectedIndex: 1),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(18, 14, 18, 22),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white
                        .withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.arrowLeft,
                      color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.serviceName ?? 'Service Form',
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.department?.isNotEmpty == true
                          ? widget.department!
                          : 'Fill out and upload required documents',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.white
                            .withValues(alpha: 0.80),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Text('Upload Progress',
                  style: AppTextStyles.h3),
              Text(
                '$_uploadCount / ${_requirements.length} files',
                style: AppTextStyles.small.copyWith(
                  color: _allUploaded
                      ? AppColors.success
                      : AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius:
                BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(
                _allUploaded
                    ? AppColors.success
                    : AppColors.primary,
              ),
              minHeight: 8,
            ),
          ),
          if (_allUploaded) ...[
            const SizedBox(height: 12),
            Row(children: [
              const Icon(LucideIcons.checkCircle2,
                  color: AppColors.success, size: 16),
              const SizedBox(width: 8),
              Text(
                'All documents uploaded. Ready to submit.',
                style: AppTextStyles.small.copyWith(
                  color:      AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildRequirementTile(int index) {
    final file        = _uploadedFiles[index];
    final isUploading = _isUploading[index] ?? false;
    final isDone      = file != null;
    final fileName =
        isDone ? file.path.split('/').last : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDone
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.divider,
          width: isDone ? 1.5 : 1,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: isDone
                    ? AppColors.successLight
                    : AppColors.background,
                borderRadius: BorderRadius.circular(13),
              ),
              child: isUploading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.primary),
                    )
                  : Icon(
                      isDone
                          ? LucideIcons.checkCircle2
                          : LucideIcons.fileUp,
                      color: isDone
                          ? AppColors.success
                          : AppColors.muted,
                      size: 22,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    _requirements[index],
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                  ),
                  if (isDone && fileName != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      fileName,
                      style: AppTextStyles.small.copyWith(
                        color:      AppColors.success,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else if (!isUploading) ...[
                    const SizedBox(height: 3),
                    Text('PDF, JPG or PNG — tap to upload',
                        style: AppTextStyles.small),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (isDone)
              GestureDetector(
                onTap: () => _removeFile(index),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.trash2,
                      color: AppColors.danger, size: 16),
                ),
              )
            else if (!isUploading)
              GestureDetector(
                onTap: () => _pickFile(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(
                        AppRadius.pill),
                    border: Border.all(
                        color: AppColors.primary
                            .withValues(alpha: 0.3),
                        width: 1),
                  ),
                  child: Text(
                    'Upload',
                    style: GoogleFonts.inter(
                      color:      AppColors.primary,
                      fontSize:   12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: _allUploaded && !_isSubmitting
            ? AppColors.primaryGradient
            : null,
        color: _allUploaded && !_isSubmitting
            ? null
            : AppColors.muted.withValues(alpha: 0.25),
        borderRadius:
            BorderRadius.circular(AppRadius.lg),
        boxShadow: _allUploaded && !_isSubmitting
            ? AppShadows.primary
            : [],
      ),
      child: ElevatedButton(
        onPressed: (_isSubmitting || !_allUploaded)
            ? null
            : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor:         Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor:             Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(AppRadius.lg)),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primary),
              )
            : Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.send,
                      size: 18,
                      color: _allUploaded
                          ? Colors.white
                          : AppColors.muted),
                  const SizedBox(width: 10),
                  Text(
                    _allUploaded
                        ? 'Submit Request'
                        : 'Upload all documents to continue',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize:   15,
                      color: _allUploaded
                          ? Colors.white
                          : AppColors.muted,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}