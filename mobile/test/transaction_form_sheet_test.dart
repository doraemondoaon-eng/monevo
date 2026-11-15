import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monevo/core/network/api_exception.dart';
import 'package:monevo/core/storage/local_cache_service.dart';
import 'package:monevo/core/theme/app_theme.dart';
import 'package:monevo/features/accounts/data/accounts_api.dart';
import 'package:monevo/features/accounts/data/accounts_repository.dart';
import 'package:monevo/features/accounts/domain/account_model.dart';
import 'package:monevo/features/accounts/presentation/accounts_controller.dart';
import 'package:monevo/features/categories/data/categories_api.dart';
import 'package:monevo/features/categories/data/categories_repository.dart';
import 'package:monevo/features/categories/domain/category_model.dart';
import 'package:monevo/features/categories/presentation/categories_controller.dart';
import 'package:monevo/features/categories/presentation/categories_screen.dart';
import 'package:monevo/features/transactions/presentation/transaction_form_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SeededAccountsController extends AccountsController {
  _SeededAccountsController(List<AccountModel> seeded)
    : super(
        AccountsRepository(api: AccountsApi(Dio()), cache: LocalCacheService()),
        isAuthenticated: false,
      ) {
    state = AccountsState(items: seeded);
  }
}

class _SeededCategoriesController extends CategoriesController {
  _SeededCategoriesController(
    List<CategoryModel> seeded, {
    Set<String> inUseIds = const <String>{},
  }) : _inUseIds = inUseIds,
       super(
         CategoriesRepository(
           api: CategoriesApi(Dio()),
           cache: LocalCacheService(),
         ),
         isAuthenticated: false,
       ) {
    state = CategoriesState(items: seeded);
  }

  final Set<String> _inUseIds;

  @override
  Future<CategoryModel> updateCategory(
    String id, {
    String? name,
    String? icon,
    String? color,
    bool? isArchived,
    int? sortOrder,
  }) async {
    final CategoryModel existing = state.items.firstWhere(
      (CategoryModel c) => c.id == id,
    );
    final CategoryModel updated = CategoryModel(
      id: existing.id,
      name: name ?? existing.name,
      type: existing.type,
      icon: icon ?? existing.icon,
      color: color ?? existing.color,
      isArchived: isArchived ?? existing.isArchived,
      sortOrder: sortOrder ?? existing.sortOrder,
      createdAt: existing.createdAt,
      updatedAt: existing.updatedAt,
    );
    state = state.copyWith(
      items: state.items
          .map((CategoryModel c) => c.id == id ? updated : c)
          .where((CategoryModel c) => state.includeArchived || !c.isArchived)
          .toList(),
    );
    return updated;
  }

  @override
  Future<void> deleteCategory(String id) async {
    if (_inUseIds.contains(id)) {
      throw const ApiException(
        code: 'CATEGORY_IN_USE',
        message: 'Category is in use',
        statusCode: 409,
      );
    }
    state = state.copyWith(
      items: state.items.where((CategoryModel c) => c.id != id).toList(),
    );
  }
}

