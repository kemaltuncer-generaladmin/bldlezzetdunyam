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

    /// Kurumsal (B2B) alanları — kayıt formunda toplanır. Sunucu her yeni
    /// kaydı `corporate` işaretler; bireysel self-servis kayıt yoktur.
    String? companyName,
    String? contactPerson,
    String? taxOffice,
    String? taxNumber,
    String? companyPhone,
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

    /// `corporate` | `individual`. Eski yanıtlarda gelmeyebilir (`null`).
    String? accountType,

    /// **ARTIK OKUNMUYOR (16.08.2026). Yeni kod bu alana BAKMAZ.**
    ///
    /// Alan cari hesap dönemine aitti: borcu olan kurumsal müşterinin sipariş
    /// yolu `CustomerGate` ile kapatılıyordu. Cari hesap kaldırıldı, kapı da
    /// kaldırıldı — **herkes sipariş verir**; sipariş verilip verilemeyeceğine
    /// artık gün karar veriyor (`DailyMenu.isOrderable`).
    ///
    /// Alanın kendisi **korunuyor**: sözleşme yalnızca ekleme yapar
    /// (`AGENTS.md` §2.3) ve sunucu bunu göndermeye devam ediyor. Silseydik
    /// alanı gönderen bir sunucuda hiçbir şey kırılmazdı ama geri açılması
    /// gerektiğinde model, önbellek ve testler yeniden yazılırdı.
    ///
    /// Varsayılan `true` kalıyor: alan gelmediğinde sipariş yolunu kapatmak
    /// hiç kimsenin istemediği davranıştır.
    @Default(true) bool canOrder,
    String? companyName,
    String? contactPerson,
  }) = _Customer;

  const Customer._();

  factory Customer.fromJson(Map<String, dynamic> json) =>
      _$CustomerFromJson(json);

  String get fullName => '$firstName $lastName';

  /// Kurumsal mı? Profil ekranında firma bilgisi buna göre gösterilir.
  bool get isCorporate => accountType == 'corporate';
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
