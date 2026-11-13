import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/storage/local_image_storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/money_utils.dart';
import '../../../core/widgets/account_badge.dart';
import '../../../core/widgets/icon_mapper.dart';
import '../../../core/widgets/monevo_feedback.dart';
import '../../../l10n/app_strings.dart';
import '../../accounts/domain/account_model.dart';
import '../../accounts/presentation/account_form_sheet.dart';
import '../../accounts/presentation/accounts_controller.dart';
import '../../categories/domain/category_model.dart';
import '../../categories/presentation/categories_controller.dart';
import '../../categories/presentation/categories_screen.dart';
import '../../dashboard/presentation/dashboard_controller.dart';
import '../../settings/presentation/settings_controller.dart';
import '../domain/transaction_model.dart';
import 'transactions_controller.dart';

class TransactionFormSheet extends ConsumerStatefulWidget {
  const TransactionFormSheet({
    super.key,
    this.existing,
    this.initialAccountId,
    this.initialType,
  });

  final TransactionModel? existing;
  final String? initialAccountId;
  final TransactionType? initialType;

  @override
  ConsumerState<TransactionFormSheet> createState() =>
      _TransactionFormSheetState();
}

class _TransactionFormSheetState extends ConsumerState<TransactionFormSheet> {
  late TransactionType _type;
  late String _amountInput;
  String? _accountId;
  String? _toAccountId;
  String? _categoryId;
  late DateTime _occurredAt;
  late final TextEditingController _payeeController;
  late final TextEditingController _noteController;
  bool _showKeypad = true;
  bool _showExtraInfo = false;
  bool _saving = false;

  // Section 3.3 Local Image Storage state (device-only, never uploaded to server)
  PickedLocalImage? _stagedImage;
  Uint8List? _existingImageBytes;
  LocalImageAttachment? _existingAttachment;
  bool _removeExistingImage = false;

  @override
  void initState() {
    super.initState();
    final TransactionModel? tx = widget.existing;
    _type = tx?.type ?? widget.initialType ?? TransactionType.expense;
    _amountInput = tx != null
        ? MoneyUtils.toEditableString(tx.amount)
        : '0';
    _accountId = tx?.accountId ?? widget.initialAccountId;
    _toAccountId = tx?.toAccountId;
    _categoryId = tx?.categoryId;
    _occurredAt = tx?.occurredAt.toLocal() ?? DateTime.now();
    _payeeController = TextEditingController(text: tx?.payee ?? '');
    _noteController = TextEditingController(text: tx?.note ?? '');
    _showExtraInfo = tx?.payee?.trim().isNotEmpty ?? false;
    if (tx != null) {
      Future<void>.microtask(() => _loadExistingLocalAttachment(tx.id));
    }
  }

  Future<void> _loadExistingLocalAttachment(String transactionId) async {
    final LocalImageAttachmentsController ctrl = ref.read(
      localImageAttachmentsProvider.notifier,
    );
    await ctrl.reload();
    final LocalImageAttachment? att = ctrl.getForTransaction(transactionId);
    if (att == null || !mounted) {
      return;
    }
    final Uint8List? bytes = await ctrl.readBytes(att);
    if (!mounted) {
      return;
    }
    setState(() {
      _existingAttachment = att;
      _existingImageBytes = bytes;
      _showExtraInfo = true;
    });
  }

