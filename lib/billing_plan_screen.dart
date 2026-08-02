import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/models/billing.dart';
import 'package:oruma_app/services/billing_service.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';
import 'package:url_launcher/url_launcher.dart';

const _billingAccent = AppColors.primary;
const _billingAccentSoft = AppColors.primaryLight;

class BillingPlanScreen extends StatefulWidget {
  const BillingPlanScreen({super.key});

  @override
  State<BillingPlanScreen> createState() => _BillingPlanScreenState();
}

class _BillingPlanScreenState extends State<BillingPlanScreen> {
  final BillingService _billingService = const BillingService();
  final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  final DateFormat _date = DateFormat('d MMM yyyy');

  BillingPortal? _portal;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBilling();
  }

  Future<void> _loadBilling() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _billingService.fetchBillingPortal();
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (result.isSuccess && result.data != null) {
        _portal = result.data;
      } else {
        _error = result.error ?? 'Unable to load billing details.';
      }
    });
  }

  Future<void> _openPlanPage() async {
    final uri = Uri.parse('https://api-erp-palliative.osperb.com/plan');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open plan page'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      isDense: true,
      labelText: label,
      prefixIcon: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.all(6),
        decoration: const BoxDecoration(
          color: _billingAccentSoft,
          borderRadius: AppRadius.sm,
        ),
        child: Icon(icon, color: _billingAccent, size: 20),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 50, minHeight: 50),
      filled: true,
      fillColor: AppColors.surface1,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      border: const OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: BorderSide(color: _billingAccent, width: 1.4),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: BorderSide(color: AppColors.danger, width: 1.4),
      ),
    );
  }

  Future<void> _showUpgradeSheet(BillingPlan plan) async {
    final portal = _portal;
    if (portal == null) return;

    final controller = TextEditingController(
      text: portal.unit.contactPhone ?? '',
    );
    final formKey = GlobalKey<FormState>();
    // Capture the parent's context/scaffold messenger before the sheet opens,
    // so we can safely use them after the sheet is dismissed.
    final parentContext = context;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        // submitting is kept local to the sheet's StatefulBuilder only.
        bool submitting = false;

        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> submit() async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final navigator = Navigator.of(sheetContext);
              final messenger = ScaffoldMessenger.of(parentContext);
              setSheetState(() => submitting = true);
              final result = await _billingService.createPlanEnquiry(
                selectedPlanId: plan.id,
                contactNumber: controller.text.trim(),
              );
              // Pop the sheet first, then show the snackbar on the parent.
              if (navigator.canPop()) {
                navigator.pop();
              }
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    result.isSuccess
                        ? 'Upgrade enquiry sent to Palliative App team.'
                        : result.error ?? 'Failed to send enquiry.',
                  ),
                  backgroundColor: result.isSuccess
                      ? AppColors.success
                      : AppColors.danger,
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Material(
                color: AppColors.surfaceModal,
                borderRadius: AppRadius.sheet,
                clipBehavior: Clip.antiAlias,
                child: Form(
                  key: formKey,
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 42,
                              height: 4,
                              margin: const EdgeInsets.only(
                                bottom: AppSpacing.lg,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.borderStrong,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              const _IconTile(
                                icon: Icons.workspace_premium_outlined,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  'Request ${plan.name}',
                                  style: Theme.of(
                                    sheetContext,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'We will contact you to confirm pricing, modules, and migration needs.',
                            style: Theme.of(sheetContext).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.45,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          TextFormField(
                            controller: controller,
                            keyboardType: TextInputType.phone,
                            decoration: _inputDecoration(
                              label: 'Contact number',
                              icon: Icons.phone_outlined,
                            ),
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'Contact number is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppPrimaryButton(
                            label: 'Create enquiry',
                            icon: Icons.send_outlined,
                            fullWidth: true,
                            loading: submitting,
                            onPressed: submitting ? null : submit,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveAppScaffold(
      backgroundColor: AppColors.background,
      contentMaxWidth: 980,
      appBar: AppBar(
        toolbarHeight: 76,
        titleSpacing: AppSpacing.lg,
        title: Text(
          'Billing & Plan',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: AppListSkeleton(itemCount: 5),
      );
    }

    if (_error != null || _portal == null) {
      return _ErrorState(
        message: _error ?? 'Billing details are not available.',
        onRetry: _loadBilling,
      );
    }

    final portal = _portal!;
    return RefreshIndicator(
      onRefresh: _loadBilling,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          _CurrentPlanCard(
            portal: portal,
            currency: _money,
            date: _formatDate,
            onOpenPlanPage: _openPlanPage,
          ),
          if (portal.pendingMaintenanceEntries.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _MaintenanceDueBanner(
              entries: portal.pendingMaintenanceEntries,
              currency: _money,
              date: _formatDate,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          _SummaryGrid(
            summary: portal.summary,
            currency: _money,
            date: _formatDate,
          ),
          const SizedBox(height: AppSpacing.sm),
          _PlansSection(
            plans: portal.plans,
            currentPlanId: portal.currentPlan?.id ?? portal.unit.planId,
            currency: _money,
            featureLabel: _featureLabel,
            onUpgrade: _showUpgradeSheet,
          ),
          const SizedBox(height: AppSpacing.sm),
          _SubscriptionSection(portal: portal, date: _formatDate),
          const SizedBox(height: AppSpacing.sm),
          _PlanDetailsSection(
            plan: portal.currentPlan,
            featureLabel: _featureLabel,
          ),
          const SizedBox(height: AppSpacing.sm),
          _MaintenanceSection(
            entries: portal.maintenanceHistory,
            currency: _money,
            date: _formatDate,
            onEntryTap: _showMaintenanceDetails,
          ),
          const SizedBox(height: AppSpacing.sm),
          _PaymentSection(
            rows: portal.paymentRows,
            currency: _money,
            date: _formatDate,
            onRowTap: _showPaymentDetails,
          ),
          const SizedBox(height: AppSpacing.sm),
          _BillingSummarySection(
            summary: portal.summary,
            currency: _money,
            date: _formatDate,
          ),
        ],
      ),
    );
  }

  String _money(double value) => _currency.format(value);

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    return _date.format(value.toLocal());
  }

  void _showMaintenanceDetails(MaintenanceHistoryEntry entry) {
    _showBillingDetailsSheet(
      icon: Icons.home_repair_service_outlined,
      title: entry.label,
      subtitle: 'Maintenance record',
      badge: entry.status,
      details: [
        _BillingDetail('Amount', _money(entry.amount)),
        _BillingDetail('Due date', _formatDate(entry.dueDate)),
        _BillingDetail('Status', entry.status),
        if ((entry.notes ?? '').isNotEmpty)
          _BillingDetail('Notes', entry.notes!),
      ],
    );
  }

  void _showPaymentDetails(PaymentHistoryRow row) {
    final isPayment = row.isPayment;
    _showBillingDetailsSheet(
      icon: isPayment ? Icons.payments_outlined : Icons.receipt_long_outlined,
      title: row.label,
      subtitle: isPayment ? 'Payment record' : 'Invoice record',
      badge: row.status,
      details: [
        _BillingDetail('Type', isPayment ? 'Payment' : 'Invoice'),
        _BillingDetail('Amount', _money(row.amount)),
        if (!isPayment) _BillingDetail('Paid amount', _money(row.paidAmount)),
        if (!isPayment) _BillingDetail('Remaining', _money(row.displayAmount)),
        _BillingDetail('Due date', _formatDate(row.dueDate)),
        if (row.paidAt != null)
          _BillingDetail('Paid on', _formatDate(row.paidAt)),
        if ((row.method ?? '').isNotEmpty)
          _BillingDetail('Method', row.method!),
        _BillingDetail('Status', row.status),
      ],
    );
  }

  void _showBillingDetailsSheet({
    required IconData icon,
    required String title,
    required String subtitle,
    required String badge,
    required List<_BillingDetail> details,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Material(
            color: AppColors.surfaceModal,
            borderRadius: AppRadius.sheet,
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.borderStrong,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _IconTile(icon: icon),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: Theme.of(
                                  sheetContext,
                                ).textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                subtitle,
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        _StatusBadge(label: badge),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppCard(
                      padding: AppInsets.md,
                      surfaceLevel: AppSurfaceLevel.surface1,
                      child: Column(
                        children: details
                            .map(
                              (detail) => _DetailRow(
                                label: detail.label,
                                value: detail.value,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppSecondaryButton(
                      label: 'Close',
                      icon: Icons.close,
                      fullWidth: true,
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BillingDetail {
  const _BillingDetail(this.label, this.value);

  final String label;
  final String value;
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({
    required this.portal,
    required this.currency,
    required this.date,
    required this.onOpenPlanPage,
  });

  final BillingPortal portal;
  final String Function(double value) currency;
  final String Function(DateTime? value) date;
  final VoidCallback onOpenPlanPage;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: _billingAccentSoft,
                  borderRadius: AppRadius.md,
                ),
                child: const Icon(
                  Icons.workspace_premium_outlined,
                  color: _billingAccent,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      portal.summary.planName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${portal.unit.name} • ${_billingCycleLabel(portal.summary.billingCycle)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(label: portal.summary.subscriptionStatus),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _SmallInfo(
                  label: 'Next payment',
                  value: currency(portal.summary.upcomingPaymentAmount),
                  helper: date(portal.summary.upcomingPaymentDueDate),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _SmallInfo(
                  label: 'Plan page',
                  value: 'More info',
                  helper: 'Pricing and modules',
                  onTap: onOpenPlanPage,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.summary,
    required this.currency,
    required this.date,
  });

  final BillingSummary summary;
  final String Function(double value) currency;
  final String Function(DateTime? value) date;

  @override
  Widget build(BuildContext context) {
    final items = [
      _SummaryItem(
        'Plan',
        summary.planName,
        _billingCycleLabel(summary.billingCycle),
      ),
      _SummaryItem(
        'Outstanding',
        currency(summary.outstandingAmount),
        'Balance due',
      ),
      _SummaryItem(
        'Upcoming',
        currency(summary.upcomingPaymentAmount),
        date(summary.upcomingPaymentDueDate),
      ),
      _SummaryItem(
        'Total paid',
        currency(summary.totalPaid),
        'Collected payments',
      ),
    ];

    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 108,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return _SectionCard(
          padding: AppInsets.md,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.label.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                item.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                item.helper,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlansSection extends StatelessWidget {
  const _PlansSection({
    required this.plans,
    required this.currentPlanId,
    required this.currency,
    required this.featureLabel,
    required this.onUpgrade,
  });

  final List<BillingPlan> plans;
  final String currentPlanId;
  final String Function(double value) currency;
  final String Function(String featureId) featureLabel;
  final ValueChanged<BillingPlan> onUpgrade;

  @override
  Widget build(BuildContext context) {
    final currentIndex = plans.indexWhere((plan) => plan.id == currentPlanId);
    final currentPlan = currentIndex == -1 ? null : plans[currentIndex];

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: 'Available plans',
            subtitle: 'Compare plan levels and request an upgrade.',
          ),
          const SizedBox(height: AppSpacing.md),
          ...plans.asMap().entries.map((entry) {
            final planIndex = entry.key;
            final plan = entry.value;
            final isCurrent = plan.id == currentPlanId;
            final canRequestUpgrade = _isUpperPlan(
              plan: plan,
              currentPlan: currentPlan,
              planIndex: planIndex,
              currentIndex: currentIndex,
            );
            return AnimatedContainer(
              duration: AppMotion.normal,
              curve: AppMotion.easeOutCubic,
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: AppInsets.md,
              decoration: BoxDecoration(
                color: isCurrent ? AppColors.primarySoft : AppColors.surface1,
                borderRadius: AppRadius.md,
                border: Border.all(
                  color: isCurrent ? _billingAccent : AppColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          plan.name,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      if (isCurrent) const _StatusBadge(label: 'Current'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${currency(plan.price)} / month • ${currency(plan.oneTimePrice)} one-time',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _billingAccent,
                    ),
                  ),
                  if ((plan.bestFor ?? '').isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      plan.bestFor!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: plan.featureIds.take(6).map((featureId) {
                      return _FeatureChip(label: featureLabel(featureId));
                    }).toList(),
                  ),
                  if (canRequestUpgrade) ...[
                    const SizedBox(height: AppSpacing.md),
                    AppSecondaryButton(
                      label: 'Request upgrade',
                      icon: Icons.arrow_upward_outlined,
                      fullWidth: true,
                      onPressed: () => onUpgrade(plan),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  bool _isUpperPlan({
    required BillingPlan plan,
    required BillingPlan? currentPlan,
    required int planIndex,
    required int currentIndex,
  }) {
    if (plan.id == currentPlanId) return false;

    if (currentPlan == null) {
      return currentIndex != -1 && planIndex > currentIndex;
    }

    if (plan.price != currentPlan.price) {
      return plan.price > currentPlan.price;
    }

    if (plan.oneTimePrice != currentPlan.oneTimePrice) {
      return plan.oneTimePrice > currentPlan.oneTimePrice;
    }

    return currentIndex != -1 && planIndex > currentIndex;
  }
}

class _SubscriptionSection extends StatelessWidget {
  const _SubscriptionSection({required this.portal, required this.date});

  final BillingPortal portal;
  final String Function(DateTime? value) date;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: 'Subscription',
            subtitle: 'Current subscription terms for this unit.',
          ),
          const SizedBox(height: AppSpacing.md),
          _DetailRow(label: 'Status', value: portal.summary.subscriptionStatus),
          _DetailRow(
            label: 'Billing cycle',
            value: _billingCycleLabel(portal.summary.billingCycle),
          ),
          _DetailRow(
            label: 'Start date',
            value: date(
              portal.subscription?.startDate ??
                  portal.unit.subscriptionStartDate,
            ),
          ),
          _DetailRow(
            label: 'Trial end',
            value: date(
              portal.subscription?.trialEndDate ?? portal.unit.trialEndDate,
            ),
          ),
          _DetailRow(
            label: 'Next renewal',
            value: date(
              portal.subscription?.renewalDate ?? portal.unit.renewalDate,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanDetailsSection extends StatelessWidget {
  const _PlanDetailsSection({required this.plan, required this.featureLabel});

  final BillingPlan? plan;
  final String Function(String featureId) featureLabel;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: 'Plan details',
            subtitle: plan?.included ?? 'Included features and usage scope.',
          ),
          const SizedBox(height: AppSpacing.md),
          if (plan == null)
            const _EmptyText('No plan details available.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: plan!.featureIds.map((featureId) {
                return _FeatureChip(label: featureLabel(featureId));
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _MaintenanceDueBanner extends StatelessWidget {
  const _MaintenanceDueBanner({
    required this.entries,
    required this.currency,
    required this.date,
  });

  final List<MaintenanceHistoryEntry> entries;
  final String Function(double value) currency;
  final String Function(DateTime? value) date;

  @override
  Widget build(BuildContext context) {
    final total = entries.fold<double>(0, (sum, entry) => sum + entry.amount);
    final first = entries.first;
    final title = entries.length == 1
        ? first.label
        : '${entries.length} maintenance payments due';

    return Container(
      padding: AppInsets.md,
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.16),
              borderRadius: AppRadius.md,
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${currency(total)} pending${first.dueDate == null ? '' : ' • due ${date(first.dueDate)}'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MaintenanceSection extends StatelessWidget {
  const _MaintenanceSection({
    required this.entries,
    required this.currency,
    required this.date,
    required this.onEntryTap,
  });

  final List<MaintenanceHistoryEntry> entries;
  final String Function(double value) currency;
  final String Function(DateTime? value) date;
  final ValueChanged<MaintenanceHistoryEntry> onEntryTap;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Maintenance history',
            subtitle: 'Yearly maintenance and service fee records.',
          ),
          const SizedBox(height: AppSpacing.md),
          if (entries.isEmpty)
            const _EmptyText('No maintenance entries yet.')
          else
            ...entries.take(6).map((entry) {
              return _ListRow(
                title: entry.label,
                subtitle: date(entry.dueDate),
                trailing: currency(entry.amount),
                badge: entry.status,
                onTap: () => onEntryTap(entry),
              );
            }),
        ],
      ),
    );
  }
}

class _PaymentSection extends StatelessWidget {
  const _PaymentSection({
    required this.rows,
    required this.currency,
    required this.date,
    required this.onRowTap,
  });

  final List<PaymentHistoryRow> rows;
  final String Function(double value) currency;
  final String Function(DateTime? value) date;
  final ValueChanged<PaymentHistoryRow> onRowTap;

  @override
  Widget build(BuildContext context) {
    final openBills = rows
        .where((row) => !row.isPayment && !row.isPaid && row.displayAmount > 0)
        .toList();
    final paymentHistory = rows
        .where((row) => row.isPayment || row.isPaid)
        .toList()
        .reversed
        .toList();

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Payment details',
            subtitle: 'Open bills and payments recorded for this unit.',
          ),
          const SizedBox(height: AppSpacing.md),
          if (openBills.isEmpty && paymentHistory.isEmpty)
            const _EmptyText('No billing records found.')
          else ...[
            if (openBills.isNotEmpty) ...[
              const _InlineLabel('Open bills'),
              ...openBills.take(4).map((row) {
                return _ListRow(
                  title: row.label,
                  subtitle: _openBillSubtitle(row),
                  trailing: currency(row.displayAmount),
                  badge: row.paidAmount > 0 ? 'partial due' : row.status,
                  onTap: () => onRowTap(row),
                );
              }),
              const SizedBox(height: AppSpacing.sm),
            ],
            const _InlineLabel('Payment history'),
            if (paymentHistory.isEmpty)
              const _EmptyText('No payments recorded yet.')
            else
              ...paymentHistory.take(8).map((row) {
                return _ListRow(
                  title: row.label,
                  subtitle: _historySubtitle(row),
                  trailing: currency(row.amount),
                  badge: row.status,
                  onTap: () => onRowTap(row),
                );
              }),
          ],
        ],
      ),
    );
  }

  String _openBillSubtitle(PaymentHistoryRow row) {
    final pieces = <String>['invoice'];
    if (row.amount > row.displayAmount) {
      pieces.add('${currency(row.amount)} total');
    }
    if (row.paidAmount > 0) {
      pieces.add('${currency(row.paidAmount)} paid');
    }
    pieces.add('due ${date(row.dueDate)}');
    return pieces.join(' • ');
  }

  String _historySubtitle(PaymentHistoryRow row) {
    final type = row.isPayment ? 'payment' : 'invoice';
    final paidText = row.paidAt != null
        ? 'paid ${date(row.paidAt)}'
        : 'due ${date(row.dueDate)}';
    return '$type • $paidText';
  }
}

class _BillingSummarySection extends StatelessWidget {
  const _BillingSummarySection({
    required this.summary,
    required this.currency,
    required this.date,
  });

  final BillingSummary summary;
  final String Function(double value) currency;
  final String Function(DateTime? value) date;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Billing summary',
            subtitle:
                'Outstanding balance reduces when invoices are marked paid or manual payments are recorded.',
          ),
          const SizedBox(height: AppSpacing.md),
          _DetailRow(
            label: 'Total invoiced',
            value: currency(summary.totalInvoiced),
          ),
          _DetailRow(label: 'Total paid', value: currency(summary.totalPaid)),
          _DetailRow(
            label: 'Outstanding amount',
            value: currency(summary.outstandingAmount),
          ),
          _DetailRow(
            label: 'Upcoming payment',
            value:
                '${currency(summary.upcomingPaymentAmount)} • ${date(summary.upcomingPaymentDueDate)}',
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.padding = AppInsets.card});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: padding,
      surfaceLevel: AppSurfaceLevel.elevated,
      child: child,
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: _billingAccentSoft,
        borderRadius: AppRadius.md,
      ),
      child: Icon(icon, color: _billingAccent, size: 22),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _InlineLabel extends StatelessWidget {
  const _InlineLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.xxs,
        bottom: AppSpacing.xxs,
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.badge,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String trailing;
  final String badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: AppInsets.md,
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                trailing,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xxs),
              _StatusBadge(label: badge),
            ],
          ),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
              size: 24,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.md,
      child: InkWell(onTap: onTap, borderRadius: AppRadius.md, child: row),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normal = label.toLowerCase();
    final color =
        normal.contains('paid') ||
            normal.contains('active') ||
            normal.contains('current')
        ? AppColors.success
        : normal.contains('trial') ||
              normal.contains('due') ||
              normal.contains('pending')
        ? AppColors.warning
        : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SmallInfo extends StatelessWidget {
  const _SmallInfo({
    required this.label,
    required this.value,
    required this.helper,
    this.onTap,
  });

  final String label;
  final String value;
  final String helper;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.md,
      child: Container(
        padding: AppInsets.md,
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: AppRadius.md,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              helper,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: const BoxDecoration(
        color: _billingAccentSoft,
        borderRadius: AppRadius.button,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, size: 14, color: _billingAccent),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _billingAccent,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.receipt_long_outlined,
      title: 'Billing unavailable',
      message: message,
      action: AppSecondaryButton(
        label: 'Retry',
        icon: Icons.refresh,
        onPressed: onRetry,
      ),
    );
  }
}

class _SummaryItem {
  const _SummaryItem(this.label, this.value, this.helper);

  final String label;
  final String value;
  final String helper;
}

String _featureLabel(String featureId) {
  const labels = {
    'patients': 'Patient management',
    'home_visits': 'Home visits',
    'volunteers': 'Volunteers',
    'social_support': 'Social support',
    'equipment': 'Equipment inventory',
    'equipment_distribution': 'Equipment distribution',
    'patient_pdf': 'Patient PDF reports',
    'nhc_assessment': 'NHC visit assessment',
    'nhc_pdf': 'NHC PDF report',
    'medicine_master': 'Medicine master',
    'medicine_stock': 'Medicine stock entry',
    'medicine_supply': 'Medicine supply',
    'advanced_reports': 'Advanced reports',
    'analytics': 'Analytics dashboard',
    'backup_export': 'Backup & export',
    'whatsapp_sms': 'WhatsApp/SMS reminders',
    'multi_centre': 'Multi-centre mode',
    'custom_forms': 'Custom forms',
  };
  return labels[featureId] ?? featureId.replaceAll('_', ' ');
}

String _billingCycleLabel(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized == 'one_time') return 'One Time';
  if (normalized == 'yearly') return 'Yearly';
  if (normalized == 'monthly') return 'Monthly';
  if (normalized == 'custom') return 'Custom';
  return value.replaceAll('_', ' ');
}
