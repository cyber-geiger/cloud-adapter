// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'translation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Translation _$TranslationFromJson(Map<String, dynamic> json) => Translation(
      idTranslation: json['idTranslation'] as String?,
      language: json['language'] as String?,
      date:
          json['date'] == null ? null : DateTime.parse(json['date'] as String),
      content: json['content'] as String?,
    );

Map<String, dynamic> _$TranslationToJson(Translation instance) =>
    <String, dynamic>{
      'idTranslation': instance.idTranslation,
      'language': instance.language,
      'date': instance.date?.toIso8601String(),
      'content': instance.content,
    };
