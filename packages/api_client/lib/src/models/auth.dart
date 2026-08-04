/// Kimlik DTO'ları — `docs/openapi.yaml` §Kimlik.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth.freezed.dart';
part 'auth.g.dart';

@freezed
abstract class RegisterRequest with _$RegisterRequest {
  const factory RegisterRequest({
    required String firstName,
    required String lastName,
    required String email,

    /// Başında 0 veya +90 olmadan 10 hane.
    required String telephone,
    required String password,

    /// `false` ise sunucu `422 VALIDATION_FAILED` döner.
    required bool kvkkAccepted,
  }) = _RegisterRequest;

  factory RegisterRequest.fromJson(Map<String, dynamic> json) =>
      _$RegisterRequestFromJson(json);
}

@freezed
abstract class LoginRequest with _$LoginRequest {
  const factory LoginRequest({
    required String email,
    required String password,
  }) = _LoginRequest;

  factory LoginRequest.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestFromJson(json);
}

@freezed
abstract class AuthResponse with _$AuthResponse {
  const factory AuthResponse({
    required String token,
    required AuthCustomer customer,
  }) = _AuthResponse;

  factory AuthResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseFromJson(json);
}

/// Giriş/kayıt yanıtındaki kısa müşteri özeti. Tam profil için [Customer].
@freezed
abstract class AuthCustomer with _$AuthCustomer {
  const factory AuthCustomer({required int id, required String firstName}) =
      _AuthCustomer;

  factory AuthCustomer.fromJson(Map<String, dynamic> json) =>
      _$AuthCustomerFromJson(json);
}

@freezed
abstract class Customer with _$Customer {
  const factory Customer({
    required int id,
    required String firstName,
    required String lastName,
    required String email,
    required String telephone,
    int? defaultLocationId,
  }) = _Customer;

  const Customer._();

  factory Customer.fromJson(Map<String, dynamic> json) =>
      _$CustomerFromJson(json);

  String get fullName => '$firstName $lastName';
}

/// `POST /me/push-token` gövdesi.
@freezed
abstract class PushTokenRequest with _$PushTokenRequest {
  const factory PushTokenRequest({
    required String fcmToken,

    /// Sözleşmede yalnızca `android` geçerlidir (`docs/openapi.yaml`).
    @Default('android') String platform,
  }) = _PushTokenRequest;

  factory PushTokenRequest.fromJson(Map<String, dynamic> json) =>
      _$PushTokenRequestFromJson(json);
}
