// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'geiger_score.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GeigerScore _$GeigerScoreFromJson(Map<String, dynamic> json) => GeigerScore(
      username: json['username'] as String?,
      sharedscore: json['sharedscore'] as String?,
      sharedscoredate: json['sharedscoredate'] == null
          ? null
          : DateTime.parse(json['sharedscoredate'] as String),
    );

Map<String, dynamic> _$GeigerScoreToJson(GeigerScore instance) =>
    <String, dynamic>{
      'username': instance.username,
      'sharedscore': instance.sharedscore,
      'sharedscoredate': instance.sharedscoredate?.toIso8601String(),
    };
