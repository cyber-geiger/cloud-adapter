import 'package:json_annotation/json_annotation.dart';

part 'security_defenders_organization.g.dart';

@JsonSerializable(explicitToJson: true)
class SecurityDefendersOrganization {
  String? idOrg;
  String? name;
  String? location;

  SecurityDefendersOrganization(
      {required this.idOrg, this.name, this.location});

  get getIdOrg => idOrg;

  set setIdOrg(String? idOrg) => this.idOrg = idOrg;

  get getName => name;

  set setName(name) => this.name = name;

  get getLocation => location;

  set setLocation(location) => this.location = location;

  factory SecurityDefendersOrganization.fromJson(Map<String, dynamic> json) =>
      _$SecurityDefendersOrganizationFromJson(json);

  Map<String, dynamic> toJson() => _$SecurityDefendersOrganizationToJson(this);
}
