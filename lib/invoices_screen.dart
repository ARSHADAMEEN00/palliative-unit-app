import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/models/billing.dart';
import 'package:oruma_app/services/billing_service.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
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
  String? _downloadingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
        _error = result.error ?? 'Unable to load invoices.';
      }
    });
  }

  Future<void> _downloadInvoice(PaymentHistoryRow invoice) async {
    final portal = _portal;
    if (portal == null) return;
    setState(() => _downloadingId = invoice.id);
    try {
      final safeNumber = (invoice.invoiceNumber ?? invoice.periodKey)
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '-');

      if (invoice.id != null && invoice.id!.isNotEmpty) {
        final serverBytes = await _billingService.downloadInvoicePdf(invoice.id!);
        if (serverBytes != null && serverBytes.isNotEmpty) {
          await Printing.sharePdf(
            bytes: serverBytes,
            filename: 'invoice-$safeNumber.pdf',
          );
          return;
        }
      }

      final document = pw.Document(
        title: invoice.invoiceNumber ?? invoice.label,
        author: 'Palliative App',
      );
      final statusColor = invoice.isPaid
          ? PdfColors.green700
          : invoice.isVerificationPending
          ? PdfColors.blue700
          : PdfColors.orange800;
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(42),
          build: (_) => [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PALLIATIVE APP',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'INVOICE',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: pw.BoxDecoration(
                    color: statusColor.shade(0.92),
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Text(
                    _statusLabel(invoice.status).toUpperCase(),
                    style: pw.TextStyle(
                      color: statusColor,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 28),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _pdfInfo('BILLED TO', [portal.unit.name, portal.unit.code]),
                  _pdfInfo('INVOICE DETAILS', [
                    invoice.invoiceNumber ?? invoice.periodKey,
                    'Due: ${_pdfDate(invoice.dueDate)}',
                    if (invoice.paidAt != null)
                      'Paid: ${_pdfDate(invoice.paidAt)}',
                  ], right: true),
                ],
              ),
            ),
            pw.SizedBox(height: 28),
            pw.Table(
              border: pw.TableBorder(
                horizontalInside: const pw.BorderSide(color: PdfColors.grey300),
                bottom: const pw.BorderSide(color: PdfColors.grey400),
              ),
              columnWidths: const {
                0: pw.FlexColumnWidth(4),
                1: pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.blueGrey800,
                  ),
                  children: [
                    _pdfTableCell('DESCRIPTION', header: true),
                    _pdfTableCell('AMOUNT', header: true, right: true),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _pdfTableCell(
                      invoice.label,
                      subtext: _invoiceTypeLabel(invoice.invoiceType),
                    ),
                    _pdfTableCell(_pdfMoney(invoice.amount), right: true),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.SizedBox(
                width: 250,
                child: pw.Column(
                  children: [
                    _pdfAmountRow('Invoice total', invoice.amount),
                    _pdfAmountRow('Amount paid', invoice.paidAmount),
                    pw.Divider(color: PdfColors.grey500),
                    _pdfAmountRow(
                      'Balance due',
                      invoice.displayAmount,
                      bold: true,
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 48),
            pw.Divider(color: PdfColors.grey300),
            pw.Text(
              'This invoice was generated from the billing ledger. Manual payments are recorded only after superadmin verification.',
              style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 9),
            ),
          ],
        ),
      );
      await Printing.sharePdf(
        bytes: await document.save(),
        filename: 'invoice-$safeNumber.pdf',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to download invoice: $error'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveAppScaffold(
      backgroundColor: AppColors.background,
      contentMaxWidth: 820,
      appBar: AppBar(
        title: const Text('Invoices'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Padding(
        padding: AppInsets.screen(context, top: AppSpacing.md),
        child: const AppListSkeleton(itemCount: 5),
      );
    }
    if (_error != null || _portal == null) {
      return Center(
        child: Padding(
          padding: AppInsets.screen(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.receipt_long_outlined, size: 44),
              const SizedBox(height: AppSpacing.sm),
              Text(_error ?? 'Invoices are unavailable.'),
              const SizedBox(height: AppSpacing.md),
              AppPrimaryButton(label: 'Try again', onPressed: _load),
            ],
          ),
        ),
      );
    }

    final invoices = _portal!.paymentRows
        .where((row) => !row.isPayment && row.id != null)
        .toList()
        .reversed
        .toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: AppInsets.screen(
          context,
          top: AppSpacing.md,
          bottom: AppSpacing.xl,
        ),
        children: [
          Text(
            'Download a PDF copy of any invoice in your billing ledger.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          if (invoices.isEmpty)
            const AppCard(child: Text('No invoices have been created yet.'))
          else
            ...invoices.map(
              (invoice) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  surfaceLevel: AppSurfaceLevel.elevated,
                  padding: AppInsets.card,
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: AppRadius.md,
                        ),
                        child: const Icon(
                          Icons.receipt_long_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              invoice.label,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${invoice.invoiceNumber ?? invoice.periodKey} • ${_currency.format(invoice.amount)} • ${_statusLabel(invoice.status)}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Download invoice',
                        onPressed: _downloadingId == invoice.id
                            ? null
                            : () => _downloadInvoice(invoice),
                        icon: _downloadingId == invoice.id
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.download_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _pdfInfo(String label, List<String> lines, {bool right = false}) {
    return pw.Column(
      crossAxisAlignment: right
          ? pw.CrossAxisAlignment.end
          : pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 9,
            color: PdfColors.grey600,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 6),
        ...lines.map(
          (line) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(line, textAlign: right ? pw.TextAlign.right : null),
          ),
        ),
      ],
    );
  }

  pw.Widget _pdfTableCell(
    String text, {
    bool header = false,
    bool right = false,
    String? subtext,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(11),
      child: pw.Column(
        crossAxisAlignment: right
            ? pw.CrossAxisAlignment.end
            : pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            text,
            textAlign: right ? pw.TextAlign.right : null,
            style: pw.TextStyle(
              color: header ? PdfColors.white : PdfColors.black,
              fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: header ? 9 : 11,
            ),
          ),
          if (subtext != null) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              subtext,
              style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 9),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _pdfAmountRow(String label, double amount, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            _pdfMoney(amount),
            style: pw.TextStyle(
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  String _pdfMoney(double value) => 'INR ${value.toStringAsFixed(2)}';
  String _pdfDate(DateTime? value) =>
      value == null ? '-' : _date.format(value.toLocal());
  String _invoiceTypeLabel(String? value) => switch (value) {
    'maintenance' => 'Maintenance charge',
    'subscription' => 'Subscription charge',
    'add_on' => 'Add-on charge',
    'service' => 'Service charge',
    _ => 'Billing charge',
  };
  String _statusLabel(String value) => value
      .split('_')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}
