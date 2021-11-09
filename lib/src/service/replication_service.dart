library geiger_replication;

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

import 'package:cloud_replication_package/src/cloud_models/threat_dict.dart';
import 'package:cloud_replication_package/src/cloud_models/threat_weights.dart';
import 'package:geiger_localstorage/geiger_localstorage.dart' as toolboxAPI;
import 'package:logging/logging.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:encrypt/encrypt.dart' as Enc;
import 'package:flutter/cupertino.dart';

import 'package:cloud_replication_package/src/service/cloud_service.dart';
import './node_listener.dart';
import '../cloud_models/event.dart';
import '../replication_controller.dart';

class ReplicationService implements ReplicationController {
  
  final _log = Logger('ReplicationService');

  final cloud = CloudService();
  late toolboxAPI.StorageController storageController;
  // GEIGER Listener
  late toolboxAPI.StorageListener storageListener;

  ReplicationService();

  @override
  Future<void> geigerReplication() async {
    print('Starting GEIGER Replication');
    //cloud = CloudService();
    /// Follow diagram
    /// 3 steps replication
    /// Cloud to device
    /// Device to cloud
    /// Storage listener
    /// Take care of strategies

    // 1. INIT STORAGE
    await initGeigerStorage();

    /// CHECK WHEN LAST REPLICATION TOOK PLACE
    /// Nodes that handle replication:
    /// :Replication:LastReplication
    DateTime _actual = DateTime.now();
    bool _fullRep;
    // 180 -> Default expiring date
    DateTime _fromDate = _actual.subtract(Duration(days: 180));
    print('[1st FLOW] - TIMESTAMP CHECKER');
    try {
      toolboxAPI.Node timeChecker = getNode(':Replication:LastReplication');
      DateTime _lastTimestamp =
          DateTime.parse(timeChecker.getValue('timestamp').toString());
      Duration _diff = _actual.difference(_lastTimestamp);
      if (_diff.inDays > 30) {
        /// FULL REPLICATION TAKES PLACE
        _fullRep = true;
      } else {
        /// PARTIAL REPLICATION TAKES PLACE
        _fullRep = false;
        _fromDate = _lastTimestamp;
      }
    } catch (e) {
      print('NO REPLICATION NODE - NO REPLICATION HAS BEEN DONE');

      /// FULL REPLICATION TAKES PLACE
      _fullRep = true;
    }

    // 2. GET USER DATA - CHECK USER IN CLOUD
    String _username;
    try {
      toolboxAPI.Node local = getNode(':Local');
      String _localUser =
          local.getValue('currentUser')!.getValue("en").toString();
      _username = _localUser;
      print(_username);
      //CHECK IF USER ALREADY IN CLOUD & IF NOT, CREATE ONE
      bool exists = await cloud.userExists(_username.toString());
      print(exists.toString());
      if (exists == false) {
        await cloud.createUser(_username.toString());
        //IF NO USER IN cloud. NO REPLICATION HAS TAKEN PLACE
        print('No replication has taken place');
        /// FULL REPLICATION TAKES PLACE
        _fullRep = true;
      }
    } catch (e) {
      print('Not user data retrieved');
      toolboxAPI.StorageException('Not able to get user data');
      exit(1);
    }

    /// WITH DATETIME TAKE EVENTS FROM THE CLOUD
    List<String> events;
    // FILTER BY DATE
    if (_fullRep == true) {
      events = await cloud.getUserEvents(_username);
    } else {
      events =
          await cloud.getUserEventsDateFilter(_username, _fromDate.toString());
    }
    print(events);
    for (var userEvent in events) {
      Event singleOne = await cloud.getSingleUserEvent(_username, userEvent);
      String type = singleOne.type.toString();
      String tlp = singleOne.tlp.toString();
      String id = singleOne.id_event.toString();
      if (type.toLowerCase() == "keyvalue") {
        print('NO E2EE');
        updateSingleNodeCloud2Device(singleOne);
      }
      if (type.toLowerCase() == "keyvalue") {
        print('E2EE');
        //GET KEYS
        try {
          toolboxAPI.Node keys = getNode(':$id:local');
          final keyVal = Enc.Key.fromUtf8(keys.getValue('key').toString());
          final enc = Enc.Encrypter(Enc.AES(keyVal, mode: Enc.AESMode.cbc));
          final iv = Enc.IV.fromLength(32);
          //DECRYPT DATA
          String decrypted = enc
              .decrypt(singleOne.content.toString() as Enc.Encrypted, iv: iv);
          singleOne.setContent = decrypted.toString();
          updateSingleNodeCloud2Device(singleOne);
        } catch (e) {
          toolboxAPI.StorageException('FAILURE GETTING KEYS');
        }
      }
    }

    ///FETCH ALL TLP WHITE EVENTS - FREELY SHARED
    ///STORE THEM IN :Global:type:UUID
    List<Event> freeEvents;
    // FILTER BY DATE
    if (_fullRep == true) {
      freeEvents = await cloud.getTLPWhiteEvents();
    } else {
      freeEvents =
          await cloud.getTLPWhiteEventsDateFilter(_fromDate.toString());
    }
    for (var free in freeEvents) {
      /// UUID WILL BE THE CLOUD ONE
      /// DATA MAY NOT COME FROM STORAGE AND USER ANOTHER UUID
      String typeTLP = free.type.toString();
      String? uuid = free.id_event;
      DateTime cloudTimestamp = DateTime.parse(free.last_modified.toString());
      if (free.content.toString().isNotEmpty) {
        try {
          print(free.content.toString());
          var content = jsonDecode(free.content.toString());
          String nodePath = ':Global:$typeTLP:$uuid';
          toolboxAPI.Node newRepNode = toolboxAPI.NodeImpl(nodePath);
          //LOOP ALL ELEMENTS
          storageController.update(newRepNode);
          Map<dynamic, dynamic> mapper = content;
          mapper.forEach((key, value) {
            newRepNode
                .addOrUpdateValue(toolboxAPI.NodeValueImpl(key, value.toString()));
          });
          checkAndUpdateNodeWithNode(nodePath, newRepNode, cloudTimestamp);
        } catch (e) {
          print("CONTENT TYPE NOT IN JSON FORMAT");
        }
      }
    }

    /// GET THREAT WEIGHTS
    /// STORE :Global:ThreatWeight:UUID
    updateThreatWeights();

    /// END OF FIRST DIAGRAM
    /// CLOUD - DEVICE
    /// WRITE LOG
    print('FIRST DIAGRAM COMPLETED');

    /// START OF THE SECOND DIAGRAM
    /// START CLEANING DATA AND REMOVING TOMBSTONES
    cleanData(_actual);
    List<toolboxAPI.Node> nodeList = [];
    if (_fullRep == true) {
      /// FIND ALL THE NODES
      nodeList = await getAllNodes();
    } else {
      /// ASK FOR SEARCH CRITERIA NODE BASED
      print('PARTIAL REPLICATION');
    }

    /// SORT NODES BY TIMESTAMP
    nodeList.sort((a, b) => a
        .getValue('timestamp')
        .toString()
        .compareTo(b.getValue('timestamp').toString()));

    if (nodeList.isEmpty == false) {
      for (var sorted in nodeList) {
        /// CHECK TLP
        String tlp = sorted.getValue('Visibility').toString();
        String identifier = sorted.getName().toString();
        print(identifier);
        /// CHECK CONSENT
        /// TBD
        /// 3 AGREEMENTS: NEVER, NO ONCE, AGREE ONCE
        /// CREATE EVENT
        Event toCheck = Event(id_event: identifier, tlp: tlp.toUpperCase());
        if (tlp.toLowerCase() == 'red') {
          try {
            toolboxAPI.Node keys = getNode(':$identifier:local');
            final keyVal = Enc.Key.fromUtf8(keys.getValue('key').toString());
            final enc = Enc.Encrypter(Enc.AES(keyVal, mode: Enc.AESMode.cbc));
            final iv = Enc.IV.fromLength(32);
            Enc.Encrypted encrypted = enc.encrypt(sorted.toString(), iv: iv);
            toCheck.setContent = encrypted.toString();
          } catch (e) {
            toolboxAPI.StorageException('FAILURE GETTING KEYS');
          }
          toCheck.setType = 'user_event';
        } else {
          toCheck.setType = 'keyvalue';
        }
        //CHECK IF EVENT IN CLOUD
        try {
          // IF OK
          // CHECK TIMESTAMP
          // IF NEEDED -> PUT
          Event exist = await cloud.getSingleUserEvent(_username, identifier);
          if (exist.last_modified != null) {
            DateTime toCompare = DateTime.parse(exist.last_modified.toString());
            //AS IN CLOUD, COMPARE DATETIMES
            cloud.updateEvent(_username, identifier, toCheck);
          }
        } catch (e) {
          // IF NO EVENT IS RETURNED -> POST NEW EVENT
          cloud.createEvent(_username, toCheck);
        }
      }
    }

    //UPDATE LAST REPLICATION
    updateReplicationNode(_actual);

    /// LAST ALGORITHM
    /// IN CHARGE OF LISTENING
    /// GETS MODIFIED NODE
    /// CHECK TLP
    /// CHECK CONSENT
    /// IF NODE IN CLOUD
    /// UPDATE
    /// ELSE
    /// CREATE NEW
    ///
    /// Event Type can be:
    /// create, update, delete, rename
    //while(true) {
      storageListenerReplication(_username);
    //}
  }

