import 'package:json_annotation/json_annotation.dart';
import 'translation.dart';

part 'tag.g.dart'; 

@JsonSerializable(explicitToJson: true)
class Tag {
  DateTime? date;
  String? description;
  List<Translation>? descriptionTranslations;
  String? idTag;
  String? name;
  List<Translation>? nameTranslations;
  String? parentIdTag;

  Tag({
    this.date,
    required this.description,
    this.descriptionTranslations,
    this.idTag,
    required this.name,
    this.nameTranslations,
    this.parentIdTag
  });

  factory Tag.fromJson(Map<String, dynamic> json) => _$TagFromJson(json);

  Map<String, dynamic> toJson() => _$TagToJson(this);

  DateTime? get getDate => date;
  set setDate(DateTime date) => this.date = date;

  String? get getDescription => description;
  set setDescription(String description) => this.description = description;

  List<Translation>? get getDescriptionTranslations => descriptionTranslations;
  set setDescriptionTranslations(List<Translation> descriptionTranslations) => this.descriptionTranslations = descriptionTranslations;

  String? get getIdTag => idTag;
  set setIdTag(String idTag) => this.idTag = idTag;

  String? get getName => name;
  set setName(String name) => this.name = name;

  List<Translation>? get getNameTranslations => nameTranslations;
  set setNameTranslations(List<Translation> idEvent) => nameTranslations = nameTranslations;

  String? get getParentIdTag => parentIdTag;
  set setParentIdTag(String parentIdTag) => this.parentIdTag = parentIdTag;
}
