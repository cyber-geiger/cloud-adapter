library geiger_replication;

import 'dart:io';
import 'dart:async';
import 'dart:convert';

// ignore: library_prefixes
import 'package:encrypt/encrypt.dart' as Enc;
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:intl/locale.dart';

import 'package:cloud_replication_package/src/cloud_models/recommendation.dart';
import 'package:cloud_replication_package/src/cloud_models/security_defender_user.dart';
import 'package:cloud_replication_package/src/cloud_models/security_defenders_organization.dart';
import 'package:cloud_replication_package/src/cloud_models/user.dart';
import '../cloud_models/threats.dart';
import '../cloud_models/event.dart';
import '../cloud_models/short_user.dart';
import 'package:cloud_replication_package/src/replication_exception.dart';
import 'package:cloud_replication_package/src/service/cloud_service/cloud_exception.dart';
import 'package:cloud_replication_package/src/cloud_models/threat_dict.dart';
import 'package:cloud_replication_package/src/cloud_models/threat_weights.dart';
import 'package:cloud_replication_package/src/service/cloud_service/cloud_service.dart';

import 'package:geiger_localstorage/geiger_localstorage.dart' as toolbox_api;
import 'package:geiger_api/geiger_api.dart';

import 'node_listener.dart';
import 'replication_message_listener.dart';

import '../replication_controller.dart';

class ReplicationService implements ReplicationController {
  /// Cloud Service
  /// Enables Replication & Pairing
  final cloud = CloudService();

  /// GEIGER API
  late final GeigerApi _localMaster;

  /// Storage controller
  late final toolbox_api.StorageController _storageController;

  /// Storage Listener
  // ignore: unused_field
  late final toolbox_api.StorageListener _storageListener;

  /// Message Listener
  ReplicationMessageListener? _messageListener;
  bool _isPluginListenerRegistered = false;
  // ignore: prefer_final_fields
  List<MessageType> _handledEvents = [];

  late final String _username;

  final String _pluginAPI = 'pairing_plugin';
  final String _replicationAPI = 'replication_plugin';
  final String __debugLine = '[REPLICATION SERVICE] ';
  final String _enterpriseUsers = ":Enterprise:Users";

  // ignore: unused_field
  final List<String> _rootDoNotReplicate = [
    ':Keys',
    ':Users',
    ':Enterprise',
    ':Global',
    ':Local'
  ];

  //MAP OF CLOUD EVENTS TO JSON
  List<Map<dynamic, dynamic>> cloudNodeList = [];
  //STRING LIST OF THE PATH THAT COVERS EACH EVENT
  List<String> cloudNodePath = [];
  //USER EVENT DATA
  List<Event> cloudEvents = [];
  //STRING LIST OF CLOUD EVENTS
  List<String> userEvents = [];
  //STRING OF CONTENTS OF EVENTS
  List<String> contentEvents = [];

  String sharedScore = '',username = '', sharedScoreDate = '';

  ReplicationService();

  @override
  Future<bool> checkConnection() async {
    print(__debugLine + 'checkConnection');
    try {
      /// CONNECTION WITH THE CLOUD
      /// PROVIDE FINAL CLOUD URL
      final response = await InternetAddress.lookup('37.48.101.252');
      if (response.isNotEmpty) {
        return true;
      } else {
        return false;
      }
    } on SocketException catch (e) {
      print(__debugLine + 'EXCEPTION: '+e.toString());
      print(e);
      return false;
    }
  }

  @override
  Future<bool> checkReplication() async {
    print(__debugLine + 'checkReplication');
    try {
      // ignore: unused_local_variable
      toolbox_api.Node checker =
          await getNode(':Local:Replication:LastReplication');
      return true;
    } catch (e) {
      print(__debugLine + 'EXCEPTION: '+e.toString());
      return false;
    }
  }

  @override
  Future<bool> checkReplicationTimingStrategy() async {
    print(__debugLine + 'checkReplicationTimingStrategy');
    try {
      // ignore: unused_local_variable
      toolbox_api.Node checker =
          await getNode(':Local:Replication:LastReplication');
      DateTime _actual = DateTime.now();
      DateTime _fromDate = _actual.subtract(Duration(days: 30));
      int milis = _fromDate.millisecondsSinceEpoch;
      int nodeTimestamp = checker.lastModified;
      if (milis < nodeTimestamp) {
        return false;
      } else {
        return true;
      }
    } catch (e) {
      print(__debugLine + 'EXCEPTION');
      return false;
    }
  }

  @override
  Future<bool> geigerReplication(
      deleteHandler, createHandler, updateHandler, renameHandler) async {
    final enable_encryption = false;
    print(__debugLine + 'STARTING GEIGER REPLICATION REGULAR WITH GLOBAL');

    /// Follow diagram
    /// 3 steps replication
    /// Cloud to device
    /// Device to cloud
    /// Storage listener
    /// Take care of strategies

    /// 1. INIT STORAGE
    /// this is done with initgeigerstoremethod providing an already initiated storage controller

    /// CHECK WHEN LAST REPLICATION TOOK PLACE
    /// Nodes that handle replication:
    /// :Replication:LastReplication
    DateTime _actual = DateTime.now();
    bool _fullRep;

    /// 180 -> Default expiring date
    DateTime _fromDate = _actual.subtract(Duration(days: 180));
    print('[1st FLOW] - TIMESTAMP CHECKER');
    try {
      toolbox_api.Node timeChecker =
          await getNode(':Local:Replication:LastReplication');
      DateTime _lastTimestamp =
          DateTime.fromMillisecondsSinceEpoch(timeChecker.lastModified);
      Duration _diff = _actual.difference(_lastTimestamp);
      if (_diff.inDays > 30) {
        /// FULL REPLICATION TAKES PLACE
        print("FULL REPLICATION");
        _fullRep = true;
      } else {
        /// PARTIAL REPLICATION TAKES PLACE
        print("PARTIAL REPLICATION");
        _fullRep = false;
        _fromDate = _lastTimestamp;
      }
    } catch (e) {
      print('NO REPLICATION NODE FOUND - NO REPLICATION HAS BEEN DONE: '+e.toString());

      /// FULL REPLICATION TAKES PLACE
      _fullRep = true;
      print(e);
    }

    // 2. GET USER DATA - CHECK USER IN CLOUD
    print('[1st FLOW] - CHECK USER DATA');
    try {
      toolbox_api.Node local = await getNode(':Local');
      String _localUser = await local
          .getValue('currentUser')
          .then((value) => value!.getValue("en").toString());
      _username = _localUser;
      //CHECK IF USER ALREADY IN CLOUD & IF NOT, CREATE ONE
      bool exists = await cloud.userExists(_username.toString());
      //print(exists.toString());
      if (exists == false) {
        await cloud.createUser(_username.toString());
        //IF NO USER IN cloud. NO REPLICATION HAS TAKEN PLACE
        //print('No replication has taken place');
        /// FULL REPLICATION TAKES PLACE
        _fullRep = true;
      }
    } catch (e) {
      toolbox_api.StorageException('USER DATA NOT FOUND. ERROR: '+e.toString());
      print(e);
      return false;
    }
    print(_username);
    // CREATE PAIRING STRUCTURE
    await createPairingStructure();

    /// CLOUD TO LOCAL REPLICATION
    print("[2nd FLOW] - CLOUD TO LOCAL");
    await cloudToLocalReplication(_username, _actual, _fromDate, _fullRep, enable_encryption: enable_encryption);

    /// LOCAL TO CLOUD REPLICATION
    print("[3rd FLOW] - LOCAL TO CLOUD");
    await localToCloudReplication(_username, _actual, _fromDate, _fullRep, enable_encryption: enable_encryption);

    /// UPDATE WHEN LAST REPLICATION TOOK PLACE
    print("[4th FLOW] - UPDATE WHEN LAST REPLICAION TOOK PLACE");
    await updateReplicationNode(_actual);

    /// STORAGE LISTENER
    print("[5th FLOW] - LISTENER REPLICATION");
    await geigerReplicationListener(
        deleteHandler, createHandler, updateHandler, renameHandler);
    return true;
  }

  @override
  Future<bool> updateGlobalData() async {
    bool result = false;
    try {
      /// Updates GEIGER Defined Threats
      await updateThreats();

      /// Updates Threat Weights
      await updateThreatWeights();

      /// Updates Global Recommendations in a Cloud to Local way
      await updateRecommendations();

      /// Updates Security Defenders Info
      await updateSecurityDefendersInfo();
      result = true;
    } catch (e) {
      print("[UPDATE GLOBAL DATA EXCEPTION]: "+e.toString());
      print(e);
    }
    return result;
  }

  Future<void> cloudToLocalReplication(String _username, DateTime _actual,
      DateTime _fromDate, bool _fullRep, {bool enable_encryption= false}) async {
    print("CLOUD TO LOCAL REPLICATION - Function cloudToLocalReplication");

    /// WITH DATETIME TAKE EVENTS FROM THE CLOUD
    List<String> events;

    // FILTER BY DATE
    if (_fullRep == true) {
      events = await cloud.getUserEvents(_username);
    } else {
      var filter =
          DateFormat("yyyy-MM-dd'T'hh:mm:ss.SSSS'Z'").format(_fromDate);
      events =
          await cloud.getUserEventsDateFilter(_username, filter.toString());
    }

    List<Event> waitingEvents = [];
    for (var userEvent in events) {
      Event singleOne = await cloud.getSingleUserEvent(_username, userEvent);
      Map<dynamic, dynamic> data = getPartialJsonString(singleOne.content!);

      // HAVE A VAR WITH DATA
      if (userEvents.contains(userEvent) == false) {
        userEvents.add(userEvent);
        cloudEvents.add(singleOne);
        cloudNodeList.add(data);
        cloudNodePath.add(data['path']);
      } else {
        int index = userEvents.indexOf(userEvent);
        Event toCompare = cloudEvents[index];
        DateTime? evToCompare = toCompare.last_modified;
        DateTime? newTime = singleOne.last_modified;
        //AS IN CLOUD, COMPARE DATETIMES
        Duration _diff = newTime!.difference(evToCompare!);
        if (_diff.inDays > 0) {
          userEvents[index] = userEvent;
          cloudNodeList[index] = (data);
          cloudNodePath[index] = (data['path']);
          cloudEvents[index] = singleOne;
        }
      }

      String type = singleOne.type.toString();
      //String tlp = singleOne.tlp.toString();
      String id = singleOne.id_event.toString();
      String owner = singleOne.owner.toString();
      if (owner != _username) {
        if (type.toLowerCase() == "keyvalue") {
          print('CLOUD TO LOCAL REPLICATION - NO E2EE - FUNCTION cloudToLocalReplication');
          toolbox_api.Node node = convertJsonStringToNode(singleOne.content!);
          await updateLocalNodeWithCloudNode(node, _username);
        }
        if (type.toLowerCase() == "user_object") {
          if (enable_encryption) {
            print(
                'CLOUD TO LOCAL REPLICATION - E2EE - FUNCTION cloudToLocalReplication');
            try {
              Map<dynamic, dynamic> jsonify = await decryptCloudData(singleOne);
              singleOne.setContent = jsonEncode(jsonify);
              toolbox_api.Node node = convertJsonStringToNode(
                  singleOne.content!);
              await checkParents(node.path);
              await updateLocalNodeWithCloudNode(node, _username);
            } catch (e) {
              print("ERROR DURING CLOUD TO LOCAL REPLICATION E2EE:"+ e.toString());

              /// KAY MAY NOT BE REPLICATED YET - CREATE NEW LIST AND DO SAME OPERATION
              waitingEvents.add(singleOne);
              print(
                  'FAILURE GETTING KEYS FOR NODE - FUNCTION cloudToLocalReplication ID-EVENT: $id');
            }
          }
          else{
            try {
              print(
                  'CLOUD TO LOCAL REPLICATION - NO ENCRYPTION ENABLED - FUNCTION cloudToLocalReplication');
              toolbox_api.Node node = convertJsonStringToNode(
                  singleOne.content!);
              await checkParents(node.path);
              await updateLocalNodeWithCloudNode(node, _username);
            } catch (e){
              print("ERROR WITHIN FUNCTION cloudToLocalReplication LINE 328: "+e.toString());
              waitingEvents.add(singleOne);
            }
          }
        }
      }
    }

    print("WAITING EVENTS - FUNCTION cloudToLocalReplication");
    for (var waiting in waitingEvents) {
      String waitingId = waiting.id_event.toString();
      try {
        ///CREATE A SEARCH CRITERIA TO FIND KEY WITH GIVEN PATH
        ///ELSE CREATE A NODE WITH VISIBILITY AMBER
        ///AND REPLICATE
        Map<dynamic, dynamic> jsonify = await decryptCloudData(waiting);
        waiting.setContent = jsonEncode(jsonify);
        toolbox_api.Node node = convertJsonStringToNode(waiting.content!);
        await checkParents(node.path);
        await updateLocalNodeWithCloudNode(node, _username);
      } catch (e) {
        print(e);
        print('FAILURE GETTING KEYS FOR NODE - FUNCTION cloudToLocalReplication: $waitingId');
        try {
          toolbox_api.Node node = convertJsonStringToNode(waiting.content!);
          await updateLocalNodeWithCloudNode(node, _username);
        } catch (e) {
          print("GET SHARED NODES FAILURE - FUNCTION cloudToLocalReplication: "+e.toString());
          print(e.toString());
        }
      }
    }

    await updateGlobalData();
  }

