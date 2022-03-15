// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recommendation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Recommendation _$RecommendationFromJson(Map<String, dynamic> json) =>
    Recommendation(
      id: json['id'] as String?,
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
      relatedThreatsWeights: (json['relatedThreatsWeights'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    )..id = json['id'] as String?;

Map<String, dynamic> _$RecommendationToJson(Recommendation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'Action': instance.Action,
      'RecommendationType': instance.RecommendationType,
      'Steps': instance.Steps,
      'costs': instance.costs,
      'long': instance.long,
      'short': instance.short,
      'minimunRequiredKnowledgeLevel': instance.minimunRequiredKnowledgeLevel,
      'parentUUID': instance.parentUUID,
      'relatedThreatsWeights': instance.relatedThreatsWeights,
    };
