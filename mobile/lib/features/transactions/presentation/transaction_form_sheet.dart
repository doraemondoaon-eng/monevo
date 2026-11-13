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
    required _TransactionFormPalette palette,
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
          palette: palette,
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
    final _TransactionFormPalette palette = _TransactionFormPalette.of(
      _type,
      isDark,
    );

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(color: palette.sheetBackground),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _AmbientSheetRibbonPainter(
                    isDark: isDark,
                    palette: palette,
                  ),
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
                  // 1. Header with Glossy Wallet Badge + Title/Subtitle + Close/Delete
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      _GlossyWalletBadge(palette: palette),
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
                    palette: palette,
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
                    type: _type,
                    formattedAmount: _formatDisplayAmount(_amountInput),
                    subtitle: strings.tr('บาทไทย', 'Thai Baht'),
                    isDark: isDark,
                    palette: palette,
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
                              palette: palette,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 10),

                  // 5. Expandable "+ เพิ่มข้อมูล" Pill
                  BouncyTap(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _showExtraInfo = !_showExtraInfo);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 36,
                      decoration: BoxDecoration(
                        color: palette.extraPillBg,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: palette.extraPillBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            _showExtraInfo
                                ? Icons.remove_rounded
                                : Icons.add_rounded,
                            size: 16,
                            color: palette.extraPillFg,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            strings.tr('เพิ่มข้อมูล', 'More details'),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: palette.extraPillFg,
                            ),
                          ),
                          if (!_showExtraInfo && hasExtraContent) ...<Widget>[
                            const SizedBox(width: 6),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: palette.extraPillDot,
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
                              color: palette.extraPillFg,
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
                                      color: palette.cardBorder,
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
                                      prefixIcon: Icon(
                                        Icons.storefront_outlined,
                                        color: palette.accentIcon,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildLocalAttachmentSection(
                                  theme,
                                  strings,
                                  palette,
                                ),
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
                                  Icon(
                                    Icons.add_rounded,
                                    size: 16,
                                    color: palette.accentIcon,
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      strings.addCategory,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: palette.accentIcon,
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
                          final bool solidSelected =
                              selected && palette.fillSelectedCategory;
                          final Color catIconColor = solidSelected
                              ? Colors.white
                              : (palette.uniformCategoryIconColor ??
                                    AppColors.fromHex(cat.color));
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
                                    color: selected && !solidSelected
                                        ? palette.selectedCategoryBg
                                        : (solidSelected
                                              ? null
                                              : (isDark
                                                    ? AppColors.darkSurface
                                                    : Colors.white)),
                                    gradient: solidSelected
                                        ? LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors:
                                                palette.selectedCategoryFillGradient,
                                          )
                                        : null,
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: selected
                                          ? palette.selectedCategoryBorder
                                          : palette.categoryCardBorder,
                                      width: selected ? 1.6 : 1.0,
                                    ),
                                    boxShadow: <BoxShadow>[
                                      BoxShadow(
                                        color: selected
                                            ? palette.selectedCategoryShadow
                                            : const Color(0x090F172A),
                                        blurRadius: selected ? 8 : 6,
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
                                        color: catIconColor,
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
                                          color: solidSelected
                                              ? Colors.white
                                              : (isDark
                                                    ? Colors.white
                                                    : const Color(0xFF1E293B)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (selected && !solidSelected)
                                  Positioned(
                                    top: -5,
                                    right: -4,
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: palette.selectedCategoryBorder,
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
                    palette: palette,
                    onTap: _pickDateTime,
                  ),
                  const SizedBox(height: 8),

                  // 8. Account Selector Pill(s)
                  if (accounts.isEmpty)
                    _CompactAddAccountPill(
                      label: strings.addAccount,
                      isDark: isDark,
                      palette: palette,
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
                      palette: palette,
                      onTap: () => _openAccountPicker(
                        title: _type == TransactionType.transfer
                            ? strings.fromAccount
                            : strings.tr('บัญชีที่ใช้', strings.account),
                        accounts: accounts,
                        selectedId: _accountId,
                        strings: strings,
                        palette: palette,
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
                        palette: palette,
                        onTap: () => _openAccountPicker(
                          title: strings.toAccount,
                          accounts: accounts,
                          selectedId: _toAccountId,
                          strings: strings,
                          palette: palette,
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
                    palette: palette,
                  ),

                  const SizedBox(height: 12),

                  // 10. Primary Save CTA Pill
                  _PrimarySubmitButton(
                    label: widget.existing == null
                        ? strings.tr('บันทึกรายการ', 'Save Transaction')
                        : strings.save,
                    saving: _saving,
                    palette: palette,
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

  Widget _buildLocalAttachmentSection(
    ThemeData theme,
    AppStrings strings,
    _TransactionFormPalette palette,
  ) {
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
                color: palette.accentIcon,
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

class _TransactionFormPalette {
  const _TransactionFormPalette({
    required this.sheetBackground,
    required this.ribbonStart,
    required this.ribbonMid,
    required this.ribbonEnd,
    required this.ribbonAccent,
    required this.bottomGlow,
    required this.badgeGradient,
    required this.badgeShadow,
    required this.walletClaspColor,
    required this.walletClaspDotColor,
    required this.segmentActiveGradient,
    required this.segmentActiveShadow,
    required this.expenseCoinSelectedColor,
    required this.cardBorder,
    required this.heroBorder,
    required this.heroGlow,
    required this.heroBadgeGradient,
    required this.heroBadgeShadow,
    required this.heroAmountColor,
    required this.heroStreakColors,
    required this.actionKeyBg,
    required this.actionKeyBorder,
    required this.actionKeyFg,
    required this.extraPillBg,
    required this.extraPillBorder,
    required this.extraPillFg,
    required this.extraPillDot,
    required this.accentIcon,
    required this.uniformCategoryIconColor,
    required this.fillSelectedCategory,
    required this.selectedCategoryFillGradient,
    required this.selectedCategoryBg,
    required this.selectedCategoryBorder,
    required this.selectedCategoryShadow,
    required this.categoryCardBorder,
    required this.noteFieldFill,
    required this.submitGradient,
    required this.submitShadow,
    required this.pickerBalanceColor,
  });

  factory _TransactionFormPalette.of(TransactionType type, bool isDark) {
    switch (type) {
      case TransactionType.expense:
        return _TransactionFormPalette(
          sheetBackground: isDark
              ? AppColors.darkBackground
              : const Color(0xFFFAF2F2),
          ribbonStart: isDark
              ? const Color(0xFF7F1D1D)
              : const Color(0xFFFBC5C5),
          ribbonMid: isDark
              ? const Color(0xFFB91C1C)
              : const Color(0xFFF26D6D),
          ribbonEnd: isDark
              ? const Color(0xFFEF4444)
              : const Color(0xFFD92D2D),
          ribbonAccent: isDark
              ? const Color(0xFFDC2626)
              : const Color(0xFFE53935),
          bottomGlow: const Color(0xFFF87171),
          badgeGradient: const <Color>[
            Color(0xFFEF2B2B),
            Color(0xFFB71212),
          ],
          badgeShadow: const Color(0x30B71212),
          walletClaspColor: const Color(0xFF8C0D0D),
          walletClaspDotColor: const Color(0xFFFCA5A5),
          segmentActiveGradient: const <Color>[
            Color(0xFFA61414),
            Color(0xFF830B0B),
          ],
          segmentActiveShadow: const Color(0x28830B0B),
          expenseCoinSelectedColor: Colors.white,
          cardBorder: isDark ? Colors.white12 : const Color(0xFFF0DEDE),
          heroBorder: isDark
              ? const Color(0xFF5C1E24)
              : const Color(0xFFF5CACA),
          heroGlow: isDark
              ? const Color(0x22000000)
              : const Color(0x20DF2626),
          heroBadgeGradient: const <Color>[
            Color(0xFFEB2626),
            Color(0xFFBE1212),
          ],
          heroBadgeShadow: const Color(0x33BE1212),
          heroAmountColor: isDark
              ? const Color(0xFFFCA5A5)
              : const Color(0xFFA81010),
          heroStreakColors: <Color>[
            const Color(0xFFEF4444).withValues(alpha: 0.75),
            const Color(0xFFFECACA).withValues(alpha: 0.0),
          ],
          actionKeyBg: isDark
              ? const Color(0xFF3E1C22)
              : const Color(0xFFF6DFDF),
          actionKeyBorder: isDark
              ? const Color(0xFF5B2830)
              : const Color(0xFFEBC8C9),
          actionKeyFg: isDark ? Colors.white70 : const Color(0xFF3F2021),
          extraPillBg: isDark
              ? const Color(0xFF42181D)
              : const Color(0xFFF6CECE),
          extraPillBorder: isDark
              ? const Color(0xFF6B242B)
              : const Color(0xFFEBAAAA),
          extraPillFg: isDark
              ? const Color(0xFFFCA5A5)
              : const Color(0xFF4A0E0E),
          extraPillDot: isDark
              ? const Color(0xFFF87171)
              : const Color(0xFFDC2626),
          accentIcon: isDark
              ? const Color(0xFFFCA5A5)
              : const Color(0xFFB31212),
          uniformCategoryIconColor: isDark
              ? const Color(0xFFF87171)
              : const Color(0xFFD91E1E),
          fillSelectedCategory: true,
          selectedCategoryFillGradient: isDark
              ? const <Color>[Color(0xFFC81E1E), Color(0xFF991B1B)]
              : const <Color>[Color(0xFFB81414), Color(0xFF960E0E)],
          selectedCategoryBg: isDark
              ? const Color(0xFF3B1318)
              : const Color(0xFFFDECEC),
          selectedCategoryBorder: isDark
              ? const Color(0xFFF87171)
              : const Color(0xFF960E0E),
          selectedCategoryShadow: const Color(0x28960E0E),
          categoryCardBorder: isDark
              ? Colors.white12
              : const Color(0xFFF0DADA),
          noteFieldFill: isDark
              ? AppColors.darkSurfaceSubtle
              : const Color(0xFFF1ECEC),
          submitGradient: const <Color>[
            Color(0xFFDF2929),
            Color(0xFFB71414),
          ],
          submitShadow: const Color(0x38B71414),
          pickerBalanceColor: isDark
              ? const Color(0xFFFCA5A5)
              : const Color(0xFF991B1B),
        );
      case TransactionType.income:
        return _TransactionFormPalette(
          sheetBackground: isDark
              ? AppColors.darkBackground
              : const Color(0xFFF3F8F6),
          ribbonStart: const Color(0xFFB4ECDA),
          ribbonMid: const Color(0xFF4CC69E),
          ribbonEnd: const Color(0xFF0E9F77),
          ribbonAccent: const Color(0xFF10B981),
          bottomGlow: const Color(0xFF34D399),
          badgeGradient: const <Color>[
            Color(0xFF1FD495),
            Color(0xFF088762),
          ],
          badgeShadow: const Color(0x30088762),
          walletClaspColor: const Color(0xFF076B4E),
          walletClaspDotColor: const Color(0xFFA7F3D0),
          segmentActiveGradient: const <Color>[
            Color(0xFF0E7458),
            Color(0xFF065640),
          ],
          segmentActiveShadow: const Color(0x28065640),
          expenseCoinSelectedColor: const Color(0xFFFACC15),
          cardBorder: isDark ? Colors.white12 : const Color(0xFFE3ECE9),
          heroBorder: isDark
              ? const Color(0xFF1F5445)
              : const Color(0xFFC8EBDD),
          heroGlow: isDark
              ? const Color(0x22000000)
              : const Color(0x2010B981),
          heroBadgeGradient: const <Color>[
            Color(0xFF28D694),
            Color(0xFF068E64),
          ],
          heroBadgeShadow: const Color(0x33068E64),
          heroAmountColor: isDark
              ? const Color(0xFF6EE7B7)
              : const Color(0xFF064E3B),
          heroStreakColors: <Color>[
            const Color(0xFF34D399).withValues(alpha: 0.75),
            const Color(0xFFA7F3D0).withValues(alpha: 0.0),
          ],
          actionKeyBg: isDark
              ? const Color(0xFF283548)
              : const Color(0xFFE5ECEF),
          actionKeyBorder: isDark ? Colors.white12 : const Color(0xFFD6E0E5),
          actionKeyFg: isDark ? Colors.white70 : const Color(0xFF334155),
          extraPillBg: isDark
              ? const Color(0xFF12382C)
              : const Color(0xFFD6F4E6),
          extraPillBorder: isDark
              ? const Color(0xFF1F5D4A)
              : const Color(0xFFB3E6D0),
          extraPillFg: isDark
              ? const Color(0xFF6EE7B7)
              : const Color(0xFF065F46),
          extraPillDot: isDark
              ? const Color(0xFF34D399)
              : const Color(0xFF059669),
          accentIcon: const Color(0xFF059669),
          uniformCategoryIconColor: null,
          fillSelectedCategory: false,
          selectedCategoryFillGradient: const <Color>[
            Color(0xFF0E7458),
            Color(0xFF065640),
          ],
          selectedCategoryBg: isDark
              ? const Color(0xFF103C2F)
              : const Color(0xFFE7F7F0),
          selectedCategoryBorder: const Color(0xFF0A6B50),
          selectedCategoryShadow: const Color(0x1F0A6B50),
          categoryCardBorder: isDark
              ? Colors.white12
              : const Color(0xFFE5ECE9),
          noteFieldFill: isDark
              ? AppColors.darkSurfaceSubtle
              : const Color(0xFFF0F4F6),
          submitGradient: const <Color>[
            Color(0xFF14A47B),
            Color(0xFF06694E),
          ],
          submitShadow: const Color(0x3806694E),
          pickerBalanceColor: isDark
              ? const Color(0xFF6EE7B7)
              : const Color(0xFF065F46),
        );
      case TransactionType.transfer:
        return _TransactionFormPalette(
          sheetBackground: isDark
              ? AppColors.darkBackground
              : const Color(0xFFF2F6FC),
          ribbonStart: const Color(0xFFBFDBFE),
          ribbonMid: const Color(0xFF60A5FA),
          ribbonEnd: const Color(0xFF2563EB),
          ribbonAccent: const Color(0xFF3B82F6),
          bottomGlow: const Color(0xFF60A5FA),
          badgeGradient: const <Color>[
            Color(0xFF3B82F6),
            Color(0xFF1D4ED8),
          ],
          badgeShadow: const Color(0x301D4ED8),
          walletClaspColor: const Color(0xFF1E40AF),
          walletClaspDotColor: const Color(0xFFBFDBFE),
          segmentActiveGradient: const <Color>[
            Color(0xFF2563EB),
            Color(0xFF1E40AF),
          ],
          segmentActiveShadow: const Color(0x281E40AF),
          expenseCoinSelectedColor: const Color(0xFFFACC15),
          cardBorder: isDark ? Colors.white12 : const Color(0xFFDCE6F4),
          heroBorder: isDark
              ? const Color(0xFF1E3A5F)
              : const Color(0xFFC7DBFA),
          heroGlow: isDark
              ? const Color(0x22000000)
              : const Color(0x203B82F6),
          heroBadgeGradient: const <Color>[
            Color(0xFF60A5FA),
            Color(0xFF1D4ED8),
          ],
          heroBadgeShadow: const Color(0x331D4ED8),
          heroAmountColor: isDark
              ? const Color(0xFF93C5FD)
              : const Color(0xFF1E3A8A),
          heroStreakColors: <Color>[
            const Color(0xFF60A5FA).withValues(alpha: 0.75),
            const Color(0xFFBFDBFE).withValues(alpha: 0.0),
          ],
          actionKeyBg: isDark
              ? const Color(0xFF1E2D45)
              : const Color(0xFFE2EBF7),
          actionKeyBorder: isDark ? Colors.white12 : const Color(0xFFCFDDF0),
          actionKeyFg: isDark ? Colors.white70 : const Color(0xFF1E3A5F),
          extraPillBg: isDark
              ? const Color(0xFF172844)
              : const Color(0xFFDBEAFE),
          extraPillBorder: isDark
              ? const Color(0xFF284370)
              : const Color(0xFFBFDBFE),
          extraPillFg: isDark
              ? const Color(0xFF93C5FD)
              : const Color(0xFF1E40AF),
          extraPillDot: isDark
              ? const Color(0xFF60A5FA)
              : const Color(0xFF2563EB),
          accentIcon: isDark
              ? const Color(0xFF93C5FD)
              : const Color(0xFF1D4ED8),
          uniformCategoryIconColor: null,
          fillSelectedCategory: false,
          selectedCategoryFillGradient: const <Color>[
            Color(0xFF2563EB),
            Color(0xFF1E40AF),
          ],
          selectedCategoryBg: isDark
              ? const Color(0xFF172844)
              : const Color(0xFFEFF6FF),
          selectedCategoryBorder: const Color(0xFF1D4ED8),
          selectedCategoryShadow: const Color(0x1F1D4ED8),
          categoryCardBorder: isDark
              ? Colors.white12
              : const Color(0xFFDCE6F4),
          noteFieldFill: isDark
              ? AppColors.darkSurfaceSubtle
              : const Color(0xFFEDF2FA),
          submitGradient: const <Color>[
            Color(0xFF3B82F6),
            Color(0xFF1D4ED8),
          ],
          submitShadow: const Color(0x381D4ED8),
          pickerBalanceColor: isDark
              ? const Color(0xFF93C5FD)
              : const Color(0xFF1E40AF),
        );
    }
  }

  final Color sheetBackground;
  final Color ribbonStart;
  final Color ribbonMid;
  final Color ribbonEnd;
  final Color ribbonAccent;
  final Color bottomGlow;
  final List<Color> badgeGradient;
  final Color badgeShadow;
  final Color walletClaspColor;
  final Color walletClaspDotColor;
  final List<Color> segmentActiveGradient;
  final Color segmentActiveShadow;
  final Color expenseCoinSelectedColor;
  final Color cardBorder;
  final Color heroBorder;
  final Color heroGlow;
  final List<Color> heroBadgeGradient;
  final Color heroBadgeShadow;
  final Color heroAmountColor;
  final List<Color> heroStreakColors;
  final Color actionKeyBg;
  final Color actionKeyBorder;
  final Color actionKeyFg;
  final Color extraPillBg;
  final Color extraPillBorder;
  final Color extraPillFg;
  final Color extraPillDot;
  final Color accentIcon;
  final Color? uniformCategoryIconColor;
  final bool fillSelectedCategory;
  final List<Color> selectedCategoryFillGradient;
  final Color selectedCategoryBg;
  final Color selectedCategoryBorder;
  final Color selectedCategoryShadow;
  final Color categoryCardBorder;
  final Color noteFieldFill;
  final List<Color> submitGradient;
  final Color submitShadow;
  final Color pickerBalanceColor;
}

class _AmbientSheetRibbonPainter extends CustomPainter {
  const _AmbientSheetRibbonPainter({
    required this.isDark,
    required this.palette,
  });

  final bool isDark;
  final _TransactionFormPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final double alphaScale = isDark ? 0.16 : 0.42;

    // Top-right sweeping silk ribbon glow matched to active transaction type
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
          palette.ribbonStart.withValues(alpha: alphaScale * 0.5),
          palette.ribbonMid.withValues(alpha: alphaScale * 0.85),
          palette.ribbonEnd.withValues(alpha: alphaScale * 0.4),
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
        ..color = palette.ribbonAccent.withValues(alpha: alphaScale * 0.45),
    );

    final Paint softGlow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          palette.bottomGlow.withValues(alpha: isDark ? 0.08 : 0.14),
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
    return oldDelegate.isDark != isDark ||
        oldDelegate.palette.ribbonEnd != palette.ribbonEnd;
  }
}

class _GlossyWalletBadge extends StatelessWidget {
  const _GlossyWalletBadge({required this.palette});

  final _TransactionFormPalette palette;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 38,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.badgeGradient,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.badgeShadow,
            blurRadius: 8,
            offset: const Offset(0, 3),
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
              decoration: BoxDecoration(
                color: palette.walletClaspColor,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(6),
                ),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 3),
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.walletClaspDotColor,
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
    required this.palette,
    required this.onChanged,
  });

  final TransactionType selectedType;
  final AppStrings strings;
  final bool isDark;
  final _TransactionFormPalette palette;
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
        border: Border.all(color: palette.cardBorder),
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
                palette: palette,
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
    required this.palette,
    required this.onTap,
  });

  final TransactionType type;
  final String label;
  final bool selected;
  final bool isDark;
  final _TransactionFormPalette palette;
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
          color: selected ? palette.expenseCoinSelectedColor : fg,
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
          color: selected ? const Color(0xFFDBEAFE) : fg,
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
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: palette.segmentActiveGradient,
                )
              : null,
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: palette.segmentActiveShadow,
                    blurRadius: 6,
                    offset: const Offset(0, 2),
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
    required this.type,
    required this.formattedAmount,
    required this.subtitle,
    required this.isDark,
    required this.palette,
    required this.onTap,
  });

  final TransactionType type;
  final String formattedAmount;
  final String subtitle;
  final bool isDark;
  final _TransactionFormPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Widget badgeChild;
    switch (type) {
      case TransactionType.expense:
        badgeChild = const Icon(
          Icons.shopping_cart_rounded,
          color: Colors.white,
          size: 20,
        );
      case TransactionType.income:
        badgeChild = const Text(
          '฿',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
        );
      case TransactionType.transfer:
        badgeChild = const Icon(
          Icons.swap_horiz_rounded,
          color: Colors.white,
          size: 22,
        );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.heroBorder, width: 1.2),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: palette.heroGlow,
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: palette.heroBadgeGradient,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: palette.heroBadgeShadow,
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: badgeChild,
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
                          color: palette.heroAmountColor,
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
                  gradient: LinearGradient(colors: palette.heroStreakColors),
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
  const _AmountKeypad({
    required this.onKeyTap,
    required this.isDark,
    required this.palette,
  });

  final ValueChanged<String> onKeyTap;
  final bool isDark;
  final _TransactionFormPalette palette;

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
                          palette: palette,
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
                    palette: palette,
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
                    palette: palette,
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
    required this.palette,
    required this.onTap,
  });

  final String label;
  final bool isAction;
  final bool isDark;
  final _TransactionFormPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bgColor = isAction
        ? palette.actionKeyBg
        : (isDark ? AppColors.darkSurface : Colors.white);
    final Color borderColor = isAction
        ? palette.actionKeyBorder
        : palette.cardBorder;
    final Color fgColor = isAction
        ? palette.actionKeyFg
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
    required this.palette,
    required this.onTap,
  });

  final String dateText;
  final bool isDark;
  final _TransactionFormPalette palette;
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
            border: Border.all(color: palette.cardBorder),
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
    required this.palette,
    required this.onTap,
  });

  final String label;
  final bool isDark;
  final _TransactionFormPalette palette;
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
          border: Border.all(color: palette.accentIcon.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.add_rounded, size: 18, color: palette.accentIcon),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: palette.accentIcon,
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
    required this.palette,
    required this.onTap,
  });

  final String label;
  final AccountModel? selectedAccount;
  final String fallbackText;
  final bool isDark;
  final _TransactionFormPalette palette;
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
            border: Border.all(color: palette.cardBorder),
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
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: palette.badgeGradient,
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
    required this.palette,
    required this.onSelected,
    required this.onAddAccount,
  });

  final String title;
  final List<AccountModel> accounts;
  final String? selectedId;
  final AppStrings strings;
  final _TransactionFormPalette palette;
  final ValueChanged<String> onSelected;
  final VoidCallback onAddAccount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        color: palette.sheetBackground,
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
                  style: TextButton.styleFrom(
                    foregroundColor: palette.accentIcon,
                  ),
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
                            ? palette.selectedCategoryBg
                            : (isDark ? AppColors.darkSurface : Colors.white),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? palette.selectedCategoryBorder
                              : palette.cardBorder,
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
                                color: palette.pickerBalanceColor,
                              ),
                            ),
                          ),
                          if (selected) ...<Widget>[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.check_circle_rounded,
                              size: 20,
                              color: palette.selectedCategoryBorder,
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
    required this.palette,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool isDark;
  final _TransactionFormPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.cardBorder),
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
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: palette.badgeGradient,
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
                color: palette.noteFieldFill,
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

class _PrimarySubmitButton extends StatelessWidget {
  const _PrimarySubmitButton({
    required this.label,
    required this.saving,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final bool saving;
  final _TransactionFormPalette palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: palette.submitGradient,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: palette.submitShadow,
              blurRadius: 14,
              offset: const Offset(0, 5),
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
