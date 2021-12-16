import 'package:geiger_localstorage/geiger_localstorage.dart' as toolbox_api;

abstract class ReplicationController {
  /// Inits the storageController through the GeigerAPI
  Future<void> initGeigerStorage();

  /// Achieves full or partial replication
  Future<void> geigerReplication();

  /// Call this function to create a pairing agreement in local and cloud
  /// userId: LocalUserId
  /// userId2: remoteUser
  /// agreement: agreement value: {"in","out","both"}
  Future<void> setPair(String userId1, String userId2, String agreement,
      [String? publicKey, String? type]);

  /// Removes both from the local and the cloud, the agreement
  Future<void> unpair(String userId1, String userId2);

  /// Places a node in the cloud encrypted
  Future<void> shareNode(
      String nodePath, String senderUserId, String receiverUserId);

  /// Gets previously shared nodes and stores them in the localStorage
  Future<void> getSharedNodes(String receiverUserId, String senderUserId);

  /// Creates a cloud user. Necesary for pairing & replication
  Future<void> createCloudUser(String userId,
      [String? email,
      String? access,
      String? expires,
      String? name,
      String? publicKey]);

  /// Flushes memory, ends storage...
  Future<void> endGeigerStorage();

  /// Checks the consent of a user & if needed, asks for it
  Future<bool> checkConsent(toolbox_api.Node node, String username);
}
