String normalizeRequestStatus(String rawStatus) {
  switch (rawStatus.toLowerCase()) {
    case 'pending':
      return 'pending_review';
    case 'in_progress':
      return 'processing';
    case 'ready':
      return 'ready_for_pickup';
    default:
      return rawStatus.toLowerCase();
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

bool isReturnedStatus(String rawStatus) {
  return normalizeRequestStatus(rawStatus) == 'returned';
}

bool isRejectedStatus(String rawStatus) {
  return normalizeRequestStatus(rawStatus) == 'rejected';
}

String requestStatusLabel(String rawStatus) {
  switch (normalizeRequestStatus(rawStatus)) {
    case 'submitted':
      return 'Submitted';
    case 'pending_review':
      return 'Pending Review';
    case 'processing':
      return 'Processing';
    case 'approved':
      return 'Approved';
    case 'ready_for_pickup':
      return 'Ready for Pick Up';
    case 'completed':
      return 'Completed';
    case 'returned':
      return 'Returned';
    case 'rejected':
      return 'Rejected';
    default:
      return rawStatus;
  }
}

List<String> requestStatusFilterValues(String filter) {
  switch (filter) {
    case 'Pending':
      return ['submitted', 'pending_review', 'pending'];
    case 'Processing':
      return [
        'processing',
        'in_progress',
        'approved',
        'ready_for_pickup',
        'ready',
      ];
    case 'Completed':
      return ['completed'];
    case 'Rejected':
      return ['rejected', 'returned'];
    default:
      return [];
  }
}