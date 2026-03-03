import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid;

  // ── Notification type → icon/color mapping ────────────────────────────────
  IconData _getIcon(String type) {
    switch (type) {
      case 'status_update':   return LucideIcons.refreshCw;
      case 'completed':       return LucideIcons.checkCircle2;
      case 'action_required': return LucideIcons.alertTriangle;
      case 'received':        return LucideIcons.clipboardCheck;
      default:                return LucideIcons.bell;
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'status_update':   return const Color(0xFF5B6AF0);
      case 'completed':       return AppColors.success;
      case 'action_required': return AppColors.warning;
      case 'received':        return AppColors.primary;
      default:                return AppColors.primary;
    }
  }

  Color _getBgColor(String type) {
    switch (type) {
      case 'status_update':   return const Color(0xFFEEF0FD);
      case 'completed':       return AppColors.successLight;
      case 'action_required': return AppColors.warningLight;
      case 'received':        return AppColors.cardBg;
      default:                return AppColors.cardBg;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _timeAgo(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final diff = DateTime.now().difference(timestamp.toDate());
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24)   return '${diff.inHours} hr ago';
    if (diff.inDays == 1)    return 'Yesterday';
    if (diff.inDays < 7)     return '${diff.inDays} days ago';
    return '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}';
  }

  // ── Mark single notification as read ──────────────────────────────────────
  Future<void> _markAsRead(String docId) async {
    if (_uid == null) return;
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(_uid)
        .collection('items')
        .doc(docId)
        .update({'isRead': true});
  }

  // ── Mark ALL notifications as read ────────────────────────────────────────
  Future<void> _markAllRead(List<QueryDocumentSnapshot> docs) async {
    if (_uid == null) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in docs) {
      if (doc['isRead'] == false) {
        batch.update(doc.reference, {'isRead': true});
      }
    }
    await batch.commit();
  }

  // ── Save FCM token for this user ──────────────────────────────────────────
  Future<void> _saveFcmToken() async {
    if (_uid == null) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
    }
  }

  @override
  void initState() {
    super.initState();
    _saveFcmToken();

    // Handle foreground FCM messages — show snackbar
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (!mounted) return;
      final title = message.notification?.title ?? 'New Notification';
      final body  = message.notification?.body  ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              if (body.isNotEmpty) Text(body),
            ],
          ),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    final notifStream = FirebaseFirestore.instance
        .collection('notifications')
        .doc(_uid)
        .collection('items')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<QuerySnapshot>(
        stream: notifStream,
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          final unreadCount = docs.where((d) => d['isRead'] == false).length;

          return Column(
            children: [
              _buildHeader(context, unreadCount, docs),
              Expanded(
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : docs.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
                            itemCount: docs.length,
                            itemBuilder: (context, i) {
                              final doc  = docs[i];
                              final data = doc.data() as Map<String, dynamic>;
                              final type = data['type']?.toString() ?? '';
                              final isRead = data['isRead'] == true;

                              return _buildNotifTile(
                                docId:   doc.id,
                                title:   data['title']  ?? 'Notification',
                                body:    data['body']   ?? '',
                                time:    _timeAgo(data['createdAt']),
                                icon:    _getIcon(type),
                                color:   _getColor(type),
                                bgColor: _getBgColor(type),
                                isRead:  isRead,
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const BottomNav(selectedIndex: 2),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(
      BuildContext context,
      int unreadCount,
      List<QueryDocumentSnapshot> docs) {
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
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
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
                    Text('Notifications',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        )),
                    if (unreadCount > 0)
                      Text('$unreadCount unread',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.80),
                            fontWeight: FontWeight.w400,
                          )),
                  ],
                ),
              ),
              if (unreadCount > 0)
                GestureDetector(
                  onTap: () => _markAllRead(docs),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: Text('Mark all read',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        )),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Notification Tile ──────────────────────────────────────────────────────
  Widget _buildNotifTile({
    required String docId,
    required String title,
    required String body,
    required String time,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required bool isRead,
  }) {
    return GestureDetector(
      onTap: () => _markAsRead(docId), // marks as read on tap
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isRead ? AppColors.divider : color.withValues(alpha: 0.25),
            width: isRead ? 1 : 1.5,
          ),
          boxShadow: isRead ? [] : AppShadows.card,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: AppTextStyles.h3.copyWith(fontSize: 14)),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 8, top: 2),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(body,
                      style: AppTextStyles.small.copyWith(
                        height: 1.5,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w400,
                      )),
                  const SizedBox(height: 8),
                  Text(time,
                      style:
                          AppTextStyles.caption.copyWith(letterSpacing: 0.2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty State ────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              color: AppColors.cardBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.bellOff,
                color: AppColors.primary, size: 46),
          ),
          const SizedBox(height: 24),
          Text("You're all caught up!", style: AppTextStyles.h2),
          const SizedBox(height: 8),
          Text('New notifications will appear here.',
              style: AppTextStyles.bodyMuted),
        ],
      ),
    );
  }
}
