// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'threat_weights.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ThreatWeights _$ThreatWeightsFromJson(Map<String, dynamic> json) =>
    ThreatWeights(
      idThreatweights: json['id_threatweights'] as String?,
      threatDict: json['threat_dict'] == null
          ? null
          : ThreatDict.fromJson(json['threat_dict'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ThreatWeightsToJson(ThreatWeights instance) =>
    <String, dynamic>{
      'id_threatweights': instance.idThreatweights,
      'threat_dict': instance.threatDict?.toJson(),
    };
