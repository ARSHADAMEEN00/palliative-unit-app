import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/models/billing.dart';
import 'package:oruma_app/services/billing_service.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';

class ManualPaymentScreen extends StatefulWidget {
  const ManualPaymentScreen({super.key, this.portal});

  final BillingPortal? portal;

  @override
  State<ManualPaymentScreen> createState() => _ManualPaymentScreenState();
}

class _ManualPaymentScreenState extends State<ManualPaymentScreen> {
  static const int _maxProofBytes = 1450000;

  final BillingService _billingService = const BillingService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _referenceController = TextEditingController();
  final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  final DateFormat _dateFormat = DateFormat('d MMM yyyy');
  final Set<String> _selectedInvoiceIds = {};

  BillingPortal? _portal;
  bool _loadingPortal = false;
  DateTime _paidAt = DateTime.now();
  String _paymentMethod = 'upi';
  String? _proofData;
  String? _proofFileName;
  Uint8List? _proofPreview;
  String? _error;
  bool _submitting = false;

  List<PaymentHistoryRow> get _payableInvoices {
    final portal = _portal;
    if (portal == null) return [];
    return portal.paymentRows.where((row) => row.canSubmitProof).toList()
      ..sort((a, b) {
        final aTime = a.dueDate?.millisecondsSinceEpoch ?? 0;
        final bTime = b.dueDate?.millisecondsSinceEpoch ?? 0;
        return aTime.compareTo(bTime);
      });
  }

  List<PaymentHistoryRow> get _selectedInvoices => _payableInvoices
      .where((row) => _selectedInvoiceIds.contains(row.id))
      .toList();

  double get _selectedAmount =>
      _selectedInvoices.fold(0, (sum, invoice) => sum + invoice.displayAmount);

  PaymentSubmission? get _activeSubmission {
    final portal = _portal;
    if (portal == null) return null;
    for (final submission in portal.paymentSubmissions) {
      if (submission.isPending) return submission;
    }
    return null;
  }

  PaymentSubmission? get _latestRejectedSubmission {
    final portal = _portal;
    if (portal == null) return null;
    for (final submission in portal.paymentSubmissions) {
      if (submission.isRejected) return submission;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.portal != null) {
      _portal = widget.portal;
      _initFromPortal(widget.portal!);
      if (!widget.portal!.paymentSettings.hasPaymentMethod) {
        _loadPortal();
      }
    } else {
      _loadPortal();
    }
  }

  void _initFromPortal(BillingPortal portal) {
    _selectedInvoiceIds.addAll(
      _payableInvoices
          .map((invoice) => invoice.id!)
          .where((id) => id.isNotEmpty),
    );
    final settings = portal.paymentSettings;
    if (!settings.hasUpiId && !settings.hasUpiQr && settings.hasBankTransfer) {
      _paymentMethod = 'bank_transfer';
    }
  }

