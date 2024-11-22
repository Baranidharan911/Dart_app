// video_calling.dart

// ignore_for_file: prefer_const_constructors, deprecated_member_use

import 'package:agora_uikit/agora_uikit.dart';
import 'package:flutter/material.dart';

class VideoCallScreen extends StatefulWidget {
  final String appId;
  final String channelName;
  final String token;

  const VideoCallScreen({
    Key? key,
    required this.appId,
    required this.channelName,
    required this.token,
  }) : super(key: key);

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late final AgoraClient _client;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    await [Permission.microphone, Permission.camera].request();

    _client = AgoraClient(
      agoraConnectionData: AgoraConnectionData(
        appId: widget.appId,
        channelName: widget.channelName,
        tempToken: widget.token,
      ),
    );
    await _client.initialize();
    setState(() {}); // Update the state to reflect the Agora client initialization
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Video Call'),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              if (_client.isInitialized)
                AgoraVideoViewer(
                  client: _client,
                  layoutType: Layout.grid,
                  showNumberOfUsers: true,
                ),
              if (_client.isInitialized)
                AgoraVideoButtons(
                  client: _client,
                  enabledButtons: const [
                    BuiltInButtons.toggleCamera,
                    BuiltInButtons.switchCamera,
                    BuiltInButtons.callEnd,
                    BuiltInButtons.toggleMic,
                  ],
                ),
              if (!_client.isInitialized)
                Center(
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}