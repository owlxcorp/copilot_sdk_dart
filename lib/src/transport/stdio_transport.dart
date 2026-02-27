import 'dart:async';
import 'dart:io';

import 'content_length_codec.dart';
import 'json_rpc_transport.dart';

/// Transport that communicates with the Copilot CLI via stdio (stdin/stdout).
///
/// Spawns the CLI process with `--headless --stdio` flags and communicates
/// via Content-Length framed JSON-RPC messages over stdin/stdout pipes.
class StdioTransport implements JsonRpcTransport {
  /// Creates a transport that spawns a CLI process.
  ///
  /// The process is started with [executable] and [arguments].
  /// Communication happens via Content-Length framed JSON-RPC over stdio.
  StdioTransport({
    required String executable,
    List<String> arguments = const [],
    String? workingDirectory,
    Map<String, String>? environment,
  })  : _executable = executable,
        _arguments = arguments,
        _workingDirectory = workingDirectory,
        _environment = environment;

  /// Creates a transport that connects to an existing process's stdin/stdout.
  ///
  /// The caller is responsible for the process lifecycle.
  StdioTransport.fromProcess(this._process)
      : _executable = '',
        _arguments = const [],
        _workingDirectory = null,
        _environment = null,
        _ownsProcess = false {
    _setupStreams();
  }

  final String _executable;
  final List<String> _arguments;
  final String? _workingDirectory;
  final Map<String, String>? _environment;
  final ContentLengthCodec _codec = ContentLengthCodec();

  Process? _process;
  bool _ownsProcess = true;
  bool _isOpen = false;
  Future<void>? _closeFuture;
  StreamController<Map<String, dynamic>>? _messageController;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  /// Serialization chain for stdin writes.
  ///
  /// Concurrent calls to [send] (e.g., multiple incoming request responses)
  /// can cause "StreamSink is bound to a stream" errors on the process stdin.
  /// We chain writes so each waits for the previous one to finish.
  Future<void>? _pendingWrite;

  /// The stderr output from the CLI process (for diagnostics).
  final StringBuffer stderrBuffer = StringBuffer();

  /// The exit code of the process, or null if still running.
  int? lastExitCode;

  /// Optional callback fired when the CLI process exits.
  void Function(int exitCode)? onProcessExit;

  /// The PID of the spawned process, or null if not started.
  int? get pid => _process?.pid;

  /// Starts the CLI process and establishes communication.
  Future<void> start() async {
    if (_isOpen) return;

    _process = await Process.start(
      _executable,
      _arguments,
      workingDirectory: _workingDirectory,
      environment: _environment,
    );

    _setupStreams();
  }

  void _setupStreams() {
    final process = _process;
    if (process == null) return;

    _messageController = StreamController<Map<String, dynamic>>.broadcast();

    // Decode stdout through Content-Length codec
    _subscription = process.stdout.transform(_codec.decoder).listen(
      _messageController!.add,
      onError: (Object error) {
        // Log decoder errors before forwarding — these are usually
        // Content-Length framing issues that kill the connection.
        stderrBuffer.write('[SDK] Decoder error: $error\n');
        _messageController!.addError(error);
      },
      onDone: () {
        _isOpen = false;
        _messageController?.close();
      },
    );

    // Capture stderr for diagnostics
    process.stderr.listen((data) {
      stderrBuffer.write(String.fromCharCodes(data));
    });

    // Capture exit code for diagnostics (fire-and-forget)
    process.exitCode.then((code) {
      lastExitCode = code;
      onProcessExit?.call(code);
    }).ignore();

    _isOpen = true;
  }

  @override
  Stream<Map<String, dynamic>> get messages {
    if (_messageController == null) {
      throw StateError('Transport not started. Call start() first.');
    }
    return _messageController!.stream;
  }

  @override
  Future<void> send(Map<String, dynamic> message) async {
    if (!_isOpen || _process == null) {
      throw StateError('Transport is not open');
    }

    final encoded = _codec.encode(message);

    // Serialize writes to prevent concurrent stdin access.
    // Dart is single-threaded so the synchronous read+set of
    // _pendingWrite is atomic (no interleaving before the await).
    final prev = _pendingWrite;
    final completer = Completer<void>();
    _pendingWrite = completer.future;

    try {
      if (prev != null) await prev;
      _process!.stdin.add(encoded);
      await _process!.stdin.flush();
    } finally {
      completer.complete();
      if (_pendingWrite == completer.future) {
        _pendingWrite = null;
      }
    }
  }

  @override
  Future<void> close() {
    final inFlight = _closeFuture;
    if (inFlight != null) return inFlight;
    if (!_isOpen) return Future<void>.value();
    final future = _closeImpl();
    _closeFuture = future;
    return future;
  }

  Future<void> _closeImpl() async {
    _isOpen = false;

    await _subscription?.cancel();
    _subscription = null;

    final process = _process;
    if (_ownsProcess && process != null) {
      await process.stdin.close();
      process.kill(ProcessSignal.sigterm);
      // Wait briefly for graceful shutdown
      await process.exitCode
          .timeout(const Duration(seconds: 5))
          .catchError((_) {
        process.kill(ProcessSignal.sigkill);
        return -1;
      });
    }

    await _messageController?.close();
    _messageController = null;
    _process = null;
  }

  @override
  bool get isOpen => _isOpen;
}