  Future<void> localToCloudReplication(String _username, DateTime _actual,
      DateTime _fromDate, bool _fullRep, {bool enable_encryption= false}) async {
    print("REPLICATION - LOCAL TO CLOUD NODES REPLICATION - FUNCTION localToCloudReplication");

    /// START OF THE SECOND DIAGRAM
    /// START CLEANING DATA AND REMOVING TOMBSTONES
    cleanData(_actual);
    List<toolbox_api.Node> nodeList = [];
    if (_fullRep == true) {
      /// FIND ALL THE NODES
      nodeList.addAll(await getAllNodes());
      //nodeList = await getAllNodes();
    } else {
      /// ASK FOR SEARCH CRITERIA NODE BASED
      //print('PARTIAL REPLICATION');
      nodeList.addAll(await getAllNodesLastModified(_fromDate));
    }

    /// SORT NODES BY TIMESTAMP
    nodeList.sort((a, b) => DateTime.fromMillisecondsSinceEpoch(a.lastModified)
        .compareTo(DateTime.fromMillisecondsSinceEpoch(b.lastModified)));

    /// GET ALL EVENTS OF A USER - THE NAME CAN BE ANYTHING
    /// UUID IS RECOMMENDED BUT NOT MANDATORY
    /// CONVERT ALL TO NODES AND CHECK
    List<String> events;
    try {
      events = await cloud.getUserEvents(_username);
      for (var userEvent in events) {
        try {
          Event newCloudEvent =
              await cloud.getSingleUserEvent(_username, userEvent);
          Map<dynamic, dynamic> data =
              getPartialJsonString(newCloudEvent.content!);
          // HAVE A VAR WITH DATA
          if (userEvents.contains(userEvent) == false) {
            userEvents.add(userEvent);
            cloudEvents.add(newCloudEvent);
            cloudNodeList.add(data);
            cloudNodePath.add(data['path']);
          } else {
            /// CHECK TIMESTAMP
            int index = userEvents.indexOf(userEvent);
            Event toCompare = cloudEvents[index];
            DateTime? evToCompare = toCompare.last_modified;
            DateTime? newTime = newCloudEvent.last_modified;
            //AS IN CLOUD, COMPARE DATETIMES
            Duration _diff = newTime!.difference(evToCompare!);
            if (_diff.inDays > 0) {
              userEvents[index] = userEvent;
              cloudNodeList[index] = (data);
              cloudNodePath[index] = (data['path']);
              cloudEvents[index] = newCloudEvent;
            }
          }
        } catch (e) {
          print("ERROR GETTING SINGLE USER EVENT: "+e.toString());
        }
      }
    } catch (e) {
      print("ERROR GETTING CLOUD USER EVENTS: "+e.toString());
    }

    if (nodeList.isEmpty == false) {
      for (var sorted in nodeList) {
        /// CHECK TLP
        String tlp = sorted.visibility.toValueString();
        // ignore: unused_local_variable
        String identifier = sorted.name.toString();
        String fullPath = sorted.path;

        /// CHECK CONSENT
        /// TBD
        /// 3 AGREEMENTS: NEVER, NO ONCE, AGREE ONCE
        /// CREATE EVENT
        String uuid = await cloud.generateUUID();
        Event toCheck = Event(id_event: uuid, tlp: tlp.toUpperCase());
        toCheck.encoding = 'ascii';
        if (tlp.toLowerCase() != 'black' &&
            sorted.path.startsWith(':Local') == false &&
            sorted.path.startsWith(':Global') == false &&
            sorted.tombstone == false) {
          if (tlp.toLowerCase() == 'red') {
            print("TLP:RED NODE");
            if(enable_encryption) {
              try {
                Map<dynamic, dynamic> convertedNode =
                await encryptCloudData(sorted);
                toCheck.content = json.encode(convertedNode);
              } catch (e) {
                print(e);
                toCheck.content =
                    json.encode(await convertNodeToJsonString(sorted));
                print('FAILURE GETTING KEYS');
              }
              toCheck.type = 'user_object';
            }
            else{
              toCheck.type = 'user_object';
              toCheck.content = json.encode(await convertNodeToJsonString(sorted));
            }
          } else {
            toCheck.type = 'keyvalue';
            toCheck.content =
                json.encode(await convertNodeToJsonString(sorted));
          }
          toCheck.owner = _username;
          //CHECK IF EVENT IN CLOUD
          try {
            // IF OK
            // CHECK TIMESTAMP
            // IF NEEDED -> PUT
            if (cloudNodePath.contains(fullPath) == true) {
              print("NODE ALREADY IN CLOUD");
              int index = cloudNodePath.indexOf(fullPath);
              DateTime toCompare = DateTime.fromMillisecondsSinceEpoch(
                  cloudNodeList[index]['lastModified']);
              DateTime nodeTime =
                  DateTime.fromMillisecondsSinceEpoch(sorted.lastModified);
              //AS IN CLOUD, COMPARE DATETIMES
              Duration _diff = nodeTime.difference(toCompare);
              if (_diff.inDays > 0) {
                print("UPDATE LOCAL NODE IN CLOUD");
                await cloud.updateEvent(_username, userEvents[index], toCheck);
              }
            } else {
              print("NODE NOT IN CLOUD");
              print("ADD LOCAL NODE TO CLOUD");
              await cloud.createEvent(_username, toCheck);
            }
          } catch (e) {
            print(e);
            print("CATCH");
            print("ADD LOCAL NODE TO CLOUD");
            print("ERROR checkin if the event is in the cloud: "+e.toString());
            // IF NO EVENT IS RETURNED -> POST NEW EVENT
            await cloud.createEvent(_username, toCheck);
          }
        } else {
          print("LOCAL NODE MUST NOT BE REPLICATED: " + sorted.toString());
        }
      }
    }
    print("END LOCAL TO CLOUD REPLICATION");
  }

  @override
  Future<bool> checkPairing(String userId1, String userId2) async {
    bool checker = false;

    /// Check if userId1 has an active agreement with userId2
    try {
      toolbox_api.Node agreementNode = await getNode(':Local:Pairing:$userId2');
      print("Agreement exist: " + agreementNode.name);
      checker = true;
    } catch (e) {
      print("PAIRING NODE NOT FOUND: "+e.toString());
      checker = false;
    }
    return checker;
  }

  @override
  Future<bool> setPair(String userId1, String userId2, String agreement,
      [String? publicKey, String? type]) async {
    print("START SET PAIR METHOD");

    /// Check if both users in the cloud
    /// second (remote) user should be created from the others device
    bool user1Exists = await cloud.userExists(userId1);
    if (!user1Exists) {
      /// CHECK IF LOCALLY WE DO HAVE MORE DATA
      await cloud.createUser(userId1);
    }

    /// CREATES LOCAL PAIRING NODE
    try {
      toolbox_api.Node agreementNode = await getNode(':Local:Pairing:$userId2');
      print("Node exists for the path:" + agreementNode.path.toString());
      print("$userId1 and $userId2 are already paired");
      //throw ReplicationException("Pairing node exist");
    } catch (e) {
      print("ERROR CREATING LOCAL PAIRING NODE: "+e.toString());
      try {
        toolbox_api.Node agreementParent = await getNode(':Local:Pairing');
        print("Parent path exists: " + agreementParent.name.toString());
      } catch (e) {
        /// Create parent node
        toolbox_api.Node agreementParent =
            toolbox_api.NodeImpl(':Local:Pairing', _replicationAPI);
        await _storageController.add(agreementParent);
      }
      toolbox_api.Node newAgreement =
          toolbox_api.NodeImpl(':Local:Pairing:$userId2', _replicationAPI);
      newAgreement
          .addOrUpdateValue(toolbox_api.NodeValueImpl("agreement", agreement));
      if (publicKey != null) {
        newAgreement
            .addOrUpdateValue(toolbox_api.NodeValueImpl("key", publicKey));
      } else {
        newAgreement.addOrUpdateValue(toolbox_api.NodeValueImpl("key", ""));
      }
      if (type != null) {
        newAgreement.addOrUpdateValue(toolbox_api.NodeValueImpl("type", type));
      } else {
        newAgreement.addOrUpdateValue(toolbox_api.NodeValueImpl("type", ""));
      }
      await _storageController.add(newAgreement);
    }

    /// REPLICATES INTO THE CLOUD WITH COMPLEMENTARY AGREEMENTS
    String complementValue;
    if (agreement == "in") {
      complementValue = "out";
    } else if (agreement == "out") {
      complementValue = "in";
    } else if (agreement == "both") {
      complementValue = "both";
    } else {
      print("Not valid agreement value. Choose between: {'in','out','both'}");
      return false;
      //throw ReplicationException(
      //"Not valid agreement value. Choose between: {'in','out','both'}");
    }

    /// check if mutual merge exists
    /// if one user agrees in - the other must agree out and vice versa
    /// if agree both - the other must agree both
    /// check userId1 agreements
    try {
      List<String> agreeUser1 = await cloud.getMergedAccounts(userId1);
      if (agreeUser1.contains(userId2) == false) {
        await cloud.createMerge(userId1, userId2, agreement, type);
      } else {
        print("CLOUD AGREEMENT ALREADY EXIST");
      }
    } catch (e) {
      print("ERROR CREATING MERGE LINE 610 REPLICATION SERVICE: "+e.toString());
      await cloud.createMerge(userId1, userId2, agreement, type);
    }
    try {
      List<String> agreeUser2 = await cloud.getMergedAccounts(userId2);
      if (agreeUser2.contains(userId1) == false) {
        await cloud.createMerge(userId2, userId1, complementValue, type);
      } else {
        print("CLOUD AGREEMENT ALREADY EXIST");
      }
    } catch (e) {
      print("ERROR CREATING MERGE LINE 621 REPLICATION SERVICE: "+e.toString());
      await cloud.createMerge(userId2, userId1, complementValue, type);
    }

    print('GET SHARED NODES BETWEEN PAIRED USERS');
    try{
      await getSharedNodes(userId1, userId2);
    }catch (e){
      print("ERROR GETTING NODES BETWEEN PAIRED USERS LINE 630 REPLICATION SERVICE: "+e.toString());
      return false;
    }

    await createEnterprisePairingNode(userId1, userId2);

    return true;
  }

  Future<void> createEnterprisePairingNode(String userId1, String userId2) async {
    print("[PAIRING] CREATE ENTERPRISE PAIRING NODE");
    try {
      toolbox_api.Node entUs = await getNode('$_enterpriseUsers:$userId1:$_pluginAPI');
      print("USER ENTERPRISE "+ entUs.toString());

      /// get user nodes
      List<String> allEvents = await cloud.getUserEvents(userId1);
      for (var event in allEvents) {
        Event newEvent = await cloud.getSingleUserEvent(userId1, event);
        contentEvents.add(newEvent.content!);
      }
      final sb = StringBuffer();
      sb.writeAll(contentEvents, ' , ');

      entUs.addOrUpdateValue(toolbox_api.NodeValueImpl("data", sb.toString()));
      _storageController.addOrUpdate(entUs);
      print("USER ENTERPRISE "+ entUs.toString());

    } catch(e){
      print("ERROR CAN NOT LOCATE ENTERPRISE USERS NODE "+e.toString());
    }
  }

  @override
  Future<bool> updatePair(String userId1) async {
    print("[REPLICATION SERVICE] UPDATE PAIR METHOD");

    /// CHECK THE CLOUD FOR AGREEMENTS
    List<String> mergeds = await cloud.getMergedAccounts(userId1);
    if (mergeds.isNotEmpty) {
      for (var user in mergeds) {
        ShortUser u = await cloud.getMergedInfo(userId1, user);

        /// CHECK LOCAL PAIRING NODE
        try {
          // ignore: unused_local_variable
          toolbox_api.Node replicationParent = await getNode(':Local:Pairing');
        } catch (e) {
          print("ERROR CHECKING PARING NODE LINE 649 REPLICATION SERVICE: "+e.toString());
          toolbox_api.Node replicationParent =
              toolbox_api.NodeImpl(':Local:Pairing', _replicationAPI);
          await _storageController.add(replicationParent);
        }
        try {
          // ignore: unused_local_variable
          toolbox_api.Node replicationNode =
              await getNode(':Local:Pairing:$user');
          print("PAIRING ALREADY EXIST");
        } catch (e) {
          toolbox_api.Node replicationNode = toolbox_api.NodeImpl(
              ':Local:Pairing:$user', 'ReplicationService');
          if (u.getPublicKey != null) {
            replicationNode.addOrUpdateValue(
                toolbox_api.NodeValueImpl("key", u.getPublicKey!));
          } else {
            replicationNode
                .addOrUpdateValue(toolbox_api.NodeValueImpl("key", ""));
          }
          await _storageController.add(replicationNode);
        }
        await getSharedNodes(userId1, user);
      }
    } else {
      return false;
    }
    return true;
  }

  @override
  Future<bool> unpair(String userId1, String userId2) async {
    print("START UNPAIR METHOD");

    /// deletes local node exists
    /// deletes merge agreement in the cloud
    /// checks if cloud users exist
    /// checks if already merged
    /// userId1 - local user
    /// userId2 - peer partner

    /// DELETE LOCAL AGREEMENT
    try {
      await _storageController.delete(":Local:Pairing:$userId2");
    } catch (e) {
      print("Pairing Node not found");
      return false;
    }

    /// CHECK IF USER IN CLOUD
    bool user1Exists = await cloud.userExists(userId1);
    if (user1Exists == false) {
      print("User not in cloud");
      return false;
    } else {
      /// CHECK USERID1 AGREEMENTS
      /// IF CONTAINS USERID2 - DELETE AGREEMENT
      try {
        List<String> agreeUser1 = await cloud.getMergedAccounts(userId1);
        if (agreeUser1.contains(userId2) == true) {
          try {
            print("AGREEMENT SET");
            await cloud.deleteMerged(userId1, userId2);
          } catch (e) {
            print("[CLOUD EXCEPTION] SOMETHING WENT WRONG WHEN UNPAIRING.");
            return false;
          }
        } else {
          return false;
        }
      } catch (e) {
        return false;
      }
    }

    /// LOOK FOR USERID2 OWNED NODES
    /// CREATE A SEARCH CRITERIA
    toolbox_api.SearchCriteria criteria = toolbox_api.SearchCriteria();
    List<toolbox_api.Node> nodeList = await _storageController.search(criteria);
    for (var toDelete in nodeList) {
      if (toDelete.owner == _pluginAPI) {
        try {
          print("NODE TO BE DELETED: " + toDelete.path);
          await _storageController.delete(toDelete.path);
        } catch (e) {
          print("FAILURE REMOVING PAIRED NODE: " + toDelete.path);
          return false;
        }
      }
    }
    return true;
  }

