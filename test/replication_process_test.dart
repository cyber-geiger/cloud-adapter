import 'package:cloud_replication_package/cloud_replication_package.dart';
//import 'package:cloud_replication_package/src/service/node_listener.dart';
import 'package:geiger_localstorage/geiger_localstorage.dart' as toolbox_api;
import 'package:geiger_api/geiger_api.dart';
import 'package:test/test.dart';

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

void replicationTests() async {
  test('Full Replication', () async {
    print("FULL REPLICATION TEST");

    /// INIT STORAGE
    ReplicationController rep = ReplicationService();
    await rep.initGeigerStorage();
    await rep.geigerReplication(rep.deleteHandler, rep.createHandler,
        rep.renameHanlder, rep.updateHanlder);
    await rep.endGeigerStorage();
  }, timeout: Timeout(Duration(minutes: 5)));
}

void main() {
  print("START MAIN");
  replicationTests();
}