  Future<void> _loadPortal() async {
    setState(() => _loadingPortal = true);
    final result = await _billingService.getBillingPortal();
    if (!mounted) return;
    if (result.isSuccess && result.data != null) {
      setState(() {
        _portal = result.data;
        _loadingPortal = false;
        _initFromPortal(result.data!);
      });
    } else {
      setState(() {
        _loadingPortal = false;
        _error = result.error ?? 'Unable to load billing portal';
      });
    }
  }

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied')));
  }

  Future<void> _pickProof() async {
    setState(() => _error = null);
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 2200,
        maxHeight: 2200,
      );
      if (file == null) return;
      final raw = await file.readAsBytes();
      final decoded = image_lib.decodeImage(raw);
      if (decoded == null) {
        throw Exception('Select a valid PNG or JPEG screenshot.');
      }

      final largestSide = decoded.width > decoded.height
          ? decoded.width
          : decoded.height;
      final resized = largestSide > 1600
          ? image_lib.copyResize(
              decoded,
              width: decoded.width >= decoded.height ? 1600 : null,
              height: decoded.height > decoded.width ? 1600 : null,
            )
          : decoded;

      var quality = 84;
      Uint8List compressed = Uint8List.fromList(
        image_lib.encodeJpg(resized, quality: quality),
      );
      while (compressed.lengthInBytes > _maxProofBytes && quality > 34) {
        quality -= 10;
        compressed = Uint8List.fromList(
          image_lib.encodeJpg(resized, quality: quality),
        );
      }
      if (compressed.lengthInBytes > _maxProofBytes) {
        throw Exception('The screenshot is too large. Crop it and try again.');
      }

      if (!mounted) return;
      setState(() {
        _proofPreview = compressed;
        _proofData = 'data:image/jpeg;base64,${base64Encode(compressed)}';
        _proofFileName =
            'payment-proof-${DateTime.now().millisecondsSinceEpoch}.jpg';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _selectPaymentDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _paidAt,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
    );
    if (selected != null && mounted) {
      setState(() => _paidAt = selected);
    }
  }

  Future<void> _submit() async {
    final reference = _referenceController.text.trim();
    if (_selectedInvoices.isEmpty) {
      setState(() => _error = 'Select at least one invoice.');
      return;
    }
    if (reference.isEmpty) {
      setState(() => _error = 'Enter the transaction reference or UTR.');
      return;
    }
    if (_proofData == null || _proofFileName == null) {
      setState(() => _error = 'Upload the payment screenshot.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    final rejected = _latestRejectedSubmission;
    final result = await _billingService.submitPaymentProof(
      invoiceIds: _selectedInvoices.map((invoice) => invoice.id!).toList(),
      declaredPaidAmount: _selectedAmount,
      transactionReference: reference,
      paidAt: _paidAt,
      paymentMethod: _paymentMethod,
      proofData: _proofData!,
      proofFileName: _proofFileName!,
      replacesSubmissionId: rejected?.id,
    );
    if (!mounted) return;

    if (!result.isSuccess || result.data == null) {
      setState(() {
        _submitting = false;
        _error = result.error ?? 'Unable to submit payment proof.';
      });
      return;
    }

    final refreshed = await _billingService.fetchBillingPortal();
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (refreshed.isSuccess && refreshed.data != null) {
        _portal = refreshed.data!;
      } else if (_portal != null) {
        _portal = BillingPortal(
          unit: _portal!.unit,
          summary: _portal!.summary,
          plans: _portal!.plans,
          maintenanceHistory: _portal!.maintenanceHistory,
          paymentRows: _portal!.paymentRows,
          paymentSettings: _portal!.paymentSettings,
          paymentSubmissions: [result.data!, ..._portal!.paymentSubmissions],
          subscription: _portal!.subscription,
          currentPlan: _portal!.currentPlan,
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Payment proof submitted. Your balance will update after superadmin verification.',
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveAppScaffold(
      backgroundColor: AppColors.background,
      contentMaxWidth: 760,
      appBar: AppBar(
        title: const Text('Payment instructions'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loadingPortal || _portal == null) {
      if (_error != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.danger),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    final portal = _portal!;

    final activeSubmission = _activeSubmission;
    if (activeSubmission != null) {
      return _statusView(activeSubmission);
    }

    if (portal.summary.outstandingAmount <= 0 || _payableInvoices.isEmpty) {
      return ListView(
        padding: AppInsets.screen(context, top: AppSpacing.lg),
        children: const [
          _PaymentInfoCard(
            icon: Icons.verified_rounded,
            color: AppColors.success,
            title: 'No due payments',
            message:
                'Your account is fully paid. There is no outstanding balance.',
          ),
        ],
      );
    }

    final settings = portal.paymentSettings;
    return RefreshIndicator(
      onRefresh: _loadPortal,
      child: ListView(
      padding: AppInsets.screen(
        context,
        top: AppSpacing.md,
        bottom: AppSpacing.xl,
      ),
      children: [
        _PaymentInfoCard(
          icon: Icons.account_balance_wallet_outlined,
          color: AppColors.warning,
          title: '${_currency.format(_selectedAmount)} selected',
          message:
              'Pay the exact selected total using the instructions below, then upload the screenshot for verification.',
        ),
        if (_latestRejectedSubmission != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _PaymentInfoCard(
            icon: Icons.error_outline_rounded,
            color: AppColors.danger,
            title: 'Previous proof was rejected',
            message:
                _latestRejectedSubmission!.rejectionReason ??
                'Please correct the payment details and submit a new screenshot.',
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        _section(
          title: 'Select invoices',
          subtitle:
              'The uploaded proof will be linked to these billing entries.',
          child: Column(
            children: _payableInvoices.map((invoice) {
              final selected = _selectedInvoiceIds.contains(invoice.id);
              return Material(
                color: Colors.transparent,
                child: CheckboxListTile(
                  value: selected,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(invoice.label),
                  subtitle: Text(
                    '${invoice.invoiceNumber ?? 'Invoice'} • due ${_formatDate(invoice.dueDate)}',
                  ),
                  secondary: Text(
                    _currency.format(invoice.displayAmount),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedInvoiceIds.add(invoice.id!);
                      } else {
                        _selectedInvoiceIds.remove(invoice.id);
                      }
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (settings.hasPaymentMethod) ...[
          if (settings.hasBankTransfer)
            _section(
              title: 'Bank transfer',
              subtitle: 'Use these details for NEFT, IMPS, or bank transfer.',
              child: Column(
                children: [
                  _copyRow('Account holder', settings.accountHolderName),
                  _copyRow('Bank', settings.bankName),
                  _copyRow('Account number', settings.accountNumber),
                  _copyRow('IFSC', settings.ifscCode),
                  if (settings.branchName.isNotEmpty)
                    _copyRow('Branch', settings.branchName),
                ],
              ),
            ),
          if (settings.hasBankTransfer &&
              (settings.hasUpiId || settings.hasUpiQr))
            const SizedBox(height: AppSpacing.sm),
          if (settings.hasUpiId || settings.hasUpiQr)
            _section(
              title: 'UPI payment',
              subtitle: 'Scan the QR or copy the UPI ID into your payment app.',
              child: Column(
                children: [
                  if (settings.hasUpiQr) _qrImage(settings.qrImage),
                  if (settings.hasUpiQr && settings.hasUpiId)
                    const SizedBox(height: AppSpacing.md),
                  if (settings.hasUpiId) _copyRow('UPI ID', settings.upiId),
                ],
              ),
            ),
          if (settings.instructions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _section(
              title: 'Additional instructions',
              child: Text(
                settings.instructions,
                style: const TextStyle(height: 1.45),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          _section(
            title: 'Upload payment proof',
            subtitle:
                'Your balance changes only after the superadmin verifies this submission.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Payment method',
                  ),
                  items: [
                    if (settings.hasUpiId || settings.hasUpiQr)
                      const DropdownMenuItem(value: 'upi', child: Text('UPI')),
                    if (settings.hasBankTransfer)
                      const DropdownMenuItem(
                        value: 'bank_transfer',
                        child: Text('Bank transfer'),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _paymentMethod = value);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _referenceController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Transaction reference / UTR',
                    hintText: 'Enter the bank or UPI reference number',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                InkWell(
                  onTap: _selectPaymentDate,
                  borderRadius: AppRadius.input,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Payment date',
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(_formatDate(_paidAt)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (_proofPreview != null) ...[
                  ClipRRect(
                    borderRadius: AppRadius.md,
                    child: Image.memory(
                      _proofPreview!,
                      height: 220,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                AppSecondaryButton(
                  label: _proofPreview == null
                      ? 'Upload payment screenshot'
                      : 'Replace screenshot',
                  icon: Icons.upload_file_outlined,
                  fullWidth: true,
                  onPressed: _submitting ? null : _pickProof,
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                AppPrimaryButton(
                  label: 'Submit for verification',
                  icon: Icons.verified_user_outlined,
                  fullWidth: true,
                  loading: _submitting,
                  onPressed: _submitting ? null : _submit,
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

  Widget _statusView(PaymentSubmission submission) {
    final underReview =
        submission.status == 'under_review' ||
        submission.status == 'processing';
    return ListView(
      padding: AppInsets.screen(context, top: AppSpacing.lg),
      children: [
        _PaymentInfoCard(
          icon: underReview
              ? Icons.manage_search_rounded
              : Icons.hourglass_top_rounded,
          color: AppColors.info,
          title: underReview
              ? 'Payment verification in progress'
              : 'Payment proof submitted',
          message:
              'After superadmin verification, you will see the updated balance here. No payment is marked paid until it is approved.',
        ),
        const SizedBox(height: AppSpacing.sm),
        _section(
          title: submission.submissionNumber.isEmpty
              ? 'Submission details'
              : submission.submissionNumber,
          child: Column(
            children: [
              _detailRow('Amount', _currency.format(submission.expectedAmount)),
              _detailRow('Reference', submission.transactionReference),
              _detailRow('Paid on', _formatDate(submission.paidAt)),
              _detailRow('Status', _statusLabel(submission.status)),
              if (submission.invoices.isNotEmpty)
                _detailRow(
                  'Invoices',
                  submission.invoices
                      .map((invoice) => invoice.label)
                      .join(', '),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppSecondaryButton(
          label: 'Back to Billing & Plan',
          icon: Icons.arrow_back_rounded,
          fullWidth: true,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }

  Widget _section({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return AppCard(
      surfaceLevel: AppSurfaceLevel.elevated,
      padding: AppInsets.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }

  Widget _copyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: 'Copy $label',
            visualDensity: VisualDensity.compact,
            onPressed: () => _copy(label, value),
            icon: const Icon(Icons.copy_rounded, size: 19),
          ),
        ],
      ),
    );
  }

  Widget _qrImage(String dataUrl) {
    try {
      final encoded = dataUrl.substring(dataUrl.indexOf(',') + 1);
      return Center(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.md,
            border: Border.all(color: AppColors.border),
          ),
          child: Image.memory(
            base64Decode(encoded),
            width: 220,
            height: 220,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox(
              width: 220,
              height: 80,
              child: Center(child: Text('QR image unavailable')),
            ),
          ),
        ),
      );
    } catch (_) {
      return const Center(child: Text('QR image unavailable'));
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    return _dateFormat.format(value.toLocal());
  }

  String _statusLabel(String value) {
    return value
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }
}

class _PaymentInfoCard extends StatelessWidget {
  const _PaymentInfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: AppRadius.card,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  message,
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