void main() {
  final DateTime fixedNow = DateTime(2026, 11, 13, 11, 35);

  final List<AccountModel> testAccounts = <AccountModel>[
    AccountModel(
      id: 'acc-1',
      name: 'กระเป๋าเงินหลัก',
      type: AccountType.cash,
      institution: null,
      accountNumberLast4: null,
      currency: 'THB',
      openingBalance: 0,
      balance: 1056400,
      color: '#10B981',
      icon: 'wallet',
      includeInNetWorth: true,
      isArchived: false,
      sortOrder: 0,
      createdAt: fixedNow,
      updatedAt: fixedNow,
    ),
    AccountModel(
      id: 'acc-2',
      name: 'ธนาคารกสิกรไทย',
      type: AccountType.bank,
      institution: 'KBANK',
      accountNumberLast4: '1234',
      currency: 'THB',
      openingBalance: 0,
      balance: 500000,
      color: '#138F2D',
      icon: 'account_balance',
      includeInNetWorth: true,
      isArchived: false,
      sortOrder: 1,
      createdAt: fixedNow,
      updatedAt: fixedNow,
    ),
  ];

  final List<CategoryModel> testCategories = <CategoryModel>[
    CategoryModel(
      id: 'cat-food',
      name: 'อาหาร',
      type: CategoryType.expense,
      icon: 'restaurant',
      color: '#F97316',
      isArchived: false,
      sortOrder: 0,
      createdAt: fixedNow,
      updatedAt: fixedNow,
    ),
    CategoryModel(
      id: 'cat-travel',
      name: 'เดินทาง',
      type: CategoryType.expense,
      icon: 'directions_car',
      color: '#3B82F6',
      isArchived: false,
      sortOrder: 1,
      createdAt: fixedNow,
      updatedAt: fixedNow,
    ),
    CategoryModel(
      id: 'cat-salary',
      name: 'เงินเดือน',
      type: CategoryType.income,
      icon: 'payments',
      color: '#10B981',
      isArchived: false,
      sortOrder: 0,
      createdAt: fixedNow,
      updatedAt: fixedNow,
    ),
  ];

  Future<void> pumpSheet(
    WidgetTester tester, {
    List<CategoryModel>? categories,
    Set<String> inUseCategoryIds = const <String>{},
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'monevo_language': 'th',
      'monevo_buddhist_era': true,
    });
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          accountsControllerProvider.overrideWith(
            (_) => _SeededAccountsController(testAccounts),
          ),
          categoriesControllerProvider.overrideWith(
            (_) => _SeededCategoriesController(
              categories ?? testCategories,
              inUseIds: inUseCategoryIds,
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('th'),
          supportedLocales: const <Locale>[Locale('th'), Locale('en')],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(),
          home: const Scaffold(body: TransactionFormSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('TransactionFormSheet redesign', () {
    testWidgets('renders fintech layout cleanly at 360x800 without overflow', (
      WidgetTester tester,
    ) async {
      await pumpSheet(tester);

      expect(find.text('บันทึกรายการใหม่'), findsOneWidget);
      expect(find.text('THB (฿)'), findsOneWidget);
      expect(find.text('฿0'), findsOneWidget);
      expect(find.text('รายจ่าย'), findsOneWidget);
      expect(find.text('รายรับ'), findsOneWidget);
      expect(find.text('โอนเงิน'), findsOneWidget);

      for (final String key in const <String>[
        '7',
        '8',
        '9',
        'C',
        '4',
        '5',
        '6',
        '00',
        '1',
        '2',
        '3',
        '.',
        '0',
      ]) {
        expect(find.byKey(ValueKey<String>('keypad_$key')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey<String>('keypad_⌫')), findsOneWidget);

      expect(find.text('เพิ่มข้อมูล'), findsOneWidget);
      expect(find.text('หมวดหมู่'), findsOneWidget);
      expect(find.text('อาหาร'), findsOneWidget);
      expect(find.text('เดินทาง'), findsOneWidget);
      expect(find.text('บัญชีที่ใช้'), findsOneWidget);
      expect(find.text('กระเป๋าเงินหลัก'), findsOneWidget);
      expect(find.text('บันทึกเพิ่มเติม (ถ้ามี)'), findsOneWidget);
      expect(find.text('บันทึกรายการ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keypad input formats commas, decimals, backspace, and clear', (
      WidgetTester tester,
    ) async {
      await pumpSheet(tester);

      for (final String k in const <String>['1', '2', '5', '0']) {
        await tester.tap(find.byKey(ValueKey<String>('keypad_$k')));
        await tester.pump();
      }
      expect(find.text('฿1,250'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('keypad_.')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('keypad_5')));
      await tester.pump();
      expect(find.text('฿1,250.5'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('keypad_⌫')));
      await tester.pump();
      expect(find.text('฿1,250.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('keypad_C')));
      await tester.pump();
      expect(find.text('฿0'), findsOneWidget);
    });

    testWidgets('expands extra details and switches between transfer & income', (
      WidgetTester tester,
    ) async {
      await pumpSheet(tester);

      // Expand "+ เพิ่มข้อมูล"
      await tester.tap(find.text('เพิ่มข้อมูล'));
      await tester.pumpAndSettle();
      expect(
        find.text('รูปสลิป / ใบเสร็จ (จัดเก็บในเครื่องเท่านั้น)'),
        findsOneWidget,
      );

      // Collapse again before testing segment switches
      await tester.tap(find.text('เพิ่มข้อมูล'));
      await tester.pumpAndSettle();

      // Switch to Transfer -> categories disappear, source & dest accounts appear
      await tester.tap(find.text('โอนเงิน'));
      await tester.pumpAndSettle();
      expect(find.text('หมวดหมู่'), findsNothing);
      expect(find.text('จากบัญชี'), findsOneWidget);
      expect(find.text('ไปยังบัญชีปลายทาง'), findsOneWidget);

      // Switch to Income -> income category appears
      await tester.tap(find.text('รายรับ'));
      await tester.pumpAndSettle();
      expect(find.text('หมวดหมู่'), findsOneWidget);
      expect(find.text('เงินเดือน'), findsOneWidget);
    });

    testWidgets(
      'uses crimson red palette in expense mode and switches cleanly per type',
      (WidgetTester tester) async {
        await pumpSheet(tester);

        // Expense is default: blush-rose canvas, crimson amount, cart hero badge
        expect(find.byIcon(Icons.shopping_cart_rounded), findsOneWidget);
        final Text expenseAmount = tester.widget<Text>(find.text('฿0'));
        expect(expenseAmount.style?.color, const Color(0xFFA81010));

        // Selecting an expense category renders white label on filled crimson card
        await tester.tap(find.text('อาหาร'));
        await tester.pumpAndSettle();
        final Text selectedFoodLabel = tester.widget<Text>(find.text('อาหาร'));
        expect(selectedFoodLabel.style?.color, Colors.white);

        // Switching to Income restores emerald palette
        await tester.tap(find.text('รายรับ'));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.shopping_cart_rounded), findsNothing);
        final Text incomeAmount = tester.widget<Text>(find.text('฿0'));
        expect(incomeAmount.style?.color, const Color(0xFF064E3B));

        // Switching to Transfer activates blue transfer palette
        await tester.tap(find.text('โอนเงิน'));
        await tester.pumpAndSettle();
        final Text transferAmount = tester.widget<Text>(find.text('฿0'));
        expect(transferAmount.style?.color, const Color(0xFF1E3A8A));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'allows renaming and immediately deleting unwanted categories via Manage sheet',
      (WidgetTester tester) async {
        final List<CategoryModel> customCategories = <CategoryModel>[
          ...testCategories,
          CategoryModel(
            id: 'cat-rider-en',
            name: 'วิ่ง rider',
            type: CategoryType.income,
            icon: 'delivery_dining',
            color: '#10B981',
            isArchived: false,
            sortOrder: 1,
            createdAt: fixedNow,
            updatedAt: fixedNow,
          ),
          CategoryModel(
            id: 'cat-rider-th',
            name: 'วิ่งไรเดอร์',
            type: CategoryType.income,
            icon: 'delivery_dining',
            color: '#10B981',
            isArchived: false,
            sortOrder: 2,
            createdAt: fixedNow,
            updatedAt: fixedNow,
          ),
        ];

        await pumpSheet(
          tester,
          categories: customCategories,
          inUseCategoryIds: const <String>{'cat-rider-en'},
        );

        // Switch to Income where duplicate rider categories exist
        await tester.tap(find.text('รายรับ'));
        await tester.pumpAndSettle();
        expect(find.text('วิ่ง rider'), findsOneWidget);
        expect(find.text('วิ่งไรเดอร์'), findsOneWidget);

        // Open inline Manage Categories modal
        await tester.tap(
          find.byKey(const ValueKey<String>('transaction_manage_categories_btn')),
        );
        await tester.pumpAndSettle();
        expect(find.text('จัดการหมวดหมู่'), findsOneWidget);

        // Rename 'วิ่งไรเดอร์' -> 'งานไรเดอร์'
        await tester.tap(
          find.byKey(const ValueKey<String>('manage_category_edit_cat-rider-th')),
        );
        await tester.pumpAndSettle();
        expect(find.text('แก้ไขหมวดหมู่'), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('category_form_delete_button')),
          findsOneWidget,
        );

        await tester.enterText(
          find.descendant(
            of: find.byType(CategoryFormSheet),
            matching: find.byType(TextFormField),
          ),
          'งานไรเดอร์',
        );
        await tester.tap(find.text('บันทึก'));
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();

        expect(find.text('งานไรเดอร์'), findsWidgets);
        expect(find.text('วิ่งไรเดอร์'), findsNothing);

        // Delete 'วิ่ง rider' (simulating 409 CATEGORY_IN_USE -> immediate hide fallback)
        await tester.tap(
          find.byKey(const ValueKey<String>('manage_category_delete_cat-rider-en')),
        );
        await tester.pumpAndSettle();
        expect(find.text('ลบหมวดหมู่'), findsOneWidget);

        await tester.tap(find.text('ลบ'));
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();

        // Unwanted duplicate category disappears immediately from list and strip
        expect(find.text('วิ่ง rider'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'long-pressing a category tile opens edit/delete actions and deletes directly',
      (WidgetTester tester) async {
        await pumpSheet(tester);

        // Long-press 'เดินทาง' in expense category strip
        await tester.longPress(find.text('เดินทาง'));
        await tester.pumpAndSettle();

        expect(find.text('แก้ไขหมวดหมู่'), findsOneWidget);
        expect(find.text('ลบหมวดหมู่'), findsOneWidget);

        // Open edit sheet and delete directly from edit modal
        await tester.tap(find.text('แก้ไขหมวดหมู่'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey<String>('category_form_delete_button')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('ลบ'));
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();

        expect(find.text('เดินทาง'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

