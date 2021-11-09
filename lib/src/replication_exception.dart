import 'dart:io';

class ReplicationException implements IOException {

  final String _message;
  final Exception? _cause;
  final StackTrace? _stackTrace;

  Exception? get cause {
    return _cause;
  }

  StackTrace? get stackTrace {
    return _stackTrace;
  }

  ReplicationException(this._message, [this._cause, this._stackTrace]);

  @override
  String toString() {
    String ret='StorageException: $_message';
    if(_cause!=null) {
      ret += '\nnested cause:\n${_cause.toString()}';
    }
    if(_stackTrace!=null)  {
      ret += '\nOffending stacktrace of nested cause:\n${_stackTrace.toString()}';
    }
    return ret;
  }
}