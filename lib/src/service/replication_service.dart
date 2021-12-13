library geiger_replication;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:intl/locale.dart';

import 'package:cloud_replication_package/src/cloud_models/user.dart';
import 'package:cloud_replication_package/src/replication_exception.dart';
import 'package:cloud_replication_package/src/service/cloud_exception.dart';
import 'package:cloud_replication_package/src/cloud_models/threat_dict.dart';
import 'package:cloud_replication_package/src/cloud_models/threat_weights.dart';
import 'package:cloud_replication_package/src/service/cloud_service.dart';

import 'package:geiger_localstorage/geiger_localstorage.dart' as toolbox_api;

//import 'package:logging/logging.dart';

// ignore: library_prefixes
import 'package:encrypt/encrypt.dart' as Enc;
//import 'package:flutter/cupertino.dart';

import './node_listener.dart';
import '../cloud_models/event.dart';
import '../cloud_models/short_user.dart';
import '../replication_controller.dart';

class ReplicationService implements ReplicationController {
  ///final _log = Logger('ReplicationService');

  final cloud = CloudService();

  /// Storage controller
  late toolbox_api.StorageController storageController;

  /// Storage Listener
  late toolbox_api.StorageListener storageListener;

  ReplicationService();

  @override
  Future<void> geigerReplication() async {
    print('STARTING GEIGER REPLICATION');

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
          DateTime.fromMicrosecondsSinceEpoch(timeChecker.lastModified);
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
      //print('NO REPLICATION NODE - NO REPLICATION HAS BEEN DONE');
      /// FULL REPLICATION TAKES PLACE
      _fullRep = true;
    }

