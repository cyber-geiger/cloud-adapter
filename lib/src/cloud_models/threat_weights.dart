import 'package:json_annotation/json_annotation.dart';
import 'threat_dict.dart';

part 'threat_weights.g.dart'; 

@JsonSerializable(explicitToJson: true)
class ThreatWeights {
  String? idThreatweights;
  ThreatDict? threatDict;

  ThreatWeights({
    required this.idThreatweights, 
    required this.threatDict
  });

  factory ThreatWeights.fromJson(Map<String, dynamic> json) => _$ThreatWeightsFromJson(json);

  Map<String, dynamic> toJson() => _$ThreatWeightsToJson(this);

  String? get getIdThreatweights => idThreatweights;
  set getIdThreatweights(String? idThreatweights) => this.idThreatweights = idThreatweights;

  ThreatDict? get getThreatDict => threatDict;
  set setThreatDict(ThreatDict threatDict) => this.threatDict = threatDict;
}

