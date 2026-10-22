import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/models/patient_enquiry.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/services/patient_enquiry_service.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';
import 'package:provider/provider.dart';

class PatientEnquiryListPage extends StatefulWidget {
  const PatientEnquiryListPage({super.key});

  @override
  State<PatientEnquiryListPage> createState() => _PatientEnquiryListPageState();
}

class _PatientEnquiryListPageState extends State<PatientEnquiryListPage> {
  final TextEditingController _searchController = TextEditingController();
  List<PatientEnquiry> _enquiries = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _statusFilter = 'pending'; // 'pending' or 'all'

  @override
  void initState() {
    super.initState();
    _loadEnquiries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEnquiries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await PatientEnquiryService.getEnquiries(
        status: _statusFilter == 'all' ? null : _statusFilter,
        search: _searchController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _enquiries = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _updateStatus(PatientEnquiry enquiry, String newStatus) async {
    try {
      await PatientEnquiryService.updateStatus(enquiry.id, newStatus);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'verified'
                ? 'Enquiry marked as verified.'
                : 'Enquiry status updated to $newStatus.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      _loadEnquiries();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _deleteEnquiry(PatientEnquiry enquiry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Enquiry?'),
        content: Text(
          'Are you sure you want to remove the enquiry for "${enquiry.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await PatientEnquiryService.deleteEnquiry(enquiry.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enquiry deleted successfully.')),
        );
        _loadEnquiries();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete enquiry: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return AdaptiveAppScaffold(
      appBar: AppBar(
        title: const Text('Patient Enquiries'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadEnquiries,
          ),
        ],
      ),
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadEnquiries,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: Column(
          children: [
            // Header / Search & Filter Section
            Container(
              color: AppColors.surface,
              padding: EdgeInsets.symmetric(
                horizontal: AppInsets.screenHorizontal(context),
                vertical: AppSpacing.sm,
              ),
              child: Column(
                children: [
                  // Search Field
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by patient name, phone, village...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _loadEnquiries();
                              },
                            )
                          : null,
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.surface1,
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.input,
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppRadius.input,
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    onSubmitted: (_) => _loadEnquiries(),
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  // Filter Chips (Pending vs All)
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xxs,
                    children: [
                      FilterChip(
                        selected: _statusFilter == 'pending',
                        label: const Text('Pending Verification'),
                        avatar: const Icon(Icons.pending_actions_rounded, size: 16),
                        selectedColor: AppColors.warning.withValues(alpha: 0.12),
                        checkmarkColor: AppColors.warning,
                        labelStyle: TextStyle(
                          color: _statusFilter == 'pending'
                              ? const Color(0xFFB45309)
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _statusFilter = 'pending');
                            _loadEnquiries();
                          }
                        },
                      ),
                      FilterChip(
                        selected: _statusFilter == 'all',
                        label: const Text('All Submissions'),
                        avatar: const Icon(Icons.list_alt_rounded, size: 16),
                        selectedColor: AppColors.primarySoft,
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: _statusFilter == 'all'
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _statusFilter = 'all');
                            _loadEnquiries();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // Content Body
            Expanded(
              child: _buildBody(auth),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AuthService auth) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton.icon(
                onPressed: _loadEnquiries,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_enquiries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _statusFilter == 'pending'
                    ? 'No Pending Patient Enquiries'
                    : 'No Patient Enquiries Found',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'New patient records submitted via the volunteer or public form will appear here awaiting WhatsApp verification.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        AppInsets.screenHorizontal(context),
        AppSpacing.md,
        AppInsets.screenHorizontal(context),
        AppSpacing.xl,
      ),
      itemCount: _enquiries.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final enquiry = _enquiries[index];
        return _buildEnquiryCard(context, enquiry, auth);
      },
    );
  }