  /// UTILS
  /// IN THIS SECTION ARE REPETITIVE TASKS
  /// AVOID DUPLICATION CODE

  /* INIT */
  Future<void> initGeigerStorage() async {
    print('INIT GEIGER STORAGE');
    WidgetsFlutterBinding.ensureInitialized();
    //String dbPath = join(await getDatabasesPath(), './dbFileName.sqlite');
    //storageController = toolboxAPI.GenericController('Cloud-Replication', toolboxAPI.SqliteMapper(dbPath));
    storageController = toolboxAPI.GenericController(
        'Cloud-Replication', toolboxAPI.DummyMapper());
    print('INIT GEIGER END');
  }

  /*
  * GET ANY NODE -> BASED ON THE PATH
  */
  toolboxAPI.Node getNode(String path) {
    toolboxAPI.Node node = storageController.get(path);
    return node;
  }

  // After replication ends, update with the compared time
  void updateReplicationNode(DateTime _actual) {
    /// Should be defined a historic with all replication timestamps?
    /// Add type of replication into the node (full, partial)?
    try {
      print('UPDATE REPLICATION NODE');
      toolboxAPI.Node updateRepNode = getNode(':Replication:LastReplication');
      updateRepNode.addOrUpdateValue(
          toolboxAPI.NodeValueImpl('timestamp', _actual.toString()));
      storageController.update(updateRepNode);
    } catch (e) {
      print('CREATE NEW REPLICATION NODE');
      toolboxAPI.Node parentNode =
          toolboxAPI.NodeImpl(':Replication');
      storageController.add(parentNode);
      toolboxAPI.Node newRepNode =
          toolboxAPI.NodeImpl(':Replication:LastReplication');
      storageController.add(newRepNode);
      newRepNode.addOrUpdateValue(
          toolboxAPI.NodeValueImpl('timestamp', _actual.toString()));
      storageController.update(newRepNode);
    }
    print('[REPLICATION NODE] UPDATED');
  }

