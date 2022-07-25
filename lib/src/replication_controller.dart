import 'package:cloud_replication_package/src/service/node_listener.dart';
import 'package:geiger_localstorage/geiger_localstorage.dart' as toolbox_api;

abstract class ReplicationController {
  /// Checks if the device is connected to the internet
  /// If not - No replication possible
  Future<bool> checkConnection();

  /// Inits the storageController through the GeigerAPI
  Future<void> initGeigerStorage();

  /// Checks if replication has took place
  /// If replication has been done -> TRUE
  /// If replication has not been done -> FALSE
  Future<bool> checkReplication();

  /// Checks if a user has replicated data in <30 days
  /// If replication <30 days -> TRUE
  /// If replication >30 days -> FALSE
  Future<bool> checkReplicationTimingStrategy();

  /// Achieves full or partial replication
  /// INCLUDES GEIGERREPLICATIONLISTENER METHOD
  /// WITHOUT GLOBAL DATA
  Future<void> geigerReplication(
      deleteHandler, createHandler, updateHandler, renameHandler);

  /// Achieves full or partial replication
  /// Once listeners are already active
  Future<void> geigerReplicationUpdate();

  /// Achieves full or partial replication
  /// INCLUDES LISTENERS
  /// INCLUDES GLOBAL DATA
  //Future<void> geigerReplicationWithoutGlobalData(
  //    deleteHandler, createHandler, updateHandler, renameHandler);

  Future<void> geigerReplicationListener(
      deleteHandler, createHandler, updateHandler, renameHandler);

  /// Check if two users have an agreement
  Future<bool> checkPairing(String userId1, String userId2);

  /// Call this function to create a pairing agreement in local and cloud
  /// INFO                            --- QR
  /// PAIRING USER                    --- qrUserId
  /// PAIR DeviceId                   --- qrDeviceId
  /// public key                      --- publicKey
  /// agreement                       --- {"in","out","both"}
  /// type                            --- device / employee
  Future<bool> setPair(String qrUserId, String qrDeviceId,
     String publicKey, String agreement, String type);

  /// TO BE RUN BY THE DEVICE THAT GENERATES THE QR CODE
  Future<bool> updatePair(String userId1);

  /// Removes both from the local and the cloud, the agreement
  Future<bool> unpair(String userId1, String userId2);

  /// Places a node in the cloud encrypted
  Future<bool> shareNode(
      String nodePath, String senderUserId, String receiverUserId);

  /// Gets previously shared nodes and stores them in the localStorage
  Future<bool> getSharedNodes(String receiverUserId, String senderUserId);

  /// Creates a cloud user. Necesary for pairing & replication
  Future<bool> createCloudUser(String userId,
      [String? email,
      String? access,
      String? expires,
      String? name,
      String? publicKey]);

  /// Flushes memory, ends storage...
  Future<void> endGeigerStorage();

  /// Adds first approach
  /// if settingsValue = true -> consent accepted
  /// if settingsValue = true -> consent rejected
  Future<void> addSettingsConsent(String username, bool settingsValue);

  /// Checks the consent of a user & if needed, asks for it
  Future<bool> checkConsent(toolbox_api.Node node, String username);

  /// THIS METHOD INCLUDES ALL THE SUB-UPDATES METHODS
  /// UPDATE THREATS
  /// UPDATETHREATWEIGHTS
  /// UPDATERECOMMENDATIONS
  /// UPDATESECURITYDEFENDERSINFO
  ///   includes:
  ///     security defenders
  ///     security defenders organizations
  ///     security defenders location
  Future<bool> updateGlobalData();

  /// updates Geiger defined threats
  Future<void> updateThreats();

  /// Updates Threat Weights
  Future<void> updateThreatWeights();

  /// Updates Global Recommendations in a Cloud to Local way
  /// TO GET FULL DATA -> UPDATETHREATWEIGHTS IS REQUIRED PREVIOUSLY
  Future<void> updateRecommendations();

  /// Updates Security Defenders Info
  Future<void> updateSecurityDefendersInfo();

  /// Updates Company events
  Future<void> updateCompanyEvents();

  /// CREATE HANDLERS
  /// 4 EVENT TYPES: create, update, rename, delete
  Future<void> createHandler(EventChange event);
  Future<void> updateHanlder(EventChange event);
  Future<void> renameHanlder(EventChange event);
  Future<void> deleteHandler(EventChange event);

  /// EXPERIMENTAL METHODS
  /// CHECK IF SOLVE THE SETPAIR/GETSHAREDNODES BEHAVIOUR
  //Future<bool> setDevicePair();

  //Future<bool> getDevicesNodes(String localId, String pairedId);

  //Future<bool> unpairDevices();

  //Future<bool> setEmployeePair();

  //Future<bool> getEmployeeNodes();

  //Future<bool> unpairEmployee();

  //Future<bool> setSupervisorPair();

  //Future<bool> unpairSupervisor();

  Future<bool> createPairingStructure(String publicKey, String type);
}
