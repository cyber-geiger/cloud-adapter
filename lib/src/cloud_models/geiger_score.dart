import 'package:json_annotation/json_annotation.dart';

part 'geiger_score.g.dart';

@JsonSerializable(explicitToJson: true)
class GeigerScore {
  String? username;
  String? sharedscore;
  DateTime? sharedscoredate;

  GeigerScore({
    this.username,
    this.sharedscore,
    this.sharedscoredate
  });

  factory GeigerScore.fromJson(Map<String,dynamic> json) => _$GeigerScoreFromJson(json);

  Map<String, dynamic> toJson() => _$GeigerScoreToJson(this);

  String? get getUsername => username;
  set setUsername(String name) => this.username = name;

  String? get getSharedScore => sharedscore;
  set setSharedScore(String score) => this.sharedscore = score;

  DateTime? get getSharedScoreDate => sharedscoredate;
  set setSharedScoreDate(DateTime date) => this.sharedscoredate = date;

}