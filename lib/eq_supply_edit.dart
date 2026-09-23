import 'package:flutter/material.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/models/equipment_supply.dart';
import 'package:oruma_app/services/equipment_supply_service.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';
import 'package:oruma_app/widgets/module_theme.dart';

const _equipmentSupplyStrong = Color(0xFFB45309);
const _equipmentSupplyIconSurface = Color(0xFFFEF3C7);

class EqSupplyEdit extends StatefulWidget {
  final EquipmentSupply supply;
  const EqSupplyEdit({super.key, required this.supply});

  @override
  State<EqSupplyEdit> createState() => _EqSupplyEditState();
}

class _EqSupplyEditState extends State<EqSupplyEdit> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _notesController;
  late TextEditingController _careOfController;
  late TextEditingController _receiverNameController;
  late TextEditingController _receiverPhoneController;
  late TextEditingController _receiverAddressController;
  late TextEditingController _receiverPlaceController;

  bool _submitting = false;
  bool _loading = true;
  late EquipmentSupply _supply;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with empty values
    _notesController = TextEditingController();
    _careOfController = TextEditingController();
    _receiverNameController = TextEditingController();
    _receiverPhoneController = TextEditingController();
    _receiverAddressController = TextEditingController();
    _receiverPlaceController = TextEditingController();

    _loadSupplyData();
  }

  Future<void> _loadSupplyData() async {
    try {
      final supply = await EquipmentSupplyService.getById(widget.supply.id!);
      if (mounted) {
        setState(() {
          _supply = supply;
          _notesController.text = supply.notes ?? '';
          _careOfController.text = supply.careOf ?? '';
          _receiverNameController.text = supply.receiverName ?? '';
          _receiverPhoneController.text = supply.receiverPhone ?? '';
          _receiverAddressController.text = supply.receiverAddress ?? '';
          _receiverPlaceController.text = supply.receiverPlace ?? '';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading supply: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _careOfController.dispose();
    _receiverNameController.dispose();
    _receiverPhoneController.dispose();
    _receiverAddressController.dispose();
    _receiverPlaceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final updates = {
        'careOf': _careOfController.text.trim(),
        'receiverName': _receiverNameController.text.trim(),
        'receiverPhone': _receiverPhoneController.text.trim(),
        'receiverAddress': _receiverAddressController.text.trim(),
        'receiverPlace': _receiverPlaceController.text.trim(),
        'notes': _notesController.text.trim(),
      };

      await EquipmentSupplyService.updateSupply(widget.supply.id!, updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Equipment supply updated successfully!'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
            'Edit Equipment Supply',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        body: _loading
            ? const AppListSkeleton(itemCount: 4)
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        AppInsets.screenHorizontal(context),
                        AppSpacing.md,
                        AppInsets.screenHorizontal(context),
                        AppSpacing.lg,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Equipment Info Card
                            _buildSectionCard(
                              title: 'Equipment Details',
                              icon: Icons.inventory_2_outlined,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _equipmentSupplyIconSurface,
                                    borderRadius: AppRadius.sm,
                                    border: Border.all(
                                      color: _equipmentSupplyStrong.withValues(
                                        alpha: 0.16,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _supply.equipmentName.toUpperCase(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'ID: ${_supply.equipmentUniqueId}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Handover Details
                            _buildSectionCard(
                              title: 'Handover & Receiver',
                              icon: Icons.handshake_outlined,
                              children: [
                                _buildTextField(
                                  controller: _careOfController,
                                  label: 'C/O (Care Of)',
                                  hint: 'Volunteer / Member Name',
                                  icon: Icons.supervised_user_circle_outlined,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTextField(
                                        controller: _receiverNameController,
                                        label: 'Name',
                                        hint: 'Name',
                                        icon: Icons.person_pin_circle_outlined,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildTextField(
                                        controller: _receiverPhoneController,
                                        label: 'Phone',
                                        hint: 'Phone',
                                        icon: Icons.phone_outlined,
                                        keyboardType: TextInputType.phone,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _receiverAddressController,
                                  label: 'Address',
                                  hint: 'Address',
                                  icon: Icons.location_on_outlined,
                                  maxLines: 3,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _receiverPlaceController,
                                  label: 'Place',
                                  hint: 'Place',
                                  icon: Icons.map_outlined,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _notesController,
                                  label: 'Notes',
                                  hint: 'Any additional instructions...',
                                  icon: Icons.notes_rounded,
                                  maxLines: 2,
                                ),
                              ],
                            ),
                            const SizedBox(height: 100), // Space for bottom bar
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom Action Bar
                  Container(
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
                      child: Row(
                        children: [
                          Expanded(
                            child: AppSecondaryButton(
                              label: 'Cancel',
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            flex: 2,
                            child: AppPrimaryButton(
                              label: 'Save Changes',
                              icon: Icons.save_outlined,
                              fullWidth: true,
                              loading: _submitting,
                              onPressed: _submitting ? null : _submit,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
        contentMaxWidth: 900,
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return AppCard(
      padding: AppInsets.card,
      surfaceLevel: AppSurfaceLevel.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: _equipmentSupplyIconSurface,
                  borderRadius: AppRadius.sm,
                ),
                child: Icon(icon, color: _equipmentSupplyStrong, size: 18),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      minLines: 1,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: _compactPrefixIcon(icon),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 50,
          minHeight: 50,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        filled: true,
        fillColor: AppColors.surface1,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(
            color: _equipmentSupplyStrong,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
        ),
      ),
    );
  }

  Widget _compactPrefixIcon(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      margin: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: _equipmentSupplyIconSurface,
        borderRadius: AppRadius.sm,
      ),
      child: Icon(icon, color: _equipmentSupplyStrong, size: AppIcons.normal),
    );
  }
}
