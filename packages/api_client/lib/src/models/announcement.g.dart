// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'announcement.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Announcement _$AnnouncementFromJson(Map<String, dynamic> json) =>
    _Announcement(
      id: (json['id'] as num).toInt(),
      placement: json['placement'] as String,
      body: json['body'] as String,
      dismissible: json['dismissible'] as bool,
      seen: json['seen'] as bool,
      dismissed: json['dismissed'] as bool,
      severity: json['severity'] == null
          ? AnnouncementSeverity.info
          : const AnnouncementSeverityConverter().fromJson(
              json['severity'] as String?,
            ),
      title: json['title'] as String?,
      actionLabel: json['action_label'] as String?,
      actionUrl: json['action_url'] as String?,
      imageUrl: json['image_url'] as String?,
      startsAt: json['starts_at'] == null
          ? null
          : DateTime.parse(json['starts_at'] as String),
      endsAt: json['ends_at'] == null
          ? null
          : DateTime.parse(json['ends_at'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$AnnouncementToJson(
  _Announcement instance,
) => <String, dynamic>{
  'id': instance.id,
  'placement': instance.placement,
  'body': instance.body,
  'dismissible': instance.dismissible,
  'seen': instance.seen,
  'dismissed': instance.dismissed,
  'severity': ?const AnnouncementSeverityConverter().toJson(instance.severity),
  'title': ?instance.title,
  'action_label': ?instance.actionLabel,
  'action_url': ?instance.actionUrl,
  'image_url': ?instance.imageUrl,
  'starts_at': ?instance.startsAt?.toIso8601String(),
  'ends_at': ?instance.endsAt?.toIso8601String(),
  'created_at': ?instance.createdAt?.toIso8601String(),
};