    // 2. GET USER DATA - CHECK USER IN CLOUD
    String _username;
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
      //print('Not user data retrieved');
      toolbox_api.StorageException('USER DATA NOT FOUND. ERROR');
      exit(1);
    }
    print(_username);

    /// CLOUD TO LOCAL REPLICATION
    print("[2nd FLOW] - CLOUD TO LOCAL");
    await cloudToLocalReplication(_username, _actual, _fromDate, _fullRep);

    /// LOCAL TO CLOUD REPLICATION
    print("[3rd FLOW] - LOCAL TO CLOUD");
    await localToCloudReplication(_username, _actual, _fromDate, _fullRep);

    /// UPDATE WHEN LAST REPLICATION TOOK PLACE
    print("[4th FLOW] - UPDATE WHEN LAST REPLICAION TOOK PLACE");
    await updateReplicationNode(_actual);

    /// STORAGE LISTENER
    print("[5th FLOW] - LISTENER REPLICATION");

    ///await storageListenerReplication(_username);
  }

  Future<void> cloudToLocalReplication(String _username, DateTime _actual,
      DateTime _fromDate, bool _fullRep) async {
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
      //String tlp = singleOne.tlp.toString();
      String id = singleOne.id_event.toString();
      String owner = singleOne.owner.toString();
      if (owner != _username) {
        if (type.toLowerCase() == "keyvalue") {
          print('NO E2EE');
          updateLocalNodeWithCloudEvent(singleOne);
        }
        if (type.toLowerCase() == "user") {
          print('E2EE');
          //GET KEYS
          try {
            toolbox_api.Node keys = await getNode(':Keys:$id');
            final hexEncodedKey = keys.getValue('key').toString();

            /// keyPattern: key=["aes-256-cfb:JWWY+/E5Xppta3AsSIsGrWUOKHmv0w3cbfH5VlsG62Y="]
            final onlyKey = hexEncodedKey.split(':');
            final String decodedKey = hex.decode(onlyKey[1]).toString();

            final keyVal = Enc.Key.fromUtf8(decodedKey);
            final iv = Enc.IV.fromLength(16);
            final enc = Enc.Encrypter(Enc.AES(keyVal, mode: Enc.AESMode.cfb64));

            //DECRYPT DATA
            String decrypted = enc
                .decrypt(singleOne.content.toString() as Enc.Encrypted, iv: iv);
            singleOne.setContent = decrypted.toString();
            updateLocalNodeWithCloudEvent(singleOne);
          } catch (e) {
            toolbox_api.StorageException('FAILURE GETTING KEYS FOR NODE: $id');
          }
        }
      } else {
        await updatePairedEvent(_username, singleOne);
      }
    }

    ///FETCH ALL TLP WHITE EVENTS - FREELY SHARED
    ///STORE THEM IN :Global:type:UUID
    await updateTLPWhiteEvents(_fullRep, _fromDate);

    /// GET THREAT WEIGHTS
    /// STORE :Global:ThreatWeight:UUID
    await updateThreatWeights();
    //print('FIRST DIAGRAM COMPLETED');
  }

  Future<void> localToCloudReplication(String _username, DateTime _actual,
      DateTime _fromDate, bool _fullRep) async {
    /// START OF THE SECOND DIAGRAM
    /// START CLEANING DATA AND REMOVING TOMBSTONES
    cleanData(_actual);
    List<toolbox_api.Node> nodeList = [];
    if (_fullRep == true) {
      /// FIND ALL THE NODES
      nodeList = await getAllNodes();
    } else {
      /// ASK FOR SEARCH CRITERIA NODE BASED
      //print('PARTIAL REPLICATION');
      nodeList = await getAllNodesLastModified(_fromDate);
    }
    print(nodeList);

    /// SORT NODES BY TIMESTAMP
    nodeList.sort((a, b) => DateTime.fromMicrosecondsSinceEpoch(a.lastModified)
        .compareTo(DateTime.fromMicrosecondsSinceEpoch(b.lastModified)));

    /// GET ALL EVENTS OF A USER - THE NAME CAN BE ANYTHING
    /// UUID IS RECOMMENDED BUT NOT MANDATORY
    /// CONVERT ALL TO NODES AND CHECK
    List<toolbox_api.Node> cloudNodeList = [];
    List<String> userEvents = [];
    try {
      userEvents = await cloud.getUserEvents(_username);
      for (var cloudEvent in userEvents) {
        try {
          Event newCloudEvent =
              await cloud.getSingleUserEvent(_username, cloudEvent);
          cloudNodeList.add(convertJsonStringToNode(newCloudEvent.content!));
        } catch (e) {
          print("ERROR GETTING SINGLE USER EVENT");
        }
      }
    } catch (e) {
      print("ERROR GETTING CLOUD USER EVENTS");
    }

    if (nodeList.isEmpty == false) {
      for (var sorted in nodeList) {
        /// CHECK TLP
        String tlp = sorted.visibility.toValueString();
        String identifier = sorted.name.toString();
        //print(identifier);
        /// CHECK CONSENT
        /// TBD
        /// 3 AGREEMENTS: NEVER, NO ONCE, AGREE ONCE
        /// CREATE EVENT
        String uuid = await cloud.generateUUID();
        Event toCheck = Event(id_event: uuid, tlp: tlp.toUpperCase());
        toCheck.encoding = 'ascii';
        print("visibility of node is TLP: " + tlp);
        if (tlp.toLowerCase() == 'red') {
          try {
            toolbox_api.Node keys = await getNode(':Keys:$identifier');
            final hexEncodedKey = keys.getValue('key').toString();

            /// keyPattern: key=["aes-256-cfb:JWWY+/E5Xppta3AsSIsGrWUOKHmv0w3cbfH5VlsG62Y="]
            final onlyKey = hexEncodedKey.split(':');
            final String decodedKey = hex.decode(onlyKey[1]).toString();

            final keyVal = Enc.Key.fromUtf8(decodedKey);
            final iv = Enc.IV.fromLength(16);
            final enc = Enc.Encrypter(Enc.AES(keyVal, mode: Enc.AESMode.cfb64));

            Enc.Encrypted encrypted =
                enc.encrypt(await convertNodeToJsonString(sorted), iv: iv);
            toCheck.content = encrypted.toString();
          } catch (e) {
            toCheck.content = await convertNodeToJsonString(sorted);
            toolbox_api.StorageException('FAILURE GETTING KEYS');
          }
          toCheck.type = 'user_object';
        } else {
          toCheck.type = 'keyvalue';
          toCheck.content = await convertNodeToJsonString(sorted);
        }
        //CHECK IF EVENT IN CLOUD
        try {
          print("NODE RETRIEVED");
          // IF OK
          // CHECK TIMESTAMP
          // IF NEEDED -> PUT
          if (cloudNodeList.contains(sorted)) {
            int index = cloudNodeList.indexOf(sorted);
            DateTime toCompare = DateTime.fromMicrosecondsSinceEpoch(
                cloudNodeList[index].lastModified);
            DateTime nodeTime =
                DateTime.fromMicrosecondsSinceEpoch(sorted.lastModified);
            //AS IN CLOUD, COMPARE DATETIMES
            Duration _diff = nodeTime.difference(toCompare);
            if (_diff.inDays > 0) {
              await cloud.updateEvent(_username, userEvents[index], toCheck);
            }
          } else {
            await cloud.createEvent(_username, toCheck);
          }
        } catch (e) {
          // IF NO EVENT IS RETURNED -> POST NEW EVENT
          await cloud.createEvent(_username, toCheck);
        }
      }
    }
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
      toolbox_api.Node agreement = await getNode(':Local:Pairing:$userId2');
      String agreeType = await agreement
          .getValue('agreement')
          .then((value) => value!.getValue("en").toString());
      String typo = await agreement
          .getValue('type')
          .then((value) => value!.getValue("en").toString());

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
        await cloud.createUser(userId1);
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
        if (agreeUser1.contains(userId2) == false) {
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
      //print(e);
      throw toolbox_api.StorageException('PAIRING NODE NOT FOUND');
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

    try {
      await storageController.delete(":Local:Pairing:$userId2");
    } catch (e) {
      throw ReplicationException("Pairing Node not found");
    }

    /// check cloud users
    bool user1Exists = await cloud.userExists(userId1);
    if (user1Exists == false) {
      throw ReplicationException(
          '$userId1 does not exist in cloud. No unpair is possible.');
    }
    /*bool user2Exists = await cloud.userExists(userId2);
    if (user2Exists == false) {
      throw ReplicationException('$userId2 does not exist in cloud. No unpair is possible.');
    }*/

    /// check userId1 agreements
    try {
      List<String> agreeUser1 = await cloud.getMergedAccounts(userId1);
      if (agreeUser1.contains(userId2) == true) {
        try {
          print("AGREEMENT SET");
          await cloud.deleteMerged(userId1, userId2);
        } catch (e) {
          print("SOMETHING WENT WRONG REP TEST");
          throw ReplicationException('Cloud Exception: ' + e.toString());
        }
      } else {
        throw ReplicationException(
            'No active agreement between $userId1 and $userId2');
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
  Future<void> shareNode(
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
              final keyVal = Enc.Key.fromUtf8(encryptedKey);
              final enc =
                  Enc.Encrypter(Enc.AES(keyVal, mode: Enc.AESMode.cfb64));
              final iv = Enc.IV.fromLength(16);
              Enc.Encrypted encrypted = enc
                  .encrypt(await convertNodeToJsonString(toShareNode), iv: iv);
              toPostEvent.setContent = encrypted.toString();
            } catch (e) {
              print("ISSUE ENCRYPTING DATA");
              toPostEvent.setContent =
                  await convertNodeToJsonString(toShareNode);
            }
            await cloud.createEvent(senderUserId, toPostEvent);
          } else {
            throw CloudException('There is no active cloud agreement');
          }
        } catch (e) {
          throw CloudException('There is no active cloud agreement');
        }
      }
    } catch (e) {
      throw ReplicationException('Key Node not found');
    }
  }

  @override
  Future<void> getSharedNodes(
      String receiverUserId, String senderUserId) async {
    /// get receiverNodes
    /// cloud API retrieves also the shared ones
    /// check the Event owner to differenciate
    try {
      print("GET SHARED NODES BETWEEN TWO PAIRED USER/DEVICE");
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
                print("ISSUE ENCRYPTING DATA");
                encryptedKey = publicKey;
              }
            }

            /// get user nodes
            List<String> allEvents = await cloud.getUserEvents(receiverUserId);
            for (var event in allEvents) {
              Event newEvent =
                  await cloud.getSingleUserEvent(receiverUserId, event);
              var owner = newEvent.getOwner;
              if (owner != null) {
                owner = owner.toString();
                if (owner == senderUserId) {
                  Map<String, dynamic> data;
                  if (newEvent.content != null) {
                    try {
                      /// DECRYPT CONTENT AND SET NEW NODE
                      final keyVal1 =
                          Enc.Key.fromUtf8(encryptedKey.split(':')[1]);
                      final enc1 = Enc.Encrypter(
                          Enc.AES(keyVal1, mode: Enc.AESMode.cfb64));
                      final iv1 = Enc.IV.fromLength(16);
                      //DECRYPT DATA
                      data = json.decode(enc1.decrypt(
                          (newEvent.content!) as Enc.Encrypted,
                          iv: iv1));
                    } catch (e) {
                      data = json.decode(newEvent.content!);
                    }

                    /// CREATE NODE
                    toolbox_api.Node newSharedNode =
                        convertJsonStringToNode(json.encode(data));
                    print(newSharedNode);
                    await storageController.addOrUpdate(newSharedNode);
                  }
                }
              }
            }
          }
        } catch (e) {
          throw CloudException('There is no active cloud agreement');
        }
      }
    } catch (e) {
      throw toolbox_api.StorageException('Key Node not found');
    }
  }

  @override
  Future<void> createCloudUser(String userId,
      [String? email,
      String? access,
      String? expires,
      String? name,
      String? publicKey]) async {
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
  @override
  Future<toolbox_api.StorageController> initGeigerStorage(
      toolbox_api.StorageController storage) async {
    //print('[REPLICATION] INIT GEIGER STORAGE');
    //WidgetsFlutterBinding.ensureInitialized();

    //await toolbox_api.StorageMapper.initDatabaseExpander();
    //storageController = toolbox_api.GenericController('Cloud-Replication', toolbox_api.SqliteMapper('dbFileName.bd'));
    //return storageController = toolbox_api.GenericController(
    //'Cloud-Replication', toolbox_api.DummyMapper('Cloud-Replication'));
    return storageController = storage;
  }

  /*
  * GET ANY NODE -> BASED ON THE PATH
  */
  Future<toolbox_api.Node> getNode(String path) async {
    toolbox_api.Node node = await storageController.get(path);
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
      await storageController.update(updateRepNode);
    } catch (e) {
      //print('CREATE NEW REPLICATION NODE');
      toolbox_api.Node parentNode =
          toolbox_api.NodeImpl(':Local:Replication', 'ReplicationController');
      await storageController.add(parentNode);
      toolbox_api.Node newRepNode = toolbox_api.NodeImpl(
          ':Local:Replication:LastReplication', 'ReplicationController');

      /// storageController.add(newRepNode);
      newRepNode.lastModified = _actual.millisecondsSinceEpoch;
      await storageController.add(newRepNode);
    }
    //print('[REPLICATION NODE] UPDATED');
  }

  void updateLocalNodeWithCloudEvent(Event event) async {
    //print('CHECK NODES');
    toolbox_api.Node _toCheck = convertJsonStringToNode(event.content!);
    String _nodePath = _toCheck.path.toString();
    try {
      toolbox_api.Node inLocal = await getNode(_nodePath);
      //CHECK TIMESTAMP
      DateTime cloud = DateTime.parse(event.last_modified.toString());

      DateTime local =
          DateTime.fromMicrosecondsSinceEpoch(inLocal.lastModified);
      Duration _diff = local.difference(cloud);
      if (_diff.inDays <= 0) {
        await storageController.update(_toCheck);
      }
    } catch (e) {
      //print('NODE NOT FOUND - CREATE ONE');
      await storageController.add(_toCheck);
    }
  }

  Future<void> updateLocalNodeWithNewNode(
      String path, toolbox_api.Node node, DateTime cloud) async {
    //print('CHECK NODES');
    try {
      toolbox_api.Node inLocal = await getNode(path);
      DateTime local =
          DateTime.fromMicrosecondsSinceEpoch(inLocal.lastModified);
      Duration _diff = local.difference(cloud);
      if (_diff.inDays <= 0) {
        await storageController.update(node);
      }
    } catch (e) {
      //print('NODE DO NOT EXIST - CREATE ONE');
      await storageController.add(node);
    }
  }

  Future<void> updateTLPWhiteEvents(bool _fullRep, DateTime _fromDate) async {
    print("TLP WHUITE EVENTS");
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
      String uuid = free.id_event;
      DateTime cloudTimestamp = DateTime.parse(free.last_modified.toString());
      if (free.content.toString().isNotEmpty) {
        try {
          ///var content = jsonDecode(free.content!);
          String nodePath = ':Global:$typeTLP:$uuid';

          /// CHECK IF typeTLP node created
          try {
            toolbox_api.Node typeChecker = await getNode(':Global:$typeTLP');
            print(typeChecker.name.toString());
          } catch (e) {
            /// CREATE NODE FOR TYPE of TLP WHITE EVENT
            toolbox_api.Node typeChecker =
                toolbox_api.NodeImpl(':Global:$typeTLP', free.owner.toString());
            toolbox_api.Visibility? checkerVisible =
                toolbox_api.VisibilityExtension.valueOf("white");
            if (checkerVisible != null) {
              typeChecker.visibility = checkerVisible;
            }
            await storageController.add(typeChecker);
          }
          toolbox_api.Node newRepNode =
              toolbox_api.NodeImpl(nodePath, free.owner.toString());
          toolbox_api.Visibility? visible =
              toolbox_api.VisibilityExtension.valueOf(free.getTlp.toString());
          if (visible != null) {
            newRepNode.visibility = visible;
          }
          //LOOP ALL ELEMENTS
          newRepNode.addOrUpdateValue(
              toolbox_api.NodeValueImpl("tlpWHITE", free.content!));
          //await storageController.update(newRepNode);
          /*Map<dynamic, dynamic> mapper = content;*/
          /*mapper.forEach((key, value) {
            newRepNode.addOrUpdateValue(
                toolbox_api.NodeValueImpl(key, value.toString()));
          });*/
          await updateLocalNodeWithNewNode(
              nodePath, newRepNode, cloudTimestamp);
        } catch (e) {
          //print("CONTENT TYPE NOT IN JSON FORMAT");
        }
      }
    }
  }

  /// STORE :Global:ThreatWeight:UUID
  Future<void> updateThreatWeights() async {
    print('UPDATE THREAT WEIGHTS');
    try {
      print("THREAET WEIGHTS NODE EXISTS");
      toolbox_api.Node typeChecker = await getNode(':Global:ThreatWeight');
      print(typeChecker.name.toString());
    } catch (e) {
      /// CREATE NODE FOR TYPE of TLP WHITE EVENT
      print("THREAT WEIGHT NODE TO BE CREATED");
      toolbox_api.Node typeChecker =
          toolbox_api.NodeImpl(':Global:ThreatWeight', 'ULEI');
      toolbox_api.Visibility? checkerVisible =
          toolbox_api.VisibilityExtension.valueOf("white");
      if (checkerVisible != null) {
        typeChecker.visibility = checkerVisible;
      }
      await storageController.add(typeChecker);
    }
    List<ThreatWeights> weights = await cloud.getThreatWeights();
    for (var weight in weights) {
      String? uuid = weight.idThreatweights;
      ThreatDict? data = weight.threatDict;
      if (uuid != null && data != null) {
        try {
          toolbox_api.Node checker =
              await getNode(':Global:ThreatWeight:$uuid');
          /*Map<String, dynamic> mapper = data.toJson();
          mapper.forEach((key, value) {
            checker.addOrUpdateValue(
                toolbox_api.NodeValueImpl(key, value.toString()));
          });*/
          // add all the fields in a single json string
          checker.addOrUpdateValue(
              toolbox_api.NodeValueImpl('threatJson', jsonEncode(data)));
          print(checker);
          await storageController.update(checker);
        } catch (e) {
          toolbox_api.Node newThreatNode =
              toolbox_api.NodeImpl(':Global:ThreatWeight:$uuid', 'ULEI');
          toolbox_api.Visibility? visible =
              toolbox_api.VisibilityExtension.valueOf("white");
          if (visible != null) {
            newThreatNode.visibility = visible;
          }
          /*Map<String, dynamic> mapper = data.toJson();
          mapper.forEach((key, value) {
            newThreatNode.addOrUpdateValue(
                toolbox_api.NodeValueImpl(key, value.toString()));
          });*/
          newThreatNode.addOrUpdateValue(
              toolbox_api.NodeValueImpl('threatJson', jsonEncode(data)));
          print(newThreatNode);
          await storageController.add(newThreatNode);
        }
      }
    }
  }

  Future<void> storageListenerReplication(String _username) async {
    ///ALL ABOUT LISTENER
    var listener = NodeListener();
    var sc = toolbox_api.SearchCriteria();
    storageController.registerChangeListener(listener, sc);

    toolbox_api.Node node = await listener.newnode;
    toolbox_api.Node oldNode = await listener.oldnode;

    String eventType = '';

    // If 'delete' check directly with the cloud
    if (eventType.toString() == 'delete') {
      String eventId = node.name.toString();
      try {
        Event checker = await cloud.getSingleUserEvent(_username, eventId);
        print(checker.getIdEvent.toString());
        //IF EVENT RETRIEVED IS BECAUSE EXISTS -> DELETE
        await cloud.deleteEvent(_username, eventId);
      } catch (e) {
        print('NODE NOT IN cloud. NOTHING TO DO');
      }
    } else {
      /// CREATE, UPDATE OR RENAME A NODE
      /// FOLLOW STEPS
      /// TLP
      String tlp = node.visibility.toValueString();
      if (tlp.toLowerCase() == 'black') {
        print('BLACK TLP NODES MUST NOT BE REPLICATED');
      } else {
        //METHOD CHECK CONSENT
        //RETURN BOOLEAN
        //IF TRUE - CONTINUE - ELSE - END
        bool consent = await checkConsent(node, _username);
        if (consent == true) {
          String nodeName = node.name.toString();
          Event toCloudEvent = Event(id_event: nodeName, tlp: tlp);
          toCloudEvent.owner = node.owner.toString();
          toCloudEvent.encoding = 'ascii';
          if (tlp.toLowerCase() == 'red') {
            //GET KEYS
            try {
              toolbox_api.Node keys = await getNode(':Keys:$nodeName');
              final hexEncodedKey = keys.getValue('key').toString();

              /// keyPattern: key=["aes-256-cfb:JWWY+/E5Xppta3AsSIsGrWUOKHmv0w3cbfH5VlsG62Y="]
              final onlyKey = hexEncodedKey.split(':');
              final String decodedKey = hex.decode(onlyKey[1]).toString();

              final keyVal = Enc.Key.fromUtf8(decodedKey);
              final iv = Enc.IV.fromLength(16);
              final enc =
                  Enc.Encrypter(Enc.AES(keyVal, mode: Enc.AESMode.cfb64));

              Enc.Encrypted encrypted = enc.encrypt(node.toString(), iv: iv);
              toCloudEvent.setContent = encrypted.toString();
              toCloudEvent.setType = 'user_object';
            } catch (e) {
              toolbox_api.StorageException('FAILURE GETTING KEYS');
            }
          } else {
            toCloudEvent.setContent = node.toString();
            toCloudEvent.setType = 'keyvalue';
          }
          //CONTINUE TO REPLICATE
          try {
            Event checker = await cloud.getSingleUserEvent(_username, nodeName);
            print(checker.getIdEvent.toString());
            if (eventType.toString() == 'create') {
              //UPDATE
              await cloud.updateEvent(_username, nodeName, toCloudEvent);
            }
            if (eventType.toString() == 'update') {
              //UPDATE
              await cloud.updateEvent(_username, nodeName, toCloudEvent);
            }
            if (eventType.toString() == 'rename') {
              //CHECK PREVIOUS ONE
              try {
                Event oldChecker = await cloud.getSingleUserEvent(
                    _username, oldNode.name.toString());
                //IF EXISTED - DELETE
                //THEN - CREATE
                await cloud.deleteEvent(
                    _username, oldChecker.id_event.toString());
                await cloud.updateEvent(_username, nodeName, toCloudEvent);
              } catch (e) {
                //PREVIOUS ONE NOT IN CLOUD
                //THEN - UPDATE NEW ONE
                await cloud.updateEvent(_username, nodeName, toCloudEvent);
              }
            }
          } catch (e) {
            //print('NODE NOT IN cloud.');
            if (eventType.toString() == 'create') {
              //CREATE
              await cloud.createEvent(_username, toCloudEvent);
            }
            if (eventType.toString() == 'update') {
              //CREATE
              await cloud.createEvent(_username, toCloudEvent);
            }
            if (eventType.toString() == 'rename') {
              //CHECK PREVIOUS ONE
              try {
                Event oldChecker = await cloud.getSingleUserEvent(
                    _username, oldNode.name.toString());
                //IF EXISTED - DELETE
                //THEN - CREATE
                await cloud.deleteEvent(
                    _username, oldChecker.id_event.toString());
                await cloud.createEvent(_username, toCloudEvent);
              } catch (e) {
                //PREVIOUS ONE NOT IN CLOUD
                //THEN - CREATE
                await cloud.createEvent(_username, toCloudEvent);
              }
            }
          }
        } else {
          //print('NO CONSENT');
        }
      }
    }
  }

  Future<List<toolbox_api.Node>> getAllNodes() async {
    print("GET ALL NODES IN A RECURSIVE WAY");
    List<toolbox_api.Node> nodeList = [];
    try {
      toolbox_api.Node root = await getNode(':');
      print(root);
      print("ROOT NODE JUST PRINTED");
      nodeList = await getRecursiveNodes(root, nodeList);
    } catch (e) {
      //print('Exception');
    }
    return nodeList;
  }

  Future<List<toolbox_api.Node>> getRecursiveNodes(
      toolbox_api.Node node, List<toolbox_api.Node> list) async {
    print("RECURSIVE METHOD");
    list.add(node);
    Map<String, toolbox_api.Node> children = await node.getChildren();
    print("CHILDREN LIST");
    print(children);
    children.forEach((key, value) async {
      print(key);
      print(value);
      list = await getRecursiveNodes(value, list);
    });
    return list;
  }

  Future<List<toolbox_api.Node>> getAllNodesLastModified(
      DateTime filter) async {
    String lastModified = filter.microsecondsSinceEpoch.toString();
    toolbox_api.SearchCriteria criteria =
        toolbox_api.SearchCriteria(nodeValueLastModified: lastModified);
    List<toolbox_api.Node> nodeList = await storageController.search(criteria);
    return nodeList;
  }

  Future<void> cleanData(DateTime actual) async {
    //print('REMOVE DATA - 180 DAYS LIMIT');

    /// COMPLETE
    /// RECURSIVE WAY
    /// CHECK TIMESTAMP > 180 DAYS: DELETE
    List<toolbox_api.Node> checkingData = await getAllNodes();

    /// SORT NODES BY TIMESTAMP
    checkingData.sort((a, b) =>
        a.lastModified.toString().compareTo(b.lastModified.toString()));
    for (var node in checkingData) {
      DateTime nodeTime =
          DateTime.fromMicrosecondsSinceEpoch(node.lastModified);
      Duration checker = actual.difference(nodeTime);
      if (checker.inDays > 180) {
        //REPLICATION TIMING STRATEGIES - DELETE NODE
        String path = node.path.toString();
        storageController.delete(path);
        //print('NODE WITH PATH $path HAS BEEN REMOVED');
      }
    }
  }

  Future<bool> checkConsent(toolbox_api.Node node, String username) async {
    bool consent = false;
    String tlp = node.visibility.toValueString();
    if (tlp.toLowerCase() == 'white') {
      consent = true;
    } else {
      //CHECK CONSENT
      try {
        //IF GET NODE - USER HAS NOT AGREED FOREVER - CONSENT FALSE
        toolbox_api.Node consentNode = await getNode(':Consent:$username');
        print(consentNode.path.toString());
        consent = true;
      } catch (e) {
        //No consent set.
        //print('NEED TO ASK CONSENT');
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
            storageController.update(newSharedNode);
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
      List customFields = mapper['custom_fields'];
      toolbox_api.Node node = toolbox_api.NodeImpl(path, owner);
      toolbox_api.Visibility? checkerVisible =
          toolbox_api.VisibilityExtension.valueOf(visibility);
      if (checkerVisible != null) {
        node.visibility = checkerVisible;
      }
      node.lastModified = lastModified;

      for (var custom in customFields) {
        var key = custom['key'];
        var value = custom['value'];
        var nodeDescription = custom['nodeDescription'];
        var valueTranslations = custom['valueTranslations'];
        var descriptionTranslations = custom['descriptionTranslations'];
        toolbox_api.NodeValue nodeValue =
            toolbox_api.NodeValueImpl(key, value.toString());
        for (var translation in valueTranslations) {
          nodeValue.setValue(translation['value'],
              Locale.fromSubtags(languageCode: translation['key']));
        }
        if (nodeDescription != null) {
          nodeValue.setDescription(nodeDescription);
          for (var description in descriptionTranslations) {
            nodeValue.setValue(description['value'],
                Locale.fromSubtags(languageCode: description['key']));
          }
        }
        node.addOrUpdateValue(nodeValue);
      }

      return node;
    } catch (e) {
      print(e);
      throw ReplicationException(
          "[REPLICATION EXCEPTION] FAIL PASSING EVENT JSON STRING CONTENT TYPE TO NODE");
    }
  }

  Future<String> convertNodeToJsonString(toolbox_api.Node node) async {
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
      String stringConverted = json.encode(converted);
      return stringConverted;
    } catch (e) {
      print(e);
      throw ReplicationException(
          "[REPLICATION EXCEPTION] FAIL CONVERT NODE TO JSON STRING");
    }
  }
}
