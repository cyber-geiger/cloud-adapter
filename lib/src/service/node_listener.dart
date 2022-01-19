import 'package:geiger_localstorage/geiger_localstorage.dart' as toolbox_api;

class NodeListener implements toolbox_api.StorageListener {

  final List<EventChange> events = [];
  late final toolbox_api.StorageController storageController;

  NodeListener(this.storageController);

  @override
  Future<void> gotStorageChange(toolbox_api.EventType event,
      toolbox_api.Node? oldNode, toolbox_api.Node? newNode) async {
        print("**********************************************************");
        /*if (event.toValueString()=='delete') {
          String path = oldNode!.path;
          try {
            toolbox_api.Node? old = await storageController.getNodeOrTombstone(path);
            events.add(EventChange(toolbox_api.EventType.delete, old, null));
          } catch (e) {
            print("STORAGE CHANGE EXCEPTION");
            print(e);
          }
        } else {*/
          events.add(EventChange(event, oldNode, newNode));
        //}
  }
}

class EventChange {
  final toolbox_api.EventType type;
  final toolbox_api.Node? oldNode;
  final toolbox_api.Node? newNode;

  EventChange(this.type, this.oldNode, this.newNode);

  @override 
  String toString() {
    return 'EventChange{type: $type, oldNode: $oldNode, newNode: $newNode}';
  }
}