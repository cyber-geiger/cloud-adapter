
abstract class ReplicationController {

  Future<void> initGeigerStorage();

  Future<void> geigerReplication();

  Future<void> setPair(String userId1, String userId2);

  Future<void> unpair(String userId1, String userId2);

  Future<void> shareNode(
      String nodePath, String senderUserId, String receiverUserId);

  Future<void> getSharedNodes(String receiverUserId, String senderUserId);

  Future<void> createCloudUser(String userId,
      [String? email,
      String? access,
      String? expires,
      String? name,
      String? publicKey]);
  
  Future<void> endGeigerStorage();
}