  @override
  Future<bool> shareNode(
      String nodePath, String senderUserId, String receiverUserId) async {
    /// check local pairing
    /// check cloud pairing
    /// get key
    /// create cloud event e2ee (if public key - else no e2ee)
    /// post event
    try {
      print("SHARE NODE BETWEEN PAIRED DEVICES");
      toolbox_api.Node node = await getNode(':Local:Pairing:$receiverUserId');
      String encryptedKey = await node
          .getValue('key')
          .then((value) => value!.getValue("en").toString());
      String agreeValue = await node
          .getValue('agreement')
          .then((value) => value!.getValue("en").toString());
      if (agreeValue == 'out' || agreeValue == 'both') {
        try {
          print("Agreement valid");
          List<String> agreements = await cloud.getMergedAccounts(senderUserId);
          if (agreements.contains(receiverUserId) == true) {
            ShortUser data =
                await cloud.getMergedInfo(senderUserId, receiverUserId);
            String? publicKey = data.getPublicKey;
            if (publicKey != null) {
              try {
                final keyVal = Enc.Key.fromUtf8(publicKey);
                final iv = Enc.IV.fromLength(16);
                final enc =
                    Enc.Encrypter(Enc.AES(keyVal, mode: Enc.AESMode.cfb64));
                // need to decrypt the encryptedKey
                // DECRYPT DATA
                encryptedKey = enc.decrypt(
                    encryptedKey.split(':')[1] as Enc.Encrypted,
                    iv: iv);
              } catch (e) {
                print("ISSUE DECRYPTING DATA");
              }
            } else {
              encryptedKey = encryptedKey.split(':')[1];
            }
            // node to send
            toolbox_api.Node toShareNode = await getNode(nodePath);
            String uuid = await cloud.generateUUID();
            Event toPostEvent = Event(
                id_event: uuid,
                tlp: toShareNode.visibility.toValueString().toUpperCase());
            toPostEvent.setOwner = senderUserId;
            toPostEvent.setType = 'user';
            toPostEvent.encoding = 'ascii';
            //EncryptNode
            try {
              Map<dynamic, dynamic> jsonify =
                  await encryptCloudData(toShareNode);
              toPostEvent.setContent = jsonEncode(jsonify);
            } catch (e) {
              print("ISSUE ENCRYPTING DATA");
              toPostEvent.setContent =
                  json.encode(await convertNodeToJsonString(toShareNode));
            }
            await cloud.createEvent(senderUserId, toPostEvent);
          } else {
            return false;
            //throw CloudException('There is no active cloud agreement');
          }
        } catch (e) {
          return false;
          //throw CloudException('There is no active cloud agreement');
        }
        return true;
      } else {
        return false;
        //return false;
      }
    } catch (e) {
      return false;
      //throw ReplicationException('Key Node not found');
    }
  }

  @override
  Future<bool> getSharedNodes(
      String receiverUserId, String senderUserId) async {
    print(
        "***************************************************************************");

    /// get receiverNodes
    /// cloud API retrieves also the shared ones
    /// check the Event owner to differenciate
    try {
      print("GET SHARED NODES BETWEEN TWO PAIRED USER/DEVICE - FUNCTION getSharedNodes");
      toolbox_api.Node node = await getNode(':Local:Pairing:$senderUserId');
      String encryptedKey = await node
          .getValue('key')
          .then((value) => value!.getValue("en").toString());
      String agreeValue = await node
          .getValue('agreement')
          .then((value) => value!.getValue("en").toString());
      if (agreeValue == 'in' || agreeValue == 'both') {
        try {
          List<String> agreements = await cloud.getMergedAccounts(senderUserId);
          if (agreements.contains(receiverUserId) == true) {
            /// check if our user has publicKey
            /// else the key will be clear
            User actualUser = await cloud.getUser(receiverUserId);
            var publicKey = actualUser.getPublicKey;
            if (publicKey != null) {
              publicKey = publicKey.toString();
              try {
                final keyVal = Enc.Key.fromUtf8(publicKey);
                final enc =
                    Enc.Encrypter(Enc.AES(keyVal, mode: Enc.AESMode.cbc));
                final iv = Enc.IV.fromLength(16);
                //DECRYPT DATA
                encryptedKey = enc.decrypt(
                    encryptedKey.split(':')[1] as Enc.Encrypted,
                    iv: iv);
              } catch (e) {
                print("ISSUE ENCRYPTING DATA - FUNCTION getSharedNodes");
                encryptedKey = publicKey;
              }
            }

            /// get user nodes
            List<String> allEvents = await cloud.getUserEvents(receiverUserId);
            List<Event> waitingEvents = [];

            print("GET USER SHARED EVENTS - FUNCTION getSharedNodes");
            for (var event in allEvents) {
              print("STARTING SHARED EVENTS - FUNCTION getSharedNodes");
              Event newEvent =
                  await cloud.getSingleUserEvent(receiverUserId, event);
              var owner = newEvent.getOwner;
              String id = newEvent.id_event;
              var type = newEvent.type;
              if (owner != receiverUserId) {
                if (newEvent.content != null) {
                  if (type!.toLowerCase() == "keyvalue") {
                    print('CLOUD TO LOCAL REPLICATION - NO E2EE - FUNCTION getSharedNodes');
                    toolbox_api.Node node =
                        convertJsonStringToNode(newEvent.content!);
                    await checkParents(node.path);
                    toolbox_api.Node pairedNode =
                        toolbox_api.NodeImpl(node.path, _pluginAPI);
                    pairedNode.visibility = node.visibility;
                    Map<String, toolbox_api.NodeValue> nodeData =
                        await node.getValues();
                    for (var entry in nodeData.entries) {
                      pairedNode.addOrUpdateValue(entry.value);
                    }
                    print("[PAIRING 1] NODE TO BE UPDATED - FUNCTION getSharedNodes");
                    print(pairedNode);
                    await updateLocalNodeWithCloudNode(pairedNode, _pluginAPI);
                  }
                  if (type.toLowerCase() == "user_object") {
                    print('CLOUD TO LOCAL REPLICATION - E2EE - FUNCTION getSharedNodes');
                    //GET KEYS
                    try {
                      ///CREATE A SEARCH CRITERIA TO FIND KEY WITH GIVEN PATH
                      ///ELSE CREATE A NODE WITH VISIBILITY AMBER
                      ///AND REPLICATE
                      Map<dynamic, dynamic> jsonify =
                          await decryptCloudData(newEvent);
                      newEvent.setContent = jsonEncode(jsonify);
                      toolbox_api.Node node =
                          convertJsonStringToNode(newEvent.content!);
                      await checkParents(node.path);
                      toolbox_api.Node pairedNode =
                          toolbox_api.NodeImpl(node.path, _pluginAPI);
                      pairedNode.visibility = node.visibility;
                      Map<String, toolbox_api.NodeValue> nodeData =
                          await node.getValues();
                      for (var entry in nodeData.entries) {
                        pairedNode.addOrUpdateValue(entry.value);
                      }
                      print("[PAIRING 2] NODE TO BE UPDATED - FUNCTION getSharedNodes");
                      print(pairedNode);
                      await updateLocalNodeWithCloudNode(
                          pairedNode, _pluginAPI);
                    } catch (e) {
                      /// KAY MAY NOT BE REPLICATED YET - CREATE NEW LIST AND DO SAME OPERATION
                      waitingEvents.add(newEvent);
                      print('FAILURE GETTING KEYS FOR NODE - FUNCTION getSharedNodes: $id');
                      print(newEvent);
                    }
                  }
                }
              } else {
                print("THE OWNER OF THE SHARED NODE IS - FUNCTION getSharedNodes: " + owner!);
              }
            }
            for (var waiting in waitingEvents) {
              print("STARTING WAITING EVENTS - FUNCTION getSharedNodes");
              String waitingId = waiting.id_event.toString();
              var owner = waiting.getOwner;
              if (owner != receiverUserId) {
                print("WAITING EVENT - FUNCTION getSharedNodes: $waitingId");
                try {
                  ///CREATE A SEARCH CRITERIA TO FIND KEY WITH GIVEN PATH
                  ///ELSE CREATE A NODE WITH VISIBILITY AMBER
                  ///AND REPLICATE
                  Map<dynamic, dynamic> jsonify =
                      await decryptCloudData(waiting);
                  waiting.setContent = jsonEncode(jsonify);
                  toolbox_api.Node node =
                      convertJsonStringToNode(waiting.content!);
                  await checkParents(node.path);
                  toolbox_api.Node pairedNode =
                      toolbox_api.NodeImpl(node.path, _pluginAPI);
                  pairedNode.visibility = node.visibility;
                  Map<String, toolbox_api.NodeValue> nodeData =
                      await node.getValues();
                  for (var entry in nodeData.entries) {
                    pairedNode.addOrUpdateValue(entry.value);
                  }
                  print("[PAIRING 3] NODE TO BE UPDATED - FUNCTION getSharedNodes");
                  print(pairedNode);
                  await updateLocalNodeWithCloudNode(pairedNode, _pluginAPI);
                } catch (e) {
                  print(
                      'WAITING EVENTS - FAILURE GETTING KEYS FOR NODE - FUNCTION getSharedNodes: $waitingId');
                  try {
                    toolbox_api.Node node =
                        convertJsonStringToNode(waiting.content!);
                    await checkParents(node.path);
                    toolbox_api.Node pairedNode =
                        toolbox_api.NodeImpl(node.path, _pluginAPI);
                    pairedNode.visibility = node.visibility;
                    Map<String, toolbox_api.NodeValue> nodeData =
                        await node.getValues();
                    for (var entry in nodeData.entries) {
                      pairedNode.addOrUpdateValue(entry.value);
                    }
                    print("[PAIRING 4] NODE TO BE UPDATED - FUNCTION getSharedNodes");
                    print(pairedNode);
                    await updateLocalNodeWithCloudNode(pairedNode, _pluginAPI);
                  } catch (e) {
                    print("GET SHARED NODES FAILURE - FUNCTION getSharedNodes");
                    print(e.toString());
                  }
                }
              }
            }
          }
        } catch (e) {
          print(e);
          return false;
        }
      }
    } catch (e) {
      print(e);
      return false;
    }
    return true;
  }

  @override
  Future<bool> createCloudUser(String userId,
      [String? email,
      String? access,
      String? expires,
      String? name,
      String? publicKey]) async {
    try {
      await cloud.createUser(userId.toString());
      return true;
    } catch (e) {
      return false;
      //throw CloudException('Could not create cloud user with id: $userId');
    }
  }

  /// UTILS
  /// IN THIS SECTION ARE REPETITIVE TASKS
  /// AVOID DUPLICATION CODE

  /* INIT */
  @override
  Future<void> initGeigerStorage() async {
    print("INIT GEIGER STORAGE");
    try {
      GeigerApi api = await _initGeigerApi();
      print(api);
      _storageController = api.storage;
      print(_storageController);
    } catch (e) {
      print("DATABASE CONNECTION ERROR FROM LOCALSTORAGE: "+e.toString());
      rethrow;
    }
    print("END INIT GEIGER STORAGE");
    //print('[REPLICATION] INIT GEIGER STORAGE');
    //WidgetsFlutterBinding.ensureInitialized();

    //await toolbox_api.StorageMapper.initDatabaseExpander();
    //_storageController = toolbox_api.GenericController('Cloud-Replication', toolbox_api.SqliteMapper('dbFileName.bd'));
    //return _storageController = toolbox_api.GenericController(
    //'Cloud-Replication', toolbox_api.DummyMapper('Cloud-Replication'));
    //return _storageController = storage;
  }

  Future<GeigerApi> _initGeigerApi() async {
    print("INIT GEIGER API");
    try {
      // LN: Due to the bug in the GeigerAPI, the internal plugin cannot see the Storage Event
      // We will try to initialize replication as an external plugin
      // When the bug has been fixed, we should reverse back to be an internal plugin
      _localMaster = (await getGeigerApi(
          _replicationAPI, GeigerApi.masterId, Declaration.doNotShareData))!;
      // _localMaster = (await getGeigerApi(
      //     "cloud_adapter", 'atos_replication_id', Declaration.doShareData))!;
      return _localMaster;
    } catch (e, s) {
      print("ERROR FROM GEIGERAPI: $e, Stack: $s");
      throw toolbox_api.StorageException("ERROR");
    }
  }

  // Register the External Plugin listener to listen all messages (events)
  // ignore: unused_element
  Future<bool> _registerListener() async {
    print("Plugin listener called");
    String id = _localMaster.id;
    if (_isPluginListenerRegistered == true) {
      print(
          'External Plugin ${_messageListener.hashCode} has been registered already!');
      return true;
    } else {
      if (_messageListener == null) {
        _messageListener = ReplicationMessageListener(id);
        print('External Plugin ${_messageListener.hashCode}');
      }
      try {
        // await _pluginAPI!
        //     .registerListener(handledEvents, pluginListener!); // This should be correct one
        _localMaster
            .registerListener([MessageType.allEvents], _messageListener!);
        _localMaster
            .registerListener([MessageType.registerPlugin], _messageListener!);
        print(
            'External Plugin ${_messageListener!.hashCode} has been registered and activated');
        _isPluginListenerRegistered = true;
        return true;
      } catch (e) {
        print('Failed to register listener');
        print(e.toString());
        return false;
      }
    }
  }

  // Dynamically define the handler for each message type
  void addMessageHandler(MessageType type, Function handler) {
    print("addMessageHandler called");
    String id = _localMaster.id;
    if (_messageListener == null) {
      _messageListener = ReplicationMessageListener(id);
      print('External PluginListener: ${_messageListener.hashCode}');
    }
    //don't have an idea all this line of code
    _handledEvents.add(type);
    //pass type and handler to addMessageHandler
    _messageListener!.addMessageHandler(type, handler);
  }

