import 'dart:convert';
import 'dart:io';

import 'package:cloud_replication_package/cloud_replication_package.dart';
import 'package:cloud_replication_package/src/service/cloud_service/cloud_exception.dart';
import 'package:cloud_replication_package/src/service/node_listener.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
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
  test("TEST UPDATE GLOBAL DATA - PROFILES & THREATS", () async {
    ReplicationController rep = ReplicationService();
    await rep.initGeigerStorage();
    await rep.updateThreatWeights();
    // GET :Global:threats
    // GET :Global:profiles
    GeigerApi localMaster =
        (await getGeigerApi("", GeigerApi.masterId, Declaration.doShareData))!;
    // ignore: unused_local_variable
    toolbox_api.StorageController storageController = localMaster.getStorage()!;
    toolbox_api.Node profile = await storageController.get(":Global:profiles");
    print("PROFILE NODE");
    print(profile);
    print("PROFILE CHILDREN");
    print(await profile.getChildren());
    toolbox_api.Node threats = await storageController.get(":Global:threats");
    print("THREAT NODE");
    print(threats);
    print("THREAT CHILDREN");
    print(await threats.getChildren());
  });
  test('STORAGE LISTENER - LAST NODE UPDATED', () async {
    print("LISTENER TEST - CHECKS DELETE BEHAVIOUR");
    GeigerApi localMaster =
        (await getGeigerApi("", GeigerApi.masterId, Declaration.doShareData))!;
    // ignore: unused_local_variable
    toolbox_api.StorageController storageController = localMaster.getStorage()!;
    toolbox_api.SearchCriteria sc = toolbox_api.SearchCriteria(searchPath: ':');
    NodeListener stListener = NodeListener();
    storageController.registerChangeListener(stListener, sc);
    print("UPDATE A NODE UNDER :LOCAL");
    toolbox_api.Node demoExample1 =
        toolbox_api.NodeImpl(':Local:DemoExample', 'CloudAdapter');
    await storageController.addOrUpdate(demoExample1);
    print(stListener.events);
    print("UPDATE A NODE NOT UNDER :LOCAL");
    toolbox_api.Node demoExample11 =
        toolbox_api.NodeImpl(':Devices:DemoExampleTest', 'CloudAdapter');
    await storageController.addOrUpdate(demoExample11);
    print(stListener.events);
    await storageController.deregisterChangeListener(stListener);
  });
  test('STORAGE LISTENER - LAST NODE DELETED', () async {
    print("LISTENER TEST - CHECKS DELETE BEHAVIOUR");
    GeigerApi localMaster =
        (await getGeigerApi("", GeigerApi.masterId, Declaration.doShareData))!;
    // ignore: unused_local_variable
    toolbox_api.StorageController storageController = localMaster.getStorage()!;
    toolbox_api.SearchCriteria sc = toolbox_api.SearchCriteria(searchPath: ':');
    toolbox_api.Node demoExample11 =
        toolbox_api.NodeImpl(':Local:DemoExampleTest', 'CloudAdapter');
    await storageController.addOrUpdate(demoExample11);
    NodeListener stListener = NodeListener();
    storageController.registerChangeListener(stListener, sc);
    print("UPDATE A NODE UNDER :LOCAL");
    toolbox_api.Node demoExample1 =
        toolbox_api.NodeImpl(':Local:DemoExample', 'CloudAdapter');
    await storageController.addOrUpdate(demoExample1);
    print(stListener.events);
    print("DELETE A NODE UNDER :LOCAL");
    await storageController.delete(':Local:DemoExampleTest');
    print(stListener.events);
    await storageController.deregisterChangeListener(stListener);
  });
  test('STORAGE LISTENER - DELETE AND ADD A NODE', () async {
    print("LISTENER TEST - CHECKS DELETE BEHAVIOUR");
    GeigerApi localMaster =
        (await getGeigerApi("", GeigerApi.masterId, Declaration.doShareData))!;
    // ignore: unused_local_variable
    toolbox_api.StorageController storageController = localMaster.getStorage()!;
    toolbox_api.SearchCriteria sc = toolbox_api.SearchCriteria(searchPath: ':');
    toolbox_api.Node demoExample11 =
        toolbox_api.NodeImpl(':Local:DemoExampleTest', 'CloudAdapter');
    await storageController.addOrUpdate(demoExample11);
    NodeListener stListener = NodeListener();
    storageController.registerChangeListener(stListener, sc);
    print("UPDATE A NODE UNDER :LOCAL");
    toolbox_api.Node demoExample1 =
        toolbox_api.NodeImpl(':Local:DemoExample', 'CloudAdapter');
    await storageController.addOrUpdate(demoExample1);
    print(stListener.events);
    print("DELETE A NODE UNDER :LOCAL");
    await storageController.delete(':Local:DemoExampleTest');
    print(stListener.events);
    print("UPDATE A NODE UNDER :LOCAL");
    toolbox_api.Node demoExample12 =
        toolbox_api.NodeImpl(':Local:NewTest', 'CloudAdapter');
    await storageController.addOrUpdate(demoExample12);
    print(stListener.events);
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
  /* test('Encrypter Test', () async {
    String data = "Demo";
    final keyVal = Enc.Key.fromLength(32);
    final enc = Enc.Encrypter(Enc.AES(keyVal, mode: Enc.AESMode.cfb64));
    final iv = Enc.IV.fromLength(32);
    Enc.Encrypted encrypted = enc.encrypt(data, iv: iv);
    print(encrypted.base64);
  });*/
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
}

void main() {
  print("START MAIN");
  replicationTests();
}
