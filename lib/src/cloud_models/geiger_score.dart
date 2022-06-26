import 'package:json_annotation/json_annotation.dart';

part 'geiger_score.g.dart';

@JsonSerializable(explicitToJson: true)
class GeigerScore {
  String? username;
  String? sharedScore;
  DateTime? sharedScoreDate;

  GeigerScore({
    this.username,
    this.sharedScore,
    this.sharedScoreDate
  });

  factory GeigerScore.fromJson(Map<String,dynamic> json) => _$GeigerScoreFromJson(json);

  Map<String, dynamic> toJson() => _$GeigerScoreToJson(this);

  String? get getUsername => username;
  set setUsername(String name) => this.username = name;

  String? get getSharedScore => sharedScore;
  set setSharedScore(String score) => this.sharedScore = score;

  DateTime? get getSharedScoreDate => sharedScoreDate;
  set setSharedScoreDate(DateTime date) => this.sharedScoreDate = date;

}