  // Send a simple message which contain only the message type to specific external plugin
  Future<bool> sendAMessageType(
      {required MessageType messageType,
      required String targetId,
      String? id,
      GeigerUrl? pluginUrl}) async {
    try {
      print('Trying to send a message type $messageType');
      Message? request;
      if (pluginUrl != null) {
        //plugin url
        request = Message(
          GeigerApi.masterId,
          targetId,
          messageType,
          pluginUrl,
        );
      } else {
        //toolbox ui url
        final GeigerUrl toolboxUrl =
            GeigerUrl.fromSpec('geiger://toolbox_ui/${id ?? ""}');
        request = Message(
            GeigerApi.masterId, targetId, messageType, toolboxUrl, null, id);
      }

      await _localMaster.sendMessage(request);
      print('A message type $messageType has been sent successfully');
      return true;
    } catch (e) {
      print('Failed to send a message type $messageType');
      print(e.toString());
      return false;
    }
  }

  /*
  * GET ANY NODE -> BASED ON THE PATH
  */
  Future<toolbox_api.Node> getNode(String path) async {
    ///print("GET TOOLBOX STORAGE NODE");
    // ToDo use try and cath to manage the response
    toolbox_api.Node node = await _storageController.get(path);
    return node;
  }

  // After replication ends, update with the compared time
  Future<void> updateReplicationNode(DateTime _actual) async {
    /// Should be defined a historic with all replication timestamps?
    /// Add type of replication into the node (full, partial)?
    try {
      //print('UPDATE REPLICATION NODE');
      toolbox_api.Node updateRepNode =
          await getNode(':Local:Replication:LastReplication');
      updateRepNode.lastModified = _actual.millisecondsSinceEpoch;
      await _storageController.update(updateRepNode);
    } catch (e) {
      //print('CREATE NEW REPLICATION NODE');
      toolbox_api.Node parentNode =
          toolbox_api.NodeImpl(':Local:Replication', _replicationAPI);
      await _storageController.addOrUpdate(parentNode);
      toolbox_api.Node newRepNode = toolbox_api.NodeImpl(
          ':Local:Replication:LastReplication', _replicationAPI);

      /// _storageController.add(newRepNode);
      newRepNode.lastModified = _actual.millisecondsSinceEpoch;
      await _storageController.addOrUpdate(newRepNode);
    }
    //print('[REPLICATION NODE] UPDATED');
  }

  Future<void> updateLocalNodeWithCloudNode(
      toolbox_api.Node eventNode, String username) async {
    print('UPDATE LOCAL NODE WITH CLOUD NODE');
    String _nodePath = eventNode.path;
    try {
      toolbox_api.Node inLocal = await getNode(_nodePath);
      //CHECK TIMESTAMP
      DateTime cloud =
          DateTime.fromMillisecondsSinceEpoch(eventNode.lastModified);
      DateTime local =
          DateTime.fromMillisecondsSinceEpoch(inLocal.lastModified);
      Duration _diff = local.difference(cloud);
      if (_diff.inMilliseconds <= 0 &&
          inLocal.owner != GeigerApi.masterId.toString()) {
        if (inLocal.path.toLowerCase().startsWith(":keys") == true) {
          print("KEY VALUE");

          /// KEYS WORK DIFFERENT WITH A SEARCH CRITERIA
          /// COMPARE PATHS && KEYS
          String _localKeyPath = '';
          try {
            _localKeyPath = await inLocal
                .getValue('path')
                .then((value) => value!.getValue("en").toString());
          } catch (e) {
            _localKeyPath = '';
          }
          String _cloudKeyPath = '';
          try {
            _cloudKeyPath = await eventNode
                .getValue('path')
                .then((value) => value!.getValue("en").toString());
          } catch (e) {
            _cloudKeyPath = '';
          }
          if (_cloudKeyPath.isNotEmpty &&
              _localKeyPath.isNotEmpty &&
              _cloudKeyPath != _localKeyPath) {
            print("KEY VALUE DO NOT MATCH");

            /// VALUE IS NOT THE SAME
            /// CREATE A NEW UUID
            String newUUID = Uuid().v4();
            String fullPath = eventNode.parentPath! + ':' + newUUID;
            toolbox_api.Node renamed =
                toolbox_api.NodeImpl(fullPath, eventNode.owner);
            toolbox_api.Visibility? checkerVisible =
                toolbox_api.VisibilityExtension.valueOf("amber");
            if (checkerVisible != null) {
              renamed.visibility = checkerVisible;
            }
            Map<String, toolbox_api.NodeValue> newValues =
                await eventNode.getValues();
            for (var entry in newValues.entries) {
              renamed.addOrUpdateValue(entry.value);
            }
            await _storageController.addOrUpdate(renamed);
          } else {
            print("PATH DO NOT MATCH");
            print(eventNode);
            await _storageController.addOrUpdate(eventNode);
          }
        } else {
          /// IF LOCAL EVENT HAS CHILDREN. GET AND UPDATE
          Map<String, toolbox_api.Node> children = await inLocal.getChildren();
          for (var child in children.entries) {
            print(child.value);
            eventNode.addChild(child.value);
          }
          await _storageController.addOrUpdate(eventNode);
        }
      } else {
        print(GeigerApi.masterId.toString());
      }
    } catch (e) {
      print('NODE NOT FOUND - CREATE ONE');
      eventNode.owner = username;
      await _storageController.add(eventNode);
    }
  }

  Future<void> updateLocalNodeWithNewNode(
      String path, toolbox_api.Node node, DateTime cloud) async {
    //print('CHECK NODES');
    try {
      toolbox_api.Node inLocal = await getNode(path);
      DateTime local =
          DateTime.fromMillisecondsSinceEpoch(inLocal.lastModified);
      Duration _diff = local.difference(cloud);
      if (_diff.inMilliseconds <= 0) {
        await _storageController.update(node);
      }
    } catch (e) {
      //print('NODE DO NOT EXIST - CREATE ONE');
      await _storageController.add(node);
    }
  }

  Future<void> updateTLPWhiteEvents(bool _fullRep, DateTime _fromDate) async {
    print("UPDATE TLP WHITE EVENTS");
    List<Event> freeEvents;
    // FILTER BY DATE
    if (_fullRep == true) {
      freeEvents = await cloud.getTLPWhiteEvents();
    } else {
      var filter =
          DateFormat("yyyy-MM-dd'T'hh:mm:ss.SSSS'Z'").format(_fromDate);
      freeEvents = await cloud.getTLPWhiteEventsDateFilter(filter.toString());
    }
    for (var free in freeEvents) {
      /// UUID WILL BE THE CLOUD ONE
      /// DATA MAY NOT COME FROM STORAGE AND USER ANOTHER UUID
      //String typeTLP = free.type.toString();
      String uuid = free.id_event;
      DateTime cloudTimestamp = DateTime.parse(free.last_modified.toString());
      if (free.content.toString().isNotEmpty) {
        try {
          ///var content = jsonDecode(free.content!);
          String nodePath = ':Global:$uuid';

          /// CHECK IF typeTLP node created
          try {
            // ignore: unused_local_variable
            toolbox_api.Node typeChecker = await getNode(':Global');
          } catch (e) {
            /// CREATE NODE FOR TYPE of TLP WHITE EVENT
            toolbox_api.Node typeChecker =
                toolbox_api.NodeImpl(':Global', free.owner.toString());
            toolbox_api.Visibility? checkerVisible =
                toolbox_api.VisibilityExtension.valueOf("white");
            if (checkerVisible != null) {
              typeChecker.visibility = checkerVisible;
            }
            await _storageController.add(typeChecker);
          }
          toolbox_api.Node newRepNode =
              toolbox_api.NodeImpl(nodePath, free.owner.toString());
          toolbox_api.Visibility? visible =
              toolbox_api.VisibilityExtension.valueOf(free.getTlp.toString());
          if (visible != null) {
            newRepNode.visibility = visible;
          }
          //LOOP ALL ELEMENTS
          //newRepNode.addOrUpdateValue(
          // toolbox_api.NodeValueImpl("tlpWHITE", free.content!));
          //await _storageController.update(newRepNode);
          Map<dynamic, dynamic> mapper = json.decode(free.content!);
          mapper.forEach((key, value) {
            newRepNode.addOrUpdateValue(
                toolbox_api.NodeValueImpl(key, value.toString()));
          });
          await updateLocalNodeWithNewNode(
              nodePath, newRepNode, cloudTimestamp);
        } catch (e) {
          //print("CONTENT TYPE NOT IN JSON FORMAT");
        }
      }
    }
  }

  @override
  Future<void> updateThreats() async {
    print('[UPDATE  GEIGER THREATS]');
    print("CHECK PARENT NODE: :GLOBAL:THREATS");
    try {
      // ignore: unused_local_variable
      toolbox_api.Node typeChecker = await getNode(':Global:threats');
    } catch (e) {
      /// CREATE NODE FOR TYPE of TLP WHITE EVENT
      toolbox_api.Node typeChecker =
          toolbox_api.NodeImpl(':Global:threats', _replicationAPI);
      toolbox_api.Visibility? checkerVisible =
          toolbox_api.VisibilityExtension.valueOf("white");
      if (checkerVisible != null) {
        typeChecker.visibility = checkerVisible;
      }
      await _storageController.add(typeChecker);
    }
    List<Threats> threats = await cloud.getThreats();
    for (var threat in threats) {
      String? uuid = threat.getUuid;
      String? name = threat.getName;
      String? value = threat.getThreat;
      try {
        toolbox_api.Node compare = await getNode(':Global:threats:$uuid');
        compare.addOrUpdateValue(toolbox_api.NodeValueImpl('name', name!));
        compare.addOrUpdateValue(
            toolbox_api.NodeValueImpl('GEIGER_threat', value!));
        await _storageController.addOrUpdate(compare);
      } catch (e) {
        toolbox_api.Node compare =
            toolbox_api.NodeImpl(':Global:threats:$uuid', _replicationAPI);
        compare.addOrUpdateValue(toolbox_api.NodeValueImpl('name', name!));
        compare.addOrUpdateValue(
            toolbox_api.NodeValueImpl('GEIGER_threat', value!));
        await _storageController.addOrUpdate(compare);
      }
    }
  }

  /// STORE :Global:threats
  @override
  Future<void> updateThreatWeights() async {
    print('[UPDATE THREAT WEIGHTS]');
    print("CHECK PARENT NODE: :GLOBAL:PROFILES");
    try {
      // ignore: unused_local_variable
      toolbox_api.Node profileChecker = await getNode(':Global:profiles');
    } catch (e) {
      /// CREATE NODE FOR TYPE of TLP WHITE EVENT
      toolbox_api.Node profileChecker =
          toolbox_api.NodeImpl(':Global:profiles', _replicationAPI);
      toolbox_api.Visibility? checkerVisible =
          toolbox_api.VisibilityExtension.valueOf("white");
      if (checkerVisible != null) {
        profileChecker.visibility = checkerVisible;
      }
      await _storageController.add(profileChecker);
    }

    print(
        "CHECK PARENT NODES SUBNODE - DIGITALLY DEPENDENT, DIGITALLY BASED, DIGITAL ENABLER");
    List<String> profiles = [
      "digitally dependent",
      "digitally based",
      "digitally enabler"
    ];
    List<toolbox_api.Node> profileNodes = [];
    for (var profile in profiles) {
      /// search criteria for each profile
      toolbox_api.SearchCriteria profileCriteria = toolbox_api.SearchCriteria(
          searchPath: ':Global:profiles:', key: 'name', value: profile);
      List<toolbox_api.Node> scProf =
          await _storageController.search(profileCriteria);
      if (scProf.isNotEmpty) {
        profileNodes.add(scProf[0]);
      } else {
        /// CREATE NEW
        String newUUID = Uuid().v4();
        toolbox_api.Node newProfile =
            toolbox_api.NodeImpl(':Global:profiles:$newUUID', _replicationAPI);
        newProfile.addOrUpdateValue(toolbox_api.NodeValueImpl('name', profile));
        await _storageController.add(newProfile);
        profileNodes.add(newProfile);
      }
    }
    List<ThreatWeights> weights = await cloud.getThreatWeights();
    for (var weight in weights) {
      ThreatDict? data = weight.threatDict;
      if (data != null) {
        Map<String, dynamic> mapper = data.toJson();
        for (var d in mapper.entries) {
          String key = d.key;
          List<double> value = d.value;
          //mapper.forEach((key, value) async {
          toolbox_api.SearchCriteria criteria = toolbox_api.SearchCriteria(
              searchPath: ':Global:threats:',
              key: 'GEIGER_threat',
              value: '${key[0].toUpperCase()}${key.substring(1)}');
          List<toolbox_api.Node> scNode =
              await _storageController.search(criteria);
          List<double> val = value;
          String path;
          if (scNode.isNotEmpty) {
            for (var element in scNode) {
              toolbox_api.Node newThreat = element;
              path = newThreat.name;
              toolbox_api.NodeValue? nameVal =
                  (await newThreat.getValue('name'));
              toolbox_api.NodeValue? threatVal =
                  (await newThreat.getValue('GEIGER_threat'));
              if (nameVal!.value == threatVal!.value) {
                int i = 0;
                for (var v in val) {
                  profileNodes[i].addOrUpdateValue(
                      toolbox_api.NodeValueImpl(path, v.toString()));
                  i++;
                }
              }
            }
          }
        }
        //});
      }
    }

    /// store updated nodes in toolbox
    print("STORE/UPDATE PROFILE NODES");
    for (var node in profileNodes) {
      await _storageController.addOrUpdate(node);
    }
  }

