import 'package:intl/intl.dart';

import '../models/app_notification.dart';
import '../models/billing.dart';
import 'api_config.dart';
import 'api_service.dart';
import 'app_cache.dart';

class NotificationService {
  NotificationService._();

  static const _prefix = 'notifications:';
  static const _keyActive = 'notifications:active';
  static const _ttlActive = Duration(minutes: 2);
  static const _keyBilling = 'billing:portal_notifications';
  static const _ttlBilling = Duration(minutes: 5);
  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  static final DateFormat _date = DateFormat('d MMM yyyy');

  static Future<List<AppNotification>> getActiveNotifications({
    bool refresh = false,
  }) async {
    if (refresh) {
      AppCache.invalidatePrefix(_prefix);
      AppCache.invalidate(_keyBilling);
    }

    return AppCache.get<List<AppNotification>>(
      _keyActive,
      ttl: _ttlActive,
      loader: _fetchActiveNotifications,
    );
  }

  static Future<List<AppNotification>> _fetchActiveNotifications() async {
    final result = await ApiService.get<dynamic>(
      ApiConfig.notificationsEndpoint,
    );
    if (result.isSuccess && result.data != null) {
      final data = result.data;
      final rawList = data is Map
          ? data['notifications']
          : data is List
          ? data
          : <dynamic>[];

      if (rawList is List) {
        final notifications = rawList
            .whereType<Map>()
            .map(
              (json) =>
                  AppNotification.fromJson(Map<String, dynamic>.from(json)),
            )
            .toList();

        final billingNotifications = await _fetchBillingNotifications();
        return _mergeBillingNotifications(notifications, billingNotifications);
      }
    }

    final billingNotifications = await _fetchBillingNotifications();
    if (billingNotifications != null && billingNotifications.isNotEmpty) {
      return billingNotifications;
    }

    throw Exception(result.error ?? 'Failed to fetch notifications');
  }

  static Future<AppNotification> markRead(String id) async {
    final result = await ApiService.put<Map<String, dynamic>>(
      '${ApiConfig.notificationsEndpoint}/$id/read',
      body: {},
    );
    if (result.isSuccess && result.data != null) {
      AppCache.invalidatePrefix(_prefix);
      return AppNotification.fromJson(result.data!);
    }
    throw Exception(result.error ?? 'Failed to mark notification as read');
  }

  static Future<void> markAllRead() async {
    final result = await ApiService.put<Map<String, dynamic>>(
      '${ApiConfig.notificationsEndpoint}/read-all',
      body: {},
    );
    AppCache.invalidatePrefix(_prefix);
    if (!result.isSuccess) {
      throw Exception(
        result.error ?? 'Failed to mark all notifications as read',
      );
    }
  }

  static Future<List<AppNotification>?> _fetchBillingNotifications() async {
    return AppCache.get<List<AppNotification>?>(
      _keyBilling,
      ttl: _ttlBilling,
      loader: _loadBillingNotificationsFromApi,
    );
  }

