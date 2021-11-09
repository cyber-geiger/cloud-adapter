// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Tag _$TagFromJson(Map<String, dynamic> json) => Tag(
      date:
          json['date'] == null ? null : DateTime.parse(json['date'] as String),
      description: json['description'] as String?,
      descriptionTranslations:
          (json['descriptionTranslations'] as List<dynamic>?)
              ?.map((e) => Translation.fromJson(e as Map<String, dynamic>))
              .toList(),
      idTag: json['idTag'] as String?,
      name: json['name'] as String?,
      nameTranslations: (json['nameTranslations'] as List<dynamic>?)
          ?.map((e) => Translation.fromJson(e as Map<String, dynamic>))
          .toList(),
      parentIdTag: json['parentIdTag'] as String?,
    );

Map<String, dynamic> _$TagToJson(Tag instance) => <String, dynamic>{
      'date': instance.date?.toIso8601String(),
      'description': instance.description,
      'descriptionTranslations':
          instance.descriptionTranslations?.map((e) => e.toJson()).toList(),
      'idTag': instance.idTag,
      'name': instance.name,
      'nameTranslations':
          instance.nameTranslations?.map((e) => e.toJson()).toList(),
      'parentIdTag': instance.parentIdTag,
    };
