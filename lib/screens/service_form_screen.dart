import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../widgets/bottom_nav.dart';

class ServiceFormScreen extends StatefulWidget {
  final String? serviceName;
  const ServiceFormScreen({super.key, this.serviceName});

  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  final List<String> requirements = [
    "Barangay Clearance",
    "Valid ID",
    "Proof of Residency",
  ];

  final Set<int> uploaded = {};
  final Map<int, File> uploadedFiles = {};
  bool isSubmitting = false;

  Future<void> pickFile(int index) async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        uploaded.add(index);
        uploadedFiles[index] = File(result.files.single.path!);
      });
    }
  }

  Future<void> submitRequest() async {
    if (uploaded.length != requirements.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload all required documents')),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final requestRef = FirebaseFirestore.instance.collection('requests').doc();

      for (final entry in uploadedFiles.entries) {
        final ref = FirebaseStorage.instance
            .ref('uploads/${user.uid}/${widget.serviceName}/${entry.value.path.split('/').last}');
        await ref.putFile(entry.value);
      }

      await requestRef.set({
        'serviceName': widget.serviceName,
        'userId': user.uid,
        'status': 'pending',
        'requirementsUploaded': requirements,
        'createdAt': FieldValue.serverTimestamp(),
      });

      Navigator.pushReplacementNamed(context, '/status_success');
    } catch (e) {
      Navigator.pushReplacementNamed(context, '/status_failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.serviceName ?? 'Service Form')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            ...requirements.asMap().entries.map(
              (e) => _requirementTile(e.key, e.value),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSubmitting ? null : submitRequest,
                child: isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('SUBMIT'),
              ),
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(selectedIndex: 2),
    );
  }

  Widget _requirementTile(int index, String label) {
    final done = uploaded.contains(index);
    return ListTile(
      title: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
      trailing: IconButton(
        icon: Icon(done ? LucideIcons.check : LucideIcons.upload),
        onPressed: () => pickFile(index),
      ),
    );
  }
}