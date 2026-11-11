import 'package:flutter/material.dart';
import 'package:oruma_app/core/theme/app_colors.dart';
import 'package:oruma_app/core/theme/app_radius.dart';
import 'package:oruma_app/core/theme/app_spacing.dart';
import 'package:oruma_app/screens/billing/billing_models.dart';
import 'package:oruma_app/screens/billing/billing_repository.dart';

// ============================================================================
// 1. SUMMARY CARD
// ============================================================================
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.summary,
    required this.repository,
    required this.onManagePlan,
    this.onPayNow,
  });

  final BillingStatsSummary summary;
  final BillingRepository repository;
  final VoidCallback onManagePlan;
  final VoidCallback? onPayNow;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkSurface1 : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB);
    final titleColor = isDark ? AppColors.darkText : const Color(0xFF111827);
    final subtitleColor = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Plan name + cycle & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${summary.planName} · ${summary.billingCycle}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: subtitleColor,
                  letterSpacing: -0.1,
                ),
              ),
              StatusPill(
                label: summary.status.toUpperCase(),
                bgColor: summary.status.toLowerCase() == 'active'
                    ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7))
                    : (isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7)),
                textColor: summary.status.toLowerCase() == 'active'
                    ? (isDark ? const Color(0xFF34D399) : const Color(0xFF15803D))
                    : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Row 2: Hero message
          if (!summary.hasDues)
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF16A34A),
                  size: 26,
                ),
                const SizedBox(width: 10),
                Text(
                  'No dues, all paid',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            )
          else
            Text(
              'Next payment ${repository.formatCurrency(summary.outstanding)} on ${repository.formatDate(summary.nextPaymentDate)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: titleColor,
                letterSpacing: -0.2,
              ),
            ),

          const SizedBox(height: 16),

          // Row 3: Action button (if dues) & "Manage plan >" link
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: onManagePlan,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Manage plan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
              if (summary.hasDues && onPayNow != null)
                FilledButton(
                  onPressed: onPayNow,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text(
                    'Pay now',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 2. BALANCE STRIP
// ============================================================================
class BalanceStrip extends StatelessWidget {
  const BalanceStrip({
    super.key,
    required this.summary,
    required this.repository,
  });

  final BillingStatsSummary summary;
  final BillingRepository repository;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkSurface1 : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB);
    final dividerColor = isDark ? const Color(0xFF273244) : const Color(0xFFE5E7EB);
    final labelColor = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);
    final valueColor = isDark ? AppColors.darkText : const Color(0xFF111827);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _StatColumn(
                label: 'Total paid',
                value: repository.formatCurrency(summary.totalPaid),
                labelColor: labelColor,
                valueColor: valueColor,
              ),
            ),
            VerticalDivider(color: dividerColor, thickness: 1, indent: 4, endIndent: 4),
            Expanded(
              child: _StatColumn(
                label: 'Outstanding',
                value: repository.formatCurrency(summary.outstanding),
                labelColor: labelColor,
                valueColor: summary.outstanding > 0 ? const Color(0xFFDC2626) : valueColor,
              ),
            ),
            VerticalDivider(color: dividerColor, thickness: 1, indent: 4, endIndent: 4),
            Expanded(
              child: _StatColumn(
                label: 'Upcoming',
                value: repository.formatCurrency(summary.upcoming),
                labelColor: labelColor,
                valueColor: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    required this.labelColor,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: labelColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: valueColor,
            letterSpacing: -0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ============================================================================
// 3. FILTER CHIPS (Google Pay Style with dropdown bottom sheet)
// ============================================================================
class FilterChips extends StatelessWidget {
  const FilterChips({
    super.key,
    required this.filter,
    required this.onFilterChanged,
  });

  final TransactionFilter filter;
  final ValueChanged<TransactionFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // 1. Type dropdown chip
          _FilterChipDropdown(
            label: filter.type == TransactionType.all
                ? 'Type'
                : 'Type: ${filter.type.label}',
            isActive: filter.type != TransactionType.all,
            isDark: isDark,
            onTap: () => _showTypePicker(context),
          ),
          const SizedBox(width: 8),

          // 2. Status dropdown chip
          _FilterChipDropdown(
            label: filter.status == TransactionStatus.all
                ? 'Status'
                : 'Status: ${filter.status.label}',
            isActive: filter.status != TransactionStatus.all,
            isDark: isDark,
            onTap: () => _showStatusPicker(context),
          ),
          const SizedBox(width: 8),

          // 3. Date dropdown chip
          _FilterChipDropdown(
            label: filter.dateFilter == DateFilter.all
                ? 'Date'
                : filter.dateFilter.label,
            isActive: filter.dateFilter != DateFilter.all,
            isDark: isDark,
            onTap: () => _showDatePicker(context),
          ),
          const SizedBox(width: 8),

          // Clear filters pill
          if (filter.isFiltered)
            InkWell(
              onTap: () {
                onFilterChanged(const TransactionFilter());
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF273244) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.close,
                      size: 14,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF4B5563),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Clear filters',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF4B5563),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showTypePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                _BottomSheetHandle(),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Filter by Type',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                ...TransactionType.values.map((type) {
                  final isSelected = filter.type == type;
                  return ListTile(
                    dense: true,
                    leading: Icon(type.icon, color: isSelected ? AppColors.primary : null),
                    title: Text(type.label, style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
                    trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      onFilterChanged(filter.copyWith(type: type));
                    },
                  );
                }),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showStatusPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                _BottomSheetHandle(),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Filter by Status',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                ...TransactionStatus.values.map((status) {
                  final isSelected = filter.status == status;
                  return ListTile(
                    dense: true,
                    title: Text(status.label, style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
                    trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      onFilterChanged(filter.copyWith(status: status));
                    },
                  );
                }),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDatePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                _BottomSheetHandle(),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Filter by Date',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                ...DateFilter.values.map((df) {
                  final isSelected = filter.dateFilter == df;
                  return ListTile(
                    dense: true,
                    title: Text(df == DateFilter.all ? 'All time' : df.label,
                        style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
                    trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
                    onTap: () async {
                      Navigator.pop(ctx);
                      if (df == DateFilter.custom) {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2030),
                          initialDateRange: filter.customFrom != null && filter.customTo != null
                              ? DateTimeRange(start: filter.customFrom!, end: filter.customTo!)
                              : null,
                        );
                        if (picked != null) {
                          onFilterChanged(
                            filter.copyWith(
                              dateFilter: DateFilter.custom,
                              customFrom: picked.start,
                              customTo: picked.end,
                            ),
                          );
                        }
                      } else {
                        onFilterChanged(
                          filter.copyWith(
                            dateFilter: df,
                            clearCustomDates: true,
                          ),
                        );
                      }
                    },
                  );
                }),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FilterChipDropdown extends StatelessWidget {
  const _FilterChipDropdown({
    required this.label,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = isActive
        ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF))
        : (isDark ? AppColors.darkSurface1 : Colors.white);
    final borderColor = isActive
        ? AppColors.primary
        : (isDark ? AppColors.darkBorder : const Color(0xFFD1D5DB));
    final textColor = isActive
        ? AppColors.primary
        : (isDark ? AppColors.darkText : const Color(0xFF374151));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: isActive ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: textColor,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: textColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomSheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ============================================================================
// 4. MONTH HEADER (Sticky section header with month total)
// ============================================================================
class MonthHeader extends StatelessWidget {
  const MonthHeader({
    super.key,
    required this.monthLabel,
    required this.monthTotal,
    required this.repository,
  });

  final String monthLabel;
  final double monthTotal;
  final BillingRepository repository;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? AppColors.darkText : const Color(0xFF111827);
    final totalColor = isDark ? AppColors.darkTextSecondary : const Color(0xFF4B5563);

    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12, left: 4, right: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            monthLabel,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: labelColor,
              letterSpacing: -0.2,
            ),
          ),
          Text(
            repository.formatCurrency(monthTotal),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: totalColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 5. PAYMENT ROW (Google Pay style with circular tinted icon)
// ============================================================================
class PaymentRow extends StatelessWidget {
  const PaymentRow({
    super.key,
    required this.transaction,
    required this.repository,
    required this.onTap,
  });

  final BillingTransaction transaction;
  final BillingRepository repository;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? AppColors.darkText : const Color(0xFF111827);
    final dateColor = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);

    final isOffer = transaction.isOffer;
    final isClientPayment = transaction.isClientPayment;
    final formattedAmount = isOffer
        ? repository.formatCurrency(transaction.amount, isNegative: true)
        : repository.formatCurrency(transaction.amount);

    final Color iconBg;
    final Color iconColor;
    final IconData iconData;

    if (isOffer) {
      iconBg = isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
      iconColor = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
      iconData = Icons.local_offer_outlined;
    } else if (isClientPayment) {
      // Light green styling for paid payment entries by client
      iconBg = isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7);
      iconColor = isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
      iconData = Icons.check_circle_outlined;
    } else {
      iconBg = transaction.type.bgTint(isDark);
      iconColor = transaction.type.iconColor(isDark);
      iconData = transaction.type.icon;
    }

    final Color amountColor;
    if (isOffer) {
      amountColor = const Color(0xFF16A34A);
    } else if (isClientPayment) {
      amountColor = isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
    } else {
      amountColor = titleColor;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Circular tinted icon by type
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  iconData,
                  size: 22,
                  color: iconColor,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Middle: Title + Date below in muted grey
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    transaction.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    repository.formatDate(transaction.paidAt ?? transaction.dueDate),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: dateColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Right: Amount + Optional Status Pill (Pending, Under review, Failed ONLY - Never for Paid)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formattedAmount,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: amountColor,
                  ),
                ),
                if (!isOffer && transaction.status.shouldShowPill) ...[
                  const SizedBox(height: 4),
                  StatusPill(
                    label: transaction.status.label,
                    bgColor: transaction.status.pillBg(isDark),
                    textColor: transaction.status.pillText(isDark),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 6. STATUS PILL
// ============================================================================
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.bgColor,
    required this.textColor,
  });

  final String label;
  final Color bgColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ============================================================================
