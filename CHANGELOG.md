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

## 0.1.1 Handler Fix

Includes:
- Bugfix related to Listener Handlers

## 0.1.2 :Keys Fix

Includes:
- Random UUID for :Keys

## 0.1.3 Overriging Issue

Includes:
- Issue with updated nodes and children

## 0.1.4 KEY Issue

Includes:
- Keys work with Search Criteria. In case of conflict -> Check the values inside the node

## 0.1.5 KEY Issue

Includes:
- Keys work with Search Criteria. In case of conflict -> Check the values inside the node

## 0.1.6 Listeners Improvement

Includes:
- Event listener were not working properly (replication & pairing issues) -> Solved.
- When pairing plugin updates a toolbox node, it should not be replicated to the cloud (comes from it) -> Solved.
- Full integrated tests:
  1. Full Replication (Setting listeners but no usage)
  2. Full Replication (Setting listeners and usage: CREATE; DELETE; UPDATE; RENAME)
  3. Pairing (2 previous replicated users)
  4. Pairing with listeners (Modifies nodes while Listeners are running & after pairing)

## 0.1.7 Recommendations Improvement

Includes:
- Loop though Recommendations['Steps']

## 0.1.8 Connection Issue

Includes:
- Improves REST API connection handling

## 0.1.9 GEIGER API UPGRADE

Includes:
- Improves REST API connection handling

## 0.1.10 GEIGER API UPGRADE v2

Includes:
- Solves Geiger API 0.7.5