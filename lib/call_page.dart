import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:wakelock/wakelock.dart';

class CallPage extends StatefulWidget {
  final String name;
  final String roomId;

  const CallPage({super.key, required this.name, required this.roomId});

  @override
  _CallPageState createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  IO.Socket? socket;

  @override
  void initState() {
    _remoteRenderer.initialize();
    _localRenderer
        .initialize()
        .then((_) => _createPeerConnection())
        .then((_) => _createLocalStream());

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    Wakelock.enable(); // prevent screen from sleeping

    _connectSocket();

    super.initState();
  }

  Future<PermissionStatus> _checkCameraPermission() async {
    var status = await Permission.camera.status;
    if (status.isDenied) {
      // We didn't ask for permission yet or the permission has been denied before but not permanently.
      status = await Permission.camera.request();
    }
    return status;
  }

  Future<PermissionStatus> _checkMicrophonePermission() async {
    var status = await Permission.microphone.status;
    if (status.isDenied) {
      // We didn't ask for permission yet or the permission has been denied before but not permanently.
      status = await Permission.microphone.request();
    }
    return status;
  }

  // create localstream
  _createLocalStream() async {
    var micStatus = await _checkCameraPermission();
    var cameraStatus = await _checkMicrophonePermission();
    if (micStatus.isGranted && cameraStatus.isGranted) {
      final Map<String, dynamic> mediaConstraints = {
        'audio': true,
        'video': {
          'facingMode': 'user',
          'mandatory': {
            'minWidth': '640',
            'minHeight': '320',
          },
        },
      };
      MediaStream stream =
          await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _localStream = stream;
      _localRenderer.srcObject = stream;

      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      setState(() {});
    }
  }

  void _connectSocket() {
    print("connect server");
    const url = "";
    socket = IO.io(url, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    socket!.connect();
    socket!.on('connect', (_) {
      print('connected to signaling server');
      socket!.emit('join', {'name': widget.name, 'room': widget.roomId});
    });

    socket!.on("start", (_) async {
      _createOffer();
    });

    socket!.on('offer', (data) async {
      print("recv offer");
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(data['sdp'], data['type']),
      );
      _createAnswer();
    });

    socket!.on('answer', (data) async {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(data['sdp'], data['type']),
      );
    });

    socket!.on('ice_candidate', (data) async {
      await _peerConnection!.addCandidate(
        RTCIceCandidate(
          data['candidate'],
          data['sdpMid'],
          data['sdpMLineIndex'],
        ),
      );
    });

    socket!.on('disconnect', (_) {
      print('disconnected from signaling server');
    });
  }

  _createPeerConnection() async {
    Map<String, dynamic> configuration = {
      "iceServers": [
        {
          "urls": ["stun:stun.l.google.com:19302"]
        },
      ],
      'sdpSemantics': 'unified-plan',
    };

    final pc = await createPeerConnection(configuration);

    pc.onIceCandidate = (candidate) {
      socket!.emit('ice_candidate', {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    pc.onTrack = (event) {
      _remoteRenderer.srcObject = event.streams[0];
      setState(() {});
    };

    _peerConnection = pc;
  }

  void _createOffer() async {
    RTCSessionDescription description = await _peerConnection!
        .createOffer({'offerToReceiveVideo': 1, 'offerToReceiveAudio': 1});
    await _peerConnection!.setLocalDescription(description);
    socket!.emit('offer', {
      'sdp': description.sdp,
      'type': description.type,
      'room': widget.roomId,
    });
  }

  void _createAnswer() async {
    RTCSessionDescription description = await _peerConnection!
        .createAnswer({'offerToReceiveVideo': 1, 'offerToReceiveAudio': 1});
    await _peerConnection!.setLocalDescription(description);
    socket!.emit('answer', {
      'sdp': description.sdp,
      'type': description.type,
      'room': widget.roomId,
    });
  }

  void _stopCall() {
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _peerConnection?.close();
    socket?.disconnect();
    socket?.off("connect");
    socket?.off("start");
    socket?.off("offer");
    socket?.off("answer");
    socket?.off("ice_candidate");
    socket?.off("disconnect");

    Wakelock.disable(); // 화면이 꺼지지 않도록 해제
  }

  void _hangup() {
    _stopCall();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: OrientationBuilder(
        builder: (context, orientation) {
          return Stack(
            children: <Widget>[
              Positioned.fill(
                child: Container(
                  color: Colors.black87,
                  child: RTCVideoView(
                    _remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
              Positioned(
                left: 20.0,
                top: 20.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Container(
                    width: orientation == Orientation.portrait ? 90.0 : 120.0,
                    height: orientation == Orientation.portrait ? 120.0 : 90.0,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.white, width: 5.0),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: RTCVideoView(_localRenderer,
                          mirror: true,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: RawMaterialButton(
                    onPressed: _hangup,
                    shape: const CircleBorder(),
                    fillColor: Colors.red,
                    padding: const EdgeInsets.all(20.0),
                    child: const Icon(
                      Icons.call_end,
                      color: Colors.white,
                      size: 30.0,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge); // Restore system UI mode

    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }
}
