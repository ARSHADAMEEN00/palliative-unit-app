import 'package:flutter/material.dart';
import 'package:oruma_app/core/theme/app_colors.dart';
import 'package:oruma_app/manual_payment_screen.dart';
import 'package:oruma_app/screens/billing/billing_models.dart';
import 'package:oruma_app/screens/billing/billing_repository.dart';
import 'package:oruma_app/screens/billing/components/billing_components.dart';
import 'package:url_launcher/url_launcher.dart';

class BillingPlanScreen extends StatefulWidget {
  const BillingPlanScreen({super.key});

  @override
  State<BillingPlanScreen> createState() => _BillingPlanScreenState();
}

class _BillingPlanScreenState extends State<BillingPlanScreen> {
  final BillingRepository _repository = BillingRepository();
  final TextEditingController _searchController = TextEditingController();

  TransactionFilter _filter = const TransactionFilter();
  BillingFetchResult? _data;
  bool _loading = true;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() => _loading = true);
    final result = await _repository.getTransactions(_filter);
    if (!mounted) return;
    setState(() {
      _data = result;
      _loading = false;
    });
  }

  void _onFilterChanged(TransactionFilter newFilter) {
    setState(() {
      _filter = newFilter;
    });
    _loadTransactions();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filter = _filter.copyWith(searchQuery: '');
        _loadTransactions();
      }
    });
  }

  void _onSearchSubmitted(String query) {
    _filter = _filter.copyWith(searchQuery: query.trim());
    _loadTransactions();
  }

  void _openManagePlan() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => const PlanSubscriptionScreen(),
      ),
    );
  }

  Future<void> _onPayNow() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => const ManualPaymentScreen(),
      ),
    );
    if (mounted) {
      _loadTransactions();
    }
  }

  Future<void> _openSupport() async {
    final uri = Uri.parse('mailto:support@oruma.care?subject=Billing%20Support%20Enquiry');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open mail client for billing support')),
      );
    }
  }

  void _downloadAllInvoices() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Preparing invoice archive zip download...'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? AppColors.darkBackground : AppColors.background;
    final titleColor = isDark ? AppColors.darkText : const Color(0xFF111827);
    final dividerColor = isDark ? AppColors.darkBorder : const Color(0xFFF3F4F6);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: titleColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: titleColor, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Search by title or invoice #',
                  hintStyle: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: _onSearchSubmitted,
                onChanged: (val) {
                  _filter = _filter.copyWith(searchQuery: val);
                  _loadTransactions();
                },
              )
            : Text(
                'Billing',
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  letterSpacing: -0.2,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: titleColor,
            ),
            onPressed: _toggleSearch,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading && _data == null
          ? const BillingSkeleton()
          : RefreshIndicator(
              onRefresh: _loadTransactions,
              color: AppColors.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  // 1. Compact Summary Card (Top)
                  if (_data != null)
                    SummaryCard(
                      summary: _data!.summary,
                      repository: _repository,
                      onManagePlan: _openManagePlan,
                      onPayNow: _data!.summary.hasDues ? _onPayNow : null,
                    ),
                  const SizedBox(height: 14),

                  // 2. Balance Strip (one row with 3 compact stats)
                  if (_data != null)
                    BalanceStrip(
                      summary: _data!.summary,
                      repository: _repository,
                    ),
                  const SizedBox(height: 18),

                  // 3. Filter Chips (horizontal scroll, Google Pay style)
                  FilterChips(
                    filter: _filter,
                    onFilterChanged: _onFilterChanged,
                  ),
                  const SizedBox(height: 10),

                  // 4. Payment History List (Grouped by month with sticky header)
                  if (_data != null && _data!.groups.isEmpty)
                    EmptyState(
                      isFiltered: _filter.isFiltered,
                      onClearFilters: () {
                        _searchController.clear();
                        _onFilterChanged(const TransactionFilter());
                      },
                    )
                  else if (_data != null)
                    ..._data!.groups.map((group) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MonthHeader(
                            monthLabel: group.monthLabel,
                            monthTotal: group.monthTotal,
                            repository: _repository,
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurface1 : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: group.transactions.length,
                              separatorBuilder: (context, index) => Divider(
                                height: 1,
                                thickness: 1,
                                color: dividerColor,
                              ),
                              itemBuilder: (context, index) {
                                final tx = group.transactions[index];
                                return PaymentRow(
                                  transaction: tx,
                                  repository: _repository,
                                  onTap: () {
                                    ReceiptDetailSheet.show(context, tx, _repository);
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    }),

                  const SizedBox(height: 36),

                  // 5. Footer Links: "Download all invoices" | "Help & billing support"
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(
                        onTap: _downloadAllInvoices,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Text(
                            'Download all invoices',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        ' · ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF),
                        ),
                      ),
                      InkWell(
                        onTap: _openSupport,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Text(
                            'Help & billing support',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
