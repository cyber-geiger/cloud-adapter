//import 'dart:io';

import 'package:json_annotation/json_annotation.dart';

part 'security_defender_user.g.dart';

@JsonSerializable(explicitToJson: true)
class SecurityDefenderUser {
  // ignore: non_constant_identifier_names
  String? id_user;
  String? name;
  String? firstname;
  String? affiliation;
  String? phone;
  String? email;
  String? title;
  String? picture;

  // ignore: non_constant_identifier_names
  SecurityDefenderUser(
      // ignore: non_constant_identifier_names
      {required this.id_user,
      this.name,
      this.firstname,
      this.affiliation,
      this.phone,
      this.email,
      this.title,
      this.picture});
  // ignore: non_constant_identifier_names
  get getId_user => id_user;

  // ignore: non_constant_identifier_names
  set setId_user(String? id_user) => this.id_user = id_user;

  get getName => name;

  set setName(name) => this.name = name;

  get getFirstname => firstname;

  set setFirstname(firstname) => this.firstname = firstname;

  get getAffiliation => affiliation;

  set setAffiliation(affiliation) => this.affiliation = affiliation;

  get getPhone => phone;

  set setPhone(phone) => this.phone = phone;

  get getEmail => email;

  set setEmail(email) => this.email = email;

  get getTitle => title;

  set setTitle(title) => this.title = title;

  get getPicture => picture;

  set setPicture(picture) => this.picture = picture;

  factory SecurityDefenderUser.fromJson(Map<String, dynamic> json) =>
      _$SecurityDefenderUserFromJson(json);

  Map<String, dynamic> toJson() => _$SecurityDefenderUserToJson(this);
}
