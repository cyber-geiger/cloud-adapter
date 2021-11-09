// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'threat_weights.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ThreatWeights _$ThreatWeightsFromJson(Map<String, dynamic> json) =>
    ThreatWeights(
      idThreatweights: json['idThreatweights'] as String?,
      threatDict: json['threatDict'] == null
          ? null
          : ThreatDict.fromJson(json['threatDict'] as Map<String, dynamic>),
    )..getIdThreatweights = json['getIdThreatweights'] as String?;

Map<String, dynamic> _$ThreatWeightsToJson(ThreatWeights instance) =>
    <String, dynamic>{
      'idThreatweights': instance.idThreatweights,
      'threatDict': instance.threatDict?.toJson(),
      'getIdThreatweights': instance.getIdThreatweights,
    };
