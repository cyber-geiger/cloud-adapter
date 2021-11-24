// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'short_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ShortUser _$ShortUserFromJson(Map<String, dynamic> json) => ShortUser(
      idUser: json['idUser'] as String?,
      publicKey: json['publicKey'] as String?,
      name: json['name'] as String?,
      email: json['email'] as String?,
    );

Map<String, dynamic> _$ShortUserToJson(ShortUser instance) => <String, dynamic>{
      'idUser': instance.idUser,
      'publicKey': instance.publicKey,
      'name': instance.name,
      'email': instance.email,
    };
