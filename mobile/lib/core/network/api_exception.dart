import 'package:dio/dio.dart';

import '../../l10n/app_strings.dart';

class ApiErrorDetail {
  const ApiErrorDetail({
    required this.path,
    required this.message,
  });

  factory ApiErrorDetail.fromJson(Map<String, dynamic> json) {
    return ApiErrorDetail(
      path: (json['path'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
    );
  }

  final String path;
  final String message;
}

class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.details = const <ApiErrorDetail>[],
  });

  factory ApiException.fromDioException(DioException error) {
    final int? statusCode = error.response?.statusCode;
    final dynamic data = error.response?.data;

    if (data is Map<String, dynamic>) {
      final dynamic rawError = data['error'];
      if (rawError is Map<String, dynamic>) {
        final String code = (rawError['code'] ?? 'UNKNOWN_ERROR').toString();
        final String message =
            (rawError['message'] ?? 'An unexpected error occurred').toString();
        final List<ApiErrorDetail> parsedDetails = <ApiErrorDetail>[];
        final dynamic rawDetails = rawError['details'];
        if (rawDetails is List<dynamic>) {
          for (final dynamic item in rawDetails) {
            if (item is Map<String, dynamic>) {
              parsedDetails.add(ApiErrorDetail.fromJson(item));
            }
          }
        }
        return ApiException(
          code: code,
          message: message,
          statusCode: statusCode,
          details: parsedDetails,
        );
      }
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return ApiException(
        code: 'TIMEOUT',
        message: 'Connection timed out while contacting the server.',
        statusCode: statusCode,
      );
    }

    if (error.type == DioExceptionType.connectionError) {
      return ApiException(
        code: 'NETWORK_ERROR',
        message: 'Unable to reach the server. Please check your connection.',
        statusCode: statusCode,
      );
    }

    return ApiException(
      code: 'INTERNAL_ERROR',
      message: error.message ?? 'Unexpected error occurred.',
      statusCode: statusCode,
    );
  }

  final String code;
  final String message;
  final int? statusCode;
  final List<ApiErrorDetail> details;

  bool get isTokenExpired => statusCode == 401 && code == 'TOKEN_EXPIRED';
  bool get isConnectivityError => code == 'NETWORK_ERROR' || code == 'TIMEOUT';
  bool get isAccountHasTransactions =>
      statusCode == 409 && code == 'ACCOUNT_HAS_TRANSACTIONS';
  bool get isCategoryInUse => statusCode == 409 && code == 'CATEGORY_IN_USE';
  bool get isRegistrationClosed =>
      statusCode == 403 && code == 'REGISTRATION_CLOSED';

  String localizedMessage(AppStrings strings) {
    switch (code) {
      case 'INVALID_CREDENTIALS':
        return strings.tr(
          'อีเมลหรือรหัสผ่านไม่ถูกต้อง',
          'Invalid email or password.',
        );
      case 'REGISTRATION_CLOSED':
        return strings.tr(
          'มีบัญชีเจ้าของระบบอยู่แล้ว ไม่สามารถลงทะเบียนเพิ่มได้',
          'Owner account already exists. Registration is closed.',
        );
      case 'EMAIL_TAKEN':
        return strings.tr(
          'อีเมลนี้ถูกใช้งานแล้ว',
          'This email address is already registered.',
        );
      case 'ACCOUNT_HAS_TRANSACTIONS':
        return strings.tr(
          'บัญชีนี้มีรายการธุรกรรมอยู่แล้ว กรุณาใช้การเก็บเข้าคลัง (Archive) แทนการลบ',
          'This account has transactions. Please archive it instead of deleting.',
        );
      case 'CATEGORY_IN_USE':
        return strings.tr(
          'หมวดหมู่นี้ถูกใช้งานในรายการธุรกรรมแล้ว กรุณาเก็บเข้าคลัง (Archive) แทนการลบ',
          'This category is in use by transactions. Please archive it instead.',
        );
      case 'RATE_LIMITED':
        return strings.tr(
          'คำขอถี่เกินไป กรุณารอสักครู่แล้วลองใหม่อีกครั้ง',
          'Too many requests. Please wait a moment and try again.',
        );
      case 'TIMEOUT':
      case 'NETWORK_ERROR':
        return strings.tr(
          'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ กรุณาตรวจสอบอินเทอร์เน็ตหรือรอเซิร์ฟเวอร์ตื่น',
          'Cannot connect to the server. Please check your network.',
        );
      case 'VALIDATION_ERROR':
        if (details.isNotEmpty) {
          final String joined = details
              .map((ApiErrorDetail d) => '${d.path}: ${d.message}')
              .join(', ');
          return '$message ($joined)';
        }
        return message;
      default:
        return message;
    }
  }

  @override
  String toString() => 'ApiException($statusCode, $code: $message)';
}
