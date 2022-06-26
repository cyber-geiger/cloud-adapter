// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'geiger_score.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GeigerScore _$GeigerScoreFromJson(Map<String, dynamic> json) => GeigerScore(
      username: json['username'] as String?,
      sharedScore: json['sharedScore'] as String?,
      sharedScoreDate: json['sharedScoreDate'] == null
          ? null
          : DateTime.parse(json['sharedScoreDate'] as String),
    );

Map<String, dynamic> _$GeigerScoreToJson(GeigerScore instance) =>
    <String, dynamic>{
      'username': instance.username,
      'sharedScore': instance.sharedScore,
      'sharedScoreDate': instance.sharedScoreDate?.toIso8601String(),
    };
