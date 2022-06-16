import 'dart:math';

import 'package:json_annotation/json_annotation.dart';

part 'company_event.g.dart';

@JsonSerializable(explicitToJson: true)
class CompanyEvent {
  String? name;
  int? minValue;
  int? maxValue;
  int? geigerValue;
  String? valueType;
  String? type;
  String? relation;
  List<String>? threatsImpact;
  int? flag;
  String? description;

  CompanyEvent({
    this.name,
    this.minValue,
    this.maxValue,
    this.geigerValue,
    this.valueType,
    this.type,
    this.relation,
    this.threatsImpact,
    this.flag,
    this.description,
  });

  factory CompanyEvent.fromJson(Map<String,dynamic> json) => _$CompanyEventFromJson(json);

  Map<String, dynamic> toJson() => _$CompanyEventToJson(this);

  String? get getName => name;
  set setName(String name) => this.name = name;

  int? get getMinValue => minValue;
  set setMinValue(int value) => this.minValue = value;

  int? get getMaxValue => maxValue;
  set setMaxValue(int value) => this.maxValue = value;

  int? get getGeigerValue => geigerValue;
  set setGeigerValue(int value) => this.geigerValue = value;

  String? get getValueType => valueType;
  set setValueType(String value) => this.valueType = value;

  String? get getType => type;
  set setType(String value) => this.type = value;

  String? get getRelation => relation;
  set setRelation(String value) => this.relation = value;

  List<String>? get getThreatsImpact => threatsImpact;
  set setThreatsImpact(List<String> values) => this.threatsImpact = values;

  int? get getFlag => flag;
  set setFlag(int value) => this.flag = value;

  String? get getDescription => description;
  set setDescription(String value) => this.description = value;

}