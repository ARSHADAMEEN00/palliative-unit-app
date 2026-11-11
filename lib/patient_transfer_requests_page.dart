import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_design_system.dart';
import 'core/utils/format_utils.dart';
import 'models/patient_transfer.dart';
import 'patient_transfer_review_page.dart';
import 'services/auth_service.dart';
import 'services/patient_transfer_service.dart';
import 'shared/widgets/app_widgets.dart';

class PatientTransferRequestsPage extends StatefulWidget {
  const PatientTransferRequestsPage({super.key, this.initialIncoming = true});

  final bool initialIncoming;

  @override
  State<PatientTransferRequestsPage> createState() =>
      _PatientTransferRequestsPageState();
}

class _PatientTransferRequestsPageState
    extends State<PatientTransferRequestsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<PatientTransferRequest> _incoming = const [];
  List<PatientTransferRequest> _outgoing = const [];
  bool _loadingIncoming = true;
  bool _loadingOutgoing = true;
  String? _incomingError;
  String? _outgoingError;
  String _status = 'all';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIncoming ? 0 : 1,
    );
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_load(true), _load(false)]);
  }

  Future<void> _load(bool incoming) async {
    if (mounted) {
      setState(() {
        if (incoming) {
          _loadingIncoming = true;
          _incomingError = null;
        } else {
          _loadingOutgoing = true;
          _outgoingError = null;
        }
      });
    }
    try {
      final page = await PatientTransferService.requests(
        incoming: incoming,
        status: _status,
      );
      if (!mounted) return;
      setState(() {
        if (incoming) {
          _incoming = page.requests;
          _loadingIncoming = false;
        } else {
          _outgoing = page.requests;
          _loadingOutgoing = false;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (incoming) {
          _incomingError = _friendly(error);
          _loadingIncoming = false;
        } else {
          _outgoingError = _friendly(error);
          _loadingOutgoing = false;
        }
      });
    }
  }

  Future<void> _open(PatientTransferRequest request, bool incoming) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PatientTransferReviewPage(
          requestId: request.id,
          incoming: incoming,
        ),
      ),
    );
    if (changed == true) await _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final pendingIncoming = _incoming.where((item) => item.isPending).length;
    if (!auth.canViewPatientTransfers) {
      return Scaffold(
        appBar: AppBar(title: const Text('Patient Transfers')),
        body: const AppEmptyState(
          icon: Icons.lock_outline,
          title: 'Access denied',
          message: 'Your role cannot view patient transfers.',
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Patient Transfers'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Incoming'),
                  if (pendingIncoming > 0) ...[
                    const SizedBox(width: AppSpacing.xs),
                    _CountBadge(count: pendingIncoming),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Outgoing'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: () {
              final dropdownStyle =
                  Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        color: AppColors.text,
                      );
              return DropdownButtonFormField<String>(
                initialValue: _status,
                style: dropdownStyle,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(Icons.filter_list),
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('All statuses', style: dropdownStyle),
                  ),
                  DropdownMenuItem(
                    value: 'PENDING',
                    child: Text('Pending', style: dropdownStyle),
                  ),
                  DropdownMenuItem(
                    value: 'ACCEPTED',
                    child: Text('Accepted', style: dropdownStyle),
                  ),
                  DropdownMenuItem(
                    value: 'REJECTED',
                    child: Text('Rejected', style: dropdownStyle),
                  ),
                  DropdownMenuItem(
                    value: 'CANCELLED',
                    child: Text('Cancelled', style: dropdownStyle),
                  ),
                  DropdownMenuItem(
                    value: 'EXPIRED',
                    child: Text('Expired', style: dropdownStyle),
                  ),
                ],
                onChanged: (value) {
                  if (value == null || value == _status) return;
                  setState(() => _status = value);
                  _loadAll();
                },
              );
            }(),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _requestList(
                  incoming: true,
                  requests: _incoming,
                  loading: _loadingIncoming,
                  error: _incomingError,
                ),
                _requestList(
                  incoming: false,
                  requests: _outgoing,
                  loading: _loadingOutgoing,
                  error: _outgoingError,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestList({
    required bool incoming,
    required List<PatientTransferRequest> requests,
    required bool loading,
    required String? error,
  }) {
    if (loading) return const AppListSkeleton(itemCount: 5);
    if (error != null) {
      return AppEmptyState(
        icon: Icons.error_outline,
        title: 'Could not load transfers',
        message: error,
        action: AppPrimaryButton(
          label: 'Retry',
          icon: Icons.refresh,
          onPressed: () => _load(incoming),
        ),
      );
    }
    if (requests.isEmpty) {
      return AppEmptyState(
        icon: incoming ? Icons.move_to_inbox_outlined : Icons.outbox_outlined,
        title: incoming ? 'No incoming transfers' : 'No outgoing transfers',
        message: incoming
            ? 'New requests sent to this unit will appear here.'
            : 'Transfers initiated by this unit will appear here.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(incoming),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        itemCount: requests.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) =>
            _requestCard(requests[index], incoming),
      ),
    );
  }

  Widget _requestCard(PatientTransferRequest request, bool incoming) {
    final color = _statusColor(request.status);
    final unit = incoming ? request.sourceUnit : request.destinationUnit;
    final patientName = request.patient?.name ?? 'Patient transfer';
    return AppCard(
      onTap: () => _open(request, incoming),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.09),
                  borderRadius: AppRadius.md,
                ),
                child: Icon(Icons.swap_horiz, color: color),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      '${incoming ? 'From' : 'To'} ${unit?.name ?? 'unit'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  request.status,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(request.reason, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Transfer date ${DateFormat('dd MMM yyyy').format(request.transferDate)}',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        FormatUtils.formatCompactCount(count),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Color _statusColor(String status) => switch (status) {
  'ACCEPTED' => AppColors.success,
  'REJECTED' => AppColors.danger,
  'CANCELLED' || 'EXPIRED' => AppColors.textMuted,
  _ => AppColors.warning,
};

String _friendly(Object error) =>
    error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
