import 'package:get/get.dart';

class AppException implements Exception {
  final dynamic _message;
  final dynamic _prefix;

  AppException([this._message, this._prefix]);

  @override
  String toString() {
    final prefix = _prefix?.toString() ?? '';
    final message = _message?.toString() ?? '';
    return '$prefix$message';
  }
}

class FetchDataException extends AppException {
  FetchDataException([String? message])
      : super(message, 'service_api_communication_error_prefix'.tr);
}

class BadRequestException extends AppException {
  BadRequestException([message])
      : super(message, 'service_api_invalid_request_prefix'.tr);
}

class UnauthorisedException extends AppException {
  UnauthorisedException([message])
      : super(message, 'service_api_unauthorized_prefix'.tr);
}

class InvalidInputException extends AppException {
  InvalidInputException([String? message])
      : super(message, 'service_api_invalid_input_prefix'.tr);
}