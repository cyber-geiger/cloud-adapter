import 'package:json_annotation/json_annotation.dart';

part 'geiger_score.g.dart';

@JsonSerializable(explicitToJson: true)
class GeigerScore {
  String? username;
  String? useruuid;
  String? devicename;
  String? sharedScore;
  int? sharedNumberOfMetrics;
  DateTime? sharedScoreDate;

  GeigerScore({
    this.username,
    this.useruuid,
    this.devicename,
    this.sharedScore,
    this.sharedNumberOfMetrics,
    this.sharedScoreDate
  });

  factory GeigerScore.fromJson(Map<String,dynamic> json) => _$GeigerScoreFromJson(json);

  Map<String, dynamic> toJson() => _$GeigerScoreToJson(this);

  String? get getUsername => username;
  set setUsername(String name) => this.username = name;

  String? get getUseruuid => useruuid;
  set setUseruuid(String useruuid) => this.useruuid = useruuid;

  String? get getDevicename => devicename;
  set setDevicename(String name) => this.devicename = name;

  String? get getSharedScore => sharedScore;
  set setSharedScore(String score) => this.sharedScore = score;

  int? get getSharedNumberOfMetrics => sharedNumberOfMetrics;
  set setSharedNumberOfMetrics(int metrics) => this.sharedNumberOfMetrics = metrics;

  DateTime? get getSharedScoreDate => sharedScoreDate;
  set setSharedScoreDate(DateTime date) => this.sharedScoreDate = date;

}