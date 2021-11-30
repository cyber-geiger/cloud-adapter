import 'package:json_annotation/json_annotation.dart';

part 'short_user.g.dart';

@JsonSerializable(explicitToJson: true)
class ShortUser {
  String? idUser;
  String? publicKey;
  String? name;
  String? email;

  ShortUser({required this.idUser, this.publicKey, this.name, this.email});

  factory ShortUser.fromJson(Map<String, dynamic> json) =>
      _$ShortUserFromJson(json);

  Map<String, dynamic> toJson() => _$ShortUserToJson(this);

  String? get getIdUser => idUser;
  set setIdUser(String idUser) => this.idUser = idUser;

  String? get getPublicKey => publicKey;
  set setPublicKey(String publicKey) => this.publicKey = publicKey;

  String? get getName => name;
  set setName(String name) => this.name = name;

  String? get getEmail => email;
  set setEmail(String email) => this.email = email;
}
