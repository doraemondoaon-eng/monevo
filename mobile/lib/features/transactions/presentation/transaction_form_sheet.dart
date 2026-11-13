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
    });
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

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);
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

    final List<CategoryModel> availableCategories =
        _type == TransactionType.transfer
        ? <CategoryModel>[]
        : categoriesState.byType(
            _type == TransactionType.income
                ? CategoryType.income
                : CategoryType.expense,
            activeOnly: true,
          );

    final Color accentColor = _type == TransactionType.income
        ? AppColors.income
        : (_type == TransactionType.transfer
              ? AppColors.transfer
              : AppColors.expense);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  widget.existing == null
                      ? strings.newTransaction
                      : strings.editTransaction,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Row(
                  children: <Widget>[
                    if (widget.existing != null)
                      IconButton(
                        onPressed: _saving ? null : _deleteExisting,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.expense,
                        ),
                      ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<TransactionType>(
              segments: <ButtonSegment<TransactionType>>[
                ButtonSegment<TransactionType>(
                  value: TransactionType.expense,
                  label: Text(strings.expense),
                  icon: const Icon(Icons.south_west_rounded, size: 18),
                ),
                ButtonSegment<TransactionType>(
                  value: TransactionType.income,
                  label: Text(strings.income),
                  icon: const Icon(Icons.north_east_rounded, size: 18),
                ),
                ButtonSegment<TransactionType>(
                  value: TransactionType.transfer,
                  label: Text(strings.transfer),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                ),
              ],
              selected: <TransactionType>{_type},
              onSelectionChanged: (Set<TransactionType> selection) {
                HapticFeedback.selectionClick();
                setState(() {
                  _type = selection.first;
                  _categoryId = null;
                });
              },
            ),
            const SizedBox(height: 16),
            // Large Amount Display Box
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _showKeypad = !_showKeypad),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accentColor.withAlpha(90)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'THB (฿)',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '฿$_amountInput',
                        textAlign: TextAlign.right,
                        style: AppTheme.tabularStyle(
                          theme.textTheme.headlineMedium ?? const TextStyle(),
                        ).copyWith(
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_showKeypad) ...<Widget>[
              const SizedBox(height: 12),
              _AmountKeypad(onKeyTap: _onKeypadTap),
            ],
            const SizedBox(height: 16),
            // Account Picker(s)
            if (accounts.isEmpty)
              OutlinedButton.icon(
                onPressed: () async {
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
                icon: const Icon(Icons.add_rounded),
                label: Text(strings.addAccount),
              )
            else ...<Widget>[
              _AccountSelectorRow(
                label: _type == TransactionType.transfer
                    ? strings.fromAccount
                    : strings.account,
                accounts: accounts,
                selectedId: _accountId,
                onSelected: (String id) => setState(() => _accountId = id),
              ),
              if (_type == TransactionType.transfer) ...<Widget>[
                const SizedBox(height: 10),
                _AccountSelectorRow(
                  label: strings.toAccount,
                  accounts: accounts,
                  selectedId: _toAccountId,
                  onSelected: (String id) => setState(() => _toAccountId = id),
                ),
              ],
            ],
            // Category Picker (Expense / Income)
            if (_type != TransactionType.transfer) ...<Widget>[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    strings.category,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final CategoryModel? created =
                          await showModalBottomSheet<CategoryModel>(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            builder: (_) => CategoryFormSheet(
                              initialType: _type == TransactionType.income
                                  ? CategoryType.income
                                  : CategoryType.expense,
                            ),
                          );
                      if (created != null && mounted) {
                        setState(() => _categoryId = created.id);
                      }
                    },
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: Text(strings.addCategory),
                  ),
                ],
              ),
              SizedBox(
                height: 46,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: availableCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (BuildContext context, int index) {
                    final CategoryModel cat = availableCategories[index];
                    final bool selected = cat.id == _categoryId;
                    final Color catColor = AppColors.fromHex(cat.color);
                    return ChoiceChip(
                      avatar: Icon(
                        IconMapper.resolve(cat.icon),
                        size: 16,
                        color: selected ? Colors.white : catColor,
                      ),
                      label: Text(cat.name),
                      selected: selected,
                      selectedColor: catColor,
                      labelStyle: TextStyle(
                        color: selected
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      onSelected: (_) {
                        setState(() {
                          _categoryId = selected ? null : cat.id;
                        });
                      },
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 14),
            // Date & Time Picker button
            OutlinedButton.icon(
              onPressed: _pickDateTime,
              icon: const Icon(Icons.calendar_today_rounded, size: 18),
              label: Text(
                AppDateUtils.formatDateTime(
                  _occurredAt,
                  language: strings.language,
                  useBuddhistEra: useBuddhistEra,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _payeeController,
              maxLength: 120,
              onTap: () => setState(() => _showKeypad = false),
              decoration: InputDecoration(
                labelText: strings.payee,
                counterText: '',
                prefixIcon: const Icon(Icons.storefront_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              maxLength: 500,
              onTap: () => setState(() => _showKeypad = false),
              decoration: InputDecoration(
                labelText: strings.note,
                counterText: '',
                prefixIcon: const Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 14),
            _buildLocalAttachmentSection(theme, strings),
            const SizedBox(height: 18),
            BouncyTap(
              onTap: _saving ? null : () => _submit(accounts),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: null,
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    disabledBackgroundColor: accentColor,
                    disabledForegroundColor: Colors.white,
                  ),
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

class _AccountSelectorRow extends StatelessWidget {
  const _AccountSelectorRow({
    required this.label,
    required this.accounts,
    required this.selectedId,
    required this.onSelected,
  });

  final String label;
  final List<AccountModel> accounts;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: accounts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (BuildContext context, int index) {
              final AccountModel acc = accounts[index];
              final bool selected = acc.id == selectedId;
              final Color accColor = AppColors.fromHex(acc.color);
              return ChoiceChip(
                avatar: Icon(
                  IconMapper.resolve(acc.icon),
                  size: 16,
                  color: selected ? Colors.white : accColor,
                ),
                label: Text(acc.name),
                selected: selected,
                selectedColor: accColor,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : theme.colorScheme.onSurface,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                onSelected: (_) => onSelected(acc.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AmountKeypad extends StatelessWidget {
  const _AmountKeypad({required this.onKeyTap});

  final ValueChanged<String> onKeyTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    const List<List<String>> keys = <List<String>>[
      <String>['7', '8', '9', 'C'],
      <String>['4', '5', '6', '00'],
      <String>['1', '2', '3', '⌫'],
      <String>['.', '0'],
    ];

    return Column(
      children: <Widget>[
        for (int r = 0; r < 3; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: keys[r].map((String k) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: SizedBox(
                      height: 46,
                      child: BouncyTap(
                        onTap: () => onKeyTap(k),
                        pressedScale: 0.90,
                        duration: const Duration(milliseconds: 90),
                        child: Material(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withAlpha(90),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: null,
                            child: Center(
                              child: Text(
                                k,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        Row(
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: SizedBox(
                  height: 46,
                  child: BouncyTap(
                    onTap: () => onKeyTap('.'),
                    pressedScale: 0.90,
                    duration: const Duration(milliseconds: 90),
                    child: Material(
                      color: theme.colorScheme.surfaceContainerHighest.withAlpha(
                        90,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: null,
                        child: Center(
                          child: Text(
                            '.',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: SizedBox(
                  height: 46,
                  child: BouncyTap(
                    onTap: () => onKeyTap('0'),
                    pressedScale: 0.90,
                    duration: const Duration(milliseconds: 90),
                    child: Material(
                      color: theme.colorScheme.surfaceContainerHighest.withAlpha(
                        90,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: null,
                        child: Center(
                          child: Text(
                            '0',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
