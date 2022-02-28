//import 'dart:convert';
//import 'dart:io';

//import 'package:cloud_replication_package/cloud_replication_package.dart';
//import 'package:cloud_replication_package/src/cloud_models/event.dart';
// import 'package:cloud_replication_package/src/cloud_models/threat_weights.dart';
//import 'package:cloud_replication_package/src/cloud_models/user.dart';
// import 'package:cloud_replication_package/src/service/cloud_service.dart';

//import 'package:http/http.dart' as http;
//import 'package:http/io_client.dart';
//import 'package:intl/intl.dart';
import 'package:test/test.dart';

// void replicationTests() async {
  //late toolbox_api.StorageController storageController;
  //final String uri = "https://37.48.101.252:8443/geiger-cloud/api";

  /// UNPAIR TEST
  /*test('Unpair Test', () async {
    //RUN PAIRING TEST BEFORE
    ReplicationController rep;
    rep = ReplicationService();
    expect(() async => await rep.unpair('replicationUser1', 'replicationUser2'),
        returnsNormally);
  });

  test('Full Replication', () async {
    ReplicationController rep;
    rep = ReplicationService();
    await rep.initGeigerStorage();
    await rep.geigerReplication();
    expect(() async => await rep.geigerReplication(), returnsNormally);
  }, timeout: Timeout(Duration(minutes: 5)));

  /// CLOUD SERVICE TESTS
  /// TEST OF EACH METHOD
  /* test('create Event', () async {
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
  test('update Event', () async {
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
  /*test('get Single User Event', () async {
    var cloud = CloudService();
    String idEvent = '3fa85f64-5717-4562-b3fc-2c963f66afa6';
    Event response = await cloud.getSingleUserEvent('hackathon', idEvent);
    expect(Exception, Exception);
  });*/
  /*test('delete Event', () async {
    var cloud = CloudService();
    String eventId = '3fa85f64-5717-4562-b3fc-2c963f66afa6';
    //await cloud.deleteEvent('hackathon', eventId);
    await cloud.deleteEvent('hackathon', eventId);
  });*/
//   test('get Threat Weights', () async {
//     var cloud = CloudService();
//     List<ThreatWeights> response = await cloud.getThreatWeights();
//     print(response.length);
//   });
// }

void main() {
  test('Stupid Test', () {
    //RUN PAIRING TEST BEFORE
    // expect(() async => await rep.unpair('replicationUser1', 'replicationUser2'),
        // returnsNormally);
    expect(true, true);
});
}
