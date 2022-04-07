import 'package:cloud_replication_package/cloud_replication_package.dart';
import 'package:cloud_replication_package/src/cloud_models/event.dart';
import 'package:cloud_replication_package/src/service/cloud_service/cloud_service.dart';
import 'package:geiger_localstorage/geiger_localstorage.dart' as toolbox_api;
import 'package:geiger_api/geiger_api.dart';
import 'package:test/test.dart';
// ignore: unused_import
import 'package:uuid/uuid.dart';

Future<toolbox_api.StorageController> initGeigerStorage() async {
  print("INIT GEIGER STORAGE");
  try {
    GeigerApi api = await _initGeigerApi();
    print(api);
    toolbox_api.StorageController storageController = api.storage;
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

void replicationTests() async {
  test('SINGLE REPLICATION', () async {
    ReplicationController rep = ReplicationService();
    await rep.initGeigerStorage();
    await rep.geigerReplication(rep.deleteHandler, rep.createHandler,
        rep.renameHanlder, rep.updateHanlder);
    GeigerApi localMaster = (await getGeigerApi(
        "demo-plugin", GeigerApi.masterId, Declaration.doNotShareData))!;
    toolbox_api.StorageController storageController = localMaster.storage;
    toolbox_api.Node local = await storageController.get(':Local');
    String _localUser = await local
        .getValue('currentUser')
        .then((value) => value!.getValue("en").toString());
    CloudService cloud = CloudService();
    List<String> replicatedList = await cloud.getUserEvents(_localUser);
    print("[FIRST] GET CLOUD USERS DATA");
    print(replicatedList);
    for (var i in replicatedList) {
      Event ev = await cloud.getSingleUserEvent(_localUser, i);
      print("REPLICATED EVENT NODE IS: ");
      print(ev);
    }
    rep.endGeigerStorage();
  }, timeout: Timeout(Duration(minutes: 5)));
  /*test('2 REPLICATIONS', () async {
    print("FULL REPLICATION TEST");
    /// INIT STORAGE
    print("FIRST REPLICATION");
    ReplicationController rep = ReplicationService();
    await rep.initGeigerStorage();
    await rep.geigerReplication(rep.deleteHandler, rep.createHandler,
        rep.renameHanlder, rep.updateHanlder);
    GeigerApi localMaster = (await getGeigerApi(
        "demo-plugin", GeigerApi.masterId, Declaration.doNotShareData))!;
    toolbox_api.StorageController storageController = localMaster.storage;
    toolbox_api.Node local = await storageController.get(':Local');
    String _localUser = await local
        .getValue('currentUser')
        .then((value) => value!.getValue("en").toString());
    CloudService cloud = CloudService();
    List<String> replicatedList = await cloud.getUserEvents(_localUser);
    print("[FIRST] GET CLOUD USERS DATA");
    print(replicatedList);
    for (var i in replicatedList) {
      Event ev = await cloud.getSingleUserEvent(_localUser, i);
      print("REPLICATED EVENT NODE IS: ");
      print(ev);
    }

    print("SECOND REPLICATION");
    await rep.geigerReplication(rep.deleteHandler, rep.createHandler,
        rep.renameHanlder, rep.updateHanlder);
    List<String> replicatedList1 = await cloud.getUserEvents(_localUser);
    print("[SECOND] GET CLOUD USERS DATA");
    print(replicatedList1);
    for (var i in replicatedList1) {
      Event ev = await cloud.getSingleUserEvent(_localUser, i);
      print("REPLICATED EVENT NODE IS: ");
      print(ev);
    }
    await rep.endGeigerStorage();
  }, timeout: Timeout(Duration(minutes: 15)));*/
/*
  test('Full Replication - WITH Listeners', () async {
    print("FULL REPLICATION TEST - WITH LISTENERS");

    /// INIT STORAGE
    ReplicationController rep = ReplicationService();
    await rep.initGeigerStorage();
    GeigerApi localMaster = (await getGeigerApi(
        "demo-plugin", GeigerApi.masterId, Declaration.doNotShareData))!;
    toolbox_api.StorageController storageController = localMaster.storage;
    await rep.geigerReplication(rep.deleteHandler, rep.createHandler,
        rep.renameHanlder, rep.updateHanlder);

    /// MODIFY :DEVICES:UUID NODE
    toolbox_api.Node local = await storageController.get(':Local');
    String _localUser = await local
        .getValue('currentUser')
        .then((value) => value!.getValue("en").toString());
    String _localDevice = await local
        .getValue('currentDevice')
        .then((value) => value!.getValue("en").toString());


    /// CHECK LISTENERS
    CloudService cloud = CloudService();

    List<String> nPre = await cloud.getUserEvents(_localUser);
    print("[FIRST] GET CLOUD USERS DATA");
    print(nPre.length);

    /// CREATE DUMMY NODE
    String uuid = Uuid().v4();
    toolbox_api.Node deviceChild =
        toolbox_api.NodeImpl(':Devices:$_localDevice:$uuid', 'demo-plugin');
    deviceChild.addOrUpdateValue(toolbox_api.NodeValueImpl('value', 'demo'));
    await storageController.addOrUpdate(deviceChild);
    
    List<String> nPre1 = await cloud.getUserEvents(_localUser);
    print("[SECOND] GET CLOUD USERS DATA");
    print(nPre1.length);

    /// UPDATE NODE
    toolbox_api.Node deviceChild1 =
        await storageController.get(':Devices:$_localDevice:$uuid');
    deviceChild1.addOrUpdateValue(toolbox_api.NodeValueImpl('value1', 'demo'));
    await storageController.addOrUpdate(deviceChild1);

    List<String> nPre2 = await cloud.getUserEvents(_localUser);
    print("[THIRD] GET CLOUD USERS DATA");
    print(nPre2.length);

    /// RENAME NODE
    try {
      toolbox_api.Node n = await storageController.get(':Devices:$_localDevice:$uuid');
      await storageController.rename(':Devices:$_localDevice:$uuid', ':Devices:$_localDevice:TEST');
    } catch (e) {
      print("NODE DOES NOT EXIST");
    }

    List<String> nPre3 = await cloud.getUserEvents(_localUser);
    print("[FOURTH] GET CLOUD USERS DATA");
    print(nPre3.length);

    /// DELETE NODE
    try {
      await storageController.delete(':Devices:$_localDevice:TEST');
    } catch (e) {
      print(e);
    }

    List<String> nPre4 = await cloud.getUserEvents(_localUser);
    print("[FIFTH] GET CLOUD USERS DATA");
    print(nPre4.length);

    await Future.delayed(Duration(minutes: 1));

    /// CHECK LOGS TO SEE IF HANDLERS JUMP
    print(await storageController.dump());
    await rep.endGeigerStorage();
  }, timeout: Timeout(Duration(minutes: 15)));*/
}

void main() {
  print("START MAIN");
  replicationTests();
}
