## 0.0.1 First Package

Includes:
- Full replication based on the defined strategies
- Listeners to achieve event based replication
- Pairing bugfixing
- Replication of :Global data from Cloud to Local 

## 0.0.2 Declaration Update

Includes:
- Modified from Declaration.doShareData to Declaration.doNotShareData

## 0.0.3 :Global bugfixing

Includes:
- Bugfixing related to :Global:Recommendations
- Bugfixing related to :Global:profiles
- Bugfixing related to :Global:threats

## 0.0.4 :Global:Recommendations bugfixing

Includes:
- Bugfixing related to :Global:Recommendations. Sets a correct relation between :Global:threats and :Global:Recommendations['relatedThreatsWeights']

## 0.0.5 :Global:threats update

Includes:
- Bugfixing/update related to :Global:threats. Updates with a new method to get GEIGER threats from GEIGER Cloud API

## 0.0.6 :Global:Recommendations bugfix

Includes:
- Bugfixing to :Global:Recommendations. Adapt to 0.0.5 update.

## 0.0.7 :Global:Recommendations bugfix

Includes:
- Bugfixing to :Global:Recommendations. Adapt to 0.0.5 update. 
- 0.0.6 was not updating :Global:Recommendations['relatedThreatsWeights'] when :Global:Recommendations node was not found.

## 0.0.8 :Global:profiles

Includes:
- Modified Search Criteria to match :Global:threats['GEIGER_threat'] and compare to :Global:threats['name']. Must match.

## 0.0.9 Pairing

Includes:
- Updated consistency of the paired data under :pairing_plugin node.

## 0.0.10 :Global:Recommendations bugfix

Includes:
- Bugfixing to :Global:Recommendations. Adapt to 0.0.8 update. 
- 0.0.9 was not updating :Global:Recommendations['relatedThreatsWeights'] as expected. Must match SC :Global:threats['GEIGER_threat'] and compare to :Global:threats['name'] to get the UUID of the Threat.

## 0.1.0 Pairing

Includes:
- Pairing Bugfixing
- Updates :Keys SearchCriteria
- Creates :Enterprise:Users:id:pairingStructure