  Widget _buildEnquiryCard(
    BuildContext context,
    PatientEnquiry enquiry,
    AuthService auth,
  ) {
    final statusColor = enquiry.isVerified
        ? AppColors.success
        : (enquiry.isRejected ? AppColors.danger : AppColors.warning);
    final statusBg = enquiry.isVerified
        ? AppColors.success.withValues(alpha: 0.12)
        : (enquiry.isRejected
            ? AppColors.danger.withValues(alpha: 0.1)
            : AppColors.warning.withValues(alpha: 0.12));

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.card,
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Patient Name, Age & Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        enquiry.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      if (enquiry.age != null && enquiry.age! > 0)
                        Text(
                          'Age: ${enquiry.age} yrs',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    enquiry.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (auth.canManagePatientEnquiries)
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    onSelected: (val) {
                      if (val == 'verify') {
                        _updateStatus(enquiry, 'verified');
                      } else if (val == 'pending') {
                        _updateStatus(enquiry, 'pending');
                      } else if (val == 'reject') {
                        _updateStatus(enquiry, 'rejected');
                      } else if (val == 'delete') {
                        _deleteEnquiry(enquiry);
                      }
                    },
                    itemBuilder: (_) => [
                      if (!enquiry.isVerified)
                        const PopupMenuItem(
                          value: 'verify',
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline,
                                  color: AppColors.success, size: 18),
                              SizedBox(width: 8),
                              Text('Mark as Verified'),
                            ],
                          ),
                        ),
                      if (enquiry.isVerified)
                        const PopupMenuItem(
                          value: 'pending',
                          child: Row(
                            children: [
                              Icon(Icons.history, size: 18),
                              SizedBox(width: 8),
                              Text('Mark as Pending'),
                            ],
                          ),
                        ),
                      if (!enquiry.isRejected)
                        const PopupMenuItem(
                          value: 'reject',
                          child: Row(
                            children: [
                              Icon(
                                Icons.cancel_outlined,
                                color: AppColors.danger,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text('Mark as Rejected'),
                            ],
                          ),
                        ),
                      if (auth.isAdmin)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                color: AppColors.danger,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Delete Enquiry',
                                style: TextStyle(color: AppColors.danger),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.sm),

            // Patient Info Rows
            _buildDetailRow(
              Icons.phone_outlined,
              'Primary Phone',
              enquiry.phone,
              isHighlight: true,
            ),
            if (enquiry.phone2 != null && enquiry.phone2!.trim().isNotEmpty)
              _buildDetailRow(
                Icons.phone_android_outlined,
                'Secondary Phone',
                enquiry.phone2!,
              ),
            _buildDetailRow(
              Icons.location_on_outlined,
              'Village & Ward',
              '${enquiry.village}${enquiry.ward != null && enquiry.ward!.isNotEmpty ? ' • Ward ${enquiry.ward}' : ''}',
            ),
            if (enquiry.address.trim().isNotEmpty)
              _buildDetailRow(
                Icons.home_outlined,
                'Address',
                enquiry.address.trim(),
              ),
            if (enquiry.displayReferredByName != null)
              _buildDetailRow(
                Icons.person_pin_circle_outlined,
                'Referred By',
                enquiry.displayReferredByName!,
              ),
            if (enquiry.displayReferredByPhone != null)
              _buildDetailRow(
                Icons.contact_phone_outlined,
                'Referred Phone',
                enquiry.displayReferredByPhone!,
              ),
            if (enquiry.submittedByVolunteerName != null &&
                enquiry.submittedByVolunteerName!.trim().isNotEmpty)
              _buildDetailRow(
                Icons.volunteer_activism_outlined,
                'Submitted By',
                '${enquiry.submittedByVolunteerName} (Volunteer)',
              ),
            if (enquiry.createdAt != null)
              _buildDetailRow(
                Icons.calendar_today_outlined,
                'Submitted At',
                DateFormat('dd MMM yyyy, hh:mm a').format(enquiry.createdAt!),
              ),

            if (auth.isAdmin) ...[
              const SizedBox(height: AppSpacing.md),

              // PRIMARY ACTION: SHARE TO WHATSAPP (Admin only)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.button,
                    ),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text(
                    'Share Details to WhatsApp',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: 0.2,
                    ),
                  ),
                  onPressed: () => PatientEnquiryService.shareToWhatsApp(
                    enquiry,
                    context,
                    unitName: auth.unitName,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.xs),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Text(':', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isHighlight ? FontWeight.w600 : FontWeight.w500,
                color: isHighlight ? AppColors.primary : AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