  @override
  Future<void> updateRecommendations() async {
    print('UPDATE RECOMMENDATIONS');
    try {
      // ignore: unused_local_variable
      toolbox_api.Node typeChecker = await getNode(':Global:Recommendations');
    } catch (e) {
      /// CREATE NODE FOR TYPE of TLP WHITE EVENT
      toolbox_api.Node typeChecker =
          toolbox_api.NodeImpl(':Global:Recommendations', _replicationAPI);
      toolbox_api.Visibility? checkerVisible =
          toolbox_api.VisibilityExtension.valueOf("white");
      if (checkerVisible != null) {
        typeChecker.visibility = checkerVisible;
      }
      await _storageController.add(typeChecker);
    }
    List<Recommendation> recommendations = await cloud.getRecommendations();
    for (var rec in recommendations) {
      String? id = rec.getId;
      if (id != null) {
        try {
          toolbox_api.Node checker =
              await getNode(':Global:Recommendations:$id');
          Map<String, dynamic> mapper = rec.toJson();
          for (var r in mapper.entries) {
            if (r.key != "relatedThreatsWeights" && r.key != "Steps") {
              checker.addOrUpdateValue(
                  toolbox_api.NodeValueImpl(r.key, r.value.toString()));
            } else {
              if (r.key == "Steps") {
                String toAdd = "";
                List<String> steps = r.value;
                for (var step in steps) {
                  if (toAdd.isEmpty) {
                    toAdd = toAdd + "[" + '"' + step + '"';
                  } else {
                    toAdd = toAdd + "," + '"' + step + '"';
                  }
                }
                toAdd = toAdd + "]";
                checker
                    .addOrUpdateValue(toolbox_api.NodeValueImpl(r.key, toAdd));
              }
              if (r.key == "relatedThreatsWeights") {
                /// IF RELATED THREATS WEIGHTS
                /// SEARCH CRITERIA TO GET NODE ID FOR KEY VALUE
                String data = "";
                List<String> related = r.value;
                List<String> splitted = related[0].split(",");
                for (var split in splitted) {
                  try {
                    List<String> splitThreat = split.split(":");
                    String threat = splitThreat[0].trim();
                    String threatValue = splitThreat[1].trim();
                    toolbox_api.SearchCriteria profileCriteria =
                        toolbox_api.SearchCriteria(
                            searchPath: ':Global:threats:',
                            key: 'GEIGER_threat',
                            value: threat);
                    List<toolbox_api.Node> scProf =
                        await _storageController.search(profileCriteria);
                    if (scProf.isNotEmpty) {
                      for (var element in scProf) {
                        toolbox_api.Node threatNode = element;
                        String uuid = threatNode.name;
                        toolbox_api.NodeValue? nameVal =
                            (await threatNode.getValue('name'));
                        toolbox_api.NodeValue? threatVal =
                            (await threatNode.getValue('GEIGER_threat'));
                        if (nameVal!.value == threatVal!.value) {
                          if (data.isEmpty == true) {
                            data = data + uuid + "," + threatValue;
                          } else {
                            data = data + ";" + uuid + "," + threatValue;
                          }
                        }
                      }
                    }
                  } catch (e) {
                    print("EXCEPTION GETTING RECOMMENDATIONS THREAT WEIGHTS");
                  }
                }
                checker
                    .addOrUpdateValue(toolbox_api.NodeValueImpl(r.key, data));
              }
            }
          }
          await _storageController.addOrUpdate(checker);
        } catch (e) {
          toolbox_api.Node newThreatNode = toolbox_api.NodeImpl(
              ':Global:Recommendations:$id', _replicationAPI);
          toolbox_api.Visibility? visible =
              toolbox_api.VisibilityExtension.valueOf("white");
          if (visible != null) {
            newThreatNode.visibility = visible;
          }
          Map<String, dynamic> mapper = rec.toJson();
          for (var r in mapper.entries) {
            if (r.key != "relatedThreatsWeights" && r.key != "Steps") {
              newThreatNode.addOrUpdateValue(
                  toolbox_api.NodeValueImpl(r.key, r.value.toString()));
            } else {
              if (r.key == "Steps") {
                String toAdd = "";
                List<String> steps = r.value;
                for (var step in steps) {
                  if (toAdd.isEmpty) {
                    toAdd = toAdd + "[" + '"' + step + '"';
                  } else {
                    toAdd = toAdd + "," + '"' + step + '"';
                  }
                }
                toAdd = toAdd + "]";
                newThreatNode
                    .addOrUpdateValue(toolbox_api.NodeValueImpl(r.key, toAdd));
              }
              if (r.key == "relatedThreatsWeights") {
                /// IF RELATED THREATS WEIGHTS
                /// SEARCH CRITERIA TO GET NODE ID FOR KEY VALUE
                String data = "";
                List<String> related = r.value;
                List<String> splitted = related[0].split(",");
                for (var split in splitted) {
                  try {
                    List<String> splitThreat = split.split(":");
                    String threat = splitThreat[0].trim();
                    String threatValue = splitThreat[1].trim();
                    toolbox_api.SearchCriteria profileCriteria =
                        toolbox_api.SearchCriteria(
                            searchPath: ':Global:threats:',
                            key: 'GEIGER_threat',
                            value: threat);
                    List<toolbox_api.Node> scProf =
                        await _storageController.search(profileCriteria);
                    if (scProf.isNotEmpty) {
                      for (var element in scProf) {
                        toolbox_api.Node threatNode = element;
                        String uuid = threatNode.name;
                        toolbox_api.NodeValue? nameVal =
                            (await threatNode.getValue('name'));
                        toolbox_api.NodeValue? threatVal =
                            (await threatNode.getValue('GEIGER_threat'));
                        if (nameVal!.value == threatVal!.value) {
                          if (data.isEmpty == true) {
                            data = data + uuid + "," + threatValue;
                          } else {
                            data = data + ";" + uuid + "," + threatValue;
                          }
                        }
                      }
                    }
                  } catch (e) {
                    print("EXCEPTION GETTING RECOMMENDATIONS THREAT WEIGHTS");
                  }
                }
                newThreatNode
                    .addOrUpdateValue(toolbox_api.NodeValueImpl(r.key, data));
              }
            }
          }
          await _storageController.addOrUpdate(newThreatNode);
        }
      }
    }
  }

  Future<List<toolbox_api.Node>> getAllNodes() async {
    print("GET ALL NODES IN A RECURSIVE WAY");
    List<toolbox_api.Node> nodeList = [];
    try {
      toolbox_api.Node root1 = await getNode(':Devices');
      await getRecursiveNodes(root1, nodeList);
      toolbox_api.Node root2 = await getNode(':Users');
      await getRecursiveNodes(root2, nodeList);
      toolbox_api.Node root3 = await getNode(':Keys');
      await getRecursiveNodes(root3, nodeList);
      toolbox_api.Node root4 = await getNode(':Enterprise');
      await getRecursiveNodes(root4, nodeList);
    } catch (e) {
      print(e);
    }
    return nodeList;
  }

