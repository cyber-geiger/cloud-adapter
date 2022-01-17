import 'package:geiger_api/geiger_api.dart';
import 'package:geiger_localstorage/geiger_localstorage.dart' as toolbox_api;

class NodeListener implements toolbox_api.StorageListener {
  final toolbox_api.Node _oldNode =
      toolbox_api.NodeImpl(':', 'CloudReplication');
  final toolbox_api.Node _newNode =
      toolbox_api.NodeImpl(':', 'CloudReplication');

  Future<toolbox_api.Node> get oldnode async {
    return await _oldNode.deepClone();
  }

  Future<toolbox_api.Node> get newnode async {
    return await _newNode.deepClone();
  }

  @override
  Future<void> gotStorageChange(toolbox_api.EventType event,
      toolbox_api.Node? oldNode, toolbox_api.Node? newNode) async {
    await _oldNode
        .update(oldNode ?? toolbox_api.NodeImpl(':', 'CloudReplication'));
    await _newNode
        .update(newNode ?? toolbox_api.NodeImpl(':', 'CloudReplication'));
  }
}