  static Future<List<AppNotification>?>
  _loadBillingNotificationsFromApi() async {
    final result = await ApiService.get<BillingPortal>(
      ApiConfig.billingPortalEndpoint,
      fromJson: (json) => BillingPortal.fromJson(json as Map<String, dynamic>),
    );

    if (!result.isSuccess || result.data == null) return null;

    final portal = result.data!;
    final unit = portal.unit;
    final notifications = <AppNotification>[];

    PaymentSubmission? activeSubmission;
    PaymentSubmission? latestRejected;
    for (final submission in portal.paymentSubmissions) {
      if (activeSubmission == null && submission.isPending) {
        activeSubmission = submission;
      }
      if (latestRejected == null && submission.isRejected) {
        latestRejected = submission;
      }
    }

    if (activeSubmission != null) {
      final amount = _formatCurrency(activeSubmission.expectedAmount);
      notifications.add(
        AppNotification(
          unitId: unit.id,
          type: 'payment_proof_submitted',
          title: 'Payment verification pending',
          message:
              'Your proof for $amount is under review. The balance will update after superadmin verification.',
          status: 'active',
          severity: 'info',
          entityType: 'payment_submission',
          entityId: activeSubmission.id,
          triggeredAt: activeSubmission.submittedAt ?? DateTime.now(),
          metadata: {
            'submissionId': activeSubmission.id,
            'submissionNumber': activeSubmission.submissionNumber,
            'amount': activeSubmission.expectedAmount,
            'transactionReference': activeSubmission.transactionReference,
          },
        ),
      );
    } else if (latestRejected != null) {
      final amount = _formatCurrency(latestRejected.expectedAmount);
      notifications.add(
        AppNotification(
          unitId: unit.id,
          type: 'payment_rejected',
          title: 'Payment proof needs attention',
          message: latestRejected.rejectionReason == null
              ? 'Your proof for $amount was rejected. Please submit a new screenshot.'
              : 'Your proof for $amount was rejected: ${latestRejected.rejectionReason}',
          status: 'active',
          severity: 'danger',
          entityType: 'payment_submission',
          entityId: latestRejected.id,
          triggeredAt:
              latestRejected.reviewedAt ??
              latestRejected.submittedAt ??
              DateTime.now(),
          metadata: {
            'submissionId': latestRejected.id,
            'submissionNumber': latestRejected.submissionNumber,
            'amount': latestRejected.expectedAmount,
            'rejectionReason': latestRejected.rejectionReason,
          },
        ),
      );
    }

    final openBills =
        portal.paymentRows.where((row) => row.canSubmitProof).toList()
          ..sort((a, b) {
            final aTime = a.dueDate?.millisecondsSinceEpoch ?? 0;
            final bTime = b.dueDate?.millisecondsSinceEpoch ?? 0;
            return aTime.compareTo(bTime);
          });

    if (openBills.isNotEmpty) {
      final amount = openBills.fold<double>(
        0,
        (sum, row) => sum + row.displayAmount,
      );
      final earliestDue = openBills.first.dueDate;
      final dueText = earliestDue == null
          ? ''
          : ' Earliest due date: ${_formatDate(earliestDue)}.';
      notifications.add(
        AppNotification(
          unitId: unit.id,
          type: 'billing_due',
          title: 'Payment due',
          message:
              '${_formatCurrency(amount)} is pending across ${openBills.length} ${openBills.length == 1 ? 'invoice' : 'invoices'}.$dueText',
          status: 'active',
          severity: 'warning',
          entityType: 'billing_account',
          entityId: unit.id,
          triggeredAt: earliestDue ?? DateTime.now(),
          metadata: {
            'periodKey': 'account-balance',
            'amount': amount,
            'invoiceCount': openBills.length,
            'dueDate': earliestDue?.toIso8601String(),
            'unitName': unit.name,
          },
        ),
      );
    }

    notifications.sort((a, b) {
      final aTime = a.triggeredAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.triggeredAt?.millisecondsSinceEpoch ?? 0;
      return aTime.compareTo(bTime);
    });

    return notifications;
  }

  static List<AppNotification> _mergeBillingNotifications(
    List<AppNotification> notifications,
    List<AppNotification>? billingNotifications,
  ) {
    if (billingNotifications == null) return notifications;

    final currentBillingKeys = billingNotifications.map(_billingKey).toSet();
    final activeNotifications = notifications.where((notification) {
      return !_isBillingFallbackType(notification.type) ||
          currentBillingKeys.contains(_billingKey(notification));
    }).toList();
    final existingBillingKeys = activeNotifications
        .where((notification) => _isBillingFallbackType(notification.type))
        .map(_billingKey)
        .toSet();
    final missingBillingNotifications = billingNotifications
        .where(
          (notification) =>
              !existingBillingKeys.contains(_billingKey(notification)),
        )
        .toList();

    return [...missingBillingNotifications, ...activeNotifications];
  }

  static bool _isBillingFallbackType(String type) {
    return type == 'maintenance_due' ||
        type == 'billing_due' ||
        type == 'payment_proof_submitted' ||
        type == 'payment_rejected';
  }

  static String _billingKey(AppNotification notification) {
    return '${notification.type}:'
        '${notification.metadata['periodKey']?.toString() ?? notification.entityId ?? notification.message}';
  }

  static String _formatCurrency(double value) {
    return _currency.format(value);
  }

  static String _formatDate(DateTime value) {
    return _date.format(value.toLocal());
  }
}
