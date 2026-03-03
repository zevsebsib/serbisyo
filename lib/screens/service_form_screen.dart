import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';

class ServiceFormScreen extends StatefulWidget {
  final String? serviceName;
  const ServiceFormScreen({super.key, this.serviceName});

  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  final List<String> _requirements = [
    'Barangay Clearance',
    'Valid ID',
    'Proof of Residency',
  ];

  final Map<int, File> _uploadedFiles = {};
  final Map<int, bool> _isUploading = {};
  bool _isSubmitting = false;

  int get _uploadCount => _uploadedFiles.length;
  bool get _allUploaded => _uploadCount == _requirements.length;
  double get _progress => _requirements.isEmpty
      ? 0
      : _uploadCount / _requirements.length;

  Future<void> _pickFile(int index) async {
    setState(() => _isUploading[index] = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _uploadedFiles[index] = File(result.files.single.path!);
        });
      }
    } finally {
      setState(() => _isUploading[index] = false);
    }
  }

  void _removeFile(int index) {
    setState(() => _uploadedFiles.remove(index));
  }

  Future<void> _handleSubmit() async {
    if (!_allUploaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(LucideIcons.alertCircle,
                  color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text(
                  'Please upload all ${_requirements.length} required documents.'),
            ],
          ),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      );
      return;
    }

    // Confirmation dialog before submitting
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text('Submit request?', style: AppTextStyles.h2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are submitting a request for:',
              style: AppTextStyles.bodyMuted,
            ),
            const SizedBox(height: 8),
            Text(
              widget.serviceName ?? 'Service',
              style: AppTextStyles.body.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This cannot be undone once submitted.',
              style: AppTextStyles.small,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final requestRef =
          FirebaseFirestore.instance.collection('requests').doc();

      for (final entry in _uploadedFiles.entries) {
        final fileName =
            entry.value.path.split('/').last;
        final ref = FirebaseStorage.instance.ref(
            'uploads/${user.uid}/${widget.serviceName}/$fileName');
        await ref.putFile(entry.value);
      }

      await requestRef.set({
        'serviceName': widget.serviceName,
        'userId': user.uid,
        'status': 'pending',
        'requirementsUploaded': _requirements,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/status_success');
    } catch (e) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/status_failed');
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
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress card
                  _buildProgressCard(),
                  const SizedBox(height: 20),

                  // Requirements section
                  Text('Required Documents', style: AppTextStyles.h2),
                  const SizedBox(height: 6),
                  Text(
                    'Upload all documents below to proceed.',
                    style: AppTextStyles.bodyMuted,
                  ),
                  const SizedBox(height: 14),

                  ...List.generate(
                    _requirements.length,
                    (i) => _buildRequirementTile(i),
                  ),

                  const SizedBox(height: 28),

                  // Submit button
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNav(selectedIndex: 2),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.arrowLeft,
                      color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                      'Fill out and upload required documents',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withOpacity(0.80),
                      ),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Upload Progress', style: AppTextStyles.h3),
              Text(
                '$_uploadCount / ${_requirements.length} files',
                style: AppTextStyles.small.copyWith(
                  color: _allUploaded ? AppColors.success : AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(
                _allUploaded ? AppColors.success : AppColors.primary,
              ),
              minHeight: 8,
            ),
          ),
          if (_allUploaded) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(LucideIcons.checkCircle2,
                    color: AppColors.success, size: 16),
                const SizedBox(width: 8),
                Text(
                  'All documents uploaded. Ready to submit.',
                  style: AppTextStyles.small.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRequirementTile(int index) {
    final file = _uploadedFiles[index];
    final isUploading = _isUploading[index] ?? false;
    final isDone = file != null;
    final fileName = isDone ? file.path.split('/').last : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDone
              ? AppColors.success.withOpacity(0.3)
              : AppColors.divider,
          width: isDone ? 1.5 : 1,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Status icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 44,
              height: 44,
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
                        color: AppColors.primary,
                      ),
                    )
                  : Icon(
                      isDone
                          ? LucideIcons.checkCircle2
                          : LucideIcons.fileUp,
                      color: isDone ? AppColors.success : AppColors.muted,
                      size: 22,
                    ),
            ),
            const SizedBox(width: 14),

            // Label + file name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                        color: AppColors.success,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else if (!isUploading) ...[
                    const SizedBox(height: 3),
                    Text(
                      'PDF, JPG or PNG — tap to upload',
                      style: AppTextStyles.small,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Action button
            if (isDone)
              // Remove button
              GestureDetector(
                onTap: () => _removeFile(index),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.trash2,
                      color: AppColors.danger, size: 16),
                ),
              )
            else if (!isUploading)
              // Upload button
              GestureDetector(
                onTap: () => _pickFile(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius:
                        BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                        width: 1),
                  ),
                  child: Text(
                    'Upload',
                    style: GoogleFonts.inter(
                      color: AppColors.primary,
                      fontSize: 12,
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
        color: _allUploaded && !_isSubmitting ? null : AppColors.muted.withOpacity(0.25),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: _allUploaded && !_isSubmitting ? AppShadows.primary : [],
      ),
      child: ElevatedButton(
        onPressed: (_isSubmitting || !_allUploaded) ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.send,
                    size: 18,
                    color: _allUploaded
                        ? Colors.white
                        : AppColors.muted,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _allUploaded
                        ? 'Submit Request'
                        : 'Upload all documents to continue',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
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