  Future<List<toolbox_api.Node>> getRecursiveNodes(
      toolbox_api.Node node, List<toolbox_api.Node> list) async {
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
        list = await getRecursiveNodes(value, list);
      }
    }
    return list;
  }

  Future<List<toolbox_api.Node>> getAllNodesLastModified(
      DateTime filter) async {
    String lastModified = filter.millisecondsSinceEpoch.toString();
    toolbox_api.SearchCriteria criteria =
        toolbox_api.SearchCriteria(nodeValueLastModified: lastModified);
    List<toolbox_api.Node> nodeList = [];
    List<toolbox_api.Node> preNodeList =
        await _storageController.search(criteria);
    for (var node in preNodeList) {
      String dataPath = node.path.toString();
      if (dataPath != ":" &&
          dataPath != ":Users" &&
          dataPath != ":Devices" &&
          dataPath != ":Enterprise" &&
          dataPath != ":Keys" &&
          dataPath != ":Global" &&
          dataPath != ":Local") {
        print("NODE THAT CAN BE ADDED");
        nodeList.add(node);
      }
    }
    return nodeList;
  }

  Future<void> cleanData(DateTime actual) async {
    print('TIMING STRATEGY - REMOVE DATA - 180 DAYS LIMIT');

    /// COMPLETE
    /// RECURSIVE WAY
    /// CHECK TIMESTAMP > 180 DAYS: DELETE
    List<toolbox_api.Node> checkingData = await getAllNodes();

    /// SORT NODES BY TIMESTAMP
    checkingData.sort((a, b) =>
        a.lastModified.toString().compareTo(b.lastModified.toString()));
    for (var node in checkingData) {
      DateTime nodeTime =
          DateTime.fromMillisecondsSinceEpoch(node.lastModified);
      Duration checker = actual.difference(nodeTime);
      if (checker.inDays > 180) {
        //REPLICATION TIMING STRATEGIES - DELETE NODE
        String path = node.path.toString();
        await _storageController.delete(path);
        print('NODE WITH PATH $path HAS BEEN REMOVED');
      }
    }
  }

  @override
  Future<bool> checkConsent(toolbox_api.Node node, String username) async {
    bool consent = false;

    /// BY DEFAULT
    /// GET CONSENT NODE
    /// IF NOT - ASK AND CREATE
    try {
      //IF GET NODE - USER HAS NOT AGREED FOREVER - CONSENT FALSE
      toolbox_api.Node consentNode = await getNode(':Local:Consent:$username');
      String consentValue = await consentNode
          .getValue('consent')
          .then((value) => value!.getValue("en").toString());
      if (consentValue == 'no_forever') {
        consent = false;
      } else if (consentValue == 'no_once' || consentValue == "once") {}
    } catch (e) {
      print("CONSENT NODE NOT FOUND. CREATE CONSENT PARENT NODE");
      toolbox_api.Node consentNode =
          toolbox_api.NodeImpl(':Local:Consent', _replicationAPI);
      await _storageController.add(consentNode);

      /// SEND MESSAGE
      /*GeigerUrl? url;
      try {
        url = GeigerUrl(null, GeigerApi.masterId, 'geiger://plugin/path');
      } catch (e) {
        print(e);
      }
      MessageType messageType = MessageType.storageEvent;
      Message message = Message('ReplicationController', 'uiId', messageType, url);
      await _localMaster.sendMessage(message);*/
      toolbox_api.Node userConsent =
          toolbox_api.NodeImpl(':Local:Consent:$username', _replicationAPI);
      userConsent.addOrUpdateValue(
          toolbox_api.NodeValueImpl("consent", 'consentData'));
      if ('consentData' == 'no_forever') {
        consent = false;
      } else if ('consentData' == 'no_once' || 'consentData' == 'once') {
        toolbox_api.Visibility? visible =
            toolbox_api.VisibilityExtension.valueOf("red");
        if (visible != null) {
          userConsent.visibility = visible;
        }
        if ('consentData' == 'once') {
          consent = true;
        } else {
          consent = false;
        }
      } else {
        print("CONSENT VALUE DOES NOT MATCH");

        /// throw ReplicationException("NOT MATCH CONSENT VALUE");
      }
      await _storageController.add(userConsent);
    }
    return consent;

    /*String tlp = node.visibility.toValueString();
    if (tlp.toLowerCase() == 'white') {
      consent = true;
    } else {
      //CHECK CONSENT
      try {
        //IF GET NODE - USER HAS NOT AGREED FOREVER - CONSENT FALSE
        toolbox_api.Node consentNode = await getNode(':Local:Consent:$username');
        String consentValue = await consentNode
          .getValue('consent')
          .then((value) => value!.getValue("en").toString());
        if (consentValue=='no_forever') {
          return false;
        } else if(consentValue == 'no_once' || consentValue == "once") {
          /// If doen't agree once
          /// ASK AGAIN
          String consentData = "";
          consentNode.addOrUpdateValue(toolbox_api.NodeValueImpl("consent", consentData));
          await _storageController.addOrUpdate(consentNode);
          if (consentValue == 'no_forever') {
            return false;
          } else if(consentValue == 'no_once' || consentValue == 'once') {
            toolbox_api.Visibility? visible =
              toolbox_api.VisibilityExtension.valueOf("red");
            if (visible != null) {
              node.visibility = visible;
            }
            await _storageController.update(node);
            if (consentValue == 'once') {
              return true;
            } else {
              return false;
            }
          } else {
            throw ReplicationException("NOT MATCH CONSENT VALUE");
          }
        } else {
          throw ReplicationException("NOT MATCH CONSENT VALUE");
        }
      } catch (e) {
        print("CONSENT NODE NOT FOUND");
        /// CREATE PARENT CONSENT NODE
        toolbox_api.Node consentNode = toolbox_api.NodeImpl(':Local:Consent','ReplicationController');
        await _storageController.addOrUpdate(consentNode);
        String consentData = "";
        toolbox_api.Node userConsent = toolbox_api.NodeImpl(':Local:Consent:$username','ReplicationController');
        userConsent.addOrUpdateValue(toolbox_api.NodeValueImpl("consent", consentData));
        await _storageController.addOrUpdate(userConsent);
        if (consentData == 'no_forever') {
          return false;
        } else if(consentData == 'no_once' || consentData == 'once') {
          toolbox_api.Visibility? visible =
            toolbox_api.VisibilityExtension.valueOf("red");
          if (visible != null) {
            node.visibility = visible;
          }
          await _storageController.update(node);
          if (consentData == 'once') {
            return true;
          } else {
            return false;
          }
        } else {
          throw ReplicationException("NOT MATCH CONSENT VALUE");
        }
      }
    }
    return consent;*/
  }

  /// if a user receives a shared event but with a different owner
  /// checks pairing
  Future<void> updatePairedEvent(String username, Event event) async {
    try {
      String owner = event.owner.toString();
      toolbox_api.Node node = await getNode(':Local:Pairing:$owner');
      String encryptedKey = node.getValue('key').toString();
      String agreeValue = node.getValue('agreement').toString();
      if (agreeValue == 'in' || agreeValue == 'both') {
        try {
          List<String> agreements = await cloud.getMergedAccounts(username);
          if (agreements.contains(owner) == true) {
            /// check if our user has publicKey
            /// else the key will be clear
            User actualUser = await cloud.getUser(username);
            var publicKey = actualUser.getPublicKey;
            if (publicKey != null) {
              publicKey = publicKey.toString();

              final keyVal = Enc.Key.fromUtf8(publicKey);
              final enc =
                  Enc.Encrypter(Enc.AES(keyVal, mode: Enc.AESMode.cfb64));
              final iv = Enc.IV.fromLength(16);
              //DECRYPT DATA
              encryptedKey = enc
                  .decrypt(encryptedKey.split(':')[1] as Enc.Encrypted, iv: iv);
            } else {
              encryptedKey = encryptedKey.split(':')[1];
            }

            /// DECRYPT CONTENT AND SET NEW NODE
            final keyVal1 = Enc.Key.fromUtf8(encryptedKey);
            final enc1 =
                Enc.Encrypter(Enc.AES(keyVal1, mode: Enc.AESMode.cfb64));
            final iv1 = Enc.IV.fromLength(16);
            //DECRYPT DATA
            var data = enc1.decrypt(event.content.toString() as Enc.Encrypted,
                iv: iv1);

            /// CREATE NODE
            toolbox_api.Node newSharedNode = convertJsonStringToNode(data);
            toolbox_api.Visibility? visible =
                toolbox_api.VisibilityExtension.valueOf(
                    event.getTlp.toString());
            if (visible != null) {
              newSharedNode.visibility = visible;
            }
            _storageController.update(newSharedNode);
          }
        } catch (e) {
          throw CloudException('There is no active cloud agreement');
        }
      }
    } catch (e) {
      throw toolbox_api.StorageException('No pairing node set up');
    }
  }

  toolbox_api.Node convertJsonStringToNode(String content) {
    /// convert string event content to Json
    print("CONVERT JSON TO NODE");
    print(content);
    try {
      Map<String, dynamic> mapper = jsonDecode(content);
      var path = mapper['path'];
      var owner = mapper['owner'];
      var visibility = mapper['visibility'];
      var lastModified = mapper['lastModified'];
      //var name = mapper['name'];
      //var parentPath = mapper['parentPath'];
      //var extendedLastModified = mapper['extendedLastModified'];
      //var tombstone = mapper['tombstone'];
      toolbox_api.Node node = toolbox_api.NodeImpl(path, owner);
      toolbox_api.Visibility? checkerVisible =
          toolbox_api.VisibilityExtension.valueOf(visibility);
      if (checkerVisible != null) {
        node.visibility = checkerVisible;
      }
      node.lastModified = lastModified;
      if (mapper['custom_fields'] != '[]') {
        List customFields = ((mapper['custom_fields']));
        if (customFields.isNotEmpty) {
          for (var custom in customFields) {
            var key = custom['key'];
            var value = custom['value'];
            var nodeDescription = custom['nodeDescription'];
            var valueTranslations = custom['valueTranslations'];
            var descriptionTranslations = custom['descriptionTranslations'];
            toolbox_api.NodeValue nodeValue =
                toolbox_api.NodeValueImpl(key, value.toString());
            for (var translation in valueTranslations) {
              var tr = translation['value'];
              if (tr != null && tr != "") {
                nodeValue.setValue(translation['value'],
                    Locale.fromSubtags(languageCode: translation['key']));
              }
            }
            if (nodeDescription != null) {
              nodeValue.setDescription(nodeDescription);
              for (var description in descriptionTranslations) {
                var dr = description['value'];
                if (dr != null && dr != "") {
                  nodeValue.setValue(description['value'],
                      Locale.fromSubtags(languageCode: description['key']));
                }
              }
            }
            node.addOrUpdateValue(nodeValue);
          }
        }
      }
      return node;
    } catch (e) {
      print(e);
      throw ReplicationException(
          "[REPLICATION EXCEPTION] FAIL PASSING EVENT JSON STRING CONTENT TYPE TO NODE");
    }
  }

  Map<dynamic, dynamic> getPartialJsonString(String content) {
    print("GET PARTIAL DATA");
    try {
      Map<String, dynamic> mapper = jsonDecode(content);
      var path = mapper['path'];
      var owner = mapper['owner'];
      var visibility = mapper['visibility'];
      var lastModified = mapper['lastModified'];
      var name = mapper['name'];
      var parentPath = mapper['parentPath'];
      var extendedLastModified = mapper['extendedLastModified'];
      var tombstone = mapper['tombstone'];
      var converted = {};
      converted['name'] = name;
      converted['parentPath'] = parentPath;
      converted['path'] = path;
      converted['owner'] = owner;
      converted['visibility'] = visibility;
      converted['lastModified'] = lastModified;
      converted['extendedLastModified'] = extendedLastModified;
      converted['tombstone'] = tombstone;
      return converted;
    } catch (e) {
      print(e);
      throw ReplicationException(
          "[REPLICATION EXCEPTION] FAIL GETTING EVENT JSON STRING CONTENT TYPE TO SHORT EVENT");
    }
  }

  Future<Map<dynamic, dynamic>> convertNodeToJsonString(
      toolbox_api.Node node) async {
    print("CONVERT NODE TO JSON");
    try {
      var converted = {};

      /// CONVERT VALUES
      converted['name'] = node.name;
      converted['parentPath'] = node.parentPath;
      converted['path'] = node.path;
      converted['owner'] = node.owner;
      converted['visibility'] = node.visibility.toValueString();
      converted['lastModified'] = node.lastModified;
      converted['extendedLastModified'] = node.extendedLastModified;
      converted['tombstone'] = node.tombstone;
      converted['custom_fields'] = [];
      Map<String, toolbox_api.NodeValue> mapper = await node.getValues();
      mapper.forEach((key, value) {
        toolbox_api.NodeValue nodeValue = value;
        var loop = {};
        loop['key'] = nodeValue.key;
        loop['value'] = nodeValue.value;
        loop['valueTranslations'] = [];

        Map<Locale, String> valueTranslations = nodeValue.allValueTranslations;
        valueTranslations.forEach((key, value) {
          var valueT = {};
          valueT['key'] = key.toString();
          valueT['value'] = value;
          loop['valueTranslations'].add(valueT);
        });

        loop['nodeDescription'] = nodeValue.getDescription();
        loop['descriptionTranslations'] = [];
        if (nodeValue.getDescription() != null) {
          Map<Locale, String> descriptionTranslations =
              nodeValue.allDescriptionTranslations;
          descriptionTranslations.forEach((key, value) {
            var valueT = {};
            valueT['key'] = key.toString();
            valueT['value'] = value;
            loop['descriptionTranslations'].add(valueT);
          });
        }
        converted['custom_fields'].add(loop);
      });
      //String stringConverted = json.encode(converted);
      return converted;
    } catch (e) {
      print(e);
      throw ReplicationException(
          "[REPLICATION EXCEPTION] FAIL CONVERT NODE TO JSON STRING");
    }
  }

  /// *******************************
  /// UTILS METHOD
  /// *******************************

  /// CHECKS IF THE PARENT NODE IS CREATED
  /// IF NOT CREATES PARENT NODE IN A RECURSIVE WAY
  Future<bool> checkParents(String path) async {
    print("CHECK PARENTS NODE");
    bool exist = false;
    //PATH MUST BE SPLITTED BY ':'
    List<String> splittedPath = path.split(':');
    String createPath = '';
    for (var p in splittedPath) {
      /// GET NODE - IF EXISTS - GO TO NEXT
      /// ELSE - CREATE NODE
      if (p.isNotEmpty) {
        createPath = createPath + ':' + p;
        try {
          // ignore: unused_local_variable
          toolbox_api.Node nodeChecker = await getNode(createPath);
        } catch (e) {
          toolbox_api.Node parentNode =
              toolbox_api.NodeImpl(createPath, _pluginAPI);
          toolbox_api.Visibility? checkerVisible =
              toolbox_api.VisibilityExtension.valueOf("amber");
          if (checkerVisible != null) {
            parentNode.visibility = checkerVisible;
          }
          try {
            await _storageController.addOrUpdate(parentNode);
            print(createPath);
          } catch (e) {
            print(e);
            exist = false;
            return exist;
          }
        }
      }
    }
    exist = true;
    return exist;
  }

  @override
  Future<void> endGeigerStorage() async {
    flushGeigerApiCache();
    await _localMaster.zapState();
    await _localMaster.close();
  }

  @override
  Future<void> updateSecurityDefendersInfo() async {
    //FIRST GET ALL SECURITY DEFENDERS ORGANIZATION
    List<SecurityDefendersOrganization> orgs =
        await cloud.getSecurityDefendersOrganizations();
    for (var org in orgs) {
      //CREATE A SEARCH CRITERIA TO SEE IF COUNTRY DOES EXIST
      String? country = org.location;
      String? id = org.idOrg;
      String? name = org.name;

      if (country != null && id != null) {
        toolbox_api.SearchCriteria criteria = toolbox_api.SearchCriteria(
            searchPath: ':Global:location', value: country);
        List<toolbox_api.Node> nodes =
            await _storageController.search(criteria);
        if (nodes.isEmpty) {
          //NEED TO CREATE COUNTRY
          toolbox_api.Node newCountry = toolbox_api.NodeImpl(
              ':Global:location:' + country, _replicationAPI);
          newCountry
              .addOrUpdateValue(toolbox_api.NodeValueImpl('name', country));
          await _storageController.addOrUpdate(newCountry);
        }
      }
      if (name != null) {
        try {
          // ignore: unused_local_variable
          toolbox_api.Node o =
              await getNode(':Global:securityDefendersOrganizations:' + id!);
        } catch (e) {
          //CREATE NODE
          toolbox_api.Node newOrg = toolbox_api.NodeImpl(
              ':Global:securityDefendersOrganizations:' + id!, _replicationAPI);
          newOrg.addOrUpdateValue(toolbox_api.NodeValueImpl('name', name));
          newOrg.addOrUpdateValue(
              toolbox_api.NodeValueImpl('location', country!));
          await _storageController.addOrUpdate(newOrg);
        }
      }

      //FOR EACH ORG - GET USERS
      List<String> uuids =
          await cloud.getSecurityDefendersOrganizationUsers(id!);
      for (var uuid in uuids) {
        SecurityDefenderUser user =
            await cloud.getSecurityDefenderUser(id, uuid);
        //ADD OR UPDATE
        toolbox_api.Node n = toolbox_api.NodeImpl(
            ':Global:securityDefenders:' + user.id_user!, _replicationAPI);
        n.addOrUpdateValue(toolbox_api.NodeValueImpl('name', user.name!));
        n.addOrUpdateValue(
            toolbox_api.NodeValueImpl('firstname', user.firstname!));
        n.addOrUpdateValue(
            toolbox_api.NodeValueImpl('affiliation', user.affiliation!));
        n.addOrUpdateValue(toolbox_api.NodeValueImpl('phone', user.phone!));
        n.addOrUpdateValue(toolbox_api.NodeValueImpl('email', user.email!));
        n.addOrUpdateValue(toolbox_api.NodeValueImpl('title', user.title!));
        n.addOrUpdateValue(toolbox_api.NodeValueImpl('picture', ''));
        await _storageController.addOrUpdate(n);
      }
    }
  }

  @override
  Future<void> geigerReplicationListener(
      deleteHandler, createHandler, updateHandler, renameHandler) async {
    try {
      userEvents = await cloud.getUserEvents(_username);
      //List<toolbox_api.Node> nodeList = [];
      //cloudEvents
      //nodeList.addAll(await getAllNodes());
      for (var cloudEvent in userEvents) {
        try {
          Event newCloudEvent =
              await cloud.getSingleUserEvent(_username, cloudEvent);
          Map<dynamic, dynamic> data =
              getPartialJsonString(newCloudEvent.content!);

          if (userEvents.contains(cloudEvent) == false) {
            userEvents.add(cloudEvent);
            cloudEvents.add(newCloudEvent);
            cloudNodeList.add(data);
            cloudNodePath.add(data['path']);
          } else {
            /// CHECK TIMESTAMP
            if (!cloudEvents.isEmpty) {
              int index = userEvents.indexOf(cloudEvent);
              Event toCompare = cloudEvents[index];
              DateTime? evToCompare = toCompare.last_modified;
              DateTime? newTime = newCloudEvent.last_modified;
              //AS IN CLOUD, COMPARE DATETIMES
              Duration _diff = newTime!.difference(evToCompare!);
              if (_diff.inDays > 0) {
                userEvents[index] = cloudEvent;
                cloudNodeList[index] = (data);
                cloudNodePath[index] = (data['path']);
                cloudEvents[index] = newCloudEvent;
              }
            }
          }
        } catch (e) {
          print("ERROR GETTING SINGLE USER EVENT");
        }
      }
    } catch (e) {
      print("ERROR GETTING CLOUD USER EVENTS");
    }

    ///ALL ABOUT LISTENER
    toolbox_api.SearchCriteria sc = toolbox_api.SearchCriteria();
    NodeListener stListener = NodeListener();

    stListener.addEventHandler(toolbox_api.EventType.delete, deleteHandler);
    stListener.addEventHandler(toolbox_api.EventType.create, createHandler!);
    stListener.addEventHandler(toolbox_api.EventType.update, updateHandler!);
    stListener.addEventHandler(toolbox_api.EventType.rename, renameHandler!);
    await _storageController.registerChangeListener(stListener, sc);
  }

  @override
  Future<void> renameHanlder(EventChange event) async {
    print("RENAME HANDLER");
    String eType = event.type.toValueString();
    print("STORAGE LISTENER EVENT TYPE: $eType");
    toolbox_api.Node? oldNode = event.getOldNode;
    String oldPath = oldNode!.path;
    toolbox_api.Node? newNode = event.getNewNode;
    String tlp = newNode!.visibility.toValueString();
    if (tlp.toLowerCase() != 'black' &&
        newNode.path.startsWith(':Local') == false &&
        newNode.path.startsWith(':Global') == false &&
        newNode.tombstone == false) {
      if (cloudNodePath.contains(oldPath)) {
        int index = cloudNodePath.indexOf(oldPath);
        String cloudId = userEvents[index];
        Event toCheck = await cloud.getSingleUserEvent(_username, cloudId);
        if (tlp.toLowerCase() == 'red') {
          try {
            Map<dynamic, dynamic> encryptedNode =
                await encryptListenerCloudData(newNode);
            toCheck.content = json.encode(encryptedNode);
          } catch (e) {
            print(e);
            toCheck.content =
                json.encode(await convertNodeToJsonString(newNode));
            print('FAILURE GETTING KEYS');
          }
          toCheck.type = 'user_object';
        } else {
          toCheck.type = 'keyvalue';
          toCheck.content = json.encode(await convertNodeToJsonString(newNode));
        }
        toCheck.owner = _username;
        print("RENAME HANDLER - UPDATE NODE TO THE CLOUD");
        await cloud.updateEvent(_username, toCheck.id_event, toCheck);
        cloudNodePath[index] = newNode.path;
      } else {
        String uuid = await cloud.generateUUID();
        Event toCheck = Event(id_event: uuid, tlp: tlp.toUpperCase());
        toCheck.encoding = 'ascii';
        if (tlp.toLowerCase() == 'red') {
          try {
            Map<dynamic, dynamic> encryptedNode =
                await encryptListenerCloudData(newNode);
            toCheck.content = json.encode(encryptedNode);
          } catch (e) {
            print(e);
            toCheck.content =
                json.encode(await convertNodeToJsonString(newNode));
            print('FAILURE GETTING KEYS');
          }
          toCheck.type = 'user_object';
        } else {
          toCheck.type = 'keyvalue';
          toCheck.content = json.encode(await convertNodeToJsonString(newNode));
        }
        toCheck.owner = _username;
        print("RENAME HANDLER - ADD NODE TO THE CLOUD");
        await cloud.createEvent(_username, toCheck);
        cloudNodePath.add(newNode.path);
        userEvents.add(uuid);
        cloudEvents.add(toCheck);
        cloudNodeList.add(await convertNodeToJsonString(newNode));
      }
    }
    print("END RENAME HANDLER");
  }

  @override
  Future<void> updateHanlder(EventChange event) async {
    print("UPDATE HANDLER");
    String eType = event.type.toValueString();
    print("STORAGE LISTENER EVENT TYPE: $eType");
    toolbox_api.Node? newNode = event.getNewNode;
    String tlp = newNode!.visibility.toValueString();
    String fullPath = newNode.path;
    if (tlp.toLowerCase() != 'black' &&
        newNode.path.startsWith(':Local') == false &&
        newNode.path.startsWith(':Global') == false &&
        newNode.tombstone == false) {
      if (cloudNodePath.contains(fullPath)) {
        int index = cloudNodePath.indexOf(fullPath);
        String cloudId = userEvents[index];
        Event toCheck = await cloud.getSingleUserEvent(_username, cloudId);
        toCheck.encoding = 'ascii';
        if (tlp.toLowerCase() == 'red') {
          try {
            Map<dynamic, dynamic> encryptedNode =
                await encryptListenerCloudData(newNode);
            toCheck.content = json.encode(encryptedNode);
          } catch (e) {
            print(e);
            toCheck.content =
                json.encode(await convertNodeToJsonString(newNode));
            print('FAILURE GETTING KEYS');
          }
          toCheck.type = 'user_object';
        } else {
          toCheck.type = 'keyvalue';
          toCheck.content = json.encode(await convertNodeToJsonString(newNode));
        }
        toCheck.owner = _username;
        print("UPDATE HANDLER - UPDATE NODE TO THE CLOUD");
        await cloud.updateEvent(_username, toCheck.id_event, toCheck);
      } else {
        String uuid = await cloud.generateUUID();
        Event toCheck = Event(id_event: uuid, tlp: tlp.toUpperCase());
        toCheck.encoding = 'ascii';
        if (tlp.toLowerCase() == 'red') {
          try {
            Map<dynamic, dynamic> encryptedNode =
                await encryptListenerCloudData(newNode);
            toCheck.content = json.encode(encryptedNode);
          } catch (e) {
            print(e);
            toCheck.content =
                json.encode(await convertNodeToJsonString(newNode));
            print('FAILURE GETTING KEYS');
          }
          toCheck.type = 'user_object';
        } else {
          toCheck.type = 'keyvalue';
          toCheck.content = json.encode(await convertNodeToJsonString(newNode));
        }
        toCheck.owner = _username;
        print("CREATE HANDLER - ADD NODE TO THE CLOUD");
        await cloud.createEvent(_username, toCheck);
        cloudNodePath.add(newNode.path);
        userEvents.add(uuid);
        cloudEvents.add(toCheck);
        cloudNodeList.add(await convertNodeToJsonString(newNode));
      }
    }
    print("END UPDATE HANDLER");
  }

  @override
  Future<void> createHandler(EventChange event) async {
    try {
      print("CREATE HANDLER");
      String eType = event.type.toValueString();
      print("STORAGE LISTENER EVENT TYPE: $eType");

      /// AS IS A NEW NODE - IS NOT IN CLOUD
      String tlp = event.newNode!.visibility.toValueString();
      toolbox_api.Node? newNode = event.getNewNode;
      String uuid = await cloud.generateUUID();
      Event toCheck = Event(id_event: uuid, tlp: tlp.toUpperCase());
      if (

          /// BETA TEST - IF PAIRING PLUGIN CREATES - IS NOT REPLICATED
          newNode!.owner != _pluginAPI &&
              tlp.toLowerCase() != 'black' &&
              newNode.path.startsWith(':Local') == false &&
              newNode.path.startsWith(':Global') == false &&
              newNode.tombstone == false) {
        toCheck.encoding = 'ascii';
        if (tlp.toLowerCase() == 'red') {
          try {
            Map<dynamic, dynamic> encryptedNode =
                await encryptListenerCloudData(newNode);
            toCheck.content = json.encode(encryptedNode);
          } catch (e) {
            print(e);
            toCheck.content =
                json.encode(await convertNodeToJsonString(newNode));
            print('FAILURE GETTING KEYS');
          }
          toCheck.type = 'user_object';
        } else {
          toCheck.type = 'keyvalue';
          toCheck.content = json.encode(await convertNodeToJsonString(newNode));
        }
        toCheck.owner = _username;
        print("CREATE HANDLER - ADD NODE TO THE CLOUD");
        await cloud.createEvent(_username, toCheck);
        userEvents.add(uuid);
        cloudEvents.add(toCheck);
        cloudNodePath.add(newNode.path);
        cloudNodeList.add(await convertNodeToJsonString(newNode));
      } else {
        print("NODE MUST NOT BE REPLICATED");
        print("TLP: $tlp");
      }
    } catch (e) {
      print(e);
    }
    print("END CREATE HANDLER");
  }

  @override
  Future<void> deleteHandler(EventChange event) async {
    print("DELETE HANDLER");
    String eType = event.type.toValueString();
    toolbox_api.Node? oldNode = event.oldNode;
    print("STORAGE LISTENER EVENT TYPE: $eType");
    if (eType == 'delete') {
      String tlp = event.oldNode!.visibility.toValueString();
      if (tlp.toLowerCase() != 'black' &&
          oldNode != null &&
          oldNode.path.startsWith(':Local') == false &&
          oldNode.path.startsWith(':Global') == false &&
          oldNode.tombstone == false) {
        if (cloudNodePath.contains(oldNode.path)) {
          int index = cloudNodePath.indexOf(oldNode.path);
          print("DELETE HANDLER - DELETE NODE FROM THE CLOUD");
          await cloud.deleteEvent(_username, userEvents[index]);
          cloudNodePath.remove(cloudNodePath[index]);
          userEvents.remove(userEvents[index]);
          cloudEvents.remove(cloudEvents[index]);
          cloudNodeList.remove(cloudNodeList[index]);
        }
      }
    } else {
      print(eType);
    }
    print("END DELETE HANDLER");
  }

  @override
  Future<void> addSettingsConsent(String username, bool settingsValue) async {
    try {
      toolbox_api.Node consentNode = await getNode(':Local:Consent:$username');
      String consentValue = await consentNode
          .getValue('settingsConsent')
          .then((value) => value!.getValue("en").toString());
      if (consentValue != settingsValue.toString()) {
        consentNode.addOrUpdateValue(toolbox_api.NodeValueImpl(
            'settingsConsent', settingsValue.toString()));
        await _storageController.addOrUpdate(consentNode);
      }
    } catch (e) {
      print("CONSENT NODE NOT FOUND. CREATE CONSENT PARENT NODE");
      toolbox_api.Node consentNode =
          toolbox_api.NodeImpl(':Local:Consent', 'ReplicationController');
      consentNode.addOrUpdateValue(toolbox_api.NodeValueImpl(
          'settingsConsent', settingsValue.toString()));
      await _storageController.addOrUpdate(consentNode);
    }
  }

  Future<Map> decryptCloudData(Event event) async {
    print("DECRYPT CLOUD DATA");
    try {
      Map<dynamic, dynamic> data = getPartialJsonString(event.content!);
      print(data);
      toolbox_api.SearchCriteria criteria = toolbox_api.SearchCriteria(
          searchPath: ':Keys', key: 'path', value: data['path']);
      List<toolbox_api.Node> keyList =
          await _storageController.search(criteria);
      toolbox_api.Node? keys;
      for (var entry in keyList) {
        String comparePath = await entry
            .getValue('path')
            .then((value) => value!.getValue("en").toString());
        if (comparePath == data['path']) {
          keys = entry;
          break;
        }
      }
      print("KEY NODE GENERATED");

      if (keyList.isNotEmpty) {
        final hexEncodedKey = await keys!
            .getValue('key')
            .then((value) => value!.getValue("en").toString());

        /// keyPattern: key=["aes-256-cfb:JWWY+/E5Xppta3AsSIsGrWUOKHmv0w3cbfH5VlsG62Y="]
        final onlyKey = hexEncodedKey.split(':');
        final String decodedKey = (onlyKey[1]).toString();
        final keyVal = Enc.Key.fromBase64(decodedKey);
        final iv = Enc.IV.fromLength(16);
        final enc = Enc.Encrypter(Enc.AES(keyVal, mode: Enc.AESMode.cfb64));
        //DECRYPT DATA
        Map<dynamic, dynamic> jsonify = jsonDecode(event.content!);
        print(jsonify['custom_fields']);
        print(jsonify['custom_fields'].toString());
        String decrypted = enc.decrypt(
            Enc.Encrypted.fromBase64(jsonify['custom_fields']),
            iv: iv);
        jsonify['custom_fields'] = decrypted;
        print("********* FOR REVIEW PORPUSES *******");
        print("********* DATA DECRYPTION FROM CLOUD TO DEVICE - FUNCTION decryptCloudData*******");
        print("**************************** KEY VALUE ****************************");
        print("keyVal: " + keyVal.toString());
        print("**************************** END KEY VALUE ****************************");
        print("**************************** DECRYPTED VALUE ****************************");
        print(decrypted);
        print("**************************** END DECRYPTED VALUE ****************************");
        print("********* END FOR REVIEW PORPUSES *******");
        return jsonify;
      } else {
        throw ReplicationException("NO KEYS FOUND");
      }
    } catch (e) {
      print("DECRYPT CLOUD DATA EXCEPTION");
      print(e);
      throw ReplicationException(e.toString());
    }
  }

  Future<Map> encryptCloudData(toolbox_api.Node node) async {
    print("ENCRYPT LOCAL NODE");
    String fullPath = node.path;
    toolbox_api.SearchCriteria criteria = toolbox_api.SearchCriteria(
        searchPath: ':Keys', key: 'path', value: fullPath);
    List<toolbox_api.Node> keyList = await _storageController.search(criteria);
    toolbox_api.Node? keys;
    if (keyList.isNotEmpty) {
      for (var entry in keyList) {
        String comparePath = await entry
            .getValue('path')
            .then((value) => value!.getValue("en").toString());
        if (comparePath == fullPath) {
          keys = entry;
          break;
        }
      }
    } else {
      /// IF A PRE EXISTING KEY DOES NOT EXIST
      /// CREATE NEW ONE AND A NODE
      /// REPLICATE KEY TO CLOUD
      String newUUID = Uuid().v4();
      toolbox_api.Node newKey =
          toolbox_api.NodeImpl(':Keys:$newUUID', _username);
      newKey.addOrUpdateValue(toolbox_api.NodeValueImpl('path', fullPath));
      final nodeKey = Enc.Key.fromSecureRandom(32).base64.toString();
      newKey.addOrUpdateValue(
          toolbox_api.NodeValueImpl('key', 'aes-256-cfb:$nodeKey'));
      toolbox_api.Visibility? checkerVisible =
          toolbox_api.VisibilityExtension.valueOf("amber");
      if (checkerVisible != null) {
        newKey.visibility = checkerVisible;
      }
      await _storageController.add(newKey);

      /// POST KEY EVENT
      String keyUUID = await cloud.generateUUID();
      Event keyEvent = Event(id_event: keyUUID, tlp: "AMBER");
      keyEvent.owner = _username;
      keyEvent.encoding = 'ascii';
      keyEvent.type = 'keyvalue';
      keyEvent.content = json.encode(await convertNodeToJsonString(newKey));
      await cloud.createEvent(_username, keyEvent);
      keys = newKey;

      if (userEvents.contains(keyUUID) == false) {
        userEvents.add(keyUUID);
        cloudEvents.add(keyEvent);
        cloudNodeList.add(json.decode(keyEvent.content!));
        cloudNodePath.add(json.decode(keyEvent.content!)['path']);
      }
    }
    final hexEncodedKey = await keys!
        .getValue('key')
        .then((value) => value!.getValue("en").toString());

    /// keyPattern: key=["aes-256-cfb:JWWY+/E5Xppta3AsSIsGrWUOKHmv0w3cbfH5VlsG62Y="]
    final onlyKey = hexEncodedKey.split(':');
    final String decodedKey = onlyKey[1];
    print("KEY USED TO ENCRYPT NODE DATA: " + decodedKey);
    final keyVal = Enc.Key.fromBase64(decodedKey);
    final iv = Enc.IV.fromLength(16);
    final enc = Enc.Encrypter(Enc.AES(keyVal, mode: Enc.AESMode.cfb64));
    Map convertedNode = await convertNodeToJsonString(node);
    Enc.Encrypted encrypted =
        enc.encrypt(json.encode(convertedNode['custom_fields']), iv: iv);
    convertedNode['custom_fields'] = encrypted.base64;
    return convertedNode;
  }

  Future<Map> encryptListenerCloudData(toolbox_api.Node node) async {
    print("ENCRYPT LOCAL NODE");
    String fullPath = node.path;
    toolbox_api.SearchCriteria criteria = toolbox_api.SearchCriteria(
        searchPath: ':Keys', key: 'path', value: fullPath);
    List<toolbox_api.Node> keyList = await _storageController.search(criteria);
    toolbox_api.Node? keys;
    if (keyList.isNotEmpty) {
      for (var entry in keyList) {
        String comparePath = await entry
            .getValue('path')
            .then((value) => value!.getValue("en").toString());
        if (comparePath == fullPath) {
          keys = entry;
          break;
        }
      }
    } else {
      /// IF A PRE EXISTING KEY DOES NOT EXIST
      /// CREATE NEW ONE AND A NODE
      /// REPLICATE KEY TO CLOUD
      String newUUID = Uuid().v4();
      toolbox_api.Node newKey =
          toolbox_api.NodeImpl(':Keys:$newUUID', _username);
      newKey.addOrUpdateValue(toolbox_api.NodeValueImpl('path', fullPath));
      final nodeKey = Enc.Key.fromSecureRandom(32).base64.toString();
      newKey.addOrUpdateValue(
          toolbox_api.NodeValueImpl('key', 'aes-256-cfb:$nodeKey'));
      toolbox_api.Visibility? checkerVisible =
          toolbox_api.VisibilityExtension.valueOf("amber");
      if (checkerVisible != null) {
        newKey.visibility = checkerVisible;
      }

      /// LISTENER RUNNING
      /// WILL AUTOMATICALLY SHARE THE ADDED KEY
      await _storageController.add(newKey);
      keys = newKey;
    }
    final hexEncodedKey = await keys!
        .getValue('key')
        .then((value) => value!.getValue("en").toString());

    /// keyPattern: key=["aes-256-cfb:JWWY+/E5Xppta3AsSIsGrWUOKHmv0w3cbfH5VlsG62Y="]
    final onlyKey = hexEncodedKey.split(':');
    final String decodedKey = onlyKey[1];
    print("KEY USED TO ENCRYPT NODE DATA: " + decodedKey);
    final keyVal = Enc.Key.fromBase64(decodedKey);
    final iv = Enc.IV.fromLength(16);
    final enc = Enc.Encrypter(Enc.AES(keyVal, mode: Enc.AESMode.cfb64));
    Map convertedNode = await convertNodeToJsonString(node);
    Enc.Encrypted encrypted =
        enc.encrypt(json.encode(convertedNode['custom_fields']), iv: iv);
    convertedNode['custom_fields'] = encrypted.base64;
    return convertedNode;
  }

  Future<Map> encryptNodeToShare(toolbox_api.Node node, String keyPath) async {
    late Map convertedNode;
    //String fullPath = node.path;
    //String identifier = node.name;
    try {
      toolbox_api.Node keyNode = await getNode(keyPath);
      final hexEncodedKey = await keyNode
          .getValue('key')
          .then((value) => value!.getValue("en").toString());
      final onlyKey = hexEncodedKey.split(':');
      final String decodedKey = onlyKey[1];
      print("KEY USED TO ENCRYPT NODE DATA: " + decodedKey);
      final keyVal = Enc.Key.fromBase64(decodedKey);
      final iv = Enc.IV.fromLength(16);
      final enc = Enc.Encrypter(Enc.AES(keyVal, mode: Enc.AESMode.cfb64));
      convertedNode = await convertNodeToJsonString(node);
      Enc.Encrypted encrypted =
          enc.encrypt(json.encode(convertedNode['custom_fields']), iv: iv);
      convertedNode['custom_fields'] = encrypted.base64;
      return convertedNode;
    } catch (e) {
      print("DECRYPT CLOUD DATA");
      throw ReplicationException(e.toString());
    }
  }

  Future<Map> decryptSharedNode(Event event, String keyPath) async {
    try {
      toolbox_api.Node keyNode = await getNode(keyPath);
      final hexEncodedKey = await keyNode
          .getValue('key')
          .then((value) => value!.getValue("en").toString());
      final onlyKey = hexEncodedKey.split(':');
      final String decodedKey = onlyKey[1];
      print("KEY USED TO ENCRYPT NODE DATA: " + decodedKey);
      final keyVal = Enc.Key.fromBase64(decodedKey);
      final iv = Enc.IV.fromLength(16);
      final enc = Enc.Encrypter(Enc.AES(keyVal, mode: Enc.AESMode.cfb64));
      //DECRYPT DATA
      Map<dynamic, dynamic> jsonify = jsonDecode(event.content!);
      String decrypted = enc.decrypt(
          Enc.Encrypted.fromBase64(jsonify['custom_fields'].toString()),
          iv: iv);
      jsonify['custom_fields'] = decrypted;
      return jsonify;
    } catch (e) {
      print("DECRYPT CLOUD DATA");
      throw ReplicationException(e.toString());
    }
  }


