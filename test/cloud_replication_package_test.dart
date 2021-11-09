import 'package:cloud_replication_package/src/service/replication_service.dart';
import 'package:test/test.dart';

import 'package:cloud_replication_package/cloud_replication_package.dart';

import 'package:cloud_replication_package/src/service/cloud_service.dart';

import 'package:cloud_replication_package/src/cloud_models/event.dart';
import 'package:cloud_replication_package/src/cloud_models/user.dart';
import 'package:intl/intl.dart';

void replicationTests() async {
  test('Full Replication', () async {
    ReplicationController rep;
    rep = ReplicationService();
    await rep.geigerReplication();
  });

  /// CLOUD SERVICE TESTS
  /// TEST OF EACH METHOD
  test('create Event', () async {
    var cloud = CloudService();
    Event event = Event(id_event: '44445555-5555-5555-5555-123456741254', tlp: 'AMBER');
    await cloud.createEvent('replicationDemo', event);
  });
  test('update Event', () async {
    var cloud = CloudService();
    String id_event = '21546532-4521-3542-1235-54321654';
    Event event = Event(id_event: id_event, tlp: 'white');
    await cloud.updateEvent('anyRandomUserId', id_event, event);
  });
  test('user Exist', () async {
    final cloud = CloudService();
    bool response = await cloud.userExists('0425e093-502a-4bcf-a5c4-74ec77d77199');
    print(response);
  });
  test('create User', () async {
    var cloud = CloudService();
    await cloud.createUser('replicationDemo');
  });
  test('get Users', () async {
    var cloud = CloudService();
    List<User> response = await cloud.getUsers();
    print("--------------------");
    print(response);
  });
  test('get TLP White Events', () async {
    var cloud = CloudService();
    List<Event> response = await cloud.getTLPWhiteEvents();
    print(response);
  });
  test('get TLP White Events - DateTime Filtered', ()  async {
    var cloud = CloudService();
    var date = DateTime.now();
    var formatted = DateFormat("yyyy-MM-dd'T'hh:mm:ss").format(date);
    print(formatted);
    var response = await cloud.getTLPWhiteEventsDateFilter(formatted.toString());
    print(response);
  });
  test('get User Events', () async {
    var cloud = CloudService();
    var response = await cloud.getUserEvents('replicationDemo');
    print(response);
  });
  test('get User Events - DateTime Filtered', () async {
    var cloud = CloudService();
    String filter= DateTime.now().toString();
    var response = await cloud.getUserEventsDateFilter('hackathon', filter);
    print(response);
  });
  test('get Single User Event', () async {
    var cloud = CloudService();
    String id_event= '3fa85f64-5717-4562-b3fc-2c963f66afa6';
    Event response = await cloud.getSingleUserEvent('hackathon', id_event);
    print(response);
  });
  test('delete Event', () async {
    var cloud = CloudService();
    String eventId = '3fa85f64-5717-4562-b3fc-2c963f66afa6';
    await cloud.deleteEvent('hackathon', eventId);
  });
  test('get Threat Weights', () async {
    var cloud = CloudService();
    var response = await cloud.getThreatWeights();
    print(response);
  });
}

void main() {
  print("START MAIN");
  replicationTests();
}
