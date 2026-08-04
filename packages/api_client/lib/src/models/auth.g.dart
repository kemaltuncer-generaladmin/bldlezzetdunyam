// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RegisterRequest _$RegisterRequestFromJson(Map<String, dynamic> json) =>
    _RegisterRequest(
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      email: json['email'] as String,
      telephone: json['telephone'] as String,
      password: json['password'] as String,
      kvkkAccepted: json['kvkk_accepted'] as bool,
    );

Map<String, dynamic> _$RegisterRequestToJson(_RegisterRequest instance) =>
    <String, dynamic>{
      'first_name': instance.firstName,
      'last_name': instance.lastName,
      'email': instance.email,
      'telephone': instance.telephone,
      'password': instance.password,
      'kvkk_accepted': instance.kvkkAccepted,
    };

_LoginRequest _$LoginRequestFromJson(Map<String, dynamic> json) =>
    _LoginRequest(
      email: json['email'] as String,
      password: json['password'] as String,
    );

Map<String, dynamic> _$LoginRequestToJson(_LoginRequest instance) =>
    <String, dynamic>{'email': instance.email, 'password': instance.password};

_AuthResponse _$AuthResponseFromJson(Map<String, dynamic> json) =>
    _AuthResponse(
      token: json['token'] as String,
      customer: AuthCustomer.fromJson(json['customer'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$AuthResponseToJson(_AuthResponse instance) =>
    <String, dynamic>{
      'token': instance.token,
      'customer': instance.customer.toJson(),
    };

_AuthCustomer _$AuthCustomerFromJson(Map<String, dynamic> json) =>
    _AuthCustomer(
      id: (json['id'] as num).toInt(),
      firstName: json['first_name'] as String,
    );

Map<String, dynamic> _$AuthCustomerToJson(_AuthCustomer instance) =>
    <String, dynamic>{'id': instance.id, 'first_name': instance.firstName};

_Customer _$CustomerFromJson(Map<String, dynamic> json) => _Customer(
  id: (json['id'] as num).toInt(),
  firstName: json['first_name'] as String,
  lastName: json['last_name'] as String,
  email: json['email'] as String,
  telephone: json['telephone'] as String,
  defaultLocationId: (json['default_location_id'] as num?)?.toInt(),
);

Map<String, dynamic> _$CustomerToJson(_Customer instance) => <String, dynamic>{
  'id': instance.id,
  'first_name': instance.firstName,
  'last_name': instance.lastName,
  'email': instance.email,
  'telephone': instance.telephone,
  'default_location_id': ?instance.defaultLocationId,
};

_PushTokenRequest _$PushTokenRequestFromJson(Map<String, dynamic> json) =>
    _PushTokenRequest(
      fcmToken: json['fcm_token'] as String,
      platform: json['platform'] as String? ?? 'android',
    );

Map<String, dynamic> _$PushTokenRequestToJson(_PushTokenRequest instance) =>
    <String, dynamic>{
      'fcm_token': instance.fcmToken,
      'platform': instance.platform,
    };
