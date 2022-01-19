import 'dart:convert';
//import 'package:convert/convert.dart';
import 'dart:io';
//import 'dart:math';
// ignore: library_prefixes
//import 'package:cloud_replication_package/src/replication_exception.dart';
// ignore: library_prefixes
import 'package:encrypt/encrypt.dart' as Enc;

//import 'package:cloud_replication_package/cloud_replication_package.dart';
//import 'package:cloud_replication_package/src/cloud_models/event.dart';
import 'package:cloud_replication_package/cloud_replication_package.dart';
import 'package:cloud_replication_package/src/cloud_models/event.dart';
//import 'package:cloud_replication_package/src/cloud_models/short_user.dart';
import 'package:cloud_replication_package/src/cloud_models/threat_weights.dart';
import 'package:cloud_replication_package/src/service/cloud_exception.dart';
//import 'package:cloud_replication_package/src/cloud_models/user.dart';
import 'package:cloud_replication_package/src/service/cloud_service.dart';
import 'package:cloud_replication_package/src/service/event_listener.dart';
import 'package:cloud_replication_package/src/service/node_listener.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
//import 'package:intl/intl.dart';
import 'package:test/test.dart';
import 'package:geiger_localstorage/geiger_localstorage.dart' as toolbox_api;
import 'package:geiger_api/geiger_api.dart';

Future<List<toolbox_api.Node>> getAllNodes(
    toolbox_api.StorageController sto) async {
  print("GET ALL NODES IN A RECURSIVE WAY");
  List<toolbox_api.Node> nodeList = [];
  try {
    toolbox_api.Node root1 = await sto.get(':Devices');
    await getRecursiveNodes(sto, root1, nodeList);
    toolbox_api.Node root2 = await sto.get(':Users');
    await getRecursiveNodes(sto, root2, nodeList);
    toolbox_api.Node root3 = await sto.get(':Keys');
    await getRecursiveNodes(sto, root3, nodeList);
    toolbox_api.Node root4 = await sto.get(':Enterprise');
    await getRecursiveNodes(sto, root4, nodeList);
  } catch (e) {
    print(e);
  }
  return nodeList;
}

Future<List<toolbox_api.Node>> getRecursiveNodes(
    toolbox_api.StorageController sto,
    toolbox_api.Node node,
    List<toolbox_api.Node> list) async {
  print("RECURSIVE METHOD");
  String dataPath = node.path.toString();
  print(dataPath);
  if (dataPath != ":" &&
      dataPath != ":Users" &&
      dataPath != ":Devices" &&
      dataPath != ":Enterprise" &&
      dataPath != ":Keys" &&
      dataPath != ":Global" &&
      dataPath != ":Local") {
    print("NODE THAT CAN BE ADDED");
    list.add(node);
  }
  Map<String, toolbox_api.Node> children = await node.getChildren();
  if (children.isNotEmpty) {
    for (var value in children.values) {
      list = await getRecursiveNodes(sto, value, list);
    }
  }
  return list;
}

Future<toolbox_api.StorageController> initGeigerStorage() async {
  print("INIT GEIGER STORAGE");
  try {
    GeigerApi api = await _initGeigerApi();
    print(api);
    toolbox_api.StorageController storageController = api.getStorage()!;
    return storageController;
  } catch (e) {
    print("DATABASE CONNECTION ERROR FROM LOCALSTORAGE");
    rethrow;
  }
}

Future<GeigerApi> _initGeigerApi() async {
  print("INIT GEIGER API");
  try {
    GeigerApi localMaster =
        (await getGeigerApi("", GeigerApi.masterId, Declaration.doShareData))!;
    print(localMaster);
    return localMaster;
  } catch (e, s) {
    print("ERROR FROM GEIGERAPI: $e, Stack: $s");
    throw toolbox_api.StorageException("ERROR");
  }
}

Future<toolbox_api.StorageController> init() async {
  //print('[REPLICATION] INIT GEIGER STORAGE');
  WidgetsFlutterBinding.ensureInitialized();

  //await toolbox_api.StorageMapper.initDatabaseExpander();
  //storageController = toolbox_api.GenericController('Cloud-Replication', toolbox_api.SqliteMapper('dbFileName.bd'));
  return toolbox_api.GenericController(
      'Cloud-Replication', toolbox_api.DummyMapper('Cloud-Replication'));
}

