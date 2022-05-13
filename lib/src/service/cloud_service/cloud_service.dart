import 'dart:convert';
import 'dart:io';

import 'package:cloud_replication_package/src/cloud_models/recommendation.dart';
import 'package:cloud_replication_package/src/service/cloud_service/cloud_exception.dart';
import 'package:flutter/cupertino.dart';

//import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../../cloud_models/event.dart';
import '../../cloud_models/threat_weights.dart';
import '../../cloud_models/user.dart';
import '../../cloud_models/short_user.dart';
import '../../cloud_models/recommendation.dart';
import '../../cloud_models/security_defender_user.dart';
import '../../cloud_models/security_defenders_organization.dart';
import '../../cloud_models/threats.dart';

class CloudService {
  final String uri = "https://37.48.101.252:8443/geiger-cloud/api";

  HttpClient client1 = HttpClient()
    ..badCertificateCallback =
        ((X509Certificate cert, String host, int port) => true);

  CloudService() {
    WidgetsFlutterBinding.ensureInitialized();
  }

  /// ****************
  /// EVENT OPERATIONS
  /// ****************

  // CREATE EVENT
  Future<void> createEvent(String username, Event event) async {
    try {
      print('CREATE USER EVENT');
      final String userUri = '/store/user/$username/event';
      Uri url = Uri.parse(uri + userUri);
      print(url);
      ////SecurityContext context = //SecurityContext.defaultContext;
      //context.useCertificateChainBytes(
      //asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //context.usePrivateKeyBytes(//asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //HttpClient client = HttpClient() //context: context)
      //..badCertificateCallback =
      //((X509Certificate cert, String host, int port)=> true);
      var ioClient = IOClient(client1);
      final response = await ioClient.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'accept': '*/*',
        },
        body: jsonEncode(event.toJson()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        //client.close();
        print("EVENT CREATED");
      } else {
        print("SOMETHING WENT WRONG: " + response.statusCode.toString());
        print(response.body);
        //client.close();
        throw Exception(response.body.toString());
      }
    } catch (e) {
      print('SOME EXCEPTION OCCURED');
      throw Exception(e.toString());
    }
  }

  // UPDATE EVENT
  Future<void> updateEvent(String username, String eventId, Event event) async {
    try {
      print('UPDATE USER EVENT');
      final String userUri = '/store/user/$username/event/$eventId';
      Uri url = Uri.parse(uri + userUri);
      print(url);
      //SecurityContext context = //SecurityContext.defaultContext;
      //context.useCertificateChainBytes(
      //asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //context.usePrivateKeyBytes(//asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //HttpClient client = HttpClient() //context: context)
      //..badCertificateCallback =
      //((X509Certificate cert, String host, int port)=> true);
      var ioClient = IOClient(client1);
      final response = await ioClient.put(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'accept': 'application/json',
        },
        body: jsonEncode(event.toJson()),
      );
      if (response.statusCode == 200) {
        print("event updated");
      }
      //client.close();
      print('USER EVENT UPDATED');
    } catch (e) {
      print('SOME EXCEPTION OCCURED');
      print(e);
      throw Exception;
    }
  }

  //GET TLP WHITE EVENTS
  Future<List<Event>> getTLPWhiteEvents() async {
    try {
      print('TLP WHITE EVENTS');
      final String eventUri = '/store/event';
      Uri url = Uri.parse(uri + eventUri);
      print(url);
      //SecurityContext context = //SecurityContext.defaultContext;
      //context.useCertificateChainBytes(
      //asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //context.usePrivateKeyBytes(//asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //HttpClient client = HttpClient() //context: context)
      //..badCertificateCallback =
      //((X509Certificate cert, String host, int port)=> true);
      var ioClient = IOClient(client1);
      final response = await ioClient.get(
        url,
        headers: <String, String>{
          'accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        print('RESPONSE OK');
        List<dynamic> object = jsonDecode(response.body);
        List<Event> allEvents = object.map((e) => Event.fromJson(e)).toList();
        //client.close();
        return allEvents;
      } else {
        //client.close();
        throw Exception;
      }
    } catch (e) {
      print('SOME EXCEPTION OCCURED');
      print(e);
      throw Exception;
    }
  }

  //GET TLP WHITE EVENTS
  //FILTERED BY DATE
  Future<List<Event>> getTLPWhiteEventsDateFilter(String timestamp) async {
    try {
      print('TIMESTAMP FILTERED TLP WHITE EVENTS');
      final String eventUri = '/store/event';
      Uri url = Uri.parse(uri + eventUri);
      print(url);
      //SecurityContext context = //SecurityContext.defaultContext;
      //context.useCertificateChainBytes(
      //asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //context.usePrivateKeyBytes(//asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //HttpClient client = HttpClient() //context: context)
      //..badCertificateCallback =
      //((X509Certificate cert, String host, int port)=> true);
      var ioClient = IOClient(client1);
      final response = await ioClient.get(
        url,
        headers: <String, String>{
          'accept': 'application/json',
          'modified_since': timestamp.toString(),
        },
      );
      print(response.body);
      if (response.statusCode == 200) {
        print('RESPONSE OK');
        List<dynamic> object = jsonDecode(response.body);
        List<Event> allEvents = object.map((e) => Event.fromJson(e)).toList();
        //client.close();
        return allEvents;
      } else {
        //client.close();
        throw Exception;
      }
    } catch (e) {
      print('SOME EXCEPTION OCCURED');
      print(e);
      throw Exception;
    }
  }

  //GET LIST OF USER EVENTS
  Future<List<String>> getUserEvents(String userId) async {
    try {
      //await Future.delayed(Duration(seconds: 5));
      print('GET USER EVENT LIST');
      final String eventUri = '/store/user/$userId/event';
      Uri url = Uri.parse(uri + eventUri);
      print(url);
      //SecurityContext context = //SecurityContext.defaultContext;
      //context.useCertificateChainBytes(
      //asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //context.usePrivateKeyBytes(//asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //HttpClient client = HttpClient() //context: context)
      //..badCertificateCallback =
      //((X509Certificate cert, String host, int port)=> true);
      var ioClient = IOClient(client1);
      final response = await ioClient.get(
        url,
        headers: <String, String>{
          'accept': 'application/json',
          'content-type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        print('RESPONSE OK');
        List<String> allEvents = [];
        if ((response.body).isNotEmpty) {
          var object = jsonDecode(response.body);
          if (object.isEmpty) {
            allEvents = [];
          } else {
            allEvents = (object as List<dynamic>).cast<String>();
          }
        } else {
          allEvents = [];
        }
        //client.close();
        return allEvents;
      } else {
        //client.close();
        throw Exception;
      }
    } catch (e) {
      print('SOME EXCEPTION OCCURED');
      print(e);
      throw Exception;
    }
  }

  //GET LIST OF USER EVENTS
  //FILTERED BY DATE
  Future<List<String>> getUserEventsDateFilter(
      String userId, String fromTimestamp) async {
    try {
      print('TIMESTAMP FILTERED GET USER EVENT LIST');
      final String eventUri = '/store/user/$userId/event';
      Uri url = Uri.parse(uri + eventUri);
      print(url);
      //SecurityContext context = //SecurityContext.defaultContext;
      //context.useCertificateChainBytes(
      //asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //context.usePrivateKeyBytes(//asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      print(fromTimestamp);
      //HttpClient client = HttpClient() //context: context)
      //..badCertificateCallback =
      //((X509Certificate cert, String host, int port)=> true);
      var ioClient = IOClient(client1);
      final response = await ioClient.get(
        url,
        headers: <String, String>{
          'accept': 'application/json',
          'content-type': 'application/json',
          'modified_since': fromTimestamp,
        },
      );
      if (response.statusCode == 200) {
        List<dynamic> object = jsonDecode(response.body);
        List<String> allEvents = object.map((e) => e.toString()).toList();
        //client.close();
        return allEvents;
      } else {
        //client.close();
        throw Exception;
      }
    } catch (e) {
      print('SOME EXCEPTION OCCURED');
      print(e);
      throw Exception;
    }
  }

  //GET USER EVENT
  Future<Event> getSingleUserEvent(String userId, String eventId) async {
    try {
      print('GET SINGLE USER EVENT');
      final String eventUri = '/store/user/$userId/event/$eventId';
      Uri url = Uri.parse(uri + eventUri);
      print(url);
      //SecurityContext context = //SecurityContext.defaultContext;
      //context.useCertificateChainBytes(
      //asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //context.usePrivateKeyBytes(//asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //HttpClient client = HttpClient() //context: context)
      //..badCertificateCallback =
      //((X509Certificate cert, String host, int port)=> true);
      var ioClient = IOClient(client1);
      final response = await ioClient.get(
        url,
        headers: <String, String>{
          'accept': 'application/json',
          'content-type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        print('RESPONSE OK');
        //var object = json.decode(response.body);
        var object = jsonDecode(response.body);
        //client.close();
        return Event.fromJson(object);
      } else {
        //client.close();
        throw CloudException(
            "Exception getting the event from the cloud. Status code: " +
                response.statusCode.toString());
      }
    } catch (e) {
      print(e);
      throw CloudException("Exception getting the event from the cloud");
    }
  }

  //DELETE USER EVENT
  Future<void> deleteEvent(String username, String eventId) async {
    try {
      print('DELETE EVENT');
      final String eventUri = '/store/user/$username/event/$eventId';
      Uri url = Uri.parse(uri + eventUri);
      print(url);
      //SecurityContext context = //SecurityContext.defaultContext;
      //context.useCertificateChainBytes(
      //asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //context.usePrivateKeyBytes(//asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //HttpClient client = HttpClient() //context: context)
      //..badCertificateCallback =
      //((X509Certificate cert, String host, int port)=> true);
      var ioClient = IOClient(client1);
      final response = await ioClient.delete(
        url,
        headers: <String, String>{
          'accept': '*/*',
        },
      );
      //client.close();
      if (response.statusCode != 200) {
        throw CloudException("Exception removing the event. Status code: " +
            response.statusCode.toString());
      }
    } catch (e) {
      print(e);
      throw CloudException("Exception removing the event from the cloud");
    }
  }

  /// ***************
  /// USER OPERATIONS
  /// ***************

  //CHECK IF A USER EXIST
  Future<bool> userExists(String username) async {
    try {
      print('CHECK USER');
      final String userUri = '/store/user/$username';
      Uri url = Uri.parse(uri + userUri);
      //SecurityContext context = //SecurityContext.defaultContext;
      //context.useCertificateChainBytes(
      //asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //context.usePrivateKeyBytes(//asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //HttpClient client = HttpClient() //context: context)
      //..badCertificateCallback =
      //((X509Certificate cert, String host, int port)=> true);
      var ioClient = IOClient(client1);
      final response = await ioClient.get(url, headers: <String, String>{
        'accept': 'application/json',
        'content-type': 'application/json',
      });
      //client.close();
      if (response.statusCode == 200) {
        print('USER EXISTS');
        return true;
      } else {
        if (response.statusCode == 404) {
          print("USER NOT EXIST");
          return false;
        } else {
          print(response.statusCode.toString());
          throw Exception;
        }
      }
    } catch (e) {
      print(e);
      return false;
    }
  }

  //CHECK IF A USER EXIST
  Future<User> getUser(String username) async {
    try {
      print('CHECK USER');
      final String userUri = '/store/user/$username';
      Uri url = Uri.parse(uri + userUri);
      //SecurityContext context = //SecurityContext.defaultContext;
      //context.useCertificateChainBytes(
      //asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //context.usePrivateKeyBytes(//asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //HttpClient client = HttpClient() //context: context)
      //..badCertificateCallback =
      //((X509Certificate cert, String host, int port)=> true);
      var ioClient = IOClient(client1);
      final response = await ioClient.get(url, headers: <String, String>{
        'accept': 'application/json',
        'content-type': 'application/json',
      });
      //client.close();
      if (response.statusCode == 200) {
        print('USER EXISTS');
        var object = jsonDecode(response.body);
        return User.fromJson(object);
      } else {
        print(response.statusCode.toString());
        throw Exception;
      }
    } catch (e) {
      print(e);
      throw CloudException('This should not happen');
    }
  }

  //CREATE A NEW USER
  Future<void> createUser(String username,
      [String? email,
      String? access,
      String? expires,
      String? name,
      String? publicKey]) async {
    try {
      print('CREATE USER');
      final String userUri = '/store/user';
      Uri url = Uri.parse(uri + userUri);
      var body = {'id_user': username};
      if (email != null) {
        body['email'] = email;
      }
      if (access != null) {
        body['access'] = access;
      }
      if (expires != null) {
        body['expires'] = expires;
      }
      if (name != null) {
        body['name'] = name;
      }
      if (publicKey != null) {
        body['public_key'] = publicKey;
      }
      //SecurityContext context = //SecurityContext.defaultContext;
      //context.useCertificateChainBytes(
      //asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //context.usePrivateKeyBytes(//asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //HttpClient client = HttpClient() //context: context)
      //..badCertificateCallback =
      //((X509Certificate cert, String host, int port)=> true);
      var ioClient = IOClient(client1);
      final response = await ioClient.post(
        url,
        headers: <String, String>{
          'accept': '*/*',
          'Content-type': 'application/json'
        },
        body: jsonEncode(body),
      );
      //client.close();
      if (response.statusCode == 200) {
        print("USER CREATED");
      } else {
        print("FAILED: STATUS CODE " + response.statusCode.toString());
        throw Exception;
      }
      print('USER CREATED');
    } catch (e) {
      print('SOME EXCEPTION OCCURED');
      print(e);
      throw Exception;
    }
  }

  //GET LIST OF USERS
  Future<List<User>> getUsers() async {
    try {
      print('GET USER LIST');
      final String userUri = '/store/user';
      Uri url = Uri.parse(uri + userUri);
      print(url);
      //SecurityContext context = //SecurityContext.defaultContext;
      //context.useCertificateChainBytes(
      //asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //context.usePrivateKeyBytes(//asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //HttpClient client = HttpClient() //context: context)
      //..badCertificateCallback =
      //((X509Certificate cert, String host, int port)=> true);
      var ioClient = IOClient(client1);
      final response = await ioClient.get(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'accept': 'application/json',
        },
      );
      //client.close();
      if (response.statusCode == 200) {
        print('RESPONSE OK');
        List<dynamic> object = jsonDecode(response.body);
        List<User> allUsers = object.map((e) => User.fromJson(e)).toList();
        return allUsers;
      } else {
        print('STATUS CODE: ' + response.statusCode.toString());
        List<User> allUsers = [];
        return allUsers;
      }
    } catch (e) {
      print('SOME EXCEPTION OCCURED');
      print(e);
      throw Exception;
    }
  }

  /// USER MERGED DATA

  // MERGE INFORMATION
  Future<void> createMerge(String idUser1, String idUser2, String agreement,
      [String? type]) async {
    try {
      print('CREATE MERGE');
      String userUri =
          '/store/user/$idUser1/merge/$idUser2?agreement=$agreement';
      if (type != null) {
        userUri = userUri + '&type=$type';
      }
      //SecurityContext context = //SecurityContext.defaultContext;
      //context.useCertificateChainBytes(
      //asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //context.usePrivateKeyBytes(//asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      Uri url = Uri.parse(uri + userUri);
      print(url.toString());
      //HttpClient client = HttpClient() //context: context)
      //..badCertificateCallback =
      //((X509Certificate cert, String host, int port)=> true);
      var ioClient = IOClient(client1);
      final response = await ioClient.post(
        url,
        headers: <String, String>{
          'accept': '*/*',
        },
      );
      //client.close();
      if (response.statusCode == 200) {
        print("USER MERGED");
      } else {
        print("FAILED: STATUS CODE " + response.statusCode.toString());
        throw Exception;
      }
    } catch (e) {
      print("SOME EXCEPTION OCCURED");
      print(e);
      throw Exception;
    }
  }

  // GET LIST OF USER MERGED ACCOUNTS
  Future<List<String>> getMergedAccounts(String idUser) async {
    try {
      print('GET MERGED LIST');
      final String mergedUri = '/store/user/$idUser/merge';
      Uri url = Uri.parse(uri + mergedUri);
      //SecurityContext context = //SecurityContext.defaultContext;
      //context.useCertificateChainBytes(
      //asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //context.usePrivateKeyBytes(//asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      print(url);
      //HttpClient client = HttpClient() //context: context)
      //..badCertificateCallback =
      //((X509Certificate cert, String host, int port)=> true);
      var ioClient = IOClient(client1);
      final response = await ioClient.get(
        url,
        headers: <String, String>{
          'accept': 'application/json',
        },
      );
      //client.close();
      if (response.statusCode == 200) {
        print('RESPONSE OK');
        List<String> allMerged = [];
        if ((response.body).isNotEmpty) {
          var object = jsonDecode(response.body);
          if (object.isEmpty) {
            allMerged = [];
          } else {
            allMerged = (object as List<dynamic>).cast<String>();
          }
        } else {
          allMerged = [];
        }
        return allMerged;
      } else {
        throw CloudException(
            "Failure getting merged accounts for user: $idUser");
      }
    } catch (e) {
      print(e);
      throw CloudException("Failure getting merged account");
    }
  }

  // GET INFO OF ONE MERGED ACCOUNT
  Future<ShortUser> getMergedInfo(String idUser1, String idUser2) async {
    try {
      print('GET MERGED INFORMATION');
      final String mergedUri = '/store/user/$idUser1/merge/$idUser2';
      Uri url = Uri.parse(uri + mergedUri);
      print(url);
      //SecurityContext context = //SecurityContext.defaultContext;
      //context.useCertificateChainBytes(
      //asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //context.usePrivateKeyBytes(//asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //HttpClient client = HttpClient() //context: context)
      //..badCertificateCallback =
      //((X509Certificate cert, String host, int port)=> true);
      var ioClient = IOClient(client1);
      final response = await ioClient.get(
        url,
        headers: <String, String>{
          'accept': 'application/json',
          'content-type': 'application/json',
        },
      );
      //client.close();
      if (response.statusCode == 200) {
        print('RESPONSE OK');
        //var object = json.decode(response.body);
        var object = jsonDecode(response.body);
        return ShortUser.fromJson(object);
      } else {
        print('FAILURE: STATUS CODE ' + response.statusCode.toString());
        throw Exception;
      }
    } catch (e) {
      print('SOME EXCEPTION OCCURED');
      print(e);
      throw Exception;
    }
  }

  //DELETE MERGED INFORMATION
  Future<void> deleteMerged(String idUser1, String idUser2) async {
    try {
      print('DELETE MERGED INFORMATION');
      final String eventUri = '/store/user/$idUser1/merge/$idUser2';
      Uri url = Uri.parse(uri + eventUri);
      print(url);
      //SecurityContext context = //SecurityContext.defaultContext;
      //context.useCertificateChainBytes(
      //asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //context.usePrivateKeyBytes(//asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //HttpClient client = HttpClient() //context: context)
      //..badCertificateCallback =
      //((X509Certificate cert, String host, int port)=> true);
      var ioClient = IOClient(client1);
      final response = await ioClient.delete(
        url,
        headers: <String, String>{
          'accept': '*/*',
        },
      );
      //client.close();
      if (response.statusCode != 200) {
        throw CloudException(
            "Error deleting agreement from cloud. Status code: " +
                response.body);
      }
    } catch (e) {
      print(e);
      throw CloudException("Error deleting agreement from cloud.");
    }
  }

  //DELETE USER INFORMATION - DEVELOPMENT PORPUSES
  Future<void> deleteUser(String idUser1) async {
    try {
      print('DELETE USER INFORMATION');
      final String eventUri = '/store/user/$idUser1';
      Uri url = Uri.parse(uri + eventUri);
      print(url);
      //SecurityContext context = //SecurityContext.defaultContext;
      //context.useCertificateChainBytes(
      //asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //context.usePrivateKeyBytes(//asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //HttpClient client = HttpClient() //context: context)
      //..badCertificateCallback =
      //((X509Certificate cert, String host, int port)=> true);
      var ioClient = IOClient(client1);
      final response = await ioClient.delete(
        url,
        headers: <String, String>{
          'accept': '*/*',
        },
      );
      //client.close();
      if (response.statusCode != 200) {
        throw CloudException(
            "Error deleting USER information from cloud. Status code: " +
                response.body);
      }
    } catch (e) {
      print(e);
      throw CloudException("Error deleting user information from cloud.");
    }
  }

  /// *************************
  /// THREAT WEIGHTS OPERATIONS
  /// *************************

  //GET THREAT WEIGHTS
  Future<List<ThreatWeights>> getThreatWeights() async {
    try {
      print('GET THREAT WEIGHTS');
      final String threatUri = '/threatweights';
      Uri url = Uri.parse(uri + threatUri);
      print(url);
      //SecurityContext context = //SecurityContext.defaultContext;
      //context.useCertificateChainBytes(
      //asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //context.usePrivateKeyBytes(//asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //HttpClient client = HttpClient() //context: context)
      //..badCertificateCallback =
      //((X509Certificate cert, String host, int port)=> true);
      var ioClient = IOClient(client1);
      final response = await ioClient.get(
        url,
        headers: <String, String>{
          'accept': 'application/json',
          'content-type': 'application/json',
        },
      );
      //client.close();
      if (response.statusCode == 200) {
        print('RESPONSE OK');
        //var object = json.decode(response.body);
        List<dynamic> object = jsonDecode(response.body);

        return object.map((e) => ThreatWeights.fromJson(e)).toList();
      } else {
        print('FAILURE: STATUS CODE ' + response.statusCode.toString());
        throw Exception;
      }
    } catch (e) {
      print('SOME EXCEPTION OCCURED');
      print(e);
      throw Exception;
    }
  }

  /// *************************
  /// GEIGER THREATS OPERATIONS
  /// *************************
  Future<List<Threats>> getThreats() async {
    try {
      print('GET THREATS');
      final String threatUri = '/threats';
      Uri url = Uri.parse(uri + threatUri);
      print(url);
      //HttpClient client = HttpClient() //context: context)
      //..badCertificateCallback =
      //((X509Certificate cert, String host, int port)=> true);
      var ioClient = IOClient(client1);
      final response = await ioClient.get(
        url,
        headers: <String, String>{
          'accept': 'application/json',
          'content-type': 'application/json',
        },
      );
      //client.close();
      if (response.statusCode == 200) {
        print('RESPONSE OK');
        //var object = json.decode(response.body);
        List<dynamic> object = jsonDecode(response.body);
        return object.map((e) => Threats.fromJson(e)).toList();
      } else {
        print('FAILURE: STATUS CODE ' + response.statusCode.toString());
        throw Exception;
      }
    } catch (e) {
      print('SOME EXCEPTION OCCURED');
      print(e);
      throw Exception;
    }
  }

  /// *************************
  /// RECOMMENDATIONS OPERATIONS
  /// *************************

  //GET RECOMMENDATIONS
  Future<List<Recommendation>> getRecommendations() async {
    try {
      print('GET RECOMMENDATIONS');
      final String threatUri = '/recommendation';
      Uri url = Uri.parse(uri + threatUri);
      print(url);
      //SecurityContext context = //SecurityContext.defaultContext;
      //context.useCertificateChainBytes(
      //asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //context.usePrivateKeyBytes(//asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //HttpClient client = HttpClient() //context: context)
      //..badCertificateCallback =
      //((X509Certificate cert, String host, int port)=> true);
      var ioClient = IOClient(client1);
      final response = await ioClient.get(
        url,
        headers: <String, String>{
          'accept': 'application/json',
          'content-type': 'application/json',
        },
      );
      //client.close();
      if (response.statusCode == 200) {
        print('RESPONSE OK');
        //var object = json.decode(response.body);
        List<dynamic> object = jsonDecode(response.body);

        return object.map((e) => Recommendation.fromJson(e)).toList();
      } else {
        print('FAILURE: STATUS CODE ' + response.statusCode.toString());
        throw Exception;
      }
    } catch (e) {
      print('SOME EXCEPTION OCCURED');
      print(e);
      throw Exception;
    }
  }

  /// *************************
  /// SECURITY DEFENDERS INFO OPERATIONS
  /// *************************
  Future<List<SecurityDefendersOrganization>>
      getSecurityDefendersOrganizations() async {
    try {
      print('GET SECURITY DEFENDERS ORGANIZATIONS');
      final String secUri = '/recommendation';
      Uri url = Uri.parse(uri + secUri);
      print(url);
      //SecurityContext context = //SecurityContext.defaultContext;
      //context.useCertificateChainBytes(
      //asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //context.usePrivateKeyBytes(//asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //HttpClient client = HttpClient() //context: context)
      //..badCertificateCallback =
      //((X509Certificate cert, String host, int port)=> true);
      var ioClient = IOClient(client1);
      final response = await ioClient.get(
        url,
        headers: <String, String>{
          'accept': 'application/json',
          'content-type': 'application/json',
        },
      );
      //client.close();
      if (response.statusCode == 200) {
        print('RESPONSE OK');
        //var object = json.decode(response.body);
        List<dynamic> object = jsonDecode(response.body);
        return object
            .map((e) => SecurityDefendersOrganization.fromJson(e))
            .toList();
      } else {
        print('FAILURE: STATUS CODE ' + response.statusCode.toString());
        throw Exception;
      }
    } catch (e) {
      print('SOME EXCEPTION OCCURED');
      print(e);
      throw Exception;
    }
  }

  Future<List<String>> getSecurityDefendersOrganizationUsers(
      String idSecOrg) async {
    try {
      print('GET USER EVENT LIST');
      final String eventUri = '/store/user/$idSecOrg/event';
      Uri url = Uri.parse(uri + eventUri);
      print(url);
      //SecurityContext context = //SecurityContext.defaultContext;
      //context.useCertificateChainBytes(
      //asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //context.usePrivateKeyBytes(//asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //HttpClient client = HttpClient() //context: context)
      //..badCertificateCallback =
      //((X509Certificate cert, String host, int port)=> true);
      var ioClient = IOClient(client1);
      final response = await ioClient.get(
        url,
        headers: <String, String>{
          'accept': 'application/json',
          'content-type': 'application/json',
        },
      );
      //client.close();
      if (response.statusCode == 200) {
        print('RESPONSE OK');
        List<String> allEvents = [];
        if ((response.body).isNotEmpty) {
          var object = jsonDecode(response.body);
          if (object.isEmpty) {
            allEvents = [];
          } else {
            allEvents = (object as List<dynamic>).cast<String>();
          }
        } else {
          allEvents = [];
        }
        return allEvents;
      } else {
        throw Exception;
      }
    } catch (e) {
      print('SOME EXCEPTION OCCURED');
      print(e);
      throw Exception;
    }
  }

  Future<SecurityDefenderUser> getSecurityDefenderUser(
      String idSecOrg, String idSerOrgUser) async {
    try {
      print('GET SINGLE USER EVENT');
      final String eventUri = '/store/user/$idSecOrg/event/$idSerOrgUser';
      Uri url = Uri.parse(uri + eventUri);
      print(url);
      //SecurityContext context = //SecurityContext.defaultContext;
      //context.useCertificateChainBytes(
      //asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //context.usePrivateKeyBytes(//asset.readAsBytesSync().buffer.asUint8List(),
      //password: pass);
      //HttpClient client = HttpClient() //context: context)
      //..badCertificateCallback =
      //((X509Certificate cert, String host, int port)=> true);
      var ioClient = IOClient(client1);
      final response = await ioClient.get(
        url,
        headers: <String, String>{
          'accept': 'application/json',
          'content-type': 'application/json',
        },
      );
      //client.close();
      if (response.statusCode == 200) {
        print('RESPONSE OK');
        //var object = json.decode(response.body);
        var object = jsonDecode(response.body);
        return SecurityDefenderUser.fromJson(object);
      } else {
        throw CloudException(
            "Exception getting the event from the cloud. Status code: " +
                response.statusCode.toString());
      }
    } catch (e) {
      print(e);
      throw CloudException("Exception getting the event from the cloud");
    }
  }

  /// *******************
  /// CLOUD UTILS METHODS
  /// *******************
  List<Event> parseEvent(String responseBody) {
    final parsed = jsonDecode(responseBody).cast<Map<String, dynamic>>();
    return parsed.map<Event>((e) => Event.fromJson(e)).toList();
  }

  Future<String> generateUUID() async {
    Uri url = Uri.parse(uri + '/uuid');
    //SecurityContext context = //SecurityContext.defaultContext;
    //context.useCertificateChainBytes(
    //asset.readAsBytesSync().buffer.asUint8List(),
    //password: pass);
    //context.usePrivateKeyBytes(//asset.readAsBytesSync().buffer.asUint8List(),
    //password: pass);
    //HttpClient client = HttpClient() //context: context)
    //..badCertificateCallback =
    //((X509Certificate cert, String host, int port)=> true);
    var ioClient = IOClient(client1);
    final response = await ioClient
        .get(url, headers: <String, String>{'accept': 'text/plain'});
    //client.close();
    if (response.statusCode == 200) {
      String uuid = (response.body).toString();
      return uuid;
    } else {
      throw CloudException("FAILURE GETTING A UUID");
    }
  }
}
