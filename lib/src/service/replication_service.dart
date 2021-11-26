library geiger_replication;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:convert/convert.dart';

import 'package:cloud_replication_package/src/cloud_models/user.dart';
import 'package:cloud_replication_package/src/replication_exception.dart';
import 'package:cloud_replication_package/src/service/cloud_exception.dart';
import 'package:cloud_replication_package/src/cloud_models/threat_dict.dart';
import 'package:cloud_replication_package/src/cloud_models/threat_weights.dart';
import 'package:cloud_replication_package/src/service/cloud_service.dart';

import 'package:geiger_localstorage/geiger_localstorage.dart' as toolboxAPI;

import 'package:logging/logging.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:encrypt/encrypt.dart' as Enc;
import 'package:flutter/cupertino.dart';
import 'package:crypto/crypto.dart';

import './node_listener.dart';
import '../cloud_models/event.dart';
import '../cloud_models/short_user.dart';
import '../replication_controller.dart';

class ReplicationService implements ReplicationController {
  
  final _log = Logger('ReplicationService');

  final cloud = CloudService();

  /// Storage controller
  late toolboxAPI.StorageController storageController;

  /// Storage Listener
  late toolboxAPI.StorageListener storageListener;

  ReplicationService();

  @override
  Future<void> geigerReplication() async {
    print('Starting GEIGER Replication');
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
    /// 180 -> Default expiring date
    DateTime _fromDate = _actual.subtract(Duration(days: 180));
    print('[1st FLOW] - TIMESTAMP CHECKER');
    try {
      toolboxAPI.Node timeChecker = await getNode(':Replication:LastReplication');
      DateTime _lastTimestamp =
          DateTime.parse(timeChecker.getValue('lastModified').toString());
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
      toolboxAPI.Node local = await getNode(':Local');
      String _localUser =
          local.getValue('currentUser').toString();
      _username = _localUser;
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
    for (var userEvent in events) {
      Event singleOne = await cloud.getSingleUserEvent(_username, userEvent);
      String type = singleOne.type.toString();
      String tlp = singleOne.tlp.toString();
      String id = singleOne.id_event.toString();
      String owner = singleOne.owner.toString();
      if (owner != _username) {
        if (type.toLowerCase() == "keyvalue") {
          print('NO E2EE');
          updateSingleNodeCloud2Device(singleOne);
        }
        if (type.toLowerCase() == "user") {
          print('E2EE');
          //GET KEYS
          try {
            toolboxAPI.Node keys = await getNode(':Keys:$id');
            final hexEncodedKey = keys.getValue('key').toString();
            /// keyPattern: key=["aes-256-cfb:JWWY+/E5Xppta3AsSIsGrWUOKHmv0w3cbfH5VlsG62Y="]
            final onlyKey = hexEncodedKey.split(':');
            final String decodedKey = hex.decode(onlyKey[1]).toString();

            final keyVal = Enc.Key.fromUtf8(decodedKey);
            final iv = Enc.IV.fromLength(128);
            final enc = Enc.Encrypter(Enc.AES(keyVal, mode: Enc.AESMode.cfb64));

            //DECRYPT DATA
            String decrypted = enc
                .decrypt(singleOne.content.toString() as Enc.Encrypted, iv: iv);
            singleOne.setContent = decrypted.toString();
            updateSingleNodeCloud2Device(singleOne);
          } catch (e) {
            toolboxAPI.StorageException('FAILURE GETTING KEYS FOR NODE: $id');
          }
        }
      } else {
        await updatePairedEvent(_username, singleOne);
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
          var content = jsonDecode(free.content.toString());
          String nodePath = ':Global:$typeTLP:$uuid';
          toolboxAPI.Node newRepNode = toolboxAPI.NodeImpl(nodePath, free.owner.toString());
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
        .lastModified
        .toString()
        .compareTo(b.lastModified.toString()));

    if (nodeList.isEmpty == false) {
      for (var sorted in nodeList) {
        /// CHECK TLP
        String tlp = sorted.visibility.toString();
        String identifier = sorted.name.toString();
        print(identifier);
        /// CHECK CONSENT
        /// TBD
        /// 3 AGREEMENTS: NEVER, NO ONCE, AGREE ONCE
        /// CREATE EVENT
        Event toCheck = Event(id_event: identifier, tlp: tlp.toUpperCase());
        if (tlp.toLowerCase() == 'red') {
          try {
            toolboxAPI.Node keys = await getNode(':Keys:$identifier');
            final hexEncodedKey = keys.getValue('key').toString();
            /// keyPattern: key=["aes-256-cfb:JWWY+/E5Xppta3AsSIsGrWUOKHmv0w3cbfH5VlsG62Y="]
            final onlyKey = hexEncodedKey.split(':');
            final String decodedKey = hex.decode(onlyKey[1]).toString();

            final keyVal = Enc.Key.fromUtf8(decodedKey);
            final iv = Enc.IV.fromLength(128);
            final enc = Enc.Encrypter(Enc.AES(keyVal, mode: Enc.AESMode.cfb64));

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
      //storageListenerReplication(_username);
    //}
  }

  @override
  Future<void> setPair(String userId1, String userId2) async {
    /// stores merge agreement in the cloud
    /// checks if local node exists
    /// checks if cloud users exist
    /// checks if already merged
    /// userId1 - local user
    /// userId2 - peer partner
    try {
      toolboxAPI.Node agreement = await getNode(':key:$userId2');
      String agreeType = agreement.getValue('agreement').toString();
      String typo = agreement.getValue('type').toString();
      
      /*String complementary;
      if (agreeType == 'in') {
        complementary = 'out';
      } else if (agreeType == 'both') {
        complementary = 'out';
      } else if(agreeType == 'out') {
        complementary = 'out';
      } else {
        throw ReplicationException('No agreement valid type defined');
      }*/

      /// check cloud users
      bool user1Exists = await cloud.userExists(userId1);
      if (user1Exists == false) {
        cloud.createUser(userId1);
      }
      /*bool user2Exists = await cloud.userExists(userId2);
      if (user2Exists == false) {
        cloud.createUser(userId2);
      }*/

      /// check if mutual merge exists
      /// if one user agrees in - the other must agree out and vice versa
      /// if agree both - the other must agree both
      /// check userId1 agreements
      try {
        List<String> agreeUser1 = await cloud.getMergedAccounts(userId1);
        if (agreeUser1.contains(userId2)==false) {
          await cloud.createMerge(userId1, userId2, agreeType, typo);
        }
      } catch (e) {
        await cloud.createMerge(userId1, userId2, agreeType, typo);
      }

      /*try {
        List<String> agreeUser2 = await cloud.getMergedAccounts(userId2);
        if (agreeUser2.contains(userId1)==false) {
          await cloud.createMerge(userId2, userId1, complementary);
        }
      } catch (e) {
        await cloud.createMerge(userId2, userId1, complementary);
      }*/
    } catch (e) {
      print(e);
      throw toolboxAPI.StorageException('PAIRING NODE NOT FOUND');
    } 
  }

  @override
  Future<void> unpair(String userId1, String userId2) async {
    /// deletes local node exists
    /// deletes merge agreement in the cloud
    /// checks if cloud users exist
    /// checks if already merged
    /// userId1 - local user
    /// userId2 - peer partner
    /// if paired - remove 2 pairs
   
    /// check cloud users
    bool user1Exists = await cloud.userExists(userId1);
    if (user1Exists == false) {
      throw ReplicationException('$userId1 does not exist in cloud. No unpair is possible.');
    }
    /*bool user2Exists = await cloud.userExists(userId2);
    if (user2Exists == false) {
      throw ReplicationException('$userId2 does not exist in cloud. No unpair is possible.');
    }*/

    /// check userId1 agreements
    try {
      List<String> agreeUser1 = await cloud.getMergedAccounts(userId1);
      if (agreeUser1.contains(userId2)==true) {
        try {
          await cloud.deleteMerged(userId1, userId2);
        } catch (e) {
          throw ReplicationException('Cloud Exception: ' + e.toString());
        }
      } else {
        throw ReplicationException('No active agreement between $userId1 and $userId2');
      }
    } catch (e) {
      throw ReplicationException('No active agreements set for $userId1');
    }

    /// check userId2 agreements
    /*try {
      List<String> agreeUser2 = await cloud.getMergedAccounts(userId2);
      if (agreeUser2.contains(userId1)==true) {
        try {
          await cloud.deleteMerged(userId2, userId1);
        } catch (e) {
          throw ReplicationException('Cloud Exception: ' + e.toString());
        }
      } else {
        throw ReplicationException('No active agreement between $userId2 and $userId1');
      }
    } catch (e) {
      throw ReplicationException('No active agreements set for $userId2');
    }*/
  }

  @override
  Future<void> shareNode(String nodePath, String senderUserId, String receiverUserId) async {
    /// check local pairing
    /// check cloud pairing
    /// get key
    /// create cloud event e2ee (if public key - else no e2ee)
    /// post event
    try {
      toolboxAPI.Node node = await getNode(':key_$receiverUserId');
      String encryptedKey = node.getValue('key').toString();
      String agreeValue = node.getValue('agreement').toString();
      if (agreeValue=='out' || agreeValue == 'both') {
        try {
          List<String> agreements = await cloud.getMergedAccounts(senderUserId);
          if (agreements.contains(receiverUserId)==true) {
            ShortUser data = await cloud.getMergedInfo(senderUserId, receiverUserId);
            String? publicKey = data.getPublicKey;
            if (publicKey != null) {
              
              final keyVal = Enc.Key.fromUtf8(publicKey);
              final iv = Enc.IV.fromLength(128);
              final enc = Enc.Encrypter(Enc.AES(keyVal, mode: Enc.AESMode.cfb64));
              // need to decrypt the encryptedKey
              //DECRYPT DATA
              encryptedKey = enc
                  .decrypt(encryptedKey.split(':')[1] as Enc.Encrypted, iv: iv);
            } else {
              encryptedKey = encryptedKey.split(':')[1];
            }
            // node to send
            toolboxAPI.Node toShareNode = await getNode(nodePath);

            Event toPostEvent = Event(id_event: toShareNode.name.toString(), tlp: toShareNode.visibility.toString());
            toPostEvent.setOwner = senderUserId;
            toPostEvent.setType = 'user';

            //EncryptNode
            final keyVal = Enc.Key.fromUtf8(encryptedKey);
            final enc = Enc.Encrypter(Enc.AES(keyVal, mode: Enc.AESMode.cfb64));
            final iv = Enc.IV.fromLength(128);
            Enc.Encrypted encrypted = enc.encrypt(toShareNode.toString(), iv: iv);
            toPostEvent.setContent = encrypted.toString();
            await cloud.createEvent(senderUserId, toPostEvent);
          } else {
            throw CloudException('There is no active cloud agreement');
          }
        } catch (e) {
          throw CloudException('There is no active cloud agreement');
        }
      }
    } catch (e) {
      throw toolboxAPI.StorageException('Key Node not found');
    }
  }

  @override
  Future<void> getSharedNodes(String receiverUserId, String senderUserId) async {
    /// get receiverNodes 
    /// cloud API retrieves also the shared ones
    /// check the Event owner to differenciate
    try {
      toolboxAPI.Node node = await getNode(':key_$senderUserId');
      String encryptedKey = node.getValue('key').toString();
      String agreeValue = node.getValue('agreement').toString();
      if (agreeValue=='in' || agreeValue == 'both') {
        try {
          List<String> agreements = await cloud.getMergedAccounts(senderUserId);
          if (agreements.contains(receiverUserId)==true) {
            /// check if our user has publicKey
            /// else the key will be clear
            User actualUser = await cloud.getUser(receiverUserId);
            var publicKey = actualUser.getPublicKey;
            if (publicKey != null) {
              publicKey = publicKey.toString();

              final keyVal = Enc.Key.fromUtf8(publicKey);
              final enc = Enc.Encrypter(Enc.AES(keyVal, mode: Enc.AESMode.cbc));
              final iv = Enc.IV.fromLength(128);
              //DECRYPT DATA
              encryptedKey = enc
                  .decrypt(encryptedKey.split(':')[1] as Enc.Encrypted, iv: iv);
            }

            /// get user nodes
            List<String> allEvents = await cloud.getUserEvents(receiverUserId);
            for (var event in allEvents) {
              Event newEvent = await cloud.getSingleUserEvent(receiverUserId, event);
              var owner = newEvent.getOwner;
              if (owner != null) {
                owner = owner.toString();
                if (owner == senderUserId) {
                  /// DECRYPT CONTENT AND SET NEW NODE
                  final keyVal1 = Enc.Key.fromUtf8(encryptedKey.split(':')[1]);
                  final enc1 = Enc.Encrypter(Enc.AES(keyVal1, mode: Enc.AESMode.cfb64));
                  final iv1 = Enc.IV.fromLength(128);
                  //DECRYPT DATA
                  var data = enc1
                      .decrypt(newEvent.content.toString() as Enc.Encrypted, iv: iv1);

                  /// CREATE NODE
                  toolboxAPI.Node newSharedNode = toolboxAPI.NodeImpl(newEvent.id_event.toString(), senderUserId);
                  toolboxAPI.Visibility? visible = toolboxAPI.VisibilityExtension.valueOf(newEvent.getTlp.toString());
                  newSharedNode.visibility = visible!;
                  //LOOP ALL ELEMENTS
                  storageController.update(newSharedNode);
                  Map<dynamic, dynamic> mapper = jsonDecode(data);
                  mapper.forEach((key, value) {
                    newSharedNode
                        .addOrUpdateValue(toolboxAPI.NodeValueImpl(key, value.toString()));
                  });
                  storageController.update(newSharedNode);
                }
              }
            }
          }
        } catch (e) {
          throw CloudException('There is no active cloud agreement');
        }
      }
    } catch (e) {
      throw toolboxAPI.StorageException('Key Node not found');
    }
  }

  @override 
  Future<void> createCloudUser(String userId, [String? email, String? access, String? expires, String? name, String? publicKey]) async {
    try {
      await cloud.createUser(userId.toString());
    } catch (e) {
      throw CloudException('Could not create cloud user with id: $userId');
    }
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
        'Cloud-Replication', toolboxAPI.DummyMapper('Cloud-Replication'));
    print('INIT GEIGER END');
  }

  /*
  * GET ANY NODE -> BASED ON THE PATH
  */
  Future<toolboxAPI.Node> getNode(String path) async {
    toolboxAPI.Node node = await storageController.get(path);
    return node;
  }

  // After replication ends, update with the compared time
  Future<void> updateReplicationNode(DateTime _actual) async {
    /// Should be defined a historic with all replication timestamps?
    /// Add type of replication into the node (full, partial)?
    try {
      print('UPDATE REPLICATION NODE');
      toolboxAPI.Node updateRepNode = await getNode(':Replication:LastReplication');
      updateRepNode.lastModified = _actual.millisecondsSinceEpoch;
      storageController.update(updateRepNode);
    } catch (e) {
      print('CREATE NEW REPLICATION NODE');
      toolboxAPI.Node parentNode =
          toolboxAPI.NodeImpl(':Replication', 'ReplicationController');
      storageController.add(parentNode);
      toolboxAPI.Node newRepNode =
          toolboxAPI.NodeImpl(':Replication:LastReplication', 'ReplicationController');
      storageController.add(newRepNode);
      newRepNode.lastModified = _actual.millisecondsSinceEpoch;
      storageController.update(newRepNode);
    }
    print('[REPLICATION NODE] UPDATED');
  }

  void updateSingleNodeCloud2Device(Event event) async {
    print('CHECK NODES');
    toolboxAPI.Node _toCheck = event.content as toolboxAPI.Node;
    String _nodePath = _toCheck.path.toString();
    try {
      toolboxAPI.Node inLocal = await getNode(_nodePath);
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
      String path, toolboxAPI.Node node, DateTime cloud) async {
    print('CHECK NODES');
    try {
      toolboxAPI.Node inLocal = await getNode(path);
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
      toolboxAPI.Node newNode = toolboxAPI.NodeImpl(path, '');
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
          toolboxAPI.Node checker = await getNode(':Global:ThreatWeight:$uuid');
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
              toolboxAPI.NodeImpl(':Global:ThreatWeight:$uuid', 'ULEI');
          Map<String, dynamic> mapper = data.toJson();
          mapper.forEach((key, value) {
            newThreatNode.addOrUpdateValue(
                toolboxAPI.NodeValueImpl(key, value.toString()));
          });
          await storageController.update(newThreatNode);
        }
      }
    }
  }

  /*void storageListenerReplication(String _username) async {
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
        bool consent = await checkConsent(node, _username);
        if (consent == true) {
          String nodeName = node.getName().toString();
          Event toCloudEvent = Event(id_event: nodeName, tlp: tlp);
          toCloudEvent.setOwner = node.getOwner.toString();
          if (tlp.toLowerCase() == 'red') {
            //GET KEYS
            try {
              toolboxAPI.Node keys = await getNode(':$nodeName:cloud');
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
  }*/

  Future<List<toolboxAPI.Node>> getAllNodes() async {
    List<toolboxAPI.Node> nodeList = [];
    try {
      toolboxAPI.Node root = await getNode('');
      getRecursiveNodes(root, nodeList);
    } catch (e) {
      print('Exception');
    }
    return nodeList;
  }

  void getRecursiveNodes(toolboxAPI.Node node, List<toolboxAPI.Node> list) async {
    list.add(node);
    Map<String, toolboxAPI.Node> children = await node.getChildren();
    children.forEach((key, value) {
      getRecursiveNodes(value, list);
    });
  }

  Future<void> cleanData(DateTime actual) async {
    print('REMOVE DATA - 180 DAYS LIMIT');

    /// COMPLETE
    /// RECURSIVE WAY
    /// CHECK TIMESTAMP > 180 DAYS: DELETE
    List<toolboxAPI.Node> checkingData = await getAllNodes();

    /// SORT NODES BY TIMESTAMP
    checkingData.sort((a, b) => a
        .lastModified
        .toString()
        .compareTo(b.lastModified.toString()));
    for (var node in checkingData) {
      DateTime nodeTime = DateTime.parse(node.lastModified.toString());
      Duration checker = actual.difference(nodeTime);
      if (checker.inDays > 180) {
        //REPLICATION TIMING STRATEGIES - DELETE NODE
        String path = node.path.toString();
        storageController.delete(path);
        print('NODE WITH PATH $path HAS BEEN REMOVED');
      }
    }
  }

  Future<bool> checkConsent(toolboxAPI.Node node, String username) async {
    bool consent = false;
    String tlp = node.visibility.toString();
    if (tlp.toLowerCase() == 'white') {
      consent = true;
    } else {
      //CHECK CONSENT
      try {
        //IF GET NODE - USER HAS NOT AGREED FOREVER - CONSENT FALSE
        toolboxAPI.Node consentNode = await getNode(':Consent:$username');
        consent = true;
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

  /// if a user receives shared event but with different owner
  /// checks pairing
  Future<void> updatePairedEvent(String username, Event event) async {
    try {
      String owner = event.owner.toString();
      toolboxAPI.Node node = await getNode(':key_$owner');
      String encryptedKey = node.getValue('key').toString();
      String agreeValue = node.getValue('agreement').toString();
      if (agreeValue=='in' || agreeValue == 'both') {
        try {
          List<String> agreements = await cloud.getMergedAccounts(username);
          if (agreements.contains(owner)==true) {
            /// check if our user has publicKey
            /// else the key will be clear
            User actualUser = await cloud.getUser(username);
            var publicKey = actualUser.getPublicKey;
            if (publicKey != null) {
              publicKey = publicKey.toString();

              final keyVal = Enc.Key.fromUtf8(publicKey);
              final enc = Enc.Encrypter(Enc.AES(keyVal, mode: Enc.AESMode.cfb64));
              final iv = Enc.IV.fromLength(128);
              //DECRYPT DATA
              encryptedKey = enc
                  .decrypt(encryptedKey.split(':')[1] as Enc.Encrypted, iv: iv);
            } else {
              encryptedKey = encryptedKey.split(':')[1];
            }

            /// DECRYPT CONTENT AND SET NEW NODE
            final keyVal1 = Enc.Key.fromUtf8(encryptedKey);
            final enc1 = Enc.Encrypter(Enc.AES(keyVal1, mode: Enc.AESMode.cfb64));
            final iv1 = Enc.IV.fromLength(128);
            //DECRYPT DATA
            var data = enc1
                .decrypt(event.content.toString() as Enc.Encrypted, iv: iv1);

            /// CREATE NODE
            toolboxAPI.Node newSharedNode = toolboxAPI.NodeImpl(event.id_event.toString(), owner);
            toolboxAPI.Visibility? visible = toolboxAPI.VisibilityExtension.valueOf(event.getTlp.toString());
            newSharedNode.visibility = visible!;
            //LOOP ALL ELEMENTS
            storageController.update(newSharedNode);
            Map<dynamic, dynamic> mapper = jsonDecode(data);
            mapper.forEach((key, value) {
              newSharedNode
                  .addOrUpdateValue(toolboxAPI.NodeValueImpl(key, value.toString()));
            });
            storageController.update(newSharedNode);
            
          }
        } catch (e) {
          throw CloudException('There is no active cloud agreement');
        }
      }
    } catch (e) {
      throw toolboxAPI.StorageException('No pairing node set up');
    }
  }
}
