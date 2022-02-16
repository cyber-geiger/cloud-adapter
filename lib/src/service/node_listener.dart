import 'package:geiger_localstorage/geiger_localstorage.dart' as toolbox_api;

class NodeListener implements toolbox_api.StorageListener {
  List<EventChange> events = [];
  Map<EventChange, Function> eventHandler = <EventChange, Function>{};
  int numberReceivedEvents = 0;
  int numberHandledEvents = 0;

  void addEventHandler(EventChange event, Function handler) {
    try {
      print("ADD HANDLER");
      //eventHandler.putIfAbsent(event, () => handler);
      eventHandler[event] = handler;
    } catch (e) {
      print("ADD MESSAGE");
      print(e);
    }
  }

  @override
  Future<void> gotStorageChange(toolbox_api.EventType event,
      toolbox_api.Node? oldNode, toolbox_api.Node? newNode) async {
    EventChange e = EventChange(event, oldNode, newNode);
    print(
        'localStorageEventListener received a NEW EVENT ==> ${e.type}\n OLD NODE ==> ${e.oldNode} \n NEW NODE ==> ${e.newNode}');
    events.add(e);
    Function? handler = eventHandler[e];
    if (handler != null) {
      numberHandledEvents++;
      handler(e);
    } else {
      print("localStorageEventListener does not handle message type ${e.type}");
    }
  }

  List<EventChange> getEvents() {
    return events;
  }
}

class EventChange {
  final toolbox_api.EventType type;
  final toolbox_api.Node? oldNode;
  final toolbox_api.Node? newNode;

  EventChange(this.type, this.oldNode, this.newNode);

  toolbox_api.EventType get getType => type;
  toolbox_api.Node? get getOldNode => oldNode;
  toolbox_api.Node? get getNewNode => newNode;

  @override
  String toString() {
    return 'EventChange{type: $type, oldNode: $oldNode, newNode: $newNode}';
  }
}
