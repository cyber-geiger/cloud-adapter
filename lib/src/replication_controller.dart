abstract class ReplicationController {
  
  Future<void> geigerReplication();

  Future<void> pair(String userId1, String userId2);

  Future<void> unpair(String userId1, String userId2);

  Future<void> shareNode(String nodePath, String senderUserId, String receiverUserId);

  Future<void> createCloudUser(String userId, [String? email, String? access, String? expires, String? name, String? publicKey]);
}