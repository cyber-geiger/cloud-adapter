import 'package:geiger_localstorage/geiger_localstorage.dart' as toolboxAPI;

class NodeListener with toolboxAPI.StorageListener {
  final toolboxAPI.Node _oldNode = toolboxAPI.NodeImpl('', '');
  final toolboxAPI.Node _newNode = toolboxAPI.NodeImpl('', '');

  Future<toolboxAPI.Node> get oldnode async {
    return await _oldNode.deepClone();
  }

  Future<toolboxAPI.Node> get newnode async {
    return await _newNode.deepClone();
  }

  @override
  Future<void> gotStorageChange(
      toolboxAPI.EventType event, toolboxAPI.Node? oldNode, toolboxAPI.Node? newNode) async {
    await _oldNode.update(oldNode ?? toolboxAPI.NodeImpl('', ''));
    await _newNode.update(newNode ?? toolboxAPI.NodeImpl('', ''));
  }
}