// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
      idUser: json['idUser'] as String?,
      publicKey: json['publicKey'] as String?,
      access: json['access'] as String?,
      lastSeen: json['lastSeen'] == null
          ? null
          : DateTime.parse(json['lastSeen'] as String),
      expires: json['expires'] == null
          ? null
          : DateTime.parse(json['expires'] as String),
      name: json['name'] as String?,
      email: json['email'] as String?,
    );

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      'idUser': instance.idUser,
      'publicKey': instance.publicKey,
      'access': instance.access,
      'lastSeen': instance.lastSeen?.toIso8601String(),
      'expires': instance.expires?.toIso8601String(),
      'name': instance.name,
      'email': instance.email,
    };