  void updateSingleNodeCloud2Device(Event event) async {
    print('CHECK NODES');
    toolboxAPI.Node _toCheck = event.content as toolboxAPI.Node;
    String _nodePath = _toCheck.getPath().toString();
    try {
      toolboxAPI.Node inLocal = getNode(_nodePath);
      //CHECK TIMESTAMP
      DateTime cloud = DateTime.parse(event.last_modified.toString());
      /*
      Datetime local = DateTime.parse(inLocal.getValue('timestamp').toString());
      Duration _diff = local.difference(cloud);
      if (_diff.inDays>0) {
        _log.('NODE IN LOCAL NEWER');
      } else {}
      */
      /// Delete node, Create New One
      storageController.delete(_nodePath);
      storageController.addOrUpdate(_toCheck);
    } catch (e) {
      print('NODE NOT FOUND - CREATE ONE');
      storageController.update(_toCheck);
    }
  }

  void checkAndUpdateNodeWithNode(
      String path, toolboxAPI.Node node, DateTime cloud) {
    print('CHECK NODES');
    try {
      toolboxAPI.Node inLocal = getNode(path);
      /*
      Datetime local = DateTime.parse(inLocal.getValue('timestamp').toString());
      Duration _diff = local.difference(cloud);
      if (_diff.inDays>0) {
        _log.('NODE IN LOCAL NEWER');
      } else {}
      */
      /// Delete node, Create New One
      storageController.delete(path);
      storageController.addOrUpdate(node);
    } catch (e) {
      print('NODE DO NOT EXIST - CREATE ONE');
      toolboxAPI.Node newNode = toolboxAPI.NodeImpl(path);
      newNode.update(node);
      storageController.update(newNode);
    }
  }