Future<String> generateUUID() async {
  final String uri = "https://37.48.101.252:8443/geiger-cloud/api";
  Uri url = Uri.parse(uri + '/uuid');
  HttpClient client = HttpClient()
    ..badCertificateCallback =
        ((X509Certificate cert, String host, int port) => true);
  var ioClient = IOClient(client);
  http.Response response =
      await ioClient.get(url, headers: <String, String>{'accept': ''});
  if (response.statusCode == 200) {
    String uuid = jsonDecode(response.body).toString();
    return uuid;
  } else {
    throw CloudException("FAILURE GETTING A UUID");
  }
}

void replicationTests() async {
  test('SIMPLE MULTIPLE PAIRING', () async {
    print('MULTIPLE PAIRING');
    GeigerApi localMaster =
        (await getGeigerApi("", GeigerApi.masterId, Declaration.doShareData))!;
    // ignore: unused_local_variable
    toolbox_api.StorageController storageController = localMaster.getStorage()!;
    toolbox_api.Node local = await storageController.get(':Local');
    String _localUser = await local
        .getValue('currentUser')
        .then((value) => value!.getValue("en").toString());

    print("PRE TEST PAIRING");
    toolbox_api.Node devices = await storageController.get(':Devices');
    print("DEVICES NODE");
    print(devices);
    print("DEVICE CHILDREN NODE");
    print(await devices.getChildren());

    /// NOW CREATE TWO RANDOM CLOUD USERS AND SET PAIR
    ReplicationController rep = ReplicationService();
    String u1 = '26486477-32e8-48b9-8a3a-b6d0377da98c';
    String u2 = 'd51a9810-6e9b-4e51-8a9a-326c8b9502b0';
    //rep.createCloudUser(u1);
    //rep.createCloudUser(u2);
    await rep.initGeigerStorage();
    await rep.setPair(
        _localUser, u1, 'both');
    toolbox_api.Node devices0 = await storageController.get(':Devices');
    print("DEVICES NODE");
    print(devices0);
    print("DEVICE CHILDREN NODE");
    print(await devices0.getChildren());
    await rep.setPair(_localUser, u2, 'both');

    /// GET DEVICES NODE AND PRINT
    toolbox_api.Node devices1 = await storageController.get(':Devices');
    print("DEVICES NODE");
    print(devices1);
    print("DEVICE CHILDREN NODE");
    print(await devices1.getChildren());
    await rep.endGeigerStorage();
  });
  test('GET STORAGE LISTENER', () async {
    print("LISTENER TEST - CHECKS DELETE BEHAVIOUR");
    GeigerApi localMaster =
        (await getGeigerApi("", GeigerApi.masterId, Declaration.doShareData))!;
    // ignore: unused_local_variable
    toolbox_api.StorageController storageController = localMaster.getStorage()!;

    toolbox_api.SearchCriteria sc = toolbox_api.SearchCriteria(searchPath: ':');
    NodeListener stListener = NodeListener(storageController);
    storageController.registerChangeListener(stListener, sc);
    toolbox_api.Node l = toolbox_api.NodeImpl(':Local:aaaa', 'CloudAdapter');
    await storageController.addOrUpdate(l);
    print(stListener.events);
    print("BEFORE DELETE");
   // await storageController.delete(':Local:aaaa');
    print("NODE DELETED");
    await storageController.deregisterChangeListener(stListener);
  });
  /*test('GET USER PROMPT', () async {
    print("GET USER PROMPT TEST");
    GeigerApi localMaster =
        (await getGeigerApi("", GeigerApi.masterId, Declaration.doShareData))!;
    // ignore: unused_local_variable
    toolbox_api.StorageController storageController = localMaster.getStorage()!;

    /// SEND MESSAGE
    GeigerUrl? url;
    try {
      url = GeigerUrl(null, GeigerApi.masterId, 'geiger://plugin/path');
    } catch (e) {
      print(e);
    }
    try {
      print("SEND MESSAGE");
      MessageType messageType = MessageType.storageEvent;
      Message message = Message('ReplicationController', 'uiId', messageType, url);
      await localMaster.sendMessage(message);
    } catch (e) {
      print(e);
    }
  });*/
  /* test('Delete Node Test', () async {
    GeigerApi localMaster =
        (await getGeigerApi("", GeigerApi.masterId, Declaration.doShareData))!;
    toolbox_api.StorageController storageController = localMaster.getStorage()!;
    /// CREATE A NODE AND DELETE IT
    toolbox_api.Node node = toolbox_api.NodeImpl(':Local:deleteNode', 'owner');
    await storageController.add(node);
    print(node.owner);
    if (node.owner != 'owner') {
      await storageController.delete(node.path);
    }
    try {
      toolbox_api.Node n1 = await storageController.get(':Local:deleteNode');
      print(n1);
    } catch (e) {
      print(e);
    }
    try {
      await storageController.delete(node.path);
    } catch (e) {
      print("LETS SEE");
      print(e);
    }
    
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
  /*test("SEARCH CRITERIA", () async {
    GeigerApi localMaster =
        (await getGeigerApi("", GeigerApi.masterId, Declaration.doShareData))!;
    toolbox_api.StorageController storageController = localMaster.getStorage()!;
    //toolbox_api.Node n = toolbox_api.NodeImpl(":Local:demo1", "checker");
    //await storageController.add(n);
    //toolbox_api.Node m = toolbox_api.NodeImpl(":Devices:demo1", "checker");
    //await storageController.add(m);

    toolbox_api.SearchCriteria criteria =
        toolbox_api.SearchCriteria();
    List<toolbox_api.Node> nodeList = await storageController.search(criteria);
    print("-----------------");
    for (var entry in nodeList) {
      print(entry);
      if (entry.owner == "checker") {
        print("CHECKER");
        await storageController.delete(entry.path);
      }
    }
  });*/
  /*test('addOrUpdateTest', () async {
    GeigerApi localMaster =
        (await getGeigerApi("", GeigerApi.masterId, Declaration.doShareData))!;
    toolbox_api.StorageController storageController = localMaster.getStorage()!;
    try {
      toolbox_api.Node first = await storageController.get(':Devices:newTestNode');
      print(first);
    } catch (e) {
      print("CATCH - Node not found");
      toolbox_api.Node nodeToAdd = toolbox_api.NodeImpl(':Devices:newTestNode', '');
      await storageController.addOrUpdate(nodeToAdd);
    }
    try {
      toolbox_api.Node checker = await storageController.get(':Devices:newTestNode');
      print(checker);
    } catch (e) {
      print("NODE HAS NOT BEEN ADDED");
    }
    toolbox_api.Node nodeToAdd = toolbox_api.NodeImpl(':Devices:newTestNode', '');
    nodeToAdd.addValue(toolbox_api.NodeValueImpl("demo", "demoTest"));
    await storageController.addOrUpdate(nodeToAdd);
    try {
      toolbox_api.Node checker = await storageController.get(':Devices:newTestNode');
      print(checker);
    } catch (e) {
      print("NODE HAS NOT BEEN ADDED");
    }
  });*/
  //late toolbox_api.StorageController storageController;
  //final String uri = "https://37.48.101.252:8443/geiger-cloud/api";

  /*test('Encrypt a node', () async {
    ReplicationService ser = ReplicationService();

    toolbox_api.StorageController storageController = await initGeigerStorage();
    toolbox_api.Node encCheck =
        toolbox_api.NodeImpl(":Local:anotherTest", "Cloud-Replication");
    await storageController.addOrUpdate(encCheck);
    toolbox_api.Node keyCheck =
        toolbox_api.NodeImpl(":Keys:" + encCheck.name, "Cloud-Replication");
    keyCheck.addOrUpdateValue(toolbox_api.NodeValueImpl("key",
        "aes-256-cfb:703373367638792F423F4528482B4D6251655468576D5A7134743777217A2443"));
    await storageController.addOrUpdate(keyCheck);

    ///
    toolbox_api.Node keys =
        await storageController.get(':Keys:' + encCheck.name);
    print(keys);
    final hexEncodedKey = await keys
        .getValue('key')
        .then((value) => value!.getValue("en").toString());
    print(hexEncodedKey);

    /// keyPattern: key=["aes-256-cfb:JWWY+/E5Xppta3AsSIsGrWUOKHmv0w3cbfH5VlsG62Y="]
    final onlyKey = hexEncodedKey.split(':');
    final String decodedKey = hex.decode(onlyKey[1]).toString();
    print(decodedKey);
    final keyVal = Enc.Key.fromUtf8(decodedKey);
    final iv = Enc.IV.fromLength(16);
    final enc = Enc.Encrypter(Enc.AES(keyVal, mode: Enc.AESMode.cfb64));

    String node = await ser.convertNodeToJsonString(encCheck);
    Enc.Encrypted encrypted = enc.encrypt(node.toString(), iv: iv);
    print(encrypted.toString());
  }, timeout: Timeout(Duration(minutes: 5)));*/
  /*test('Get all nodes', () async {
    toolbox_api.StorageController storageController = await initGeigerStorage();
    List<toolbox_api.Node> n = await getAllNodes(storageController);
    print(n);
  });
  test('Test Connection', () async {
    ReplicationController rep = ReplicationService();
    bool tester = await rep.checkConnection();
    print(tester);
  });*/

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
  /* test('Encrypter Test', () async {
    String data = "Demo";
    final keyVal = Enc.Key.fromLength(32);
    final enc = Enc.Encrypter(Enc.AES(keyVal, mode: Enc.AESMode.cfb64));
    final iv = Enc.IV.fromLength(32);
    Enc.Encrypted encrypted = enc.encrypt(data, iv: iv);
    print(encrypted.base64);
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

  /*test('Full Replication', () async {
    print("FULL REPLICATION TEST");
    toolbox_api.StorageController storageController = await initGeigerStorage();
    toolbox_api.Node n =
        toolbox_api.NodeImpl(':Enterprise:demo', 'Replication');
    n.addOrUpdateValue(
        toolbox_api.NodeValueImpl('prueba', 'la gente lo presentia'));
    await storageController.addOrUpdate(n);

    /// INIT STORAGE
    ReplicationController rep = ReplicationService();
    await rep.initGeigerStorage();
    await rep.geigerReplication();
    await rep.endGeigerStorage();*/

    ///GET REPLICATION TLP WHITE MISP NODES
    /*toolbox_api.Node see = await storageController.get(":Global:misp");
    Map<String, toolbox_api.Node> demo = await see.getChildren();
    print(demo);*/

    /// CHECK IF REPLICATION NODE HAS BEEN UPDATED
    /* toolbox_api.Node updateRep =
        await storageController.get(':Local:Replication:LastReplication');
    toolbox_api.Node updateRepNode =
        await storageController.get(':Local:Replication:LastReplication');
    print(updateRep);
    print(updateRepNode);
    toolbox_api.Node threat =
        await storageController.get(':Global:ThreatWeight');
    print(threat);
    print(await threat.getChildren());*/
  //}, timeout: Timeout(Duration(minutes: 5)));
  /*test('First consent approach', () async {
    toolbox_api.StorageController storageController = await initGeigerStorage();

    /// INIT STORAGE WITH ALREADY GIVEN
    ReplicationController rep = ReplicationService();
    await rep.initGeigerStorage();


    toolbox_api.Node node =
        toolbox_api.NodeImpl(':Local:test', 'CloudReplication');
    await storageController.addOrUpdate(node);
    toolbox_api.Node node1 =
        toolbox_api.NodeImpl(':Local:test:test1', 'CloudReplication');
    await storageController.addOrUpdate(node1);
    toolbox_api.Node node2 =
        toolbox_api.NodeImpl(':Local:test', 'CloudReplication');
    await storageController.addOrUpdate(node2);
    toolbox_api.Node tryal = await storageController.get(':Local:test:test1');
    print(tryal);
  }, timeout: Timeout(Duration(minutes: 5)));*/

  /// CLOUD SERVICE TESTS
  /// TEST OF EACH METHOD
  /*test('merge Test', () async {
    var cloud = CloudService();
    String idUser1 = "replicationTest";
    String idUser2 = "replicationTest1";
    await cloud.deleteMerged(idUser1, idUser2);
  });*/
  /*test('create Event', () async {
    var cloud = CloudService();
    //TO GENERATE A NEW CLOUD UUID
    Uri url = Uri.parse(uri + '/uuid');
    HttpClient client = HttpClient()
      ..badCertificateCallback =
          ((X509Certificate cert, String host, int port) => true);
    var ioClient = IOClient(client);
    http.Response response =
        await ioClient.get(url, headers: <String, String>{'accept': ''});
    if (response.statusCode == 200) {
      var uuid = jsonDecode(response.body);
      Event event = Event(id_event: uuid, tlp: 'AMBER');
      await cloud.createEvent('replicationDemo', event);
    } else {
      print("Something went wrong: $response");
    }
    expect(response.statusCode, returnsNormally);
  });*/
  /*test('update Event', () async {
    var cloud = CloudService();
    String idEvent = '21546532-4521-3542-1235-54321654';
    Event event = Event(id_event: idEvent, tlp: 'WHITE');
    expect(
        () async => await cloud.updateEvent('anyRandomUserId', idEvent, event),
        returnsNormally);
  });
  test('user Exist', () async {
    final cloud = CloudService();
    bool response =
        await cloud.userExists('0425e093-502a-4bcf-a5c4-74ec77d77199');
    print(response);
  });
  test('create User', () async {
    var cloud = CloudService();
    expect(() async => await cloud.createUser('dummyCreate'), returnsNormally);
  });
  test('get Users', () async {
    var cloud = CloudService();
    List<User> response = await cloud.getUsers();
    print(response);
  });
  test('get TLP White Events', () async {
    var cloud = CloudService();
    List<Event> response = await cloud.getTLPWhiteEvents();
    print(response);
  }, timeout: Timeout(Duration(minutes: 5)));

  test('get TLP White Events - DateTime Filtered', () async {
    var cloud = CloudService();
    var date = DateTime.now().subtract(Duration(days: 1));
    var formatted = DateFormat("yyyy-MM-dd'T'hh:mm:ss.SSSS'Z'").format(date);
    var response =
        await cloud.getTLPWhiteEventsDateFilter(formatted.toString());
    print(response);
  }, timeout: Timeout(Duration(minutes: 5)));
  test('get User Events', () async {
    var cloud = CloudService();
    List<String> response = await cloud.getUserEvents('anyRandomUserId');
    print(response);
  });
  test('get User Events - DateTime Filtered', () async {
    var cloud = CloudService();
    var date = DateTime.now().subtract(Duration(days: 752));
    var formatted = DateFormat("yyyy-MM-dd'T'hh:mm:ss.SSSS'Z'").format(date);
    List<String> response = await cloud.getUserEventsDateFilter(
        'anyRandomUserId', formatted.toString());
    print(response);
  });*/
  /* test('get Single User Event', () async {
    var cloud = CloudService();
    String eventId = await generateUUID();
    String userId = "replicationTest";
    bool exist = await cloud.userExists(userId);
    if (exist == false) {
      await cloud.createUser(userId);
    }

    /// Create a simple event
    Event replicateEvent = Event(id_event: eventId, tlp: "WHITE");
    await cloud.createEvent(userId, replicateEvent);

    /// Check if the event exists
    Event checker = await cloud.getSingleUserEvent(userId, eventId);
    expect(checker.id_event, eventId);
  });*/
  /*test('delete Event', () async {
    var cloud = CloudService();
    String eventId = await generateUUID();
    String userId = "replicationTest";
    bool exist = await cloud.userExists(userId);
    if (exist == false) {
      await cloud.createUser(userId);
    }

    /// Create a simple event
    Event replicateEvent = Event(id_event: eventId, tlp: "WHITE");
    await cloud.createEvent(userId, replicateEvent);

    /// Check if the event exists
    Event checker = await cloud.getSingleUserEvent(userId, eventId);
    print("Event has been stored succesfully");
    print(checker.id_event);
    print(checker.owner);
    await cloud.deleteEvent(userId, eventId);

    /// Try to get the event
    expect(() async => await cloud.getSingleUserEvent(userId, eventId),
        throwsA(isA<CloudException>()));
  });*/
  /*test('get Threat Weights', () async {
    var cloud = CloudService();
    List<ThreatWeights> response = await cloud.getThreatWeights();
    print(response.length);
  });*/
}

void main() {
  print("START MAIN");
  replicationTests();
}
