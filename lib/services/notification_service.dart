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

  static Future<List<AppNotification>?> _fetchBillingNotifications() async {
    final result = await ApiService.get<BillingPortal>(
      ApiConfig.billingPortalEndpoint,
      fromJson: (json) => BillingPortal.fromJson(json as Map<String, dynamic>),
    );

    if (!result.isSuccess || result.data == null) return null;

    final portal = result.data!;
    final unit = portal.unit;
    final notifications = <AppNotification>[];

    notifications.addAll(
      portal.pendingMaintenanceEntries.map((entry) {
        final amount = _formatCurrency(entry.amount);
        final dueText = entry.dueDate == null
            ? ''
            : ' due on ${_formatDate(entry.dueDate!)}';

        return AppNotification(
          unitId: unit.id,
          type: 'maintenance_due',
          title: 'Maintenance payment due',
          message:
              '${entry.label} of $amount$dueText is pending for ${unit.name}.',
          status: 'active',
          severity: 'info',
          entityType: 'maintenance_history',
          entityId: entry.id ?? entry.periodKey,
          triggeredAt: entry.dueDate ?? DateTime.now(),
          metadata: {
            'periodKey': entry.periodKey,
            'label': entry.label,
            'amount': entry.amount,
            'dueDate': entry.dueDate?.toIso8601String(),
            'unitName': unit.name,
          },
        );
      }),
    );

    final openBills = portal.paymentRows.where((row) {
      return !row.isPayment && !row.isPaid && row.displayAmount > 0;
    });

    notifications.addAll(
      openBills.map((row) {
        final amount = _formatCurrency(row.displayAmount);
        final dueText = row.dueDate == null
            ? ''
            : ' due on ${_formatDate(row.dueDate!)}';

        return AppNotification(
          unitId: unit.id,
          type: 'billing_due',
          title: 'Payment due',
          message: '${row.label} payment of $amount$dueText is pending.',
          status: 'active',
          severity: 'warning',
          entityType: 'billing_invoice',
          entityId: row.periodKey,
          triggeredAt: row.dueDate ?? DateTime.now(),
          metadata: {
            'periodKey': row.periodKey,
            'label': row.label,
            'amount': row.displayAmount,
            'dueDate': row.dueDate?.toIso8601String(),
            'unitName': unit.name,
          },
        );
      }),
    );

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
    return type == 'maintenance_due' || type == 'billing_due';
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
