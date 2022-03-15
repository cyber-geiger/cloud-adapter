import 'package:json_annotation/json_annotation.dart';

part 'threats.g.dart';

@JsonSerializable(explicitToJson: true)
class Threats {
  @JsonKey(name: "GEIGER-threat")
  String? threat;
  @JsonKey(name: "UUID")
  String? uuid;
  @JsonKey(name: "Name")
  String? name;

  Threats({required this.threat, required this.uuid, required this.name});

  String? get getName => name;
  set setName(String name) => this.name = name;

  String? get getUuid => uuid;
  set setUuid(String uuid) => this.uuid = uuid;

  String? get getThreat => threat;
  set setThreat(String threat) => this.threat = threat;

  factory Threats.fromJson(Map<String, dynamic> json) =>
      _$ThreatsFromJson(json);

  Map<String, dynamic> toJson() => _$ThreatsToJson(this);
}