/*
// TTBOMK Functions do not used within the GEIGER APP //
  @override
  Future<bool> geigerReplicationWithoutGlobalData(
      deleteHandler, createHandler, updateHandler, renameHandler) async {
    print('STARTING GEIGER REPLICATION WITHOUT GLOBAL DATA');

    /// Follow diagram
    /// 3 steps replication
    /// Cloud to device
    /// Device to cloud
    /// Storage listener
    /// Take care of strategies

    /// 1. INIT STORAGE
    /// this is done with initgeigerstoremethod providing an already initiated storage controller

    /// CHECK WHEN LAST REPLICATION TOOK PLACE
    /// Nodes that handle replication:
    /// :Replication:LastReplication
    DateTime _actual = DateTime.now();
    bool _fullRep;

    /// 180 -> Default expiring date
    DateTime _fromDate = _actual.subtract(Duration(days: 180));
    print('[1st FLOW] - TIMESTAMP CHECKER');
    try {
      toolbox_api.Node timeChecker =
          await getNode(':Local:Replication:LastReplication');
      DateTime _lastTimestamp =
          DateTime.fromMillisecondsSinceEpoch(timeChecker.lastModified);
      Duration _diff = _actual.difference(_lastTimestamp);
      if (_diff.inDays > 30) {
        /// FULL REPLICATION TAKES PLACE
        print("FULL REPLICATION");
        _fullRep = true;
      } else {
        /// PARTIAL REPLICATION TAKES PLACE
        print("PARTIAL REPLICATION");
        _fullRep = false;
        _fromDate = _lastTimestamp;
      }
    } catch (e) {
      print('NO REPLICATION NODE FOUND - NO REPLICATION HAS BEEN DONE');

      /// FULL REPLICATION TAKES PLACE
      _fullRep = true;
      print(e);
    }

    // 2. GET USER DATA - CHECK USER IN CLOUD
    print('[1st FLOW] - CHECK USER DATA');
    try {
      toolbox_api.Node local = await getNode(':Local');
      String _localUser = await local
          .getValue('currentUser')
          .then((value) => value!.getValue("en").toString());
      _username = _localUser;
      //CHECK IF USER ALREADY IN CLOUD & IF NOT, CREATE ONE
      bool exists = await cloud.userExists(_username.toString());
      //print(exists.toString());
      if (exists == false) {
        await cloud.createUser(_username.toString());
        //IF NO USER IN cloud. NO REPLICATION HAS TAKEN PLACE
        //print('No replication has taken place');
        /// FULL REPLICATION TAKES PLACE
        _fullRep = true;
      }
    } catch (e) {
      toolbox_api.StorageException('USER DATA NOT FOUND. ERROR');
      print(e);
      return false;
    }
    print(_username);

    /// CLOUD TO LOCAL REPLICATION
    print("[2nd FLOW] - CLOUD TO LOCAL");
    await cloudToLocalReplicationWithoutGlobalData(
        _username, _actual, _fromDate, _fullRep);

    /// LOCAL TO CLOUD REPLICATION
    print("[3rd FLOW] - LOCAL TO CLOUD");
    await localToCloudReplication(_username, _actual, _fromDate, _fullRep);

    /// UPDATE WHEN LAST REPLICATION TOOK PLACE
    print("[4th FLOW] - UPDATE WHEN LAST REPLICAION TOOK PLACE");
    await updateReplicationNode(_actual);

    /// STORAGE LISTENER
    print("[5th FLOW] - LISTENER REPLICATION");
    await geigerReplicationListener(
        deleteHandler, createHandler, updateHandler, renameHandler);
    return true;
  }

  Future<void> cloudToLocalReplicationWithoutGlobalData(String _username,
      DateTime _actual, DateTime _fromDate, bool _fullRep) async {
    print("CLOUD TO LOCAL REPLICATION - FUNCTION WithoutGlobalData");

    /// WITH DATETIME TAKE EVENTS FROM THE CLOUD
    List<String> events;
    // FILTER BY DATE
    if (_fullRep == true) {
      events = await cloud.getUserEvents(_username);
    } else {
      var filter =
          DateFormat("yyyy-MM-dd'T'hh:mm:ss.SSSS'Z'").format(_fromDate);
      events =
          await cloud.getUserEventsDateFilter(_username, filter.toString());
    }

    List<Event> waitingEvents = [];
    for (var userEvent in events) {
      Event singleOne = await cloud.getSingleUserEvent(_username, userEvent);
      String type = singleOne.type.toString();
      //String tlp = singleOne.tlp.toString();
      String id = singleOne.id_event.toString();
      //String owner = singleOne.owner.toString();
      //if (owner != _username) {
      if (type.toLowerCase() == "keyvalue") {
        print('CLOUD TO LOCAL REPLICATION - NO E2EE - FUNCTION WithoutGlobalData');
        toolbox_api.Node node = convertJsonStringToNode(singleOne.content!);
        await updateLocalNodeWithCloudNode(node, _username);
      }
      if (type.toLowerCase() == "user_object") {
        print('CLOUD TO LOCAL REPLICATION - E2EE - FUNCTION WithoutGlobalData');
        try {
          Map<dynamic, dynamic> jsonify = await decryptCloudData(singleOne);
          singleOne.setContent = jsonEncode(jsonify);
          toolbox_api.Node node = convertJsonStringToNode(singleOne.content!);
          await checkParents(node.path);
          await updateLocalNodeWithCloudNode(node, _username);
        } catch (e) {
          print(e);

          /// KAY MAY NOT BE REPLICATED YET - CREATE NEW LIST AND DO SAME OPERATION
          waitingEvents.add(singleOne);
          print('FAILURE GETTING KEYS FOR NODE - FUNCTION WithoutGlobalData: $id');
        }
      }
    }

    print("WAITING EVENTS - FUNCTION WithoutGlobalData");
    for (var waiting in waitingEvents) {
      String waitingId = waiting.id_event.toString();
      try {
        ///CREATE A SEARCH CRITERIA TO FIND KEY WITH GIVEN PATH
        ///ELSE CREATE A NODE WITH VISIBILITY AMBER
        ///AND REPLICATE
        Map<dynamic, dynamic> jsonify = await decryptCloudData(waiting);
        waiting.setContent = jsonEncode(jsonify);
        toolbox_api.Node node = convertJsonStringToNode(waiting.content!);
        await checkParents(node.path);
        await updateLocalNodeWithCloudNode(node, _username);
      } catch (e) {
        print(e);
        print('FAILURE GETTING KEYS FOR NODE - FUNCTION WithoutGlobalData: $waitingId');
        try {
          toolbox_api.Node node = convertJsonStringToNode(waiting.content!);
          await updateLocalNodeWithCloudNode(node, _username);
        } catch (e) {
          print("GET SHARED NODES FAILURE - FUNCTION WithoutGlobalData");
          print(e.toString());
        }
      }
    }
  }
*/


  /// EXPERIMENTAL NODES

  Future<bool> createPairingStructure() async {
    toolbox_api.Node local = await getNode(':Local');
    String _localUser = await local
        .getValue('currentUser')
        .then((value) => value!.getValue("en").toString());
    try {
      // ignore: unused_local_variable
      toolbox_api.Node entUs = await getNode(':Enterprise:Users');
    } catch (e) {
      toolbox_api.Node entUs =
          toolbox_api.NodeImpl(':Enterprise:Users', _replicationAPI);
      toolbox_api.Visibility? checkerVisible =
          toolbox_api.VisibilityExtension.valueOf("amber");
      if (checkerVisible != null) {
        entUs.visibility = checkerVisible;
      }
      await _storageController.add(entUs);
    }
    try {
      // ignore: unused_local_variable
      toolbox_api.Node entUsId = await getNode(':Enterprise:Users:$_localUser');
    } catch (e) {
      toolbox_api.Node entUsId = toolbox_api.NodeImpl(
          ':Enterprise:Users:$_localUser', _replicationAPI);
      toolbox_api.Visibility? checkerVisible =
          toolbox_api.VisibilityExtension.valueOf("amber");
      if (checkerVisible != null) {
        entUsId.visibility = checkerVisible;
      }
      await _storageController.add(entUsId);
    }
    try {
      // ignore: unused_local_variable
      toolbox_api.Node structure =
          await getNode(':Enterprise:Users:$_localUser:$_pluginAPI');
      return true;
    } catch (e) {
      print("PAIRING STRUCTURE NOT EXIST");
      toolbox_api.Node structure = toolbox_api.NodeImpl(
          ':Enterprise:Users:$_localUser:$_pluginAPI', _replicationAPI);
      toolbox_api.Node data = toolbox_api.NodeImpl(
          ':Enterprise:Users:$_localUser:$_pluginAPI:data', _replicationAPI);
      toolbox_api.Visibility? checkerData =
          toolbox_api.VisibilityExtension.valueOf("amber");
      if (checkerData != null) {
        structure.visibility = checkerData;
      }
      data.addValue(toolbox_api.NodeValueImpl('username', ''));
      data.addValue(toolbox_api.NodeValueImpl('sharedScore', ''));
      data.addValue(toolbox_api.NodeValueImpl('sharedScoreDate', ''));
      toolbox_api.Node config = toolbox_api.NodeImpl(
          ':Enterprise:Users:$_localUser:$_pluginAPI:config', _replicationAPI);
      toolbox_api.Visibility? checkerConfig =
          toolbox_api.VisibilityExtension.valueOf("amber");
      if (checkerConfig != null) {
        structure.visibility = checkerConfig;
      }
      config.addValue(toolbox_api.NodeValueImpl('supervisor', ''));
      config.addValue(toolbox_api.NodeValueImpl('employees', ''));
      toolbox_api.Visibility? checkerSt =
          toolbox_api.VisibilityExtension.valueOf("amber");
      if (checkerSt != null) {
        structure.visibility = checkerSt;
      }
      await _storageController.add(structure);
      return true;
    }
  }
}
