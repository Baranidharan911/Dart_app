// audio_calling.dart

// ignore_for_file: prefer_const_constructors, deprecated_member_use

import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioCallScreen extends StatefulWidget {
  final String appId;
  final String channelName;
  final String token;

  const AudioCallScreen({
    Key? key,
    required this.appId,
    required this.channelName,
    required this.token,
  }) : super(key: key);

  @override
  State<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends State<AudioCallScreen> {
  late RtcEngine _engine;
  bool _localUserJoined = false;
  int? _remoteUid;
  bool isMuted = false;
  bool isSpeakerOn = false;

  @override
  void initState() {
    super.initState();
    initAgora();
  }

  Future<void> initAgora() async {
    await [Permission.microphone].request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: widget.appId));

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("local user ${connection.localUid} joined");
          setState(() {
            _localUserJoined = true;
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("remote user $remoteUid joined");
          setState(() {
            _remoteUid = remoteUid;
          });
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint("remote user $remoteUid left channel");
          setState(() {
            _remoteUid = null;
          });
        },
      ),
    );

    await _engine.joinChannel(
      token: widget.token,
      channelId: widget.channelName,
      options: const ChannelMediaOptions(
        autoSubscribeAudio: true,
        publishMicrophoneTrack: true,
        publishCameraTrack: false, // Disable video
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
      uid: 0,
    );
  }

  Future<void> _dispose() async {
    await _engine.leaveChannel(); // Leave the channel
    await _engine.release(); // Release resources
  }

  void _toggleSpeaker() {
    setState(() {
      isSpeakerOn = !isSpeakerOn;
      _engine.setEnableSpeakerphone(isSpeakerOn);
    });
  }

  void _toggleMute() {
    setState(() {
      isMuted = !isMuted;
      _engine.muteLocalAudioStream(isMuted);
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Audio Call'),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              if (_localUserJoined)
                Center(
                  child: Text(
                    "Audio Call...🤙",
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              if (!_localUserJoined)
                Center(
                  child: CircularProgressIndicator(),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          isMuted ? Icons.mic_off : Icons.mic,
                          color: isMuted ? Colors.red : Colors.blue,
                        ),
                        onPressed: _toggleMute,
                      ),
                      IconButton(
                        icon: Icon(
                          isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                          color: isSpeakerOn ? Colors.blue : Colors.red,
                        ),
                        onPressed: _toggleSpeaker,
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.call_end,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          _dispose();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }
}
