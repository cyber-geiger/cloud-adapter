//import 'package:convert/convert.dart';

//import 'dart:math';
// ignore: library_prefixes
//import 'package:cloud_replication_package/src/replication_exception.dart';
// ignore: library_prefixes
import 'package:cloud_replication_package/src/cloud_models/user.dart';
//import 'package:encrypt/encrypt.dart' as Enc;

//import 'package:cloud_replication_package/cloud_replication_package.dart';
//import 'package:cloud_replication_package/src/cloud_models/event.dart';
//import 'package:cloud_replication_package/cloud_replication_package.dart';
import 'package:cloud_replication_package/src/cloud_models/event.dart';
//import 'package:cloud_replication_package/src/cloud_models/short_user.dart';
import 'package:cloud_replication_package/src/cloud_models/threat_weights.dart';
import 'package:cloud_replication_package/src/service/cloud_service/cloud_exception.dart';
//import 'package:cloud_replication_package/src/cloud_models/user.dart';
import 'package:cloud_replication_package/src/service/cloud_service/cloud_service.dart';
//import 'package:cloud_replication_package/src/service/event_listener.dart';
//import 'package:cloud_replication_package/src/service/node_listener.dart';
//import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
//import 'package:intl/intl.dart';
import 'package:test/test.dart';
//import 'package:geiger_localstorage/geiger_localstorage.dart' as toolbox_api;
//import 'package:geiger_api/geiger_api.dart';

/// CLOUD SERVICE TESTS
void cloudServiceTests() async {
  /// TEST OF EACH METHOD
  test('Authentication', () async {
    var cloud = CloudService();
    await cloud.createUser('letsseeifcan');
  });
  test('merge Test', () async {
    var cloud = CloudService();
    String idUser1 = "replicationTest";
    String idUser2 = "replicationTest1";
    await cloud.deleteMerged(idUser1, idUser2);
  });
  test('create Event', () async {
    var cloud = CloudService();
    var uuid = await cloud.generateUUID();
    Event event = Event(id_event: uuid, tlp: 'AMBER');
    await cloud.createEvent('replicationDemo', event);
  });
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
    await cloud.createUser('dummyCreate');
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
  });
  test('get Single User Event', () async {
    var cloud = CloudService();
    String eventId = await cloud.generateUUID();
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
    String eventId = await cloud.generateUUID();
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

void main() async {
  print("START CLOUD SERVICE TESTS");
  cloudServiceTests();
}