  /// STORE :Global:ThreatWeight:UUID
  void updateThreatWeights() async {
    print('UPDATE THREAT WEIGHTS');
    List<ThreatWeights> weights = await cloud.getThreatWeights();
    for (var weight in weights) {
      String? uuid = weight.idThreatweights;
      ThreatDict? data = weight.threatDict;
      try {
        if (data!=null){
          toolboxAPI.Node checker = getNode(':Global:ThreatWeight:$uuid');
          Map<String, dynamic> mapper = data.toJson();
          mapper.forEach((key, value) {
            checker.addOrUpdateValue(
                toolboxAPI.NodeValueImpl(key, value.toString()));
          });
          storageController.update(checker);
        }
      } catch (e) {
        if (data!=null){
          toolboxAPI.Node newThreatNode =
              toolboxAPI.NodeImpl(':Global:ThreatWeight:$uuid');
          Map<String, dynamic> mapper = data.toJson();
          mapper.forEach((key, value) {
            newThreatNode.addOrUpdateValue(
                toolboxAPI.NodeValueImpl(key, value.toString()));
          });
          storageController.update(newThreatNode);
        }
      }
    }
  }

  void cleanData(DateTime actual) {
    print('REMOVE DATA - 180 DAYS LIMIT');

    /// COMPLETE
    /// RECURSIVE WAY
    /// CHECK TIMESTAMP > 180 DAYS: DELETE
    List<toolboxAPI.Node> checkingData = getAllNodes();

    /// SORT NODES BY TIMESTAMP
    checkingData.sort((a, b) => a
        .getValue('timestamp')
        .toString()
        .compareTo(b.getValue('timestamp').toString()));
    for (var node in checkingData) {
      DateTime nodeTime = DateTime.parse(node.getValue('timestamp').toString());
      Duration checker = actual.difference(nodeTime);
      if (checker.inDays > 180) {
        //REPLICATION TIMING STRATEGIES - DELETE NODE
        String path = node.getPath().toString();
        storageController.delete(path);
        print('NODE WITH PATH $path HAS BEEN REMOVED');
      }
    }
  }

  List<toolboxAPI.Node> getAllNodes() {
    List<toolboxAPI.Node> nodeList = [];
    try {
      toolboxAPI.Node root = getNode('');
      getRecursiveNodes(root, nodeList);
    } catch (e) {
      print('Exception');
    }
    return nodeList;
  }

  void getRecursiveNodes(toolboxAPI.Node node, List<toolboxAPI.Node> list) {
    list.add(node);
    Map<String, toolboxAPI.Node> children = node.getChildren();
    children.forEach((key, value) {
      getRecursiveNodes(value, list);
    });
  }

