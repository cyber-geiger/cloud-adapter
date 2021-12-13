// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'threat_dict.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ThreatDict _$ThreatDictFromJson(Map<String, dynamic> json) => ThreatDict(
      botnets: (json['botnets'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      dataBreach: (json['data breach'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      denialOfService: (json['denial of service'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      externalEnvironmentThreats:
          (json['external environment threats'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList(),
      insiderThreats: (json['insider threats'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      malware: (json['malware'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      phishing: (json['phishing'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      physicalThreats: (json['physical threats'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      ransomware: (json['ransomware'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      spam: (json['spam'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      webApplicationThreats: (json['web application threats'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      webBasedThreats: (json['web-based threats'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
    );

Map<String, dynamic> _$ThreatDictToJson(ThreatDict instance) =>
    <String, dynamic>{
      'botnets': instance.botnets,
      'data breach': instance.dataBreach,
      'denial of service': instance.denialOfService,
      'external environment threats': instance.externalEnvironmentThreats,
      'insider threats': instance.insiderThreats,
      'malware': instance.malware,
      'phishing': instance.phishing,
      'physical threats': instance.physicalThreats,
      'ransomware': instance.ransomware,
      'spam': instance.spam,
      'web application threats': instance.webApplicationThreats,
      'web-based threats': instance.webBasedThreats,
    };
