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
  Future<void> geigerReplication();

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

  /// Checks the consent of a user & if needed, asks for it
  Future<bool> checkConsent(toolbox_api.Node node, String username);

  /// Updates Global Recommendations in a Cloud to Local way
  Future<void> updateRecommendations();
}
