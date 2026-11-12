import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_utils.dart';
import '../../../core/widgets/icon_mapper.dart';
import '../../../l10n/app_strings.dart';
import '../../dashboard/presentation/dashboard_controller.dart';
import '../domain/account_model.dart';
import 'accounts_controller.dart';

class AccountFormSheet extends ConsumerStatefulWidget {
  const AccountFormSheet({
    super.key,
    this.existing,
  });

  final AccountModel? existing;

  @override
  ConsumerState<AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends ConsumerState<AccountFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _institutionController;
  late final TextEditingController _last4Controller;
  late final TextEditingController _openingBalanceController;
  late AccountType _selectedType;
  late String _selectedColor;
  late String _selectedIcon;
  late bool _includeInNetWorth;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final AccountModel? acc = widget.existing;
    _nameController = TextEditingController(text: acc?.name ?? '');
    _institutionController = TextEditingController(
      text: acc?.institution ?? '',
    );
    _last4Controller = TextEditingController(
      text: acc?.accountNumberLast4 ?? '',
    );
    _openingBalanceController = TextEditingController(
      text: acc != null
          ? MoneyUtils.toEditableString(acc.openingBalance)
          : '0',
    );
    _selectedType = acc?.type ?? AccountType.bank;
    _selectedColor = acc?.color ?? AccountType.bank.defaultColor;
    _selectedIcon = acc?.icon ?? AccountType.bank.defaultIcon;
    _includeInNetWorth = acc?.includeInNetWorth ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _institutionController.dispose();
    _last4Controller.dispose();
    _openingBalanceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final int? openingSatang = MoneyUtils.parseToSatang(
      _openingBalanceController.text.isEmpty
          ? '0'
          : _openingBalanceController.text,
      allowNegative: true,
      allowZero: true,
    );
    final AppStrings strings = AppStrings.of(context);
    if (openingSatang == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.tr('ยอดยกมาไม่ถูกต้อง', 'Invalid opening balance'),
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    HapticFeedback.lightImpact();

    try {
      AccountModel saved;
      if (widget.existing == null) {
        saved = await ref
            .read(accountsControllerProvider.notifier)
            .createAccount(
              name: _nameController.text.trim(),
              type: _selectedType,
              institution: _institutionController.text.trim(),
              accountNumberLast4: _last4Controller.text.trim(),
              openingBalance: openingSatang,
              color: _selectedColor,
              icon: _selectedIcon,
              includeInNetWorth: _includeInNetWorth,
            );
      } else {
        saved = await ref
            .read(accountsControllerProvider.notifier)
            .updateAccount(
              widget.existing!.id,
              name: _nameController.text.trim(),
              type: _selectedType,
              institution: _institutionController.text.trim(),
              accountNumberLast4: _last4Controller.text.trim(),
              openingBalance: openingSatang,
              color: _selectedColor,
              icon: _selectedIcon,
              includeInNetWorth: _includeInNetWorth,
            );
      }

      ref.read(dashboardControllerProvider.notifier).refresh();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(saved);
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.localizedMessage(strings))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);
    final bool isEditing = widget.existing != null;
    final Color activeColor = AppColors.fromHex(_selectedColor);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    isEditing ? strings.editAccount : strings.addAccount,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                strings.accountType,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AccountType.values.map((AccountType type) {
                  final bool selected = type == _selectedType;
                  return ChoiceChip(
                    label: Text(type.label(strings)),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        _selectedType = type;
                        if (!isEditing) {
                          _selectedIcon = type.defaultIcon;
                          _selectedColor = type.defaultColor;
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: strings.accountName,
                  prefixIcon: Icon(
                    IconMapper.resolve(_selectedIcon),
                    color: activeColor,
                  ),
                ),
                validator: (String? v) {
                  if (v == null || v.trim().isEmpty) {
                    return strings.tr(
                      'กรุณากรอกชื่อบัญชี',
                      'Please enter account name',
                    );
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _institutionController,
                      decoration: InputDecoration(
                        labelText: strings.institution,
                        hintText: 'KBank, SCB, TrueMoney...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _last4Controller,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: InputDecoration(
                        labelText: strings.last4Digits,
                        counterText: '',
                        hintText: '1234',
                      ),
                      validator: (String? v) {
                        final String trimmed = (v ?? '').trim();
                        if (trimmed.isNotEmpty &&
                            !RegExp(r'^\d{4}$').hasMatch(trimmed)) {
                          return strings.tr('ต้องเป็นตัวเลข 4 หลัก', '4 digits');
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _openingBalanceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: InputDecoration(
                  labelText: strings.openingBalance,
                  prefixText: '฿ ',
                  helperText: strings.tr(
                    'ใส่ค่าติดลบได้สำหรับหนี้บัตรเครดิต เช่น -5000.00',
                    'Negative values allowed for credit card debt',
                  ),
                ),
                validator: (String? v) {
                  final String raw = (v == null || v.trim().isEmpty) ? '0' : v;
                  final int? parsed = MoneyUtils.parseToSatang(
                    raw,
                    allowNegative: true,
                    allowZero: true,
                  );
                  if (parsed == null) {
                    return strings.tr(
                      'รูปแบบจำนวนเงินไม่ถูกต้อง (ทศนิยมไม่เกิน 2 ตำแหน่ง)',
                      'Invalid amount format (max 2 decimals)',
                    );
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  strings.includeInNetWorth,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                value: _includeInNetWorth,
                onChanged: (bool val) {
                  setState(() => _includeInNetWorth = val);
                },
              ),
              const SizedBox(height: 12),
              Text(
                strings.selectColor,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: AppColors.presetHexColors.map((String hex) {
                  final Color c = AppColors.fromHex(hex);
                  final bool selected =
                      hex.toUpperCase() == _selectedColor.toUpperCase();
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = hex),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(
                                color: theme.colorScheme.onSurface,
                                width: 3,
                              )
                            : null,
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text(
                strings.selectIcon,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: IconMapper.allKeys.length,
                  itemBuilder: (BuildContext context, int index) {
                    final String key = IconMapper.allKeys[index];
                    final bool selected = key == _selectedIcon;
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _selectedIcon = key),
                      child: Container(
                        decoration: BoxDecoration(
                          color: selected
                              ? activeColor.withAlpha(36)
                              : theme.colorScheme.surfaceContainerHighest
                                    .withAlpha(60),
                          borderRadius: BorderRadius.circular(12),
                          border: selected
                              ? Border.all(color: activeColor, width: 2)
                              : null,
                        ),
                        child: Icon(
                          IconMapper.resolve(key),
                          color: selected
                              ? activeColor
                              : theme.colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(strings.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
