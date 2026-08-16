// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client_error.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ClientErrorReport _$ClientErrorReportFromJson(Map<String, dynamic> json) =>
    _ClientErrorReport(
      message: json['message'] as String,
      kind: json['kind'] as String?,
      stack: json['stack'] as String?,
      route: json['route'] as String?,
      occurredAt: json['occurred_at'] == null
          ? null
          : DateTime.parse(json['occurred_at'] as String),
      appBuild: json['app_build'] as String?,
      device: json['device'] as String?,
      context: json['context'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$ClientErrorReportToJson(_ClientErrorReport instance) =>
    <String, dynamic>{
      'message': instance.message,
      'kind': ?instance.kind,
      'stack': ?instance.stack,
      'route': ?instance.route,
      'occurred_at': ?instance.occurredAt?.toIso8601String(),
      'app_build': ?instance.appBuild,
      'device': ?instance.device,
      'context': ?instance.context,
    };
