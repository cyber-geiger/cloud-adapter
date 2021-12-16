import 'dart:convert';
import 'package:convert/convert.dart';
import 'dart:io';
//import 'dart:math';
// ignore: library_prefixes
import 'package:cloud_replication_package/src/replication_exception.dart';
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
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
//import 'package:intl/intl.dart';
import 'package:test/test.dart';
import 'package:geiger_localstorage/geiger_localstorage.dart' as toolbox_api;
import 'package:geiger_api/geiger_api.dart';

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

  test('Check pair test', () async {
    ReplicationController rep = ReplicationService();
    await rep.initGeigerStorage();
    String userId1 = "replicationTest";
    String userId2 = "replicationTest1";
    bool check = await rep.checkPairing(userId1, userId2);
    print(check);
    rep.endGeigerStorage();
  });

  test('Pair test', () async {
    //ReplicationController rep = ReplicationService();
    //await rep.endGeigerStorage();
    toolbox_api.StorageController storageController = await initGeigerStorage();
    toolbox_api.Node l = await storageController.get(":Devices");
    print(await l.getChildren());
    print(await storageController
        .get(":Devices:8190499d-9794-41cd-bdc3-b6936279f26a"));
    exit(0);

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
  });

  /// UNPAIR TEST
  test('Unpair Test', () async {
    /// RUN PAIRING TEST BEFORE
    toolbox_api.StorageController storageController = await initGeigerStorage();

    /// INIT STORAGE WITH ALREADY GIVEN
    ReplicationController rep = ReplicationService();
    await rep.initGeigerStorage();
    String userId1 = "replicationTest";
    String userId2 = "replicationTest1";
    CloudService cloud = CloudService();

    /// Set pair method
    await rep.setPair(userId1, userId2, "in", "demo", "peer");
    List<String> userList = await cloud.getMergedAccounts(userId1);
    if (userList.contains(userId2)) {
      print("HAS AGREEMENT");
    }

    await rep.unpair(userId1, userId2);
    try {
      List<String> userList2 = await cloud.getMergedAccounts(userId1);
      if (userList2.contains(userId2) == false) {
        print("UNPAIR ACHIEVED");
      }
    } catch (e) {
      print("AGREEMENT REMOVED");
    }

    /// CHECK IF LOCAL NODE EXISTS
    try {
      toolbox_api.Node node =
          await storageController.get(":Local:Pairing:$userId2");
      print(node);
    } catch (e) {
      print("NODE NOT FOUND. UNPAIRING ACHIEVED");
    }
  });
  test('Encrypter Test', () async {
    String data = "Demo";
    final keyVal = Enc.Key.fromLength(32);
    final enc = Enc.Encrypter(Enc.AES(keyVal, mode: Enc.AESMode.cfb64));
    final iv = Enc.IV.fromLength(32);
    Enc.Encrypted encrypted = enc.encrypt(data, iv: iv);
    print(encrypted.base64);
  });
  test('Share Nodes Test', () async {
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
  }, timeout: Timeout(Duration(minutes: 5)));
  test('Get shared nodes', () async {
    toolbox_api.StorageController storageController = await initGeigerStorage();

    /// INIT STORAGE WITH ALREADY GIVEN
    ReplicationController rep = ReplicationService();
    //ReplicationService ser = ReplicationService();
    await rep.initGeigerStorage();
    String userId1 = "replicationTest";
    String userId2 = "replicationTest1";

    /// Create a custom pairing agreement
    try {
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
  }, timeout: Timeout(Duration(minutes: 5)));

  test('Full Replication', () async {
    //toolbox_api.StorageController storageController = await initGeigerStorage();

    /// INIT STORAGE
    ReplicationController rep = ReplicationService();
    await rep.initGeigerStorage();
    await rep.geigerReplication();
    await rep.endGeigerStorage();

    ///GET REPLICATION TLP WHITE MISP NODES
    /*toolbox_api.Node see = await storageController.get(":Global:misp");
    Map<String, toolbox_api.Node> demo = await see.getChildren();
    print(demo);*/

    /// CHECK IF REPLICATION NODE HAS BEEN UPDATED
    /* toolbox_api.Node updateRep =
        await storageController.get(':Local:Replication:LastReplication');
    toolbox_api.Node updateRepNode =
        await storageController.get(':Local:Replication:LastReplication');*/
    /*print(updateRep);
    print(updateRepNode);
    toolbox_api.Node threat =
        await storageController.get(':Global:ThreatWeight');
    print(threat);
    print(await threat.getChildren());*/
  }, timeout: Timeout(Duration(minutes: 5)));
  test('First consent approach', () async {
    toolbox_api.StorageController storageController = await initGeigerStorage();

    /// INIT STORAGE WITH ALREADY GIVEN
    ReplicationController rep = ReplicationService();
    await rep.initGeigerStorage();

    toolbox_api.Node node =
        toolbox_api.NodeImpl(':Local:test', 'CloudReplication');
    await storageController.addOrUpdate(node);
    print(node);
    expect(() async => await rep.checkConsent(node, "replicationTest"),
        throwsA(isA<ReplicationException>()));
  }, timeout: Timeout(Duration(minutes: 5)));

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
  test('get Single User Event', () async {
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
  });
  test('delete Event', () async {
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
  });
  test('get Threat Weights', () async {
    var cloud = CloudService();
    List<ThreatWeights> response = await cloud.getThreatWeights();
    print(response.length);
  });
}

void main() {
  print("START MAIN");
  replicationTests();
}
