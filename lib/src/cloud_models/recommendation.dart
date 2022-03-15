// ignore_for_file: non_constant_identifier_names
// done to achieve parsing from Recommendation Cloud API
import 'package:json_annotation/json_annotation.dart';

part 'recommendation.g.dart';

@JsonSerializable(explicitToJson: true)
class Recommendation {
  String? id;
  String? Action;
  String? RecommendationType;
  List<String>? Steps;
  bool? costs;
  String? long;
  String? short;
  int minimunRequiredKnowledgeLevel;
  String? parentUUID;
  List<String>? relatedThreatsWeights;

  Recommendation({
    required this.id,
    this.Action,
    this.RecommendationType,
    this.Steps,
    this.costs,
    this.long,
    this.short,
    required this.minimunRequiredKnowledgeLevel,
    this.parentUUID,
    this.relatedThreatsWeights,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) =>
      _$RecommendationFromJson(json);

  Map<String, dynamic> toJson() => _$RecommendationToJson(this);

  get getId => id;

  set setId(id) => this.id = id;

  get getAction => Action;

  set setAction(Action) => this.Action = Action;

  get getRecommendationType => RecommendationType;

  set setRecommendationType(RecommendationType) =>
      this.RecommendationType = RecommendationType;

  get getSteps => Steps;

  set setSteps(Steps) => this.Steps = Steps;

  get getCosts => costs;

  set setCosts(costs) => this.costs = costs;

  get getLong => long;

  set setLong(long) => this.long = long;

  get getShort => short;

  set setShort(short) => this.short = short;

  get getMinimunRequiredKnowledgeLevel => minimunRequiredKnowledgeLevel;

  set setMinimunRequiredKnowledgeLevel(minimunRequiredKnowledgeLevel) =>
      this.minimunRequiredKnowledgeLevel = minimunRequiredKnowledgeLevel;

  get getParentUUID => parentUUID;

  set setParentUUID(parentUUID) => this.parentUUID = parentUUID;

  get getRelatedThreatsWeights => relatedThreatsWeights;

  set setRelatedThreatsWeights(relatedThreatsWeights) =>
      this.relatedThreatsWeights = relatedThreatsWeights;
}
