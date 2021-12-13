import 'package:json_annotation/json_annotation.dart';

part 'threat_dict.g.dart';

@JsonSerializable(explicitToJson: true)
class ThreatDict {
  List<double>? botnets;
  @JsonKey(name: "data breach")
  List<double>? dataBreach;
  @JsonKey(name: "denial of service")
  List<double>? denialOfService;
  @JsonKey(name: "external environment threats")
  List<double>? externalEnvironmentThreats;
  @JsonKey(name: "insider threats")
  List<double>? insiderThreats;
  List<double>? malware;
  List<double>? phishing;
  @JsonKey(name: "physical threats")
  List<double>? physicalThreats;
  List<double>? ransomware;
  List<double>? spam;
  @JsonKey(name: "web application threats")
  List<double>? webApplicationThreats;
  @JsonKey(name: "web-based threats")
  List<double>? webBasedThreats;

  ThreatDict(
      {required this.botnets,
      required this.dataBreach,
      required this.denialOfService,
      required this.externalEnvironmentThreats,
      required this.insiderThreats,
      required this.malware,
      required this.phishing,
      required this.physicalThreats,
      required this.ransomware,
      required this.spam,
      required this.webApplicationThreats,
      required this.webBasedThreats});

  factory ThreatDict.fromJson(Map<String, dynamic> json) =>
      _$ThreatDictFromJson(json);

  Map<String, dynamic> toJson() => _$ThreatDictToJson(this);
}
