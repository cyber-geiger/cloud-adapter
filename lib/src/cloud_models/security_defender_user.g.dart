// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'security_defender_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SecurityDefenderUser _$SecurityDefenderUserFromJson(
        Map<String, dynamic> json) =>
    SecurityDefenderUser(
      id_user: json['id_user'] as String?,
      name: json['name'] as String?,
      firstname: json['firstname'] as String?,
      affiliation: json['affiliation'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      title: json['title'] as String?,
      picture: json['picture'] as String?,
    );

Map<String, dynamic> _$SecurityDefenderUserToJson(
        SecurityDefenderUser instance) =>
    <String, dynamic>{
      'id_user': instance.id_user,
      'name': instance.name,
      'firstname': instance.firstname,
      'affiliation': instance.affiliation,
      'phone': instance.phone,
      'email': instance.email,
      'title': instance.title,
      'picture': instance.picture,
    };