  void storageListenerReplication(String _username) async {
    ///ALL ABOUT LISTENER
    var listener = NodeListener();
    var sc = toolboxAPI.SearchCriteria();
    storageController.registerChangeListener(listener, sc);

    toolboxAPI.Node node = listener.newnode;
    toolboxAPI.Node oldNode = listener.oldnode;

    String eventType = '';

    // If 'delete' check directly with the cloud
    if (eventType.toString() == 'delete') {
      String eventId = node.getName().toString();
      try {
        Event checker = await cloud.getSingleUserEvent(_username, eventId);
        //IF EVENT RETRIEVED IS BECAUSE EXISTS -> DELETE
        cloud.deleteEvent(_username, eventId);
      } catch (e) {
        print('NODE NOT IN cloud. NOTHING TO DO');
      }
    } else {
      /// CREATE, UPDATE OR RENAME A NODE
      /// FOLLOW STEPS
      /// TLP
      String tlp = node.getValue('Visibility').toString();
      if (tlp.toLowerCase() == 'black') {
        print('BLACK TLP NODES MUST NOT BE REPLICATED');
      } else {
        //METHOD CHECK CONSENT
        //RETURN BOOLEAN
        //IF TRUE - CONTINUE - ELSE - END
        bool consent = checkConsent(node, _username);
        if (consent == true) {
          String nodeName = node.getName().toString();
          Event toCloudEvent = Event(id_event: nodeName, tlp: tlp);
          toCloudEvent.setOwner = node.getOwner.toString();
          if (tlp.toLowerCase() == 'red') {
            //GET KEYS
            try {
              toolboxAPI.Node keys = getNode(':$nodeName:cloud');
              final keyVal = Enc.Key.fromUtf8(keys.getValue('key').toString());
              final enc = Enc.Encrypter(Enc.AES(keyVal, mode: Enc.AESMode.cbc));
              final iv = Enc.IV.fromLength(32);
              //ENCRYPT DATA IN A VARIABLE
              var encryptedNode = node.toString();
              toCloudEvent.setContent = encryptedNode;
              toCloudEvent.setType = 'user_object';
            } catch (e) {
              toolboxAPI.StorageException('FAILURE GETTING KEYS');
            }
          } else {
            toCloudEvent.setContent = node.toString();
            toCloudEvent.setType = 'keyvalue';
          }
          //CONTINUE TO REPLICATE
          try {
            Event checker = await cloud.getSingleUserEvent(_username, nodeName);
            if (eventType.toString() == 'create') {
              //UPDATE
              cloud.updateEvent(_username, nodeName, toCloudEvent);
            }
            if (eventType.toString() == 'update') {
              //UPDATE
              cloud.updateEvent(_username, nodeName, toCloudEvent);
            }
            if (eventType.toString() == 'rename') {
              //CHECK PREVIOUS ONE
              try {
                Event oldChecker = await cloud.getSingleUserEvent(
                    _username, oldNode.getName().toString());
                //IF EXISTED - DELETE
                //THEN - CREATE
                cloud.deleteEvent(_username, oldChecker.id_event.toString());
                cloud.updateEvent(_username, nodeName, toCloudEvent);
              } catch (e) {
                //PREVIOUS ONE NOT IN CLOUD
                //THEN - UPDATE NEW ONE
                cloud.updateEvent(_username, nodeName, toCloudEvent);
              }
            }
          } catch (e) {
            print('NODE NOT IN cloud.');
            if (eventType.toString() == 'create') {
              //CREATE
              cloud.createEvent(_username, toCloudEvent);
            }
            if (eventType.toString() == 'update') {
              //CREATE
              cloud.createEvent(_username, toCloudEvent);
            }
            if (eventType.toString() == 'rename') {
              //CHECK PREVIOUS ONE
              try {
                Event oldChecker = await cloud.getSingleUserEvent(
                    _username, oldNode.getName().toString());
                //IF EXISTED - DELETE
                //THEN - CREATE
                cloud.deleteEvent(_username, oldChecker.id_event.toString());
                cloud.createEvent(_username, toCloudEvent);
              } catch (e) {
                //PREVIOUS ONE NOT IN CLOUD
                //THEN - CREATE
                cloud.createEvent(_username, toCloudEvent);
              }
            }
          }
        } else {
          print('NO CONSENT');
        }
      }
    }
  }

  bool checkConsent(toolboxAPI.Node node, String username) {
    bool consent = false;
    String tlp = node.getValue('Visibility').toString();
    if (tlp.toLowerCase() == 'white') {
      consent = true;
    } else {
      //CHECK CONSENT
      try {
        //IF GET NODE - USER HAS NOT AGREED FOREVER - CONSENT FALSE
        toolboxAPI.Node consentNode = getNode(':Consent:$username');
        consent = false;
      } catch (e) {
        //No consent set.
        print('NEED TO ASK CONSENT');
        //TBD - ASK USER FOR CONSENT - GENERAL CONSENT - USER BASED
        //IF USER AGREE ONCE - Consent true & TLP RED - UPDATE NODE
        //IF USER NOT AGREE FOREVER - Consent false CREATE CONSENT
        //USER DOES NOT AGREE ONCE - Consent false & SET TLP RED - UPDATE NODE

        //UNTIL CONSENT CLEAR - TRUE
        consent = true;
      }
      consent = true;
    }
    return consent;
  }
}
