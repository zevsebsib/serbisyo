import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState
    extends State<AdminNotificationsScreen> {
  bool   _loading      = true;
  String _filterType   = 'all';
  String _searchQuery  = '';
  int    _currentPage  = 0;
  static const int _pageSize = 10;

  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _allNotifs      = [];
  List<Map<String, dynamic>> _filteredNotifs = [];
  List<Map<String, dynamic>> _citizens       = [];

  final _typeFilters = <Map<String, dynamic>>[
    {'key': 'all',             'label': 'All',            'icon': Icons.notifications_rounded},
    {'key': 'status_update',   'label': 'Status Update',  'icon': Icons.update_rounded},
    {'key': 'missing_docs',    'label': 'Missing Docs',   'icon': Icons.folder_off_rounded},
    {'key': 'completed',       'label': 'Completed',      'icon': Icons.check_circle_rounded},
    {'key': 'manual',          'label': 'Manual',         'icon': Icons.send_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Load ───────────────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // Load citizens for dropdown in send dialog
      final citizenSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'citizen')
          .get();
      _citizens = citizenSnap.docs.map((d) => {
        'uid':      d.id,
        'fullName': d.data()['fullName'] ?? 'Citizen',
        'email':    d.data()['email'] ?? '',
      }).toList();

      // Load all notifications via collection group
      final notifSnap = await FirebaseFirestore.instance
          .collectionGroup('items')
          .orderBy('createdAt', descending: true)
          .limit(200)
          .get();

      // Build userId -> name map
      final Map<String, String> nameMap = {};
      for (final c in _citizens) {
        nameMap[c['uid'] as String] =
            c['fullName'] as String;
      }

      _allNotifs = notifSnap.docs.map((d) {
        final data   = d.data();
        final uid    = d.reference.parent.parent?.id ?? '';
        return {
          'id':        d.id,
          'uid':       uid,
          'citizen':   nameMap[uid] ?? 'Citizen',
          'title':     data['title'] ?? '',
          'body':      data['body'] ?? '',
          'type':      data['type'] ?? 'manual',
          'isRead':    data['isRead'] ?? false,
          'createdAt': data['createdAt'],
          'ref':       d.reference,
        };
      }).toList();

      _applyFilters();
    } catch (e) {
      debugPrint('Notif error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _applyFilters() {
    List<Map<String, dynamic>> result = _allNotifs;

    if (_filterType != 'all') {
      result = result
          .where((n) => n['type'] == _filterType)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((n) =>
        n['citizen'].toString().toLowerCase().contains(q) ||
        n['title'].toString().toLowerCase().contains(q) ||
        n['body'].toString().toLowerCase().contains(q)
      ).toList();
    }

    setState(() {
      _filteredNotifs = result;
      _currentPage    = 0;
    });
  }

  List<Map<String, dynamic>> get _paged {
    final start = _currentPage * _pageSize;
    final end   =
        (start + _pageSize).clamp(0, _filteredNotifs.length);
    if (start >= _filteredNotifs.length) return [];
    return _filteredNotifs.sublist(start, end);
  }

  int get _totalPages =>
      (_filteredNotifs.length / _pageSize).ceil();

  // ── Mark read/unread ───────────────────────────────────────────────────────
  Future<void> _toggleRead(Map<String, dynamic> n) async {
    final ref      = n['ref'] as DocumentReference;
    final isRead   = n['isRead'] as bool;
    await ref.update({'isRead': !isRead});
    setState(() => n['isRead'] = !isRead);
  }

  Future<void> _markAllRead() async {
    final batch = FirebaseFirestore.instance.batch();
    for (final n in _filteredNotifs) {
      if (!(n['isRead'] as bool)) {
        batch.update(
            n['ref'] as DocumentReference,
            {'isRead': true});
      }
    }
    await batch.commit();
    _loadData();
  }

  // ── Send manual notification ───────────────────────────────────────────────
  void _showSendDialog() {
    String? selectedUid;
    final titleCtrl = TextEditingController();
    final bodyCtrl  = TextEditingController();
    final formKey   = GlobalKey<FormState>();
    bool  sending   = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(28),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary
                            .withValues(alpha: 0.10),
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                      child: const Icon(
                          Icons.send_rounded,
                          color: AppColors.primary,
                          size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Send Notification',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color:
                                const Color(0xFF111111),
                          )),
                    ),
                    IconButton(
                      onPressed: () =>
                          Navigator.pop(ctx),
                      icon: const Icon(Icons.close,
                          size: 18,
                          color: AppColors.muted),
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // Recipient
                  _fieldLabel('Recipient'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FC),
                      borderRadius:
                          BorderRadius.circular(10),
                      border: Border.all(
                          color:
                              const Color(0xFFEEEEEE)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedUid,
                        isExpanded: true,
                        hint: Text(
                            'Select citizen...',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.muted)),
                        icon: const Icon(
                            Icons
                                .keyboard_arrow_down_rounded,
                            size: 16,
                            color: AppColors.muted),
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            color:
                                const Color(0xFF333333)),
                        items: _citizens.map((c) =>
                          DropdownMenuItem<String>(
                            value: c['uid'] as String,
                            child: Text(
                              '${c['fullName']} — ${c['email']}',
                              overflow:
                                  TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  fontSize: 13),
                            ),
                          )).toList(),
                        onChanged: (v) => setInner(
                            () => selectedUid = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Title
                  _fieldLabel('Title'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: titleCtrl,
                    style: GoogleFonts.inter(
                        fontSize: 13),
                    validator: (v) =>
                        v == null || v.isEmpty
                            ? 'Title is required'
                            : null,
                    decoration: _inputDeco(
                        'e.g. Your request has been updated'),
                  ),
                  const SizedBox(height: 14),

                  // Body
                  _fieldLabel('Message'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: bodyCtrl,
                    maxLines: 3,
                    style: GoogleFonts.inter(
                        fontSize: 13),
                    validator: (v) =>
                        v == null || v.isEmpty
                            ? 'Message is required'
                            : null,
                    decoration: _inputDeco(
                        'Enter notification message...'),
                  ),
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () =>
                            Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFFEEEEEE)),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      10)),
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12),
                        ),
                        child: Text('Cancel',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                            )),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: sending
                            ? null
                            : () async {
                                if (selectedUid == null) {
                                  _showSnack(
                                      'Please select a recipient',
                                      AppColors.warning);
                                  return;
                                }
                                if (!formKey.currentState!
                                    .validate()) {
                                  return;
                                }
                                setInner(
                                    () => sending = true);
                                try {
                                  await FirebaseFirestore
                                      .instance
                                      .collection('notifications')
                                      .doc(selectedUid)
                                      .collection('items')
                                      .add({
                                    'title':     titleCtrl.text.trim(),
                                    'body':      bodyCtrl.text.trim(),
                                    'type':      'manual',
                                    'isRead':    false,
                                    'createdAt': FieldValue.serverTimestamp(),
                                  });
                                  if (mounted) {
                                    Navigator.pop(ctx);
                                    _showSnack(
                                        'Notification sent ✓',
                                        AppColors.success);
                                    _loadData();
                                  }
                                } catch (e) {
                                  setInner(() =>
                                      sending = false);
                                  _showSnack(
                                      'Failed: $e',
                                      AppColors.danger);
                                }
                              },
                        icon: sending
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ))
                            : const Icon(
                                Icons.send_rounded,
                                size: 15),
                        label: Text(
                            sending
                                ? 'Sending...'
                                : 'Send',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            )),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          disabledBackgroundColor:
                              AppColors.primary
                                  .withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      10)),
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildFilterRow(),
          const SizedBox(height: 16),
          Expanded(child: _buildTable()),
          const SizedBox(height: 12),
          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final unread = _allNotifs
        .where((n) => !(n['isRead'] as bool))
        .length;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('Notifications',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111111),
                      letterSpacing: -0.5,
                    )),
                if (unread > 0) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: Text('$unread unread',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        )),
                  ),
                ],
              ]),
              const SizedBox(height: 4),
              Text(
                '${_allNotifs.length} total · ${_filteredNotifs.length} shown',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.muted),
              ),
            ],
          ),
        ),
        if (unread > 0)
          OutlinedButton.icon(
            onPressed: _markAllRead,
            icon: const Icon(
                Icons.done_all_rounded,
                size: 15),
            label: Text('Mark all read',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                )),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(
                  color: AppColors.primary),
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
            ),
          ),
        const SizedBox(width: 10),
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: const Color(0xFFEEEEEE)),
          ),
          child: IconButton(
            icon: const Icon(Icons.refresh_rounded,
                size: 18, color: AppColors.muted),
            onPressed: _loadData,
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: _showSendDialog,
          icon: const Icon(Icons.send_rounded,
              size: 15),
          label: Text('Send Notification',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              )),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(
                horizontal: 18, vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Search
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) {
                  _searchQuery = v;
                  _applyFilters();
                },
                style: GoogleFonts.inter(fontSize: 13),
                decoration: InputDecoration(
                  hintText:
                      'Search by citizen, title, message...',
                  hintStyle: GoogleFonts.inter(
                      color: AppColors.muted,
                      fontSize: 12),
                  prefixIcon: const Icon(Icons.search,
                      size: 16, color: AppColors.muted),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear,
                              size: 14,
                              color: AppColors.muted),
                          onPressed: () {
                            _searchCtrl.clear();
                            _searchQuery = '';
                            _applyFilters();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF7F8FC),
                  contentPadding:
                      const EdgeInsets.symmetric(
                          horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Color(0xFFEEEEEE)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Color(0xFFEEEEEE)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Type filters
          ..._typeFilters.map((f) {
            final sel = _filterType == f['key'];
            return GestureDetector(
              onTap: () {
                setState(
                    () => _filterType = f['key'] as String);
                _applyFilters();
              },
              child: AnimatedContainer(
                duration:
                    const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.primary
                      : const Color(0xFFF7F8FC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: sel
                        ? AppColors.primary
                        : const Color(0xFFEEEEEE),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(f['icon'] as IconData,
                        size: 13,
                        color: sel
                            ? Colors.white
                            : AppColors.muted),
                    const SizedBox(width: 5),
                    Text(f['label'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: sel
                              ? Colors.white
                              : AppColors.muted,
                        )),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTable() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(
              color: AppColors.primary));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF7F8FC),
              borderRadius: BorderRadius.only(
                topLeft:  Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(children: [
              _hCell('Citizen',   flex: 3),
              _hCell('Title',     flex: 3),
              _hCell('Message',   flex: 4),
              _hCell('Type',      flex: 2),
              _hCell('Date',      flex: 2),
              _hCell('Status',    flex: 2),
              _hCell('Actions',   flex: 1,
                  align: TextAlign.center),
            ]),
          ),
          const Divider(
              height: 1, color: Color(0xFFF0F0F0)),
          Expanded(
            child: _paged.isEmpty
                ? _buildEmpty()
                : ListView.separated(
                    itemCount: _paged.length,
                    separatorBuilder: (_, __) =>
                        const Divider(
                            height: 1,
                            color: Color(0xFFF5F5F5)),
                    itemBuilder: (_, i) =>
                        _buildRow(_paged[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(Map<String, dynamic> n) {
    final isRead   = n['isRead'] as bool;
    final type     = n['type'] as String;
    final typeConf = _typeConfig(type);

    return InkWell(
      onTap: () => _toggleRead(n),
      hoverColor: const Color(0xFFFFF7ED),
      child: Container(
        color: isRead
            ? Colors.transparent
            : AppColors.primary.withValues(alpha: 0.03),
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 14),
        child: Row(children: [
          // Citizen
          Expanded(
            flex: 3,
            child: Row(children: [
              if (!isRead)
                Container(
                  width: 6, height: 6,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              Expanded(
                child: Text(n['citizen'] as String,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isRead
                          ? FontWeight.w400
                          : FontWeight.w600,
                      color: const Color(0xFF222222),
                    )),
              ),
            ]),
          ),
          // Title
          Expanded(
            flex: 3,
            child: Text(n['title'] as String,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isRead
                      ? FontWeight.w400
                      : FontWeight.w600,
                  color: const Color(0xFF333333),
                )),
          ),
          // Body
          Expanded(
            flex: 4,
            child: Text(n['body'] as String,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.muted)),
          ),
          // Type badge
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (typeConf['color'] as Color)
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(typeConf['icon'] as IconData,
                      size: 10,
                      color: typeConf['color'] as Color),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                        typeConf['label'] as String,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color:
                              typeConf['color'] as Color,
                        )),
                  ),
                ],
              ),
            ),
          ),
          // Date
          Expanded(
            flex: 2,
            child: Text(
              _fmtTs(n['createdAt'] as Timestamp?),
              style: GoogleFonts.inter(
                  fontSize: 11, color: AppColors.muted),
            ),
          ),
          // Read/unread badge
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isRead
                    ? const Color(0xFFF5F5F5)
                    : const Color(0xFFEF4444)
                        .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isRead ? 'Read' : 'Unread',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isRead
                      ? AppColors.muted
                      : const Color(0xFFEF4444),
                ),
              ),
            ),
          ),
          // Toggle action
          Expanded(
            flex: 1,
            child: Tooltip(
              message: isRead
                  ? 'Mark unread'
                  : 'Mark read',
              child: InkWell(
                onTap: () => _toggleRead(n),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: (isRead
                            ? AppColors.muted
                            : AppColors.primary)
                        .withValues(alpha: 0.10),
                    borderRadius:
                        BorderRadius.circular(6),
                  ),
                  child: Icon(
                    isRead
                        ? Icons.mark_email_unread_rounded
                        : Icons.mark_email_read_rounded,
                    size: 14,
                    color: isRead
                        ? AppColors.muted
                        : AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_rounded,
              size: 48,
              color: AppColors.muted
                  .withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text('No notifications found',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              )),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    if (_totalPages <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Showing ${_currentPage * _pageSize + 1}–'
          '${(_currentPage * _pageSize + _paged.length)} '
          'of ${_filteredNotifs.length}',
          style: GoogleFonts.inter(
              fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(width: 20),
        _pageBtn(
          icon: Icons.chevron_left_rounded,
          enabled: _currentPage > 0,
          onTap: () =>
              setState(() => _currentPage--),
        ),
        const SizedBox(width: 6),
        ...List.generate(
            _totalPages.clamp(0, 6), (i) {
          final sel = i == _currentPage;
          return GestureDetector(
            onTap: () =>
                setState(() => _currentPage = i),
            child: AnimatedContainer(
              duration:
                  const Duration(milliseconds: 150),
              width: 32, height: 32,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: sel
                    ? AppColors.primary
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: sel
                      ? AppColors.primary
                      : const Color(0xFFEEEEEE),
                ),
              ),
              child: Center(
                child: Text('${i + 1}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: sel
                          ? Colors.white
                          : const Color(0xFF555555),
                    )),
              ),
            ),
          );
        }),
        const SizedBox(width: 4),
        _pageBtn(
          icon: Icons.chevron_right_rounded,
          enabled: _currentPage < _totalPages - 1,
          onTap: () =>
              setState(() => _currentPage++),
        ),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _hCell(String label,
      {int flex = 1,
      TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(label,
          textAlign: align,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF888888),
            letterSpacing: 0.5,
          )),
    );
  }

  Widget _pageBtn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: const Color(0xFFEEEEEE)),
        ),
        child: Icon(icon,
            size: 18,
            color: enabled
                ? const Color(0xFF444444)
                : AppColors.muted),
      ),
    );
  }

  Widget _fieldLabel(String label) => Text(label,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF333333),
      ));

  InputDecoration _inputDeco(String hint) =>
      InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
            color: AppColors.muted, fontSize: 12),
        filled: true,
        fillColor: const Color(0xFFF7F8FC),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
              color: Color(0xFFEEEEEE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
              color: Color(0xFFEEEEEE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
              color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
              color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
              color: Color(0xFFEF4444), width: 1.5),
        ),
      );

  Map<String, dynamic> _typeConfig(String type) {
    switch (type) {
      case 'status_update':
        return {
          'label': 'Status',
          'icon':  Icons.update_rounded,
          'color': const Color(0xFF3B82F6),
        };
      case 'missing_docs':
        return {
          'label': 'Missing Docs',
          'icon':  Icons.folder_off_rounded,
          'color': const Color(0xFFF59E0B),
        };
      case 'completed':
        return {
          'label': 'Completed',
          'icon':  Icons.check_circle_rounded,
          'color': const Color(0xFF10B981),
        };
      default:
        return {
          'label': 'Manual',
          'icon':  Icons.send_rounded,
          'color': AppColors.primary,
        };
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _fmtTs(Timestamp? ts) {
    if (ts == null) return '—';
    final d = ts.toDate();
    const mo = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${mo[d.month - 1]} ${d.day}, ${d.year}';
  }
}