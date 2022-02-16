// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recommendation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Recommendation _$RecommendationFromJson(Map<String, dynamic> json) =>
    Recommendation(
      id_recommendation: json['id_recommendation'] as String?,
      Action: json['Action'] as String?,
      RecommendationType: json['RecommendationType'] as String?,
      Steps:
          (json['Steps'] as List<dynamic>?)?.map((e) => e as String).toList(),
      costs: json['costs'] as bool?,
      long: json['long'] as String?,
      short: json['short'] as String?,
      minimunRequiredKnowledgeLevel:
          json['minimunRequiredKnowledgeLevel'] as int,
      parentUUID: json['parentUUID'] as String?,
      relatedThreatWeights: (json['relatedThreatWeights'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    )..idrecommendation = json['idrecommendation'] as String?;

Map<String, dynamic> _$RecommendationToJson(Recommendation instance) =>
    <String, dynamic>{
      'id_recommendation': instance.id_recommendation,
      'Action': instance.Action,
      'RecommendationType': instance.RecommendationType,
      'Steps': instance.Steps,
      'costs': instance.costs,
      'long': instance.long,
      'short': instance.short,
      'minimunRequiredKnowledgeLevel': instance.minimunRequiredKnowledgeLevel,
      'parentUUID': instance.parentUUID,
      'relatedThreatWeights': instance.relatedThreatWeights,
      'idrecommendation': instance.idrecommendation,
    };
