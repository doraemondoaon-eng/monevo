import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../features/transactions/presentation/transaction_form_sheet.dart';
import '../../l10n/app_strings.dart';
import '../theme/app_colors.dart';

class MainShellScreen extends StatelessWidget {
  const MainShellScreen({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    HapticFeedback.selectionClick();
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  Future<void> _openQuickAddTransaction(BuildContext context) async {
    HapticFeedback.mediumImpact();
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const TransactionFormSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isTabletOrWide = screenWidth >= 840;

    if (isTabletOrWide) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: <Widget>[
              NavigationRail(
                extended: screenWidth >= 1080,
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: _onDestinationSelected,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: FloatingActionButton(
                    onPressed: () => _openQuickAddTransaction(context),
                    backgroundColor: AppColors.primaryEmerald,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    tooltip: strings.addTransaction,
                    child: const Icon(Icons.add_rounded, size: 24),
                  ),
                ),
                destinations: <NavigationRailDestination>[
                  NavigationRailDestination(
                    icon: const Icon(Icons.space_dashboard_outlined),
                    selectedIcon: const Icon(
                      Icons.space_dashboard_rounded,
                      color: AppColors.primaryEmerald,
                    ),
                    label: Text(strings.navDashboard),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.receipt_long_outlined),
                    selectedIcon: const Icon(
                      Icons.receipt_long_rounded,
                      color: AppColors.primaryEmerald,
                    ),
                    label: Text(strings.navTransactions),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                    selectedIcon: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: AppColors.primaryEmerald,
                    ),
                    label: Text(strings.navAccounts),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.settings_outlined),
                    selectedIcon: const Icon(
                      Icons.settings_rounded,
                      color: AppColors.primaryEmerald,
                    ),
                    label: Text(strings.navSettings),
                  ),
                ],
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(child: navigationShell),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: navigationShell,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openQuickAddTransaction(context),
        backgroundColor: AppColors.primaryEmerald,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add_rounded, size: 24),
        label: Text(
          strings.addTransaction,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.space_dashboard_outlined),
            selectedIcon: const Icon(
              Icons.space_dashboard_rounded,
              color: AppColors.primaryEmerald,
            ),
            label: strings.navDashboard,
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(
              Icons.receipt_long_rounded,
              color: AppColors.primaryEmerald,
            ),
            label: strings.navTransactions,
          ),
          NavigationDestination(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: const Icon(
              Icons.account_balance_wallet_rounded,
              color: AppColors.primaryEmerald,
            ),
            label: strings.navAccounts,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(
              Icons.settings_rounded,
              color: AppColors.primaryEmerald,
            ),
            label: strings.navSettings,
          ),
        ],
      ),
    );
  }
}