  String _formatDisplayAmount(String raw) {
    final List<String> parts = raw.split('.');
    final String intPart = parts.first.isEmpty ? '0' : parts.first;
    final StringBuffer formattedInt = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) {
        formattedInt.write(',');
      }
      formattedInt.write(intPart[i]);
    }
    if (parts.length > 1) {
      return '฿$formattedInt.${parts[1]}';
    }
    return '฿$formattedInt';
  }

  Future<void> _chooseLocalImageSource() async {
    final AppStrings strings = AppStrings.of(context);
    final LocalImagePickSource? source =
        await showModalBottomSheet<LocalImagePickSource>(
          context: context,
          useSafeArea: true,
          builder: (BuildContext ctx) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Text(
                        strings.tr(
                          'แนบรูปสลิป / ใบเสร็จ (จัดเก็บในเครื่องเท่านั้น)',
                          'Attach Slip / Receipt (Stored on device only)',
                        ),
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.photo_library_outlined),
                      title: Text(
                        strings.tr('เลือกจากคลังรูปภาพ', 'Choose from Photo Library'),
                      ),
                      onTap: () =>
                          Navigator.of(ctx).pop(LocalImagePickSource.photoLibrary),
                    ),
                    ListTile(
                      leading: const Icon(Icons.camera_alt_outlined),
                      title: Text(
                        strings.tr('ถ่ายรูปสลิป / ใบเสร็จ', 'Take Photo with Camera'),
                      ),
                      onTap: () =>
                          Navigator.of(ctx).pop(LocalImagePickSource.camera),
                    ),
                    ListTile(
                      leading: const Icon(Icons.folder_open_rounded),
                      title: Text(
                        strings.tr(
                          'เลือกไฟล์รูปภาพจากเครื่อง (File Picker)',
                          'Browse Device Files (File Picker)',
                        ),
                      ),
                      onTap: () =>
                          Navigator.of(ctx).pop(LocalImagePickSource.filePicker),
                    ),
                  ],
                ),
              ),
            );
          },
        );

    if (source == null || !mounted) {
      return;
    }

    try {
      final PickedLocalImage? picked = await ref
          .read(localImageAttachmentsProvider.notifier)
          .pickImage(source);
      if (picked == null || !mounted) {
        return;
      }
      setState(() {
        _stagedImage = picked;
        _removeExistingImage = false;
      });
    } on LocalImagePermissionException catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.tr(
              'ไม่สามารถเข้าถึงไฟล์หรือรูปภาพได้ กรุณาอนุญาตสิทธิ์ในการตั้งค่าอุปกรณ์',
              'Permission denied. Please grant photo/file access in device settings.',
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.tr(
              'เกิดข้อผิดพลาดในการเลือกไฟล์รูปภาพ',
              'Could not load the selected image file.',
            ),
          ),
        ),
      );
    }
  }

  void _openFullscreenImagePreview(Uint8List bytes, String fileName) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: <Widget>[
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.5,
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: SafeArea(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          fileName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _payeeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onKeypadTap(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      if (key == 'C') {
        _amountInput = '0';
        return;
      }
      if (key == '⌫') {
        if (_amountInput.length <= 1) {
          _amountInput = '0';
        } else {
          _amountInput = _amountInput.substring(0, _amountInput.length - 1);
        }
        return;
      }
      if (key == '.') {
        if (!_amountInput.contains('.')) {
          _amountInput = '$_amountInput.';
        }
        return;
      }
      if (key == '00') {
        if (_amountInput == '0') {
          return;
        }
        if (_amountInput.contains('.')) {
          final String decimals = _amountInput.split('.')[1];
          if (decimals.isEmpty) {
            _amountInput = '${_amountInput}00';
          } else if (decimals.length == 1) {
            _amountInput = '${_amountInput}0';
          }
          return;
        }
        if (_amountInput.length <= 8) {
          _amountInput = '${_amountInput}00';
        }
        return;
      }

      // Digit 0-9
      if (_amountInput.contains('.')) {
        final String decimals = _amountInput.split('.')[1];
        if (decimals.length >= 2) {
          return;
        }
        _amountInput = '$_amountInput$key';
      } else {
        if (_amountInput == '0') {
          _amountInput = key;
        } else if (_amountInput.length < 10) {
          _amountInput = '$_amountInput$key';
        }
      }
    });
  }

  Future<void> _pickDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) {
      return;
    }
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _occurredAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime?.hour ?? _occurredAt.hour,
        pickedTime?.minute ?? _occurredAt.minute,
      );
    });
  }

  Future<void> _deleteExisting() async {
    final TransactionModel? existing = widget.existing;
    if (existing == null) {
      return;
    }
    final AppStrings strings = AppStrings.of(context);
    final bool hasAttachedImage = _existingAttachment != null;

    // Section 3.3: When deleting a transaction that has an attached image,
    // provide explicit options for managing the associated local image file.
    bool deleteLocalFile = true;
    final String? action = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(strings.delete),
          content: Text(
            hasAttachedImage
                ? strings.tr(
                    'รายการธุรกรรมนี้มีรูปภาพสลิป/ใบเสร็จที่จัดเก็บไว้ในเครื่อง คุณต้องการจัดการรูปภาพที่เกี่ยวข้องอย่างไร?',
                    'This transaction has a locally stored receipt/slip image. How would you like to handle the image file?',
                  )
                : strings.tr(
                    'คุณต้องการลบรายการธุรกรรมนี้ใช่หรือไม่?',
                    'Are you sure you want to delete this transaction?',
                  ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('cancel'),
              child: Text(strings.cancel),
            ),
            if (hasAttachedImage)
              OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop('keep_image'),
                child: Text(
                  strings.tr(
                    'ลบธุรกรรมแต่เก็บรูปไว้ในเครื่อง',
                    'Delete transaction, keep image',
                  ),
                ),
              ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop('delete_all'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
              child: Text(
                hasAttachedImage
                    ? strings.tr(
                        'ลบธุรกรรมและลบรูปภาพ',
                        'Delete transaction & image',
                      )
                    : strings.delete,
              ),
            ),
          ],
        );
      },
    );

    if (action == null || action == 'cancel' || !mounted) {
      return;
    }
    deleteLocalFile = action == 'delete_all';

    setState(() => _saving = true);
    try {
      await ref
          .read(transactionsControllerProvider.notifier)
          .deleteTransaction(existing.id, fallback: existing);
      if (hasAttachedImage) {
        await ref
            .read(localImageAttachmentsProvider.notifier)
            .removeForTransaction(
              existing.id,
              deleteLocalFile: deleteLocalFile,
            );
      }
      ref.read(accountsControllerProvider.notifier).loadAccounts();
      ref.read(dashboardControllerProvider.notifier).refresh();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop('deleted');

      final BuildContext? targetContext = rootNavigatorKey.currentContext;
      if (targetContext != null && targetContext.mounted) {
        MonevoAlert.showToast(
          targetContext,
          message: strings.tr(
            'ลบรายการธุรกรรมเรียบร้อยแล้ว',
            'Transaction deleted successfully',
          ),
          type: MonevoAlertType.info,
          icon: Icons.delete_outline_rounded,
        );
      }
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      MonevoAlert.showError(
        context,
        title: strings.tr('ลบรายการไม่สำเร็จ', 'Failed to delete transaction'),
        message: e.localizedMessage(strings),
      );
    }
  }

  Future<void> _submit(List<AccountModel> accounts) async {
    final AppStrings strings = AppStrings.of(context);
    final int? satang = MoneyUtils.parseToSatang(_amountInput);
    if (satang == null || satang <= 0) {
      MonevoAlert.showToast(
        context,
        message: strings.tr(
          'กรุณาระบุจำนวนเงินที่มากกว่า 0',
          'Please enter an amount greater than 0',
        ),
        type: MonevoAlertType.warning,
      );
      return;
    }

    final String? effectiveFromId =
        _accountId ?? (accounts.isNotEmpty ? accounts.first.id : null);
    if (effectiveFromId == null) {
      MonevoAlert.showToast(
        context,
        message: strings.tr(
          'กรุณาสร้างและเลือกบัญชีก่อนบันทึกรายการ',
          'Please create and select an account first',
        ),
        type: MonevoAlertType.warning,
      );
      return;
    }

    if (_type == TransactionType.transfer) {
      if (_toAccountId == null || _toAccountId == effectiveFromId) {
        MonevoAlert.showToast(
          context,
          message: strings.tr(
            'กรุณาเลือกบัญชีปลายทางที่ต่างจากบัญชีต้นทาง',
            'Please select a different destination account',
          ),
          type: MonevoAlertType.warning,
        );
        return;
      }
    }

    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    try {
      final TransactionModel savedTx;
      if (widget.existing == null) {
        savedTx = await ref
            .read(transactionsControllerProvider.notifier)
            .createTransaction(
              type: _type,
              amount: satang,
              accountId: effectiveFromId,
              toAccountId: _type == TransactionType.transfer
                  ? _toAccountId
                  : null,
              categoryId: _type == TransactionType.transfer
                  ? null
                  : _categoryId,
              occurredAt: _occurredAt,
              payee: _payeeController.text,
              note: _noteController.text,
            );
      } else {
        savedTx = await ref
            .read(transactionsControllerProvider.notifier)
            .updateTransaction(
              widget.existing!.id,
              type: _type,
              amount: satang,
              accountId: effectiveFromId,
              toAccountId: _type == TransactionType.transfer
                  ? _toAccountId
                  : null,
              categoryId: _type == TransactionType.transfer
                  ? null
                  : _categoryId,
              occurredAt: _occurredAt,
              payee: _payeeController.text,
              note: _noteController.text,
            );
      }

      // Section 3.3: Persist or remove local image attachment on the device only.
      if (_stagedImage != null) {
        await ref
            .read(localImageAttachmentsProvider.notifier)
            .attachImage(
              transactionId: savedTx.id,
              picked: _stagedImage!,
            );
      } else if (_removeExistingImage && _existingAttachment != null) {
        await ref
            .read(localImageAttachmentsProvider.notifier)
            .removeForTransaction(savedTx.id, deleteLocalFile: true);
      }

      if (!mounted) {
        return;
      }

      final AccountsState accountsState = ref.read(accountsControllerProvider);
      final CategoriesState categoriesState =
          ref.read(categoriesControllerProvider);
      final AccountModel? acct = accountsState.findById(savedTx.accountId);
      final CategoryModel? cat = categoriesState.findById(savedTx.categoryId);

      final String actionTitle = widget.existing == null
          ? (_type == TransactionType.expense
              ? 'บันทึกรายจ่ายเรียบร้อย!'
              : _type == TransactionType.income
                  ? 'บันทึกรายรับเรียบร้อย!'
                  : 'บันทึกการโอนเงินเรียบร้อย!')
          : 'อัปเดตรายการเรียบร้อย!';

      final Color amountColor = _type == TransactionType.income
          ? AppColors.income
          : _type == TransactionType.expense
              ? AppColors.expense
              : AppColors.transfer;

      Navigator.of(context).pop(true);

      final BuildContext? targetContext = rootNavigatorKey.currentContext;
      if (targetContext != null && targetContext.mounted) {
        MonevoAlert.showSuccess(
          targetContext,
          title: actionTitle,
          amountFormatted: MoneyUtils.formatSatang(satang),
          amountColor: amountColor,
          categoryName: cat?.name,
          accountName: acct?.name,
        );
      }
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      MonevoAlert.showError(
        context,
        title: 'บันทึกไม่สำเร็จ',
        message: e.localizedMessage(strings),
      );
    }
  }

  Future<void> _openAccountPicker({
    required String title,
    required List<AccountModel> accounts,
    required String? selectedId,
    required ValueChanged<String> onSelected,
    required AppStrings strings,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return _AccountPickerBottomSheet(
          title: title,
          accounts: accounts,
          selectedId: selectedId,
          strings: strings,
          onSelected: (String id) {
            Navigator.of(sheetContext).pop();
            onSelected(id);
          },
          onAddAccount: () async {
            Navigator.of(sheetContext).pop();
            final AccountModel? created =
                await showModalBottomSheet<AccountModel>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => const AccountFormSheet(),
                );
            if (created != null && mounted) {
              onSelected(created.id);
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final bool useBuddhistEra = ref.watch(
      settingsControllerProvider.select(
        (AppSettingsState s) => s.useBuddhistEra,
      ),
    );
    final List<AccountModel> accounts = ref
        .watch(accountsControllerProvider)
        .activeAccounts;
    final CategoriesState categoriesState = ref.watch(
      categoriesControllerProvider,
    );

    if (_accountId == null && accounts.isNotEmpty) {
      _accountId = accounts.first.id;
    }
    if (_type == TransactionType.transfer &&
        (_toAccountId == null || _toAccountId == _accountId) &&
        accounts.length > 1) {
      _toAccountId = accounts
          .firstWhere(
            (AccountModel a) => a.id != _accountId,
            orElse: () => accounts.first,
          )
          .id;
    }

    final AccountModel? selectedAccount = accounts
        .where((AccountModel a) => a.id == _accountId)
        .cast<AccountModel?>()
        .firstOrNull;
    final AccountModel? selectedToAccount = accounts
        .where((AccountModel a) => a.id == _toAccountId)
        .cast<AccountModel?>()
        .firstOrNull;

    final List<CategoryModel> availableCategories =
        _type == TransactionType.transfer
        ? <CategoryModel>[]
        : categoriesState.byType(
            _type == TransactionType.income
                ? CategoryType.income
                : CategoryType.expense,
            activeOnly: true,
          );

    final bool hasExtraContent =
        _payeeController.text.trim().isNotEmpty ||
        _stagedImage != null ||
        (!_removeExistingImage && _existingImageBytes != null);

    final String dateText =
        '${AppDateUtils.formatShortDate(_occurredAt, language: strings.language, useBuddhistEra: useBuddhistEra)} · '
        '${_occurredAt.hour.toString().padLeft(2, '0')}:'
        '${_occurredAt.minute.toString().padLeft(2, '0')}';

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBackground : const Color(0xFFF3F8F6),
        ),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _AmbientSheetRibbonPainter(isDark: isDark),
                ),
              ),
            ),
            SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 14,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // 1. Header with Glossy Emerald Wallet + Title/Subtitle + Close/Delete
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      const _GlossyWalletBadge(),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              widget.existing == null
                                  ? strings.tr(
                                      'บันทึกรายการใหม่',
                                      'New Transaction',
                                    )
                                  : strings.editTransaction,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              strings.tr(
                                'บันทึกรายรับ รายจ่าย อย่างรวดเร็ว',
                                'Record income & expenses quickly',
                              ),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.white60
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.existing != null)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: _saving ? null : _deleteExisting,
                          tooltip: strings.delete,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.expense,
                            size: 22,
                          ),
                        ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: strings.cancel,
                        icon: Icon(
                          Icons.close_rounded,
                          size: 23,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 2. 3-Segment Type Pill Switch (Expense / Income / Transfer)
                  _TypeSegmentedPillBar(
                    selectedType: _type,
                    strings: strings,
                    isDark: isDark,
                    onChanged: (TransactionType nextType) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _type = nextType;
                        _categoryId = null;
                      });
                    },
                  ),
                  const SizedBox(height: 11),

                  // 3. Currency & Large Amount Card
                  _AmountHeroCard(
                    formattedAmount: _formatDisplayAmount(_amountInput),
                    subtitle: strings.tr('บาทไทย', 'Thai Baht'),
                    isDark: isDark,
                    onTap: () => setState(() => _showKeypad = !_showKeypad),
                  ),

                  // 4. Fintech 4x4 Numeric Keypad
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: _showKeypad
                        ? Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: _AmountKeypad(
                              onKeyTap: _onKeypadTap,
                              isDark: isDark,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 10),

                  // 5. Expandable "+ เพิ่มข้อมูล" Mint Pill
                  BouncyTap(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _showExtraInfo = !_showExtraInfo);
                    },
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF12382C)
                            : const Color(0xFFD6F4E6),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF1F5D4A)
                              : const Color(0xFFB3E6D0),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            _showExtraInfo
                                ? Icons.remove_rounded
                                : Icons.add_rounded,
                            size: 16,
                            color: isDark
                                ? const Color(0xFF6EE7B7)
                                : const Color(0xFF065F46),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            strings.tr('เพิ่มข้อมูล', 'More details'),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? const Color(0xFF6EE7B7)
                                  : const Color(0xFF065F46),
                            ),
                          ),
                          if (!_showExtraInfo && hasExtraContent) ...<Widget>[
                            const SizedBox(width: 6),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFF059669),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                          const SizedBox(width: 4),
                          AnimatedRotation(
                            turns: _showExtraInfo ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: isDark
                                  ? const Color(0xFF6EE7B7)
                                  : const Color(0xFF065F46),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  AnimatedSize(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    child: _showExtraInfo
                        ? Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.darkSurface
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white12
                                          : const Color(0xFFE2ECE8),
                                    ),
                                  ),
                                  child: TextFormField(
                                    controller: _payeeController,
                                    maxLength: 120,
                                    onTap: () =>
                                        setState(() => _showKeypad = false),
                                    decoration: InputDecoration(
                                      labelText: strings.payee,
                                      counterText: '',
                                      filled: false,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      prefixIcon: const Icon(
                                        Icons.storefront_outlined,
                                        color: Color(0xFF0D9488),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildLocalAttachmentSection(theme, strings),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  // 6. Category Grid Strip (Expense / Income)
                  if (_type != TransactionType.transfer) ...<Widget>[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Expanded(
                          child: Row(
                            children: <Widget>[
                              Icon(
                                Icons.grid_view_rounded,
                                size: 17,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  strings.category,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () async {
                              final CategoryModel? created =
                                  await showModalBottomSheet<CategoryModel>(
                                    context: context,
                                    isScrollControlled: true,
                                    useSafeArea: true,
                                    builder: (_) => CategoryFormSheet(
                                      initialType:
                                          _type == TransactionType.income
                                          ? CategoryType.income
                                          : CategoryType.expense,
                                    ),
                                  );
                              if (created != null && mounted) {
                                setState(() => _categoryId = created.id);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Icon(
                                    Icons.add_rounded,
                                    size: 16,
                                    color: Color(0xFF059669),
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      strings.addCategory,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 78,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        padding: const EdgeInsets.only(top: 6, right: 4),
                        itemCount: availableCategories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (BuildContext context, int index) {
                          final CategoryModel cat = availableCategories[index];
                          final bool selected = cat.id == _categoryId;
                          final Color catColor = AppColors.fromHex(cat.color);
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _categoryId = selected ? null : cat.id;
                              });
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: <Widget>[
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  width: 68,
                                  height: 68,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? (isDark
                                              ? const Color(0xFF103C2F)
                                              : const Color(0xFFE7F7F0))
                                        : (isDark
                                              ? AppColors.darkSurface
                                              : Colors.white),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: selected
                                          ? const Color(0xFF0A6B50)
                                          : (isDark
                                                ? Colors.white12
                                                : const Color(0xFFE5ECE9)),
                                      width: selected ? 1.6 : 1.0,
                                    ),
                                    boxShadow: <BoxShadow>[
                                      BoxShadow(
                                        color: selected
                                            ? const Color(0x1F0A6B50)
                                            : const Color(0x090F172A),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      Icon(
                                        IconMapper.resolve(cat.icon),
                                        size: 22,
                                        color: catColor,
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        cat.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: selected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF1E293B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (selected)
                                  Positioned(
                                    top: -5,
                                    right: -4,
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0A6B50),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDark
                                              ? AppColors.darkBackground
                                              : Colors.white,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.check_rounded,
                                        size: 11,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // 7. Compact Date/Time Row
                  _CompactDateRow(
                    dateText: dateText,
                    isDark: isDark,
                    onTap: _pickDateTime,
                  ),
                  const SizedBox(height: 8),

                  // 8. Account Selector Pill(s)
                  if (accounts.isEmpty)
                    _CompactAddAccountPill(
                      label: strings.addAccount,
                      isDark: isDark,
                      onTap: () async {
                        final AccountModel? created =
                            await showModalBottomSheet<AccountModel>(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              builder: (_) => const AccountFormSheet(),
                            );
                        if (created != null && mounted) {
                          setState(() => _accountId = created.id);
                        }
                      },
                    )
                  else ...<Widget>[
                    _AccountPillSelector(
                      label: _type == TransactionType.transfer
                          ? strings.fromAccount
                          : strings.tr('บัญชีที่ใช้', strings.account),
                      selectedAccount: selectedAccount,
                      fallbackText: strings.tr('เลือกบัญชี', 'Select account'),
                      isDark: isDark,
                      onTap: () => _openAccountPicker(
                        title: _type == TransactionType.transfer
                            ? strings.fromAccount
                            : strings.tr('บัญชีที่ใช้', strings.account),
                        accounts: accounts,
                        selectedId: _accountId,
                        strings: strings,
                        onSelected: (String id) =>
                            setState(() => _accountId = id),
                      ),
                    ),
                    if (_type == TransactionType.transfer) ...<Widget>[
                      const SizedBox(height: 8),
                      _AccountPillSelector(
                        label: strings.toAccount,
                        selectedAccount: selectedToAccount,
                        fallbackText: strings.tr(
                          'เลือกบัญชีปลายทาง',
                          'Select destination',
                        ),
                        isDark: isDark,
                        onTap: () => _openAccountPicker(
                          title: strings.toAccount,
                          accounts: accounts,
                          selectedId: _toAccountId,
                          strings: strings,
                          onSelected: (String id) =>
                              setState(() => _toAccountId = id),
                        ),
                      ),
                    ],
                  ],

                  const SizedBox(height: 8),

                  // 9. Inline Note Pill Row
                  _InlineNoteRow(
                    controller: _noteController,
                    label: strings.tr('บันทึกเพิ่มเติม (ถ้ามี)', strings.note),
                    hint: strings.tr(
                      'เช่น ซื้อของที่ตลาด...',
                      'e.g. Groceries...',
                    ),
                    isDark: isDark,
                  ),

                  const SizedBox(height: 12),

                  // 10. Primary Emerald Save CTA Pill
                  _PrimaryEmeraldButton(
                    label: widget.existing == null
                        ? strings.tr('บันทึกรายการ', 'Save Transaction')
                        : strings.save,
                    saving: _saving,
                    onTap: _saving ? null : () => _submit(accounts),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalAttachmentSection(ThemeData theme, AppStrings strings) {
    final Uint8List? activeBytes =
        _stagedImage?.bytes ??
        (_removeExistingImage ? null : _existingImageBytes);
    final String? activeFileName =
        _stagedImage?.fileName ??
        (_removeExistingImage ? null : _existingAttachment?.originalFileName);
    final int? activeSizeBytes =
        _stagedImage?.sizeBytes ??
        (_removeExistingImage ? null : _existingAttachment?.sizeBytes);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(110),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.receipt_long_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.tr(
                    'รูปสลิป / ใบเสร็จ (จัดเก็บในเครื่องเท่านั้น)',
                    'Slip / Receipt Image (Stored on device only)',
                  ),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            strings.tr(
              'ไฟล์รูปภาพจะถูกคัดลอกเก็บไว้ในพื้นที่ส่วนตัวของแอปในเครื่องนี้ ไม่มีการอัปโหลดขึ้นเซิร์ฟเวอร์',
              'Copied into private Local Application Storage on this device. Never uploaded to the server.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          if (activeBytes != null && activeFileName != null) ...<Widget>[
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () =>
                  _openFullscreenImagePreview(activeBytes, activeFileName),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Image.memory(activeBytes, fit: BoxFit.cover),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(165),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(
                                Icons.zoom_in_rounded,
                                size: 15,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                strings.tr('แตะเพื่อขยาย', 'Tap to zoom'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    activeSizeBytes != null
                        ? '$activeFileName (${(activeSizeBytes / 1024).toStringAsFixed(1)} KB)'
                        : activeFileName,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: _saving ? null : _chooseLocalImageSource,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: Text(strings.tr('เปลี่ยนรูป', 'Replace')),
                ),
                TextButton.icon(
                  onPressed: _saving
                      ? null
                      : () {
                          setState(() {
                            _stagedImage = null;
                            _removeExistingImage = true;
                          });
                        },
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: AppColors.expense,
                  ),
                  label: Text(
                    strings.delete,
                    style: const TextStyle(color: AppColors.expense),
                  ),
                ),
              ],
            ),
          ] else
            OutlinedButton.icon(
              onPressed: _saving ? null : _chooseLocalImageSource,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: Text(
                strings.tr(
                  'แนบรูปสลิป / ใบเสร็จจากในเครื่อง',
                  'Attach Slip / Receipt from Device',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AmbientSheetRibbonPainter extends CustomPainter {
  const _AmbientSheetRibbonPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final double alphaScale = isDark ? 0.14 : 0.42;

    // Top-right sweeping mint-emerald silk ribbon glow
    final Path ribbonA = Path()
      ..moveTo(size.width * 0.46, 0)
      ..quadraticBezierTo(
        size.width * 0.68,
        size.height * 0.08,
        size.width * 0.96,
        size.height * 0.14,
      )
      ..lineTo(size.width, size.height * 0.14)
      ..lineTo(size.width, 0)
      ..close();

    final Paint ribbonPaintA = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          const Color(0xFFB4ECDA).withValues(alpha: alphaScale * 0.5),
          const Color(0xFF4CC69E).withValues(alpha: alphaScale * 0.85),
          const Color(0xFF0E9F77).withValues(alpha: alphaScale * 0.4),
        ],
      ).createShader(Rect.fromLTWH(size.width * 0.45, 0, size.width * 0.55, 160));
    canvas.drawPath(ribbonA, ribbonPaintA);

    final Path ribbonB = Path()
      ..moveTo(size.width * 0.62, 0)
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.11,
        size.width,
        size.height * 0.06,
      )
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(
      ribbonB,
      Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: alphaScale * 0.45),
    );

    // Subtle soft glow near top-right & bottom-left
    final Paint softGlow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          const Color(0xFF34D399).withValues(alpha: isDark ? 0.08 : 0.14),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(0, size.height * 0.85),
          radius: size.width * 0.55,
        ),
      );
    canvas.drawCircle(
      Offset(0, size.height * 0.85),
      size.width * 0.55,
      softGlow,
    );
  }

  @override
  bool shouldRepaint(covariant _AmbientSheetRibbonPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}

class _GlossyWalletBadge extends StatelessWidget {
  const _GlossyWalletBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF1FD495), Color(0xFF088762)],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x30088762),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: 0,
            left: 0,
            right: 8,
            height: 11,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomRight: Radius.circular(8),
                ),
                color: Colors.white.withValues(alpha: 0.22),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 12,
            bottom: 11,
            width: 11,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF076B4E),
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(6),
                ),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 3),
              child: Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Color(0xFFA7F3D0),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeSegmentedPillBar extends StatelessWidget {
  const _TypeSegmentedPillBar({
    required this.selectedType,
    required this.strings,
    required this.isDark,
    required this.onChanged,
  });

  final TransactionType selectedType;
  final AppStrings strings;
  final bool isDark;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<TransactionType> order = <TransactionType>[
      TransactionType.expense,
      TransactionType.income,
      TransactionType.transfer,
    ];

    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE3ECE9),
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0B0F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < order.length; i++) ...<Widget>[
            Expanded(
              child: _TypePillSegment(
                type: order[i],
                label: _labelFor(order[i]),
                selected: order[i] == selectedType,
                isDark: isDark,
                onTap: () => onChanged(order[i]),
              ),
            ),
            if (i < order.length - 1 &&
                order[i] != selectedType &&
                order[i + 1] != selectedType)
              Container(
                width: 1,
                height: 18,
                color: isDark ? Colors.white12 : const Color(0xFFE5EAE8),
              ),
          ],
        ],
      ),
    );
  }

  String _labelFor(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        return strings.expense;
      case TransactionType.income:
        return strings.income;
      case TransactionType.transfer:
        return strings.transfer;
    }
  }
}

