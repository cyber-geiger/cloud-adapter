// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'geiger_score.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GeigerScore _$GeigerScoreFromJson(Map<String, dynamic> json) => GeigerScore(
      username: json['username'] as String?,
      useruuid: json['useruuid'] as String?,
      devicename: json['devicename'] as String?,
      sharedScore: json['sharedScore'] as String?,
      sharedNumberOfMetrics: json['sharedNumberOfMetrics'] as int?,
      sharedScoreDate: json['sharedScoreDate'] == null
          ? null
          : DateTime.parse(json['sharedScoreDate'] as String),
    );

Map<String, dynamic> _$GeigerScoreToJson(GeigerScore instance) =>
    <String, dynamic>{
      'username': instance.username,
      'useruuid': instance.useruuid,
      'devicename': instance.devicename,
      'sharedScore': instance.sharedScore,
      'sharedNumberOfMetrics': instance.sharedNumberOfMetrics,
      'sharedScoreDate': instance.sharedScoreDate?.toIso8601String(),
    };
