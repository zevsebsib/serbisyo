import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState
    extends State<PersonalInformationScreen> {
  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;

  String _fullName = '';
  String _email    = '';
  String _phone    = '';
  bool   _loading  = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _fullName = data['fullName'] ?? _auth.currentUser?.displayName ?? '';
          _email    = data['email']    ?? _auth.currentUser?.email ?? '';
          _phone    = data['phone']    ?? '';
          _loading  = false;
        });
      } else {
        setState(() {
          _fullName = _auth.currentUser?.displayName ?? '';
          _email    = _auth.currentUser?.email ?? '';
          _loading  = false;
        });
      }
    } catch (_) {
      setState(() {
        _fullName = _auth.currentUser?.displayName ?? '';
        _email    = _auth.currentUser?.email ?? '';
        _loading  = false;
      });
    }
  }

  String get _initials {
    final parts = _fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return _fullName.isNotEmpty ? _fullName[0].toUpperCase() : 'U';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Personal Information'),
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
                  // FIX: avatar with initials instead of hardcoded logo
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

                  // FIX: real data from Firestore
                  _buildInfoItem('Full Name',       _fullName.isNotEmpty ? _fullName : '—'),
                  _buildInfoItem('Email',           _email.isNotEmpty    ? _email    : '—'),
                  _buildInfoItem('Contact Number',  _phone.isNotEmpty    ? _phone    : '—'),
                  _buildInfoItem('Password',        '••••••••••'),

                  const SizedBox(height: 48),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await Navigator.pushNamed(context, '/profile_edit');
                        _loadUserData(); // reload after editing
                      },
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
                      child: Text('EDIT PROFILE',
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

  Widget _buildInfoItem(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
                letterSpacing: 2.0,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: Colors.black.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}