// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Event _$EventFromJson(Map<String, dynamic> json) => Event(
      id_event: json['id_event'] as String?,
      tlp: json['tlp'] as String?,
      type: json['type'] as String?,
      encoding: json['encoding'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
      last_modified: json['last_modified'] == null
          ? null
          : DateTime.parse(json['last_modified'] as String),
      expires: json['expires'] == null
          ? null
          : DateTime.parse(json['expires'] as String),
      language: json['language'] as String?,
      owner: json['owner'] as String?,
      content: json['content'] as String?,
      translation: (json['translation'] as List<dynamic>?)
          ?.map((e) => Translation.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$EventToJson(Event instance) => <String, dynamic>{
      'id_event': instance.id_event,
      'tlp': instance.tlp,
      'type': instance.type,
      'encoding': instance.encoding,
      'tags': instance.tags,
      'last_modified': instance.last_modified?.toIso8601String(),
      'expires': instance.expires?.toIso8601String(),
      'language': instance.language,
      'owner': instance.owner,
      'content': instance.content,
      'translation': instance.translation?.map((e) => e.toJson()).toList(),
    };
