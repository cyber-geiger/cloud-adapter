import 'package:json_annotation/json_annotation.dart';

part 'translation.g.dart'; 

@JsonSerializable(explicitToJson: true)
class Translation {
	String? idTranslation;
	String? language;
	DateTime? date;
	String? content;

	Translation({
    required this.idTranslation, 
    required this.language, 
    required this.date, 
    this.content
  });

  factory Translation.fromJson(Map<String, dynamic> json) => _$TranslationFromJson(json);

  Map<String, dynamic> toJson() => _$TranslationToJson(this);

  DateTime? get getDate => date;
  set setDate(DateTime date) => this.date = date;

  String? get getLanguage => language;
  set setLanguage(String language) => this.language = language;

  String? get getContent => content;
  set setContent(String content) => this.content = content;

  String? get getIdTranslation => idTranslation;
  set setIdTranslation(String idTranslation) => this.idTranslation = idTranslation;
}