// ignore_for_file: non_constant_identifier_names
// done to achieve parsing from Event Cloud API
import 'package:json_annotation/json_annotation.dart';
import 'translation.dart';

part 'event.g.dart';

@JsonSerializable(explicitToJson: true)
class Event {
  String id_event;
  String tlp;
  String? type;
  String? encoding;
  List<String>? tags;
  DateTime? last_modified;
  DateTime? expires;
  String? language;
  String? owner;
  String? content;
  List<Translation>? translation;

  Event({
    required this.id_event,
    required this.tlp,
    this.type,
    this.encoding,
    this.tags,
    this.last_modified,
    this.expires,
    this.language,
    this.owner,
    this.content,
    this.translation,
  });

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);

  Map<String, dynamic> toJson() => _$EventToJson(this);

  String? get getIdEvent => id_event;
  set setIdEvent(String id_event) => this.id_event = id_event;

  String? get getTlp => tlp;
  set setTlp(String tlp) => this.tlp = tlp;

  String? get getType => type;
  set setType(String type) => this.type = type;

  String? get getEncoding => encoding;
  set setEncoding(String encoding) => this.encoding = encoding;

  List<String>? get getTags => tags;
  set setTags(List<String> tags) => this.tags = tags;

  DateTime? get getLastModified => last_modified;
  set setLastModified(DateTime last_modified) =>
      this.last_modified = last_modified;

  DateTime? get getExpires => expires;
  set setExpires(DateTime expires) => this.expires = expires;

  String? get getLanguage => language;
  set setLanguage(String language) => this.language = language;

  String? get getOwner => owner;
  set setOwner(String owner) => this.owner = owner;

  String? get getContent => content;
  set setContent(String content) => this.content = content;

  List<Translation>? get getTranslation => translation;
  set setTranslation(List<Translation> translation) =>
      this.translation = translation;
}