class _TypePillSegment extends StatelessWidget {
  const _TypePillSegment({
    required this.type,
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final TransactionType type;
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color fg = selected
        ? Colors.white
        : (isDark ? Colors.white70 : const Color(0xFF1E293B));

    Widget typeGlyph;
    switch (type) {
      case TransactionType.expense:
        typeGlyph = Icon(
          selected ? Icons.monetization_on_rounded : Icons.south_west_rounded,
          size: 15,
          color: selected ? const Color(0xFFFACC15) : fg,
        );
      case TransactionType.income:
        typeGlyph = Icon(
          Icons.north_east_rounded,
          size: 15,
          color: selected ? const Color(0xFF6EE7B7) : fg,
        );
      case TransactionType.transfer:
        typeGlyph = Icon(
          Icons.swap_horiz_rounded,
          size: 16,
          color: selected ? const Color(0xFF93C5FD) : fg,
        );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFF0E7458), Color(0xFF065640)],
                )
              : null,
          boxShadow: selected
              ? const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x28065640),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (selected) ...<Widget>[
                const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
              ],
              typeGlyph,
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: fg,
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

class _AmountHeroCard extends StatelessWidget {
  const _AmountHeroCard({
    required this.formattedAmount,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
  });

  final String formattedAmount;
  final String subtitle;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF1F5445)
                    : const Color(0xFFC8EBDD),
                width: 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: isDark
                      ? const Color(0x22000000)
                      : const Color(0x2010B981),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[Color(0xFF28D694), Color(0xFF068E64)],
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Color(0x33068E64),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '฿',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'THB (฿)',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? Colors.white60
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      formattedAmount,
                      textAlign: TextAlign.right,
                      style: AppTheme.tabularStyle(
                        TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          color: isDark
                              ? const Color(0xFF6EE7B7)
                              : const Color(0xFF064E3B),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: -2,
          right: 12,
          child: IgnorePointer(
            child: Transform.rotate(
              angle: -0.55,
              child: Container(
                width: 16,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(
                    colors: <Color>[
                      const Color(0xFF34D399).withValues(alpha: 0.75),
                      const Color(0xFFA7F3D0).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AmountKeypad extends StatelessWidget {
  const _AmountKeypad({required this.onKeyTap, required this.isDark});

  final ValueChanged<String> onKeyTap;
  final bool isDark;

  static const double _gap = 7.0;
  static const double _keyHeight = 42.0;

  @override
  Widget build(BuildContext context) {
    const List<List<String>> topRows = <List<String>>[
      <String>['7', '8', '9', 'C'],
      <String>['4', '5', '6', '00'],
      <String>['1', '2', '3', '⌫'],
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double colWidth = (constraints.maxWidth - (_gap * 3)) / 4;
        return Column(
          children: <Widget>[
            for (final List<String> row in topRows)
              Padding(
                padding: const EdgeInsets.only(bottom: _gap),
                child: Row(
                  children: <Widget>[
                    for (int i = 0; i < row.length; i++) ...<Widget>[
                      SizedBox(
                        width: colWidth,
                        height: _keyHeight,
                        child: _KeypadButton(
                          label: row[i],
                          isAction: row[i] == 'C' || row[i] == '⌫',
                          isDark: isDark,
                          onTap: () => onKeyTap(row[i]),
                        ),
                      ),
                      if (i < row.length - 1) const SizedBox(width: _gap),
                    ],
                  ],
                ),
              ),
            Row(
              children: <Widget>[
                SizedBox(
                  width: colWidth,
                  height: _keyHeight,
                  child: _KeypadButton(
                    label: '.',
                    isAction: false,
                    isDark: isDark,
                    onTap: () => onKeyTap('.'),
                  ),
                ),
                const SizedBox(width: _gap),
                SizedBox(
                  width: (colWidth * 2) + _gap,
                  height: _keyHeight,
                  child: _KeypadButton(
                    label: '0',
                    isAction: false,
                    isDark: isDark,
                    onTap: () => onKeyTap('0'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({
    required this.label,
    required this.isAction,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool isAction;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bgColor = isAction
        ? (isDark ? const Color(0xFF283548) : const Color(0xFFE5ECEF))
        : (isDark ? AppColors.darkSurface : Colors.white);
    final Color borderColor = isAction
        ? (isDark ? Colors.white12 : const Color(0xFFD6E0E5))
        : (isDark ? Colors.white10 : const Color(0xFFE3EAE8));
    final Color fgColor = isAction
        ? (isDark ? Colors.white70 : const Color(0xFF334155))
        : (isDark ? Colors.white : const Color(0xFF0F172A));

    return BouncyTap(
      key: ValueKey<String>('keypad_$label'),
      onTap: onTap,
      pressedScale: 0.92,
      duration: const Duration(milliseconds: 80),
      child: Semantics(
        button: true,
        label: label,
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x0D0F172A),
                blurRadius: 4,
                offset: Offset(0, 1.5),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: label == '⌫'
              ? Icon(Icons.backspace_outlined, size: 19, color: fgColor)
              : Text(
                  label,
                  style: AppTheme.tabularStyle(
                    TextStyle(
                      fontSize: label == '00' ? 16.5 : 19,
                      fontWeight: FontWeight.w600,
                      color: fgColor,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _CompactDateRow extends StatelessWidget {
  const _CompactDateRow({
    required this.dateText,
    required this.isDark,
    required this.onTap,
  });

  final String dateText;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? AppColors.darkSurface : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFE3ECE9),
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x080F172A),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              const SizedBox(width: 20),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        dateText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactAddAccountPill extends StatelessWidget {
  const _CompactAddAccountPill({
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF0D9488).withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.add_rounded, size: 18, color: Color(0xFF0D9488)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D9488),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountPillSelector extends StatelessWidget {
  const _AccountPillSelector({
    required this.label,
    required this.selectedAccount,
    required this.fallbackText,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final AccountModel? selectedAccount;
  final String fallbackText;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AccountModel? acc = selectedAccount;
    final bool hasInstitution = acc?.institution?.trim().isNotEmpty ?? false;

    return Material(
      color: isDark ? AppColors.darkSurface : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFE3ECE9),
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x080F172A),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              if (acc != null && hasInstitution)
                AccountBrandAvatar(
                  institution: acc.institution,
                  accountName: acc.name,
                  iconKey: acc.icon,
                  colorHex: acc.color,
                  size: 26,
                  borderRadius: 8,
                )
              else
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[Color(0xFF1EC98D), Color(0xFF077355)],
                    ),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              const SizedBox(width: 9),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        acc?.name ?? fallbackText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 19,
                      color: isDark
                          ? Colors.white54
                          : const Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountPickerBottomSheet extends StatelessWidget {
  const _AccountPickerBottomSheet({
    required this.title,
    required this.accounts,
    required this.selectedId,
    required this.strings,
    required this.onSelected,
    required this.onAddAccount,
  });

  final String title;
  final List<AccountModel> accounts;
  final String? selectedId;
  final AppStrings strings;
  final ValueChanged<String> onSelected;
  final VoidCallback onAddAccount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        color: isDark ? AppColors.darkBackground : const Color(0xFFF3F8F6),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextButton.icon(
                  onPressed: onAddAccount,
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: Text(strings.addAccount),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: accounts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (BuildContext context, int index) {
                  final AccountModel acc = accounts[index];
                  final bool selected = acc.id == selectedId;
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onSelected(acc.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? (isDark
                                  ? const Color(0xFF103C2F)
                                  : const Color(0xFFE7F7F0))
                            : (isDark ? AppColors.darkSurface : Colors.white),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF0A6B50)
                              : (isDark
                                    ? Colors.white12
                                    : const Color(0xFFE3ECE9)),
                          width: selected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          AccountBrandAvatar(
                            institution: acc.institution,
                            accountName: acc.name,
                            iconKey: acc.icon,
                            colorHex: acc.color,
                            size: 38,
                            borderRadius: 11,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  acc.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                                if (acc.subtitle.isNotEmpty)
                                  Text(
                                    acc.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark
                                          ? Colors.white60
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            MoneyUtils.formatSatang(acc.balance),
                            style: AppTheme.tabularStyle(
                              TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? const Color(0xFF6EE7B7)
                                    : const Color(0xFF065F46),
                              ),
                            ),
                          ),
                          if (selected) ...<Widget>[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 20,
                              color: Color(0xFF0A6B50),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineNoteRow extends StatelessWidget {
  const _InlineNoteRow({
    required this.controller,
    required this.label,
    required this.hint,
    required this.isDark,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE3ECE9),
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFF1EC98D), Color(0xFF077355)],
              ),
            ),
            child: const Icon(
              Icons.description_rounded,
              size: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 9),
          Flexible(
            flex: 5,
            fit: FlexFit.loose,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 6,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceSubtle
                    : const Color(0xFFF0F4F6),
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.centerLeft,
              child: TextFormField(
                controller: controller,
                maxLength: 500,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: hint,
                  hintStyle: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  ),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryEmeraldButton extends StatelessWidget {
  const _PrimaryEmeraldButton({
    required this.label,
    required this.saving,
    required this.onTap,
  });

  final String label;
  final bool saving;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: <Color>[Color(0xFF14A47B), Color(0xFF06694E)],
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x3806694E),
              blurRadius: 14,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.check_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
