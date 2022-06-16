// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'company_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CompanyEvent _$CompanyEventFromJson(Map<String, dynamic> json) => CompanyEvent(
      name: json['name'] as String?,
      minValue: json['minValue'] as int?,
      maxValue: json['maxValue'] as int?,
      geigerValue: json['geigerValue'] as int?,
      valueType: json['valueType'] as String?,
      type: json['type'] as String?,
      relation: json['relation'] as String?,
      threatsImpact: (json['threatsImpact'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      flag: json['flag'] as int?,
      description: json['description'] as String?,
    );

Map<String, dynamic> _$CompanyEventToJson(CompanyEvent instance) =>
    <String, dynamic>{
      'name': instance.name,
      'minValue': instance.minValue,
      'maxValue': instance.maxValue,
      'geigerValue': instance.geigerValue,
      'valueType': instance.valueType,
      'type': instance.type,
      'relation': instance.relation,
      'threatsImpact': instance.threatsImpact,
      'flag': instance.flag,
      'description': instance.description,
    };
