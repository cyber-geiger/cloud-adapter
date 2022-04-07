import 'package:cloud_replication_package/cloud_replication_package.dart';
import 'package:geiger_localstorage/geiger_localstorage.dart' as toolbox_api;
import 'package:geiger_api/geiger_api.dart';
import 'package:test/test.dart';

void pairingTests() async {
  test('SIMPLE MULTIPLE PAIRING', () async {
    print('SIMPLE PAIRING');
    GeigerApi localMaster = (await getGeigerApi(
        "", GeigerApi.masterId, Declaration.doNotShareData))!;
    // ignore: unused_local_variable
    toolbox_api.StorageController storageController = localMaster.storage;
    print(await storageController.dump());
    /*toolbox_api.Node local = await storageController.get(':Local');
    print(local);
    print(await local.getChildren());
    toolbox_api.Node devices = await storageController.get(':Devices');
    print("PRE DEVICES NODE");
    print(devices);
    print("PRE DEVICE CHILDREN NODE");
    Map<String, toolbox_api.Node> nodes1 = await devices.getChildren();
    print(nodes1);
    for(var node in nodes1.entries) {
      toolbox_api.Node nn = (node.value);
      print("CHILDREN OF NODE: " + nn.path);
      print(await nn.getChildren());
    }*/

    ReplicationController rep = ReplicationService();
    await rep.initGeigerStorage();
    await rep.setPair('b9fc801e-59fc-4672-8638-7c4717034172',
        'd73f9d07-ffc0-4878-be74-89f1d05d7a5d', 'both');
    print(
        "********************************* AFTER PAIRING *******************************************");
    print(await storageController.dump());
    /*toolbox_api.Node devices0 = await storageController.get(':Devices');
    print("POST DEVICES NODE");
    print(devices0);
    print("POST DEVICE CHILDREN NODE");
    Map<String, toolbox_api.Node> nodes = await devices0.getChildren();
    print(nodes);
    for(var node in nodes.entries) {
      toolbox_api.Node nn = (node.value);
      print("CHILDREN OF NODE: " + nn.path);
      print(nn);
      print(await nn.getChildren());
    }*/
    await rep.endGeigerStorage();
  }, timeout: Timeout(Duration(minutes: 5)));
  /* test('SIMPLE MULTIPLE PAIRING', () async {
    print('SIMPLE PAIRING');
    GeigerApi localMaster =
        (await getGeigerApi("", GeigerApi.masterId, Declaration.doShareData))!;
    // ignore: unused_local_variable
    toolbox_api.StorageController storageController = localMaster.getStorage()!;
    toolbox_api.Node devices = await storageController.get(':Devices');
    print("PRE DEVICES NODE");
    print(devices);
    print("PRE DEVICE CHILDREN NODE");
    print(await devices.getChildren());

    /// NOW CREATE TWO RANDOM CLOUD USERS AND SET PAIR
    ReplicationController rep = ReplicationService();
    await rep.initGeigerStorage();
    await rep.setPair('6f3ac19e-aa49-469d-bbf0-17956b652273',
        'b7c05573-60f7-4055-aa1c-e0ae63a544ed', 'both');
    toolbox_api.Node devices0 = await storageController.get(':Devices');
    print("POST DEVICES NODE");
    print(devices0);
    print("POST DEVICE CHILDREN NODE");
    print(await devices0.getChildren());
    await rep.endGeigerStorage();
  });*/
  /*test('multiple pairing', () async {
    GeigerApi localMaster =
        (await getGeigerApi("", GeigerApi.masterId, Declaration.doShareData))!;
    toolbox_api.StorageController storageController = localMaster.getStorage()!;
    // REMOVE PAIRING NODES
    await storageController.delete(':Local:Pairing:a6517751-9d5d-411a-ac4a-2295974df6f5');
    await storageController.delete(':Local:Pairing:c982e7c0-6554-4d77-b895-8af7e6d872cd');
    toolbox_api.Node node = await storageController.get(":Devices");
    print(await node.getChildren());
    toolbox_api.Node local = await storageController.get(':Local');
    String _localUser = await local
        .getValue('currentUser')
        .then((value) => value!.getValue("en").toString());

    ReplicationController rep = ReplicationService();
    await rep.initGeigerStorage();
    await rep.setPair(_localUser, "a6517751-9d5d-411a-ac4a-2295974df6f5", 'both');
    await rep.setPair(_localUser, "c982e7c0-6554-4d77-b895-8af7e6d872cd", 'both');
    toolbox_api.Node nod1e = await storageController.get(":Devices");
    print("---------------------");
    print(await nod1e.getChildren());
    await rep.unpair(_localUser, "a6517751-9d5d-411a-ac4a-2295974df6f5");
    print("---------------------");
    toolbox_api.Node nod2e = await storageController.get(":Devices");
    print(await nod2e.getChildren());
    await rep.endGeigerStorage();
  }, timeout: Timeout(Duration(minutes: 5)));*/
  /*test('Check pair test', () async {
    ReplicationController rep = ReplicationService();
    await rep.initGeigerStorage();
    String userId1 = "replicationTest";
    String userId2 = "replicationTest1";
    bool check = await rep.checkPairing(userId1, userId2);
    print(check);
    rep.endGeigerStorage();
  });*/

  /* test('Pair test', () async {
    //ReplicationController rep = ReplicationService();
    //await rep.endGeigerStorage();
    toolbox_api.StorageController storageController = await initGeigerStorage();
    toolbox_api.Node l = await storageController.get(":Devices");
    print(await l.getChildren());
    print(await storageController
        .get(":Devices:8190499d-9794-41cd-bdc3-b6936279f26a"));
    exit(0);*/

  /// INIT STORAGE WITH ALREADY GIVEN
  /*ReplicationController rep = ReplicationService();
    await rep.initGeigerStorage();
    String userId1 = "replicationTest";
    String userId2 = "replicationTest1";
    CloudService cloud = CloudService();

    await rep.setPair(userId1, userId2, "in", "demo", "peer");
    //GET MERGE FROM CLOUD
    List<String> userList = await cloud.getMergedAccounts(userId1);
    if (userList.contains(userId2)) {
      print("HAS AGREEMENT");
    }*/
  // });

  /// UNPAIR TEST
/*  test('Unpair Test', () async {
    /// RUN PAIRING TEST BEFORE
    toolbox_api.StorageController storageController = await initGeigerStorage();

    /// INIT STORAGE WITH ALREADY GIVEN
    ReplicationController rep = ReplicationService();
    await rep.initGeigerStorage();
    String userId1 = "replicationTest";
    String userId2 = "replicationTest1";
    CloudService cloud = CloudService();
    await storageController.delete(':Local:Pairing:replicationTest1');
    cloud.createUser(userId2);
    /// Set pair method
    await rep.setPair(userId1, userId2, "in", "demo", "peer");
    List<String> userList = await cloud.getMergedAccounts(userId1);
    if (userList.contains(userId2)) {
      print("HAS AGREEMENT");
    }
    toolbox_api.Node nodeDemo = toolbox_api.NodeImpl(":Devices:tryal", userId2);
    await storageController.add(nodeDemo);
    await rep.unpair(userId1, userId2);
    try {
      List<String> userList2 = await cloud.getMergedAccounts(userId1);
      if (userList2.contains(userId2) == false) {
        print("UNPAIR ACHIEVED");
      }
    } catch (e) {
      print("AGREEMENT REMOVED");
    }
    try {
      toolbox_api.Node c = await storageController.get(":Devices:tryal");
      print(c);
    } catch (e) {
      print("NONE");
    }
    /// CHECK IF LOCAL NODE EXISTS
    try {
      toolbox_api.Node node =
          await storageController.get(":Local:Pairing:$userId2");
      print(node);
    } catch (e) {
      print("NODE NOT FOUND. UNPAIRING ACHIEVED");
    }
  });*/
  /* test('Share Nodes Test', () async {
    toolbox_api.StorageController storageController = await initGeigerStorage();

    /// INIT STORAGE WITH ALREADY GIVEN
    ReplicationController rep = ReplicationService();
    await rep.initGeigerStorage();
    String userId1 = "replicationTest";
    String userId2 = "replicationTest1";
    CloudService cloud = CloudService();
    await rep.setPair(userId1, userId2, "in", "demo", "peer");
    //GET MERGE FROM CLOUD
    List<String> userList = await cloud.getMergedAccounts(userId1);
    if (userList.contains(userId2)) {
      print("HAS AGREEMENT");
    }

    /// CREATE TWO DIFFERENT NODES FOR TESTING PURPOSES
    try {
      toolbox_api.Node node1 = await storageController.get(':Devices:demo');
      print(node1.name);
    } catch (e) {
      toolbox_api.Node node1 = toolbox_api.NodeImpl(':Devices:demo', userId1);
      node1.addValue(toolbox_api.NodeValueImpl("demo", "workds"));
      await storageController.add(node1);
    }

    /// GET NODE and PRINT
    toolbox_api.Node checker = await storageController.get(':Devices:demo');
    print(checker);
    await rep.shareNode(':Devices:demo', userId1, userId2);

    /// CHECK IF NODE IN THE CLOUD FOR USERID2 EVENTS
    /// user 2 has to have the agreement as well in the devide and also in the cloud
    /// agreement has to be complementary to user1
    await cloud.createMerge(userId2, userId1, "both");
    List<String> events = await cloud.getUserEvents(userId2);
    print(events);
    for (var single in events) {
      Event singleOne = await cloud.getSingleUserEvent(userId2, single);
      print(singleOne);
    }
  }, timeout: Timeout(Duration(minutes: 5)));*/
  /*test('Get shared nodes', () async {
    toolbox_api.StorageController storageController = await initGeigerStorage();
    final nodeKey = Enc.Key.fromSecureRandom(32);
    print(nodeKey.toString());
    //toolbox_api.Node n = toolbox_api.NodeImpl(':Enterprise:f44a059d-3bcb-4e82-9913-088a26571970', 'Cloud');
    //n.addOrUpdateValue(toolbox_api.NodeValueImpl('path',':Users:f44a059d-3bcb-4e82-9913-088a26571970'));
    //await storageController.add(n);
    //print(n);
    toolbox_api.SearchCriteria criteria =
      toolbox_api.SearchCriteria(searchPath: ':Keys', value: ':Users:f44a059d-3bcb-4e82-9913-088a26571970');
      print("HERE ARRIVES");
      print(criteria);
    List<toolbox_api.Node> keyList = await storageController.search(criteria);
    print("ATRE");
    print(keyList);*/

  /// INIT STORAGE WITH ALREADY GIVEN
  //ReplicationController rep = ReplicationService();
  //ReplicationService ser = ReplicationService();
  /* await rep.initGeigerStorage();
    String userId1 = "a396c2ed-59f4-4d2d-b86d-8e9b7bdb0bd0";
    String userId2 = "547b7932-6e13-4dc2-9975-15ad24dcba10";*/

  /// Create a custom pairing agreement
  /* try {
      toolbox_api.Node pairParent =
          await storageController.get(":Local:Pairing");
      print(pairParent.name);
    } catch (e) {
      toolbox_api.Node pairParent =
          toolbox_api.NodeImpl(":Local:Pairing", "Cloud-Replication");
      await storageController.add(pairParent);
    }
    try {
      toolbox_api.Node pair =
          await storageController.get(":Local:Pairing:$userId1");
      print(pair.name);
    } catch (e) {
      toolbox_api.Node pair =
          toolbox_api.NodeImpl(":Local:Pairing:$userId1", "Cloud-Replication");

      pair.addOrUpdateValue(toolbox_api.NodeValueImpl("agreement", "in"));
      pair.addOrUpdateValue(toolbox_api.NodeValueImpl("type", "peer"));
      pair.addOrUpdateValue(toolbox_api.NodeValueImpl("key",
          "aes-256-cfb:703373367638792F423F4528482B4D6251655468576D5A7134743777217A2443"));

      //Map<String, toolbox_api.NodeValue> checker = await pair.getValues();
      await storageController.add(pair);
    }

    await rep.getSharedNodes(userId2, userId1);
    toolbox_api.Node tas = await storageController.get(':Users');
    print(await tas.getChildren());*/
  //}, timeout: Timeout(Duration(minutes: 5)));
}

void main() {
  print("START MAIN");
  pairingTests();
}
