import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_utils.dart';
import '../../../core/widgets/account_badge.dart';
import '../../../core/widgets/icon_mapper.dart';
import '../../../core/widgets/monevo_feedback.dart';
import '../../../core/widgets/thai_institution_catalog.dart';
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
  bool _userChangedType = false;
  String? _lastAutoName;

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
    _userChangedType = acc != null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _institutionController.dispose();
    _last4Controller.dispose();
    _openingBalanceController.dispose();
    super.dispose();
  }

  ThaiInstitution? get _matchedInstitution => ThaiInstitutionCatalog.match(
    _institutionController.text,
    accountName: _nameController.text,
  );

  void _applyInstitution(ThaiInstitution picked) {
    HapticFeedback.selectionClick();
    final String currentName = _nameController.text.trim();
    final bool shouldAutofillName =
        widget.existing == null &&
        (currentName.isEmpty || currentName == _lastAutoName);

    setState(() {
      _institutionController.text = picked.storedName;
      _selectedColor = picked.primaryHex;
      _selectedIcon = IconMapper.allKeys.contains(picked.fallbackIconKey)
          ? picked.fallbackIconKey
          : picked.defaultType.defaultIcon;
      if (!_userChangedType && widget.existing == null) {
        _selectedType = picked.defaultType;
      }
      if (shouldAutofillName) {
        _nameController.text = picked.storedName;
        _lastAutoName = picked.storedName;
      }
    });
  }

  void _clearInstitution() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_nameController.text.trim() == _lastAutoName) {
        _nameController.clear();
        _lastAutoName = null;
      }
      _institutionController.clear();
      if (widget.existing == null) {
        _selectedIcon = _selectedType.defaultIcon;
        _selectedColor = _selectedType.defaultColor;
      }
    });
  }

  Future<void> _openInstitutionPicker() async {
    final ThaiInstitutionPickerResult? result =
        await ThaiInstitutionPickerSheet.show(
          context,
          selected: _matchedInstitution,
        );
    if (!mounted || result == null) {
      return;
    }
    if (result.cleared) {
      _clearInstitution();
    } else if (result.institution != null) {
      _applyInstitution(result.institution!);
    }
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

      final BuildContext? targetContext = rootNavigatorKey.currentContext;
      if (targetContext != null && targetContext.mounted) {
        MonevoAlert.showSuccess(
          targetContext,
          title: widget.existing == null
              ? 'สร้างบัญชีใหม่สำเร็จ!'
              : 'อัปเดตข้อมูลบัญชีเรียบร้อย!',
          subtitle: saved.name,
          amountFormatted: MoneyUtils.formatSatang(saved.balance),
          accountName: (saved.institution != null &&
                  saved.institution!.trim().isNotEmpty)
              ? saved.institution!
              : saved.type.label(strings),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      MonevoAlert.showError(
        context,
        title: 'บันทึกบัญชีไม่สำเร็จ',
        message: e.localizedMessage(strings),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);
    final bool isEditing = widget.existing != null;
    final Color activeColor = AppColors.fromHex(_selectedColor);
    final ThaiInstitution? matchedInstitution = _matchedInstitution;
    final List<String> colorChoices = <String>[
      if (!AppColors.presetHexColors.any(
        (String c) => c.toUpperCase() == _selectedColor.toUpperCase(),
      ))
        _selectedColor,
      ...AppColors.presetHexColors,
    ];

    final String previewName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : (matchedInstitution?.storedName ??
              strings.tr('ชื่อบัญชีใหม่', 'New Account'));
    final String previewSub = <String>[
      if (_institutionController.text.trim().isNotEmpty)
        _institutionController.text.trim(),
      if (_last4Controller.text.trim().isNotEmpty)
        '•••• ${_last4Controller.text.trim()}',
    ].join(' · ');

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
              const SizedBox(height: 10),
              // Live preview of account badge & styling
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: activeColor.withAlpha(18),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: activeColor.withAlpha(65)),
                ),
                child: Row(
                  children: <Widget>[
                    AccountBrandAvatar(
                      institution: _institutionController.text,
                      accountName: _nameController.text,
                      iconKey: _selectedIcon,
                      colorHex: _selectedColor,
                      size: 48,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            previewName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            previewSub.isNotEmpty
                                ? previewSub
                                : _selectedType.label(strings),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (matchedInstitution != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: activeColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          matchedInstitution.shortLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: activeColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Thai Banks & Loans Catalog Picker
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      strings.tr(
                        'ธนาคาร / สินเชื่อ / วอลเล็ทในไทย',
                        'Thai Bank / Loan / Wallet',
                      ),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _openInstitutionPicker,
                    icon: const Icon(Icons.search_rounded, size: 17),
                    label: Text(
                      strings.tr(
                        'ค้นหาทั้งหมด (${ThaiInstitutionCatalog.all.length})',
                        'Browse All (${ThaiInstitutionCatalog.all.length})',
                      ),
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: ThaiInstitutionCatalog.popularItems.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (BuildContext context, int index) {
                    if (index == ThaiInstitutionCatalog.popularItems.length) {
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _openInstitutionPicker,
                        child: Container(
                          width: 72,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withAlpha(90),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant
                                  .withAlpha(110),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(
                                Icons.apps_rounded,
                                size: 28,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                strings.tr('ดูเพิ่มเติม', 'More...'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final ThaiInstitution item =
                        ThaiInstitutionCatalog.popularItems[index];
                    final bool isSelected = matchedInstitution?.id == item.id;
                    final Color itemColor = AppColors.fromHex(item.primaryHex);

                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _applyInstitution(item),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 68,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? itemColor.withAlpha(28)
                              : theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? itemColor
                                : theme.colorScheme.outlineVariant
                                      .withAlpha(100),
                            width: isSelected ? 1.8 : 1.0,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            ThaiInstitutionBadge(institution: item, size: 34),
                            const SizedBox(height: 5),
                            Text(
                              item.shortLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10.5,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isSelected
                                    ? itemColor
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
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
                        _userChangedType = true;
                        if (!isEditing && _matchedInstitution == null) {
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
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: strings.accountName,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(10),
                    child: AccountBrandAvatar(
                      institution: _institutionController.text,
                      accountName: _nameController.text,
                      iconKey: _selectedIcon,
                      colorHex: _selectedColor,
                      size: 26,
                      borderRadius: 8,
                    ),
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
                      maxLength: 80,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: strings.institution,
                        counterText: '',
                        hintText: strings.tr(
                          'KBank, SCB, เงินติดล้อ, กยศ...',
                          'KBank, SCB, KTC, Tidlor...',
                        ),
                        suffixIcon: _institutionController.text.isNotEmpty
                            ? IconButton(
                                tooltip: strings.clear,
                                onPressed: _clearInstitution,
                                icon: const Icon(Icons.close_rounded, size: 18),
                              )
                            : IconButton(
                                tooltip: strings.tr(
                                  'เลือกจากรายการ',
                                  'Browse list',
                                ),
                                onPressed: _openInstitutionPicker,
                                icon: const Icon(
                                  Icons.account_balance_outlined,
                                  size: 18,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _last4Controller,
                      onChanged: (_) => setState(() {}),
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
                    'ใส่ค่าติดลบได้สำหรับหนี้บัตรเครดิต/สินเชื่อ เช่น -5000.00',
                    'Negative values allowed for credit card / loan debt',
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
                children: colorChoices.map((String hex) {
                  final Color c = AppColors.fromHex(hex);
                  final bool selected =
                      hex.toUpperCase() == _selectedColor.toUpperCase();
                  final bool lightCheck =
                      ThemeData.estimateBrightnessForColor(c) ==
                      Brightness.light;
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
                          ? Icon(
                              Icons.check_rounded,
                              color: lightCheck ? Colors.black87 : Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text(
                matchedInstitution != null
                    ? strings.tr(
                        '${strings.selectIcon} (สำรองเมื่อไม่ใช้โลโก้)',
                        '${strings.selectIcon} (Fallback Icon)',
                      )
                    : strings.selectIcon,
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
              BouncyTap(
                onTap: _saving ? null : _submit,
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: null,
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
