import 'package:geiger_api/geiger_api.dart';

class ReplicationMessageListener implements PluginListener {
  int numberReceivedMessages = 0;
  int numberHandledMessages = 0;
  List<Message> events = [];
  Map<MessageType, Function> messageHandler = {};
  final String _id;

  ReplicationMessageListener(this._id);

  @override
  void pluginEvent(GeigerUrl? url, Message msg) async {
    events.add(msg);
    numberReceivedMessages++;
    Function? handler = messageHandler[msg.type];
    if (handler != null) {
      numberHandledMessages++;
      await handler(msg);
    } else {
      print('Eventlistener $_id does not handle message type ${msg.type}');
    }
  }

  List<Message> getEvents() {
    return events;
  }

  @override
  String toString() {
    String ret = '';
    ret += 'Eventlistener "$_id" contains {\r\n';
    getEvents().forEach((element) {
      ret += '  ${element.toString()}\r\n';
    });
    ret += '}\r\n';
    return ret;
  }

  void addMessageHandler(MessageType type, Function handler) {
    messageHandler[type] = handler;
  }
}
