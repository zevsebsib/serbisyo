import 'package:flutter/material.dart';

/// Normalizes canonical and legacy status values used across admin screens.
String normalizeRequestStatus(String rawStatus) {
  final status = rawStatus.trim().toLowerCase();
  switch (status) {
    case 'pending':
      return 'pending_review';
    case 'in_progress':
      return 'processing';
    case 'ready':
      return 'ready_for_pickup';
    default:
      return status;
  }
}

bool isPendingStatus(String rawStatus) {
  final status = normalizeRequestStatus(rawStatus);
  return status == 'submitted' || status == 'pending_review';
}

bool isProcessingStatus(String rawStatus) {
  final status = normalizeRequestStatus(rawStatus);
  return status == 'processing' ||
      status == 'approved' ||
      status == 'ready_for_pickup';
}

bool isCompletedStatus(String rawStatus) {
  return normalizeRequestStatus(rawStatus) == 'completed';
}

bool isReturnedOrRejectedStatus(String rawStatus) {
  final status = normalizeRequestStatus(rawStatus);
  return status == 'returned' || status == 'rejected';
}

bool matchesStatusFilter(String rawStatus, String selectedFilter) {
  if (selectedFilter == 'all') return true;
  return normalizeRequestStatus(rawStatus) ==
      normalizeRequestStatus(selectedFilter);
}

/// Unified status style helper for all admin screens.
/// Provides consistent label, color, and icon for any request status.
/// Handles both singular and grouped status values.
Map<String, dynamic> getStatusStyle(String status) {
  switch (status) {
    // ── Submitted ──────────────────────────────────────────────────────────
    case 'submitted':
      return {
        'label': 'Submitted',
        'color': const Color(0xFF5C6BC0),
        'icon': Icons.send_rounded,
      };

    // ── Pending / Pending Review ───────────────────────────────────────────
    case 'pending_review':
    case 'pending':
      return {
        'label': 'Pending Review',
        'color': const Color(0xFFF59E0B),
        'icon': Icons.hourglass_empty_rounded,
      };

    // ── Processing / In Progress ───────────────────────────────────────────
    case 'processing':
    case 'in_progress':
      return {
        'label': 'Processing',
        'color': const Color(0xFF3B82F6),
        'icon': Icons.sync_rounded,
      };

    // ── Approved ───────────────────────────────────────────────────────────
    case 'approved':
      return {
        'label': 'Approved',
        'color': const Color(0xFF8B5CF6),
        'icon': Icons.thumb_up_rounded,
      };

    // ── Ready for Pickup ───────────────────────────────────────────────────
    case 'ready_for_pickup':
    case 'ready':
      return {
        'label': 'Ready for Pick Up',
        'color': const Color(0xFFFF9200),
        'icon': Icons.inventory_rounded,
      };

    // ── Completed ──────────────────────────────────────────────────────────
    case 'completed':
      return {
        'label': 'Completed',
        'color': const Color(0xFF10B981),
        'icon': Icons.check_circle_rounded,
      };

    // ── Returned ───────────────────────────────────────────────────────────
    case 'returned':
      return {
        'label': 'Returned',
        'color': const Color(0xFFF97316),
        'icon': Icons.undo_rounded,
      };

    // ── Rejected ───────────────────────────────────────────────────────────
    case 'rejected':
      return {
        'label': 'Rejected',
        'color': const Color(0xFFEF4444),
        'icon': Icons.cancel_rounded,
      };

    // ── Default ────────────────────────────────────────────────────────────
    default:
      return {
        'label': 'Submitted',
        'color': const Color(0xFF5C6BC0),
        'icon': Icons.send_rounded,
      };
  }
}
