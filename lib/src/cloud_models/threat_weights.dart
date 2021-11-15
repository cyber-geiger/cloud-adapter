import 'package:json_annotation/json_annotation.dart';

import 'threat_dict.dart';

part 'threat_weights.g.dart';

@JsonSerializable(explicitToJson: true)
class ThreatWeights {
  @JsonKey(name: "id_threatweights")
  String? idThreatweights;
  @JsonKey(name: "threat_dict")
  ThreatDict? threatDict;

  ThreatWeights({required this.idThreatweights, required this.threatDict});

  factory ThreatWeights.fromJson(Map<String, dynamic> json) =>
      _$ThreatWeightsFromJson(json);

  Map<String, dynamic> toJson() => _$ThreatWeightsToJson(this);

  String? get getIdThreatweights => idThreatweights;

  // why do you want to set idThreatweights
  // set getIdThreatweights(String? idThreatweights) =>
  //     this.idThreatweights = idThreatweights;

  ThreatDict? get getThreatDict => threatDict;
  //same question her
  //set setThreatDict(ThreatDict threatDict) => this.threatDict = threatDict;
}
