import 'package:cloud_replication_package/src/service/node_listener.dart';
import 'package:geiger_localstorage/geiger_localstorage.dart' as toolbox_api;

abstract class ReplicationController {
  /// Checks if the device is connected to the internet
  /// If not - No replication possible
  Future<bool> checkConnection();

  /// Inits the storageController through the GeigerAPI
  Future<void> initGeigerStorage();

  /// FOR DEV PURPOSES. CHECK IF REPLICATION HAS TOOK PLACE
  /// returns true if replication has been done
  /// else returns false
  Future<bool> checkReplication();

  /// Achieves full or partial replication
  /// INCLUDES GEIGERREPLICATIONLISTENER METHOD
  /// WITHOUT GLOBAL DATA
  Future<void> geigerReplication(
      deleteHandler, createHandler, updateHandler, renameHandler);

  /// Achieves full or partial replication
  /// INCLUDES LISTENERS
  /// INCLUDES GLOBAL DATA
  Future<void> geigerReplicationWithoutGlobalData(
      deleteHandler, createHandler, updateHandler, renameHandler);

  Future<void> geigerReplicationListener(
      deleteHandler, createHandler, updateHandler, renameHandler);

  /// Check if two users have an agreement
  Future<bool> checkPairing(String userId1, String userId2);

  /// Call this function to create a pairing agreement in local and cloud
  /// userId: LocalUserId
  /// userId2: remoteUser
  /// agreement: agreement value: {"in","out","both"}
  Future<bool> setPair(String userId1, String userId2, String agreement,
      [String? publicKey, String? type]);

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
  /// UPDATETHREATWEIGHTS
  /// UPDATERECOMMENDATIONS
  /// UPDATESECURITYDEFENDERSINFO
  ///   includes:
  ///     security defenders
  ///     security defenders organizations
  ///     security defenders location
  Future<bool> updateGlobalData();

  /// Updates Threat Weights
  Future<void> updateThreatWeights();

  /// Updates Global Recommendations in a Cloud to Local way
  Future<void> updateRecommendations();

  /// Updates Security Defenders Info
  Future<void> updateSecurityDefendersInfo();

  /// CREATE HANDLERS
  /// 4 EVENT TYPES: create, update, rename, delete
  Future<void> createHandler(EventChange event);
  Future<void> updateHanlder(EventChange event);
  Future<void> renameHanlder(EventChange event);
  Future<void> deleteHandler(EventChange event);
}
