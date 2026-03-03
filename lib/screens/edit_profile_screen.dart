import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;

  final _fullNameController = TextEditingController();
  final _emailController    = TextEditingController();
  final _phoneController    = TextEditingController();

  bool _loading  = true;
  bool _saving   = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // FIX: load existing data into text fields
  Future<void> _loadUserData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _fullNameController.text = data['fullName'] ?? _auth.currentUser?.displayName ?? '';
        _emailController.text    = data['email']    ?? _auth.currentUser?.email ?? '';
        _phoneController.text    = data['phone']    ?? '';
      } else {
        _fullNameController.text = _auth.currentUser?.displayName ?? '';
        _emailController.text    = _auth.currentUser?.email ?? '';
      }
    } catch (_) {
      _fullNameController.text = _auth.currentUser?.displayName ?? '';
      _emailController.text    = _auth.currentUser?.email ?? '';
    }

    if (mounted) setState(() => _loading = false);
  }

  // FIX: saves to Firestore instead of going to status_success
  Future<void> _saveProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final fullName = _fullNameController.text.trim();
    final phone    = _phoneController.text.trim();

    if (fullName.isEmpty) {
      setState(() => _error = 'Full name cannot be empty.');
      return;
    }

    setState(() {
      _saving = true;
      _error  = null;
    });

    try {
      // Save to Firestore
      await _db.collection('users').doc(uid).set({
        'fullName': fullName,
        'email':    _emailController.text.trim(),
        'phone':    phone,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also update Firebase Auth display name
      await _auth.currentUser?.updateDisplayName(fullName);

      HapticFeedback.lightImpact();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context); // go back to profile
      }
    } catch (e) {
      setState(() {
        _error  = 'Failed to save. Please try again.';
        _saving = false;
      });
    }
  }

  String get _initials {
    final name  = _fullNameController.text.trim();
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                children: [
                  // FIX: avatar with initials
                  Center(
                    child: Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 40,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _initials,
                          style: GoogleFonts.inter(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // FIX: pre-filled fields from Firestore
                  _buildField('Full Name',      _fullNameController),
                  const SizedBox(height: 24),
                  _buildField('Email',          _emailController,
                      readOnly: true), // email change needs re-auth
                  const SizedBox(height: 24),
                  _buildField('Contact Number', _phoneController,
                      keyboardType: TextInputType.phone),

                  // Error message
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEEEE),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _error!,
                        style: GoogleFonts.inter(
                            color: AppColors.danger, fontSize: 13),
                      ),
                    ),
                  ],

                  const SizedBox(height: 48),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        elevation: 10,
                        shadowColor:
                            AppColors.primary.withValues(alpha: 0.3),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text('SAVE CHANGES',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 2.0,
                              )),
                    ),
                  ),
                  const SizedBox(height: 120),
                ],
              ),
            ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    bool obscure = false,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: readOnly ? AppColors.muted : AppColors.primary,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller:   controller,
          obscureText:  obscure,
          readOnly:     readOnly,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(
              fontWeight: FontWeight.bold, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: readOnly
                ? Colors.black.withValues(alpha: 0.03)
                : Colors.white,
            contentPadding: const EdgeInsets.all(20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(
                  color: Colors.black.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(
                  color: Colors.black.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 2),
            ),
            suffixIcon: readOnly
                ? const Icon(LucideIcons.lock,
                    color: AppColors.muted, size: 18)
                : null,
          ),
        ),
        if (readOnly)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Text(
              'Email cannot be changed here.',
              style: GoogleFonts.inter(
                  fontSize: 10, color: AppColors.muted),
            ),
          ),
      ],
    );
  }
}