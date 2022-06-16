// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'threats.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Threats _$ThreatsFromJson(Map<String, dynamic> json) => Threats(
      threat: json['GEIGER-threat'] as String?,
      uuid: json['UUID'] as String?,
      name: json['Name'] as String?,
    );

Map<String, dynamic> _$ThreatsToJson(Threats instance) => <String, dynamic>{
      'GEIGER-threat': instance.threat,
      'UUID': instance.uuid,
      'Name': instance.name,
    };
