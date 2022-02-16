// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'security_defenders_organization.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SecurityDefendersOrganization _$SecurityDefendersOrganizationFromJson(
        Map<String, dynamic> json) =>
    SecurityDefendersOrganization(
      idOrg: json['idOrg'] as String?,
      name: json['name'] as String?,
      location: json['location'] as String?,
    );

Map<String, dynamic> _$SecurityDefendersOrganizationToJson(
        SecurityDefendersOrganization instance) =>
    <String, dynamic>{
      'idOrg': instance.idOrg,
      'name': instance.name,
      'location': instance.location,
    };
