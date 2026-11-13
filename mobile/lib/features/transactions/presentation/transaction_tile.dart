import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_image_storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/account_badge.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/icon_mapper.dart';
import '../../../core/widgets/monevo_feedback.dart';
import '../../../core/widgets/thai_institution_catalog.dart';
import '../../../l10n/app_strings.dart';
import '../../accounts/domain/account_model.dart';
import '../../accounts/presentation/accounts_controller.dart';
import '../../categories/domain/category_model.dart';
import '../../categories/presentation/categories_controller.dart';
import '../../settings/presentation/settings_controller.dart';
import '../domain/transaction_model.dart';

class TransactionTile extends ConsumerWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.showDate = false,
  });

  final TransactionModel transaction;
  final VoidCallback? onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);
    final bool useBuddhistEra = ref.watch(
      settingsControllerProvider.select(
        (AppSettingsState s) => s.useBuddhistEra,
      ),
    );
    final AccountsState accountsState = ref.watch(accountsControllerProvider);
    final CategoriesState categoriesState = ref.watch(
      categoriesControllerProvider,
    );
    final bool hasLocalImage = ref.watch(
      localImageAttachmentsProvider.select(
        (Map<String, LocalImageAttachment> map) =>
            map.containsKey(transaction.id),
      ),
    );

    final AccountModel? fromAccount = accountsState.findById(
      transaction.accountId,
    );
    final AccountModel? toAccount = accountsState.findById(
      transaction.toAccountId,
    );
    final CategoryModel? category = categoriesState.findById(
      transaction.categoryId,
    );

    final bool isIncome = transaction.type == TransactionType.income;
    final bool isTransfer = transaction.type == TransactionType.transfer;

    final Color badgeColor = isTransfer
        ? AppColors.transfer
        : (category != null
              ? AppColors.fromHex(category.color)
              : (isIncome ? AppColors.income : AppColors.expense));

    final IconData iconData = isTransfer
        ? Icons.swap_horiz_rounded
        : IconMapper.resolve(category?.icon);

    final String primaryTitle;
    if (transaction.payee != null && transaction.payee!.trim().isNotEmpty) {
      primaryTitle = transaction.payee!.trim();
    } else if (isTransfer) {
      primaryTitle = strings.transfer;
    } else if (category != null) {
      primaryTitle = category.name;
    } else {
      primaryTitle = strings.uncategorized;
    }

    final List<String> subtitleParts = <String>[];
    if (isTransfer) {
      final String fromName = fromAccount?.name ?? '—';
      final String toName = toAccount?.name ?? '—';
      subtitleParts.add('$fromName → $toName');
    } else {
      if (category != null &&
          transaction.payee != null &&
          transaction.payee!.trim().isNotEmpty) {
        subtitleParts.add(category.name);
      }
      if (fromAccount != null) {
        subtitleParts.add(fromAccount.name);
      }
    }
    if (showDate) {
      subtitleParts.add(
        AppDateUtils.formatShortDate(
          transaction.occurredAt,
          language: strings.language,
          useBuddhistEra: useBuddhistEra,
        ),
      );
    } else {
      subtitleParts.add(AppDateUtils.formatTimeOnly(transaction.occurredAt));
    }

    final Color amountColor = isTransfer
        ? AppColors.transfer
        : (isIncome ? AppColors.income : theme.colorScheme.onSurface);

    final int signedSatang = isTransfer
        ? transaction.amount
        : (isIncome ? transaction.amount : -transaction.amount);

    return BouncyTap(
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: badgeColor.withAlpha(28),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(iconData, color: badgeColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          primaryTitle,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasLocalImage) ...<Widget>[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: strings.tr(
                            'มีรูปสลิป/ใบเสร็จแนบในเครื่อง',
                            'Local receipt/slip attached on device',
                          ),
                          child: Icon(
                            Icons.receipt_long_rounded,
                            size: 15,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: <Widget>[
                      if (fromAccount != null &&
                          ThaiInstitutionCatalog.match(
                                fromAccount.institution,
                                accountName: fromAccount.name,
                              ) !=
                              null) ...<Widget>[
                        AccountBrandAvatar(
                          institution: fromAccount.institution,
                          accountName: fromAccount.name,
                          iconKey: fromAccount.icon,
                          colorHex: fromAccount.color,
                          size: 16,
                          borderRadius: 4,
                        ),
                        const SizedBox(width: 5),
                      ],
                      Expanded(
                        child: Text(
                          subtitleParts.join(' · '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (transaction.note != null &&
                      transaction.note!.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      transaction.note!.trim(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withAlpha(190),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            AmountText(
              satang: signedSatang,
              showPlusSign: isIncome,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: amountColor,
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
  }
}
