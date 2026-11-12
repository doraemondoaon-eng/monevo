import 'package:flutter/material.dart';

import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_strings.dart';
import '../domain/transaction_model.dart';
import 'transaction_form_sheet.dart';

/// Section 8.2 Add Transaction Screen (`/transactions/add`):
/// Full-screen experience using the unified MONEVO Design System.
class AddTransactionScreen extends StatelessWidget {
  const AddTransactionScreen({
    super.key,
    this.initialType,
    this.initialAccountId,
    this.existing,
  });

  final TransactionType? initialType;
  final String? initialAccountId;
  final TransactionModel? existing;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          existing != null
              ? strings.editTransaction
              : strings.addTransaction,
        ),
      ),
      body: ResponsiveCenter(
        maxWidth: 640,
        child: TransactionFormSheet(
          existing: existing,
          initialType: initialType,
          initialAccountId: initialAccountId,
        ),
      ),
    );
  }
}

