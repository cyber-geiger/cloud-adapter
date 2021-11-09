import 'package:geiger_localstorage/geiger_localstorage.dart' as toolboxAPI;

class NodeListener with toolboxAPI.StorageListener {
  final toolboxAPI.Node _oldNode = toolboxAPI.NodeImpl('');
  final toolboxAPI.Node _newNode = toolboxAPI.NodeImpl('');

  toolboxAPI.Node get oldnode {
    return _oldNode.deepClone();
  }

  toolboxAPI.Node get newnode {
    return _newNode.deepClone();
  }

  @override
  void gotStorageChange(toolboxAPI.EventType event, toolboxAPI.Node? oldNode, toolboxAPI.Node? newNode) {
    _oldNode.update(oldNode ?? toolboxAPI.NodeImpl(''));
    _newNode.update(newNode ?? toolboxAPI.NodeImpl(''));
  }
}