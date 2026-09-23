import 'package:flutter/material.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/models/equipment.dart';
import 'package:oruma_app/services/equipment_service.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';
import 'package:oruma_app/widgets/module_theme.dart';

const _equipmentStrong = Color(0xFFB45309);
const _equipmentIconSurface = Color(0xFFFEF3C7);

class EquipmentRegistration extends StatefulWidget {
  const EquipmentRegistration({super.key});

  @override
  State<EquipmentRegistration> createState() => _EquipmentRegistrationState();
}

class _EquipmentRegistrationState extends State<EquipmentRegistration> {
  final _formKey = GlobalKey<FormState>();

  bool _isSubmitting = false;
  String? _errorMessage;

  // Controllers
  final TextEditingController purchasedFromController = TextEditingController();
  final TextEditingController placeController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController itemNameController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();

  // Dropdown Items
  final List<String> items = [
    'Wheelchair',
    'Walker',
    'Oxygen Cylinder',
    'Crutches',
    'Air bed',
    'Hospital cot',
    'Concentrator',
  ];

  String? selectedValue;

  // List to store saved equipment
  final List<Equipment> equipmentList = [];

  // Serial number counter
  int counter = 1;

  // Generate serial number like WA01, WH02, etc.
  String generateSerial(String name) {
    String prefix = name.isNotEmpty
        ? name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase()
        : 'EQ';
    return "$prefix${counter.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    purchasedFromController.dispose();
    placeController.dispose();
    phoneController.dispose();
    itemNameController.dispose();
    quantityController.dispose();
    super.dispose();
  }

  Future<void> submitEquipment() async {
    if (!_formKey.currentState!.validate()) return;

    final qty = int.tryParse(quantityController.text.trim()) ?? 0;
    if (qty <= 0) {
      setState(() => _errorMessage = 'Quantity must be greater than 0');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final response = await EquipmentService.createEquipment(
        name: itemNameController.text.trim(),
        quantity: qty,
        purchasedFrom: purchasedFromController.text.trim(),
        place: placeController.text.trim(),
        phone: phoneController.text.trim(),
        serialNo: generateSerial(itemNameController.text.trim()),
      );

      setState(() {
        equipmentList.insertAll(0, response.equipment);
        counter += qty;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Equipment saved: ${itemNameController.text.trim()} ($qty items)',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      _clearForm();
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _clearForm() {
    itemNameController.clear();
    quantityController.clear();
    purchasedFromController.clear();
    placeController.clear();
    phoneController.clear();
    setState(() {
      selectedValue = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ModuleTheme(
      palette: ModulePalettes.equipmentSupply,
      child: AdaptiveAppScaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          toolbarHeight: 72,
          titleSpacing: AppSpacing.md,
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.text,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            'Equipment Registration',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        contentMaxWidth: 900,
        bottomSheet: Container(
          padding: EdgeInsets.fromLTRB(
            AppInsets.screenHorizontal(context),
            AppSpacing.sm,
            AppInsets.screenHorizontal(context),
            AppSpacing.md,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surfaceFloating,
            border: Border(top: BorderSide(color: AppColors.border)),
            boxShadow: AppShadow.medium,
          ),
          child: SafeArea(
            top: false,
            child: AppPrimaryButton(
              label: 'Submit',
              icon: Icons.save_outlined,
              fullWidth: true,
              loading: _isSubmitting,
              onPressed: _isSubmitting ? null : submitEquipment,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppInsets.screenHorizontal(context),
            AppSpacing.md,
            AppInsets.screenHorizontal(context),
            112,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                if (_errorMessage != null) _errorBanner(),
                AppCard(
                  padding: AppInsets.card,
                  surfaceLevel: AppSurfaceLevel.elevated,
                  child: Column(
                    children: [
                      _field(
                        controller: itemNameController,
                        label: 'Item Name',
                        icon: Icons.inventory_2_outlined,
                        validator: (val) => val == null || val.isEmpty
                            ? 'Enter Item Name'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _field(
                        controller: quantityController,
                        label: 'Quantity',
                        icon: Icons.numbers_outlined,
                        keyboardType: TextInputType.number,
                        validator: (val) => val == null || val.isEmpty
                            ? 'Enter Quantity'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<String>(
                        initialValue: selectedValue,
                        style: AppTypography.dropdownTextStyle(context),
                        decoration: _inputDecoration(
                          'Choose equipment',
                          Icons.category_outlined,
                        ),
                        items: items.map((item) {
                          return DropdownMenuItem<String>(
                            value: item,
                            child: Text(item),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            selectedValue = newValue;
                            if (newValue != null) {
                              itemNameController.text = newValue;
                            }
                          });
                        },
                        validator: (val) =>
                            val == null ? 'Please select equipment' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  padding: AppInsets.card,
                  surfaceLevel: AppSurfaceLevel.elevated,
                  child: Column(
                    children: [
                      _field(
                        controller: purchasedFromController,
                        label: 'Purchased From',
                        icon: Icons.store_outlined,
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Enter value' : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _field(
                        controller: placeController,
                        label: 'Place',
                        icon: Icons.location_on_outlined,
                        validator: (val) => val == null || val.isEmpty
                            ? 'Enter the place'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _field(
                        controller: phoneController,
                        label: 'Phone Number',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Enter the Phone Number';
                          }
                          if (!RegExp(r'^[0-9]{10}$').hasMatch(val)) {
                            return 'Enter a valid 10-digit number';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                if (equipmentList.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Recently Added Equipment',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...equipmentList.map(_recentEquipmentCard),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: AppInsets.md,
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: AppRadius.input,
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: _inputDecoration(label, icon),
      validator: validator,
    );
  }

  Widget _recentEquipmentCard(Equipment eq) {
    final prefix = eq.serialNo.length >= 2 ? eq.serialNo.substring(0, 2) : 'EQ';
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: AppInsets.md,
      surfaceLevel: AppSurfaceLevel.elevated,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: _equipmentIconSurface,
              borderRadius: AppRadius.md,
            ),
            alignment: Alignment.center,
            child: Text(
              prefix,
              style: const TextStyle(
                color: _equipmentStrong,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${eq.serialNo} - ${eq.name}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Qty: ${eq.quantity} | From: ${eq.purchasedFrom}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  'Place: ${eq.place} | Phone: ${eq.phone}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      isDense: true,
      hintText: label,
      hintStyle: const TextStyle(color: AppColors.textSecondary),
      prefixIcon: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.all(6),
        decoration: const BoxDecoration(
          color: _equipmentIconSurface,
          borderRadius: AppRadius.sm,
        ),
        child: Icon(icon, color: _equipmentStrong, size: AppIcons.normal),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 50, minHeight: 50),
      floatingLabelBehavior: FloatingLabelBehavior.never,
      filled: true,
      fillColor: AppColors.surface1,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      border: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(color: _equipmentStrong, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
      ),
    );
  }
}