// 7. RECEIPT DETAIL SHEET (Screen 2: Receipt / Invoice Detail)
// ============================================================================
class ReceiptDetailSheet extends StatelessWidget {
  const ReceiptDetailSheet({
    super.key,
    required this.transaction,
    required this.repository,
  });

  final BillingTransaction transaction;
  final BillingRepository repository;

  static void show(BuildContext context, BillingTransaction transaction, BillingRepository repository) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReceiptDetailSheet(
        transaction: transaction,
        repository: repository,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? AppColors.darkSurface : Colors.white;
    final cardBg = isDark ? AppColors.darkSurface1 : const Color(0xFFF9FAFB);
    final borderColor = isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB);
    final titleColor = isDark ? AppColors.darkText : const Color(0xFF111827);
    final subtitleColor = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);

    final isOffer = transaction.isOffer;
    final formattedAmount = isOffer
        ? repository.formatCurrency(transaction.amount, isNegative: true)
        : repository.formatCurrency(transaction.amount);

    final hasOffer = transaction.offerAmount > 0;
    final planAmount = transaction.planAmount ?? transaction.amount;
    final netPayable = transaction.netPayable ?? (planAmount - transaction.offerAmount);
    final paidAmount = transaction.paidAmount ?? (transaction.status == TransactionStatus.paid ? transaction.amount : 0.0);
    final balance = transaction.balance ?? (transaction.status == TransactionStatus.paid ? 0.0 : transaction.amount);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          _BottomSheetHandle(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top: Amount and Status Pill
                  Center(
                    child: Column(
                      children: [
                        Text(
                          formattedAmount,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: isOffer
                                ? const Color(0xFF16A34A)
                                : (transaction.isClientPayment
                                    ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A))
                                    : titleColor),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          transaction.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: subtitleColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        StatusPill(
                          label: transaction.status.label.toUpperCase(),
                          bgColor: transaction.status.pillBg(isDark),
                          textColor: transaction.status.pillText(isDark),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Breakdown: Plan amount → Offer applied (−₹) → Net payable → Paid → Balance
                  Text(
                    'BILLING BREAKDOWN',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: subtitleColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      children: [
                        _BreakdownRow('Plan amount', repository.formatCurrency(planAmount)),
                        if (hasOffer) ...[
                          const SizedBox(height: 8),
                          _BreakdownRow(
                            'Offer applied',
                            repository.formatCurrency(transaction.offerAmount, isNegative: true),
                            valueColor: const Color(0xFF16A34A),
                          ),
                        ],
                        const Divider(height: 16),
                        _BreakdownRow('Net payable', repository.formatCurrency(netPayable), isBold: true),
                        const SizedBox(height: 8),
                        _BreakdownRow('Paid', repository.formatCurrency(paidAmount)),
                        const SizedBox(height: 8),
                        _BreakdownRow(
                          'Balance',
                          repository.formatCurrency(balance),
                          valueColor: balance > 0 ? const Color(0xFFDC2626) : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Details: Payment date, payment method, invoice number, note
                  Text(
                    'DETAILS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: subtitleColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      children: [
                        _DetailItem(
                          label: 'Payment date',
                          value: repository.formatDate(transaction.paidAt ?? transaction.dueDate),
                        ),
                        if (transaction.invoiceNo != null) ...[
                          const Divider(height: 16),
                          _DetailItem(label: 'Invoice number', value: transaction.invoiceNo!),
                        ],
                        if (transaction.method != null) ...[
                          const Divider(height: 16),
                          _DetailItem(label: 'Payment method', value: transaction.method!),
                        ],
                        if ((transaction.note ?? '').isNotEmpty) ...[
                          const Divider(height: 16),
                          _DetailItem(label: 'Note / Reason', value: transaction.note!),
                        ],
                      ],
                    ),
                  ),

                  // Verification Timeline Tracker (if under review)
                  if (transaction.status == TransactionStatus.underReview || transaction.timeline != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      'VERIFICATION STATUS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: subtitleColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TimelineTracker(timeline: transaction.timeline ?? [
                            TimelineStep(step: 'submitted', label: 'Submitted', completed: true),
                            TimelineStep(step: 'under_review', label: 'Under review', completed: false, isCurrent: true),
                            TimelineStep(step: 'approved', label: 'Approved', completed: false),
                          ]),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline, size: 16, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'The outstanding balance changes only after payment proof is approved.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: subtitleColor,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Bottom Buttons: Download PDF and Share
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Invoice link copied to clipboard')),
                            );
                          },
                          icon: const Icon(Icons.share_outlined, size: 18),
                          label: const Text('Share'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Downloading invoice ${transaction.invoiceNo ?? ''}...')),
                            );
                          },
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text('Download PDF'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow(this.label, this.value, {this.valueColor, this.isBold = false});

  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark ? AppColors.darkText : const Color(0xFF111827);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: valueColor ?? defaultColor,
          ),
        ),
      ],
    );
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkText : const Color(0xFF111827),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineTracker extends StatelessWidget {
  const _TimelineTracker({required this.timeline});

  final List<TimelineStep> timeline;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(timeline.length * 2 - 1, (index) {
        if (index.isOdd) {
          final stepBefore = timeline[index ~/ 2];
          return Expanded(
            child: Container(
              height: 2,
              color: stepBefore.completed ? AppColors.primary : Colors.grey.withOpacity(0.3),
            ),
          );
        }

        final step = timeline[index ~/ 2];
        final isCompleted = step.completed;
        final isCurrent = step.isCurrent;

        return Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.primary
                    : (isCurrent ? const Color(0xFFDBEAFE) : Colors.grey.withOpacity(0.2)),
                shape: BoxShape.circle,
                border: isCurrent ? Border.all(color: AppColors.primary, width: 2) : null,
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : (isCurrent
                        ? Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              step.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isCurrent || isCompleted ? FontWeight.w600 : FontWeight.w400,
                color: isCurrent || isCompleted ? AppColors.primary : Colors.grey,
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ============================================================================
// 8. PLAN & SUBSCRIPTION SCREEN (Screen 3: opened from "Manage plan >")
// ============================================================================
class PlanSubscriptionScreen extends StatefulWidget {
  const PlanSubscriptionScreen({super.key});

  @override
  State<PlanSubscriptionScreen> createState() => _PlanSubscriptionScreenState();
}

class _PlanSubscriptionScreenState extends State<PlanSubscriptionScreen> {
  bool _isYearly = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? AppColors.darkBackground : AppColors.background;
    final cardBg = isDark ? AppColors.darkSurface1 : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB);
    final titleColor = isDark ? AppColors.darkText : const Color(0xFF111827);
    final subtitleColor = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text('Plan & Subscription', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        elevation: 0,
        backgroundColor: scaffoldBg,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Plan Card: name, price, cycle, start date, next renewal, status
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CURRENT PLAN',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: subtitleColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Clinical Pro',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                      StatusPill(
                        label: 'ACTIVE',
                        bgColor: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
                        textColor: isDark ? const Color(0xFF34D399) : const Color(0xFF15803D),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SubscriptionInfo(label: 'Price & Cycle', value: '₹9,999 / year'),
                      _SubscriptionInfo(label: 'Start Date', value: '1 Jan 2026'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SubscriptionInfo(label: 'Next Renewal', value: '1 Jan 2028'),
                      _SubscriptionInfo(label: 'Access Duration', value: '2 Years Prepaid'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Plan features/modules as an expandable list
            Text(
              'INCLUDED FEATURES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: subtitleColor,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: Column(
                  children: [
                    _FeatureAccordion(
                      title: 'Patient & Clinical Care',
                      subtitle: 'Records, nurse visits & reports',
                      features: const [
                        'Patient registry & bed-bound tracking',
                        'Nurse & doctor clinical home visit records',
                        'NHC assessment form & automated PDF exports',
                        'Patient history & discharge summary',
                      ],
                    ),
                    const Divider(height: 1),
                    _FeatureAccordion(
                      title: 'Pharmacy & Stock Distribution',
                      subtitle: 'Medicine registers & consumption',
                      features: const [
                        'Medicine master catalog & inventory entries',
                        'Patient medication dispensing & dosages',
                        'Low stock alerts & consumption reports',
                      ],
                    ),
                    const Divider(height: 1),
                    _FeatureAccordion(
                      title: 'Operations & Volunteer Network',
                      subtitle: 'Field team coordination & assets',
                      features: const [
                        'Volunteer directory & availability requests',
                        'Equipment inventory (Oxygen, Hospital beds)',
                        'Equipment lending tracking to patients',
                        'LSG ward single source mapping',
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Compare Plans with Billing Cycle Switch (Monthly / Yearly)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'COMPARE PLANS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: subtitleColor,
                    letterSpacing: 0.5,
                  ),
                ),
                // Billing cycle switch
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    children: [
                      _CycleSwitchTab(
                        label: 'Monthly',
                        isSelected: !_isYearly,
                        onTap: () => setState(() => _isYearly = false),
                      ),
                      _CycleSwitchTab(
                        label: 'Yearly · Save 17%',
                        isSelected: _isYearly,
                        isHighlight: true,
                        onTap: () => setState(() => _isYearly = true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Plan 1: Operations Plus
            _PlanComparisonCard(
              name: 'Operations Plus',
              monthlyPrice: '₹599 / month',
              yearlyPrice: '₹5,999 / year',
              description: 'Centres managing field work, volunteer activities, and equipment assets.',
              features: const [
                'Patient management & field visits',
                'Volunteer coordinator directory',
                'Equipment tracking & distribution',
              ],
              isYearly: _isYearly,
              isCurrent: false,
              onRequestUpgrade: () => _showUpgradeDialog(context, 'Operations Plus'),
            ),
            const SizedBox(height: 12),

            // Plan 2: Clinical Pro (Current)
            _PlanComparisonCard(
              name: 'Clinical Pro',
              monthlyPrice: '₹999 / month',
              yearlyPrice: '₹9,999 / year',
              description: 'Centres doing regular nurse clinical documentation and medicine management.',
              features: const [
                'All features in Operations Plus',
                'Clinical NHC block & automated PDF reports',
                'Medicine stock & dispensary logs',
                'Priority support & data backups',
              ],
              isYearly: _isYearly,
              isCurrent: true,
              onRequestUpgrade: null,
            ),
            const SizedBox(height: 12),

            // Plan 3: Complete Suite
            _PlanComparisonCard(
              name: 'Complete Suite',
              monthlyPrice: '₹1,399 / month',
              yearlyPrice: '₹13,999 / year',
              description: 'Larger units with multi-ward decentralization, multiple nurses, and advanced analytics.',
              features: const [
                'All features in Clinical Pro',
                'Multi-village & multi-ward restriction gates',
                'Custom report exports & audit logging',
                'Dedicated onboarding manager',
              ],
              isYearly: _isYearly,
              isCurrent: false,
              onRequestUpgrade: () => _showUpgradeDialog(context, 'Complete Suite'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context, String targetPlan) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Upgrade to $targetPlan'),
        content: Text(
          'Would you like to send an enquiry to upgrade this unit to the $targetPlan plan? Our team will activate it and adjust your billing cycle.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Upgrade request for $targetPlan submitted successfully!')),
              );
            },
            child: const Text('Send request'),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionInfo extends StatelessWidget {
  const _SubscriptionInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkText : const Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}

class _FeatureAccordion extends StatelessWidget {
  const _FeatureAccordion({
    required this.title,
    required this.subtitle,
    required this.features,
  });

  final String title;
  final String subtitle;
  final List<String> features;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ExpansionTile(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkText : const Color(0xFF111827),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
        ),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: features
          .map(
            (feat) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF16A34A)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      feat,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkText : const Color(0xFF374151),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _CycleSwitchTab extends StatelessWidget {
  const _CycleSwitchTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isHighlight = false,
  });

  final String label;
  final bool isSelected;
  final bool isHighlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (isHighlight ? const Color(0xFF15803D) : const Color(0xFF111827))
                : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

class _PlanComparisonCard extends StatelessWidget {
  const _PlanComparisonCard({
    required this.name,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.description,
    required this.features,
    required this.isYearly,
    required this.isCurrent,
    this.onRequestUpgrade,
  });

  final String name;
  final String monthlyPrice;
  final String yearlyPrice;
  final String description;
  final List<String> features;
  final bool isYearly;
  final bool isCurrent;
  final VoidCallback? onRequestUpgrade;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkSurface1 : Colors.white;
    final borderColor = isCurrent
        ? AppColors.primary
        : (isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB));
    final titleColor = isDark ? AppColors.darkText : const Color(0xFF111827);
    final subtitleColor = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isCurrent ? 2 : 1),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              if (isCurrent)
                StatusPill(
                  label: 'CURRENT',
                  bgColor: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
                  textColor: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isYearly ? yearlyPrice : monthlyPrice,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: subtitleColor,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...features.map(
            (feat) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  const Icon(Icons.check, size: 16, color: Color(0xFF16A34A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feat,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkText : const Color(0xFF374151),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isCurrent && onRequestUpgrade != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onRequestUpgrade,
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: AppColors.primary),
                ),
                child: const Text(
                  'Request upgrade',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// 9. EMPTY STATE
// ============================================================================
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.isFiltered,
    required this.onClearFilters,
  });

  final bool isFiltered;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? AppColors.darkText : const Color(0xFF111827);
    final subtitleColor = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              isFiltered ? 'No payments found' : 'No payments yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isFiltered
                  ? 'Try changing your active filters or clear search terms.'
                  : 'Billing invoices and payment records will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: subtitleColor,
              ),
            ),
            if (isFiltered) ...[
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onClearFilters,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 10. BILLING SKELETON
// ============================================================================
class BillingSkeleton extends StatefulWidget {
  const BillingSkeleton({super.key});

  @override
  State<BillingSkeleton> createState() => _BillingSkeletonState();
}

class _BillingSkeletonState extends State<BillingSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE5E7EB);
    final highlightColor = isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final color = Color.lerp(baseColor, highlightColor, _controller.value)!;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary card skeleton
              Container(
                height: 140,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 16),

              // Balance strip skeleton
              Container(
                height: 70,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(height: 20),

              // Filter chips skeleton
              Row(
                children: List.generate(
                  3,
                  (index) => Container(
                    width: 80,
                    height: 36,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Month header skeleton
              Container(
                width: 140,
                height: 20,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),

              // Rows skeleton
              ...List.generate(
                4,
                (index) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 180,
                              height: 16,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: 90,
                              height: 12,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 60,
                        height: 16,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

