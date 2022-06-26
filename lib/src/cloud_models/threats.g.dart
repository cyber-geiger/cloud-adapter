part of 'threats.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Threats _$ThreatsFromJson(Map<String, dynamic> json) => Threats(
  uuid: json['UUID'] as String?,
  name: json['Name'] as String?,
  threat: json['GEIGER-threat'] as String?,
)..uuid = json['UUID'] as String?;

Map<String, dynamic> _$ThreatsToJson(Threats instance) => <String, dynamic>{
  'GEIGER-threat': instance.threat,
  'UUID': instance.uuid,
  'Name': instance.name,
};