// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'threat_dict.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ThreatDict _$ThreatDictFromJson(Map<String, dynamic> json) => ThreatDict(
      botnets: (json['botnets'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      dataBreach: (json['dataBreach'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      denialOfService: (json['denialOfService'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      externalEnvironmentThreats:
          (json['externalEnvironmentThreats'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList(),
      insiderThreats: (json['insiderThreats'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      malware: (json['malware'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      phishing: (json['phishing'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      physicalThreats: (json['physicalThreats'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      ransomware: (json['ransomware'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      spam: (json['spam'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      webApplicationThreats: (json['webApplicationThreats'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      webBasedThreats: (json['webBasedThreats'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
    );

Map<String, dynamic> _$ThreatDictToJson(ThreatDict instance) =>
    <String, dynamic>{
      'botnets': instance.botnets,
      'dataBreach': instance.dataBreach,
      'denialOfService': instance.denialOfService,
      'externalEnvironmentThreats': instance.externalEnvironmentThreats,
      'insiderThreats': instance.insiderThreats,
      'malware': instance.malware,
      'phishing': instance.phishing,
      'physicalThreats': instance.physicalThreats,
      'ransomware': instance.ransomware,
      'spam': instance.spam,
      'webApplicationThreats': instance.webApplicationThreats,
      'webBasedThreats': instance.webBasedThreats,
    };
