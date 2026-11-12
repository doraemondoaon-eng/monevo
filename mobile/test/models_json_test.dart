import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monevo/core/security/pin_hasher.dart';
import 'package:monevo/core/widgets/icon_mapper.dart';
import 'package:monevo/features/accounts/domain/account_model.dart';
import 'package:monevo/features/auth/domain/auth_models.dart';
import 'package:monevo/features/categories/domain/category_model.dart';
import 'package:monevo/features/dashboard/domain/dashboard_models.dart';
import 'package:monevo/features/transactions/domain/transaction_model.dart';

void main() {
  group('Domain Models JSON Serialization', () {
    test('AuthSession, User, and AuthTokens parse accurately', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'user': <String, dynamic>{
          'id': 'u-1',
          'email': 'owner@monevo.app',
          'displayName': 'Somchai',
          'baseCurrency': 'THB',
          'timezone': 'Asia/Bangkok',
          'createdAt': '2026-11-12T02:15:00.000Z',
        },
        'tokens': <String, dynamic>{
          'accessToken': 'jwt-access',
          'refreshToken': 'jwt-refresh',
          'accessTokenExpiresIn': 900,
          'refreshTokenExpiresAt': '2026-12-12T02:15:00.000Z',
        },
      };

      final AuthSession session = AuthSession.fromJson(json);
      expect(session.user.id, 'u-1');
      expect(session.user.displayName, 'Somchai');
      expect(session.user.baseCurrency, 'THB');
      expect(session.tokens.accessToken, 'jwt-access');
      expect(session.tokens.refreshToken, 'jwt-refresh');
      expect(session.tokens.accessTokenExpiresIn, 900);
    });

    test('AccountModel parses minor units and nullable fields', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'id': 'acc-1',
        'name': 'KBank Main',
        'type': 'bank',
        'institution': 'KBank',
        'accountNumberLast4': '8899',
        'currency': 'THB',
        'openingBalance': 100000,
        'balance': 250075,
        'color': '#0D9488',
        'icon': 'account_balance',
        'includeInNetWorth': true,
        'isArchived': false,
        'sortOrder': 1,
        'createdAt': '2026-11-12T02:15:00.000Z',
        'updatedAt': '2026-11-12T02:15:00.000Z',
      };

      final AccountModel account = AccountModel.fromJson(json);
      expect(account.id, 'acc-1');
      expect(account.type, AccountType.bank);
      expect(account.balance, 250075);
      expect(account.subtitle, 'KBank · •••• 8899');
    });

    test('CategoryModel and PaginatedTransactions parse accurately', () {
      final CategoryModel category = CategoryModel.fromJson(<String, dynamic>{
        'id': 'cat-1',
        'name': 'อาหารและเครื่องดื่ม',
        'type': 'expense',
        'icon': 'restaurant',
        'color': '#F43F5E',
        'isArchived': false,
        'sortOrder': 0,
        'createdAt': '2026-11-12T02:15:00.000Z',
        'updatedAt': '2026-11-12T02:15:00.000Z',
      });
      expect(category.type, CategoryType.expense);
      expect(category.icon, 'restaurant');

      final PaginatedTransactions page = PaginatedTransactions.fromJson(
        <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'tx-1',
              'type': 'expense',
              'amount': 12500,
              'currency': 'THB',
              'accountId': 'acc-1',
              'toAccountId': null,
              'categoryId': 'cat-1',
              'occurredAt': '2026-11-12T05:00:00.000Z',
              'payee': 'After You',
              'note': 'Shibuya Honey Toast',
              'createdAt': '2026-11-12T05:00:00.000Z',
              'updatedAt': '2026-11-12T05:00:00.000Z',
            },
          ],
          'nextCursor': 'cursor-abc',
        },
      );
      expect(page.items.length, 1);
      expect(page.items.first.amount, 12500);
      expect(page.hasMore, isTrue);
    });

    test('DashboardSummary handles null and non-null savingsRate', () {
      final DashboardSummary summaryWithNull = DashboardSummary.fromJson(
        <String, dynamic>{
          'month': '2026-11',
          'currency': 'THB',
          'netWorth': 5000000,
          'totalAssets': 5500000,
          'totalLiabilities': 500000,
          'income': 0,
          'expense': 150000,
          'net': -150000,
          'savingsRate': null,
          'previousMonth': <String, dynamic>{'income': 3000000, 'expense': 2000000},
          'accountCount': 3,
        },
      );
      expect(summaryWithNull.savingsRate, isNull);
      expect(summaryWithNull.previousMonth.income, 3000000);
    });

    test('IconMapper resolves known keys and falls back to more_horiz', () {
      expect(IconMapper.resolve('wallet'), Icons.account_balance_wallet_rounded);
      expect(IconMapper.resolve('unknown_custom_icon'), Icons.more_horiz_rounded);
      expect(IconMapper.resolve(null), Icons.more_horiz_rounded);
    });

    test('PinHasher hashes and verifies 6-digit PINs in constant time', () {
      final String salt = PinHasher.generateSalt();
      final String hash = PinHasher.hashPin('123456', salt);
      expect(
        PinHasher.verifyPin(
          inputPin: '123456',
          storedHash: hash,
          storedSalt: salt,
        ),
        isTrue,
      );
      expect(
        PinHasher.verifyPin(
          inputPin: '654321',
          storedHash: hash,
          storedSalt: salt,
        ),
        isFalse,
      );
    });
  });
}
