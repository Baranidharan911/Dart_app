// ignore_for_file: prefer_const_declarations, avoid_print, library_private_types_in_public_api, prefer_const_constructors, avoid_unnecessary_containers

import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flick_video_player/flick_video_player.dart';

import 'video_calling.dart';
import 'audio_calling.dart';

class TwoWayChatPage extends StatefulWidget {
  final String userId;
  final String enquiryId;
  final String technicianId;

  const TwoWayChatPage({
    super.key,
    required this.userId,
    required this.enquiryId,
    required this.technicianId,
  });

  @override
  TwoWayChatPageState createState() => TwoWayChatPageState();
}

class TwoWayChatPageState extends State<TwoWayChatPage> {
  final ChatService _chatService = ChatService();
  late String userId;
  late String enquiryId;
  late String technicianId;
  String? userProfileImageUrl;
  VideoPlayerController? _videoController;
  List<FileUploadTask> fileUploadTasks = [];
  final TextEditingController _textController = TextEditingController();
  List<Map<String, dynamic>> conversation = [];
  bool inputEnabled = true;
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  String? _audioFilePath;
  String? _token; // To store the fetched token

  @override
  void initState() {
    super.initState();
    userId = widget.userId;
    enquiryId = widget.enquiryId;
    technicianId = widget.technicianId;
    _fetchUserProfileImageUrl();
    _initializeRecorder();
    _fetchToken(); // Fetch the token on initialization
  }

  Future<void> _fetchUserProfileImageUrl() async {
    try {
      var userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: userId)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        var userDoc = userQuery.docs.first;
        setState(() {
          userProfileImageUrl = userDoc['profileImageUrl'];
        });
      }
    } catch (e) {
      print('Failed to fetch user profile image URL: $e');
    }
  }

  Future<void> _initializeRecorder() async {
    _recorder = FlutterSoundRecorder();
    await _recorder!.openRecorder();
    await _recorder!.setSubscriptionDuration(const Duration(milliseconds: 10));

    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException("Microphone permission not granted");
    }
  }

  Future<void> _fetchToken() async {
    final tokenSnapshot = await FirebaseFirestore.instance
        .collection('videoTokens')
        .doc(enquiryId)
        .get();

    if (tokenSnapshot.exists) {
      setState(() {
        _token = tokenSnapshot.data()?['token'];
      });
    } else {
      print('Firestore document does not exist.');
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _videoController?.dispose();
    _recorder?.closeRecorder();
    _recorder = null;
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_recorder == null) return;
    final directory = await getApplicationDocumentsDirectory();
    final path =
        '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';
    await _recorder!.startRecorder(
      toFile: path,
      codec: Codec.aacADTS,
    );
    setState(() {
      _isRecording = true;
      _audioFilePath = path;
    });
  }

  Future<void> _stopRecording() async {
    if (_recorder == null) return;
    await _recorder!.stopRecorder();
    setState(() {
      _isRecording = false;
    });
    if (_audioFilePath != null) {
      File audioFile = File(_audioFilePath!);
      UploadTask uploadTask = await _uploadFile(audioFile, 'audio');
      fileUploadTasks.add(FileUploadTask(
        file: audioFile,
        uploadTask: uploadTask,
        mediaType: 'audio',
      ));
    }
  }

  Future<void> uploadMedia() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      List<FileUploadTask> tasks = [];
      for (String? path in result.paths) {
        if (path != null) {
          File file = File(path);
          bool isVideo = _isVideoFile(file.path);
          bool isDocument = _isDocumentFile(file.path);
          bool isAudio = _isAudioFile(file.path);
          bool isImage = _isImageFile(file.path);
          String mediaType = isVideo
              ? 'video'
              : isDocument
                  ? 'document'
                  : isImage
                      ? 'image'
                      : isAudio
                          ? 'audio'
                          : 'audio';
          UploadTask uploadTask = await _uploadFile(file, mediaType);
          tasks.add(FileUploadTask(
            file: file,
            uploadTask: uploadTask,
            isVideo: isVideo,
            isDocument: isDocument,
            mediaType: mediaType,
          ));
          uploadTask.snapshotEvents.listen((event) {
            final progress = event.bytesTransferred / event.totalBytes;
            setState(() {
              // Update the progress of the upload in the UI
              fileUploadTasks = List<FileUploadTask>.from(fileUploadTasks.map((task) {
                if (task.uploadTask == uploadTask) {
                  task.progress = progress;
                }
                return task;
              }));
            });
          });

          if (isVideo) {
            _initializeVideoController(file);
          }
        }
      }
      setState(() {
        fileUploadTasks.addAll(tasks); // Add to existing list
      });
    }
  }

  bool _isVideoFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv'].contains(ext);
  }

  bool _isDocumentFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt']
        .contains(ext);
  }

  bool _isImageFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif'].contains(ext);
  }

  bool _isAudioFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['mp3', 'wav', 'aac', 'm4a'].contains(ext);
  }

  Future<void> captureImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      File file = File(image.path);
      UploadTask uploadTask = await _uploadFile(file, 'image');
      uploadTask.snapshotEvents.listen((event) {
        final progress = event.bytesTransferred / event.totalBytes;
        setState(() {
          // Update the progress of the upload in the UI
          fileUploadTasks = List<FileUploadTask>.from(fileUploadTasks.map((task) {
            if (task.uploadTask == uploadTask) {
              task.progress = progress;
            }
            return task;
          }));
        });
      });

      setState(() {
        fileUploadTasks.add(FileUploadTask(
          file: file,
          uploadTask: uploadTask,
          mediaType: 'image',
        ));
      });
    }
  }

  Future<void> captureVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.camera);
    if (video != null) {
      File file = File(video.path);
      UploadTask uploadTask = await _uploadFile(file, 'video');
      uploadTask.snapshotEvents.listen((event) {
        final progress = event.bytesTransferred / event.totalBytes;
        setState(() {
          // Update the progress of the upload in the UI
          fileUploadTasks = List<FileUploadTask>.from(fileUploadTasks.map((task) {
            if (task.uploadTask == uploadTask) {
              task.progress = progress;
            }
            return task;
          }));
        });
      });

      setState(() {
        fileUploadTasks.add(FileUploadTask(
          file: file,
          uploadTask: uploadTask,
          isVideo: true,
          mediaType: 'video',
        ));
        _initializeVideoController(file);
      });
    }
  }

  void _initializeVideoController(File file) {
    _videoController = VideoPlayerController.file(file)
      ..initialize().then((_) {
        setState(() {}); // Update the UI after the video is initialized
        _videoController!.setLooping(true);
      });
  }

  Future<UploadTask> _uploadFile(File file, String mediaType) async {
    var currentUser = FirebaseAuth.instance.currentUser;
    String filePath =
        'uploads/${currentUser!.uid}/${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    UploadTask uploadTask =
        FirebaseStorage.instance.ref().child(filePath).putFile(file);
    uploadTask.then((taskSnapshot) async {
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();
      _addMessage('', mediaUrl: downloadUrl, mediaType: mediaType);
    }).catchError((error) {
      print('Error uploading file: $error');
    });
    return uploadTask;
  }

  void handleSendButtonPressed() {
    sendMessage(_textController.text, isChatEnd: true);
    setState(() {
      conversation.add({'text': "Chat ended", 'userInitiated': false});
      inputEnabled = false; // Ensure input is disabled after chat ends
    });
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  captureImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('Video'),
                onTap: () {
                  Navigator.pop(context);
                  captureVideo();
                },
              ),
              ListTile(
                leading: Icon(_isRecording ? Icons.stop : Icons.mic),
                title: Text(_isRecording ? 'Stop Recording' : 'Audio'),
                onTap: () {
                  Navigator.pop(context);
                  if (_isRecording) {
                    _stopRecording().then((_) =>
                        _sendAudioMessage()); // Ensure audio message is sent once
                  } else {
                    _startRecording();
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file),
                title: const Text('File'),
                onTap: () {
                  Navigator.pop(context);
                  uploadMedia();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendAudioMessage() async {
    if (_audioFilePath == null) return;
    File audioFile = File(_audioFilePath!);
    UploadTask uploadTask = await _uploadFile(audioFile, 'audio');
    fileUploadTasks.add(FileUploadTask(
      file: audioFile,
      uploadTask: uploadTask,
      mediaType: 'audio',
    ));
  }

  void _joinVideoCall() {
    if (_token != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoCallScreen(
            appId: '9c8a0a30302e44a4b60f1620f355d8bb',
            channelName: enquiryId,
            token: _token!,
          ),
        ),
      );
    } else {
      print('Token not found');
    }
  }

  void _joinAudioCall() {
    if (_token != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AudioCallScreen(
            appId: '9c8a0a30302e44a4b60f1620f355d8bb',
            channelName: enquiryId,
            token: _token!,
          ),
        ),
      );
    } else {
      print('Token not found');
    }
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          CircleAvatar(
            radius: 20.0,
            backgroundColor: const Color.fromARGB(248, 255, 255, 255),
            child: ClipOval(
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.contain,
                width: 40.0,
                height: 40.0,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text("Dial2Tech"),
        ],
      ),
      leading: const BackButton(),
      actions: [
        IconButton(
          icon: Icon(Icons.phone),
          onPressed: _joinAudioCall,
        ),
        IconButton(
          icon: Icon(Icons.videocam),
          onPressed: _joinVideoCall,
        ),
      ],
    ),
    body: Container(
      // decoration: BoxDecoration(
      //   image: DecorationImage(
      //     image: AssetImage("assets/chat.jpg"), // Reference your image here
      //     fit: BoxFit.cover, // To make the image cover the entire screen
      //   ),
      // ),
      child: Column(
        children: [
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chat')
                  .doc(enquiryId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.data!.exists) {
                  FirebaseFirestore.instance
                      .collection('chat')
                      .doc(enquiryId)
                      .set({
                    'enquiryId': enquiryId,
                    'messages': [],
                    'technicianId': technicianId,
                    'userId': userId,
                  });
                  return const Center(
                      child: Text('No messages yet. Document created.'));
                }

                var chatData = snapshot.data!.data() as Map<String, dynamic>?;
                if (chatData == null) {
                  return const Center(child: Text('No messages yet.'));
                }

                var messages =
                    List<Map<String, dynamic>>.from(chatData['messages']);
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }

                return ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var message = messages[index];
                    var text = message['text'] ?? '';
                    var sender = message['senderId'] ?? '';
                    var isMe = sender == userId;

                    return MessageBubble(
                      text: text,
                      isMe: isMe,
                      mediaUrl: message['mediaUrl'],
                      mediaType: message['mediaType'],
                    );
                  },
                );
              },
            ),
          ),
          MessageInputBox(
            onSendMessage: (text) => _addMessage(text),
            onShowAttachmentOptions: _showAttachmentOptions,
            isRecording: _isRecording,
          ),
        ],
      ),
    ),
  );
}
  Future<void> _addMessage(String text,
      {String? mediaUrl, String? mediaType}) async {
    final chatDoc =
        FirebaseFirestore.instance.collection('chat').doc(enquiryId);

    final message = {
      'text': text,
      'senderId': userId,
      'timestamp': Timestamp.now(),
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
    };

    try {
      final docSnapshot = await chatDoc.get();
      if (!docSnapshot.exists) {
        await chatDoc.set({
          'enquiryId': enquiryId,
          'messages': [message],
          'technicianId': technicianId,
          'userId': userId,
        });
      } else {
        await chatDoc.update({
          'messages': FieldValue.arrayUnion([message]),
        });
      }
    } catch (error) {
      print('Failed to add message: $error');
    }
  }

  void sendMessage(String text, {bool isChatEnd = false}) {
    if (text.isNotEmpty) {
      _addMessage(text);
      if (isChatEnd) {
        setState(() {
          inputEnabled = false;
        });
      }
    }
  }
}

class FileUploadTask {
  final File file;
  final UploadTask uploadTask;
  final bool isVideo;
  final bool isDocument;
  final String? mediaType;
  double progress;

  FileUploadTask({
    required this.file,
    required this.uploadTask,
    this.isVideo = false,
    this.isDocument = false,
    this.mediaType,
    this.progress = 0.0,
  });
}

class MessageInputBox extends StatefulWidget {
  final Function(String) onSendMessage;
  final VoidCallback onShowAttachmentOptions;
  final bool isRecording;

  const MessageInputBox({
    super.key,
    required this.onSendMessage,
    required this.onShowAttachmentOptions,
    required this.isRecording,
  });

  @override
  MessageInputBoxState createState() => MessageInputBoxState();
}

class MessageInputBoxState extends State<MessageInputBox> {
  final TextEditingController _controller = TextEditingController();

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSendMessage(text);
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(widget.isRecording ? Icons.stop : Icons.add),
            onPressed: widget.onShowAttachmentOptions,
            tooltip: widget.isRecording
                ? 'Stop recording'
                : 'Show attachment options',
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Type a message',
                labelText: 'Message',
              ),
              onSubmitted: (value) => _sendMessage(),
              enabled: !widget.isRecording,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sendMessage,
            tooltip: 'Send message',
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatefulWidget {
  final String text;
  final bool isMe;
  final String? mediaUrl;
  final String? mediaType;

  const MessageBubble({
    Key? key,
    required this.text,
    required this.isMe,
    this.mediaUrl,
    this.mediaType,
  }) : super(key: key);

  @override
  _MessageBubbleState createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  late ap.AudioPlayer _audioPlayer;
  FlickManager? _flickManager;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool isPlaying = false;
  bool isDownloaded = false;
  bool isLoading = false;
  String? _localFilePath;

  @override
  void initState() {
    super.initState();
    _audioPlayer = ap.AudioPlayer();
    _audioPlayer.onDurationChanged.listen((d) {
      setState(() {
        _duration = d;
      });
    });
    _audioPlayer.onPositionChanged.listen((p) {
      setState(() {
        _position = p;
      });
    });
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        isPlaying = false;
        _position = Duration.zero;
      });
    });

    if (widget.mediaType == 'video' && widget.mediaUrl != null) {
      _initializeFlickManager(widget.mediaUrl!);
    }

    if (widget.isMe) {
      _checkIfFileIsDownloaded();
    }
  }

  Future<void> _initializeFlickManager(String url) async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;
    String fileName = url.split('/').last;
    _localFilePath = '$appDocPath/$fileName';

    if (!await File(_localFilePath!).exists()) {
      await _downloadVideo(url, _localFilePath!);
    }

    _flickManager = FlickManager(
      videoPlayerController: VideoPlayerController.file(File(_localFilePath!)),
    );

    setState(() {
      // Update the UI after the FlickManager is initialized
    });
  }

  Future<void> _checkIfFileIsDownloaded() async {
    if (widget.mediaUrl == null) return;
    final directory = await getApplicationDocumentsDirectory();
    final fileName = widget.mediaUrl!.split('/').last;
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    final exists = await file.exists();

    setState(() {
      isDownloaded = exists;
      _localFilePath = exists ? filePath : null;
    });
  }

  Future<void> _downloadFile() async {
    if (widget.mediaUrl == null) return;
    setState(() {
      isLoading = true;
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = widget.mediaUrl!.split('/').last;
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      final request = await HttpClient().getUrl(Uri.parse(widget.mediaUrl!));
      final response = await request.close();
      final bytes = await consolidateHttpClientResponseBytes(response);

      await file.writeAsBytes(bytes);
      setState(() {
        isDownloaded = true;
        _localFilePath = filePath;
      });
    } catch (e) {
      print('Error downloading file: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _downloadVideo(String url, String savePath) async {
    try {
      await Dio().download(url, savePath);
    } catch (e) {
      print('Error downloading video: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _flickManager?.dispose();
    super.dispose();
  }

  Widget _buildMediaContent() {
    if (widget.mediaUrl == null) {
      return Text(
        widget.text,
        style: TextStyle(
          color: widget.isMe ? Colors.white : Colors.black,
          fontSize: 16.0,
        ),
      );
    }

    switch (widget.mediaType) {
      case 'image':
        return ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Image.network(widget.mediaUrl!),
        );
      case 'video':
        return _flickManager != null
            ? FlickVideoPlayer(flickManager: _flickManager!)
            : const CircularProgressIndicator();
      case 'audio':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: widget.isMe ? Colors.white : Colors.black,
                  ),
                  onPressed: () async {
                    if (isPlaying) {
                      await _audioPlayer.pause();
                    } else {
                      await _audioPlayer.play(ap.UrlSource(widget.mediaUrl!));
                    }
                    setState(() {
                      isPlaying = !isPlaying;
                    });
                  },
                ),
                Expanded(
                  child: CustomPaint(
                    painter: AudioWaveformPainter(
                      position: _position,
                      duration: _duration,
                      isPlaying: isPlaying,
                      color: widget.isMe ? Colors.white : Colors.black,
                    ),
                    size: Size(double.infinity, 50.0),
                  ),
                ),
                Text(
                  "${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')}",
                  style: TextStyle(
                    color: widget.isMe ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ],
        );
      case 'document':
        return Container(
          color: widget.isMe ? Color.fromARGB(0, 0, 0, 0) : Colors.blue,
          child: ListTile(
            leading: Icon(Icons.picture_as_pdf,
                color: widget.isMe
                    ? const Color.fromARGB(255, 255, 255, 255)
                    : Colors.white),
            title: Text(
              'Document',
              style: TextStyle(
                  color: widget.isMe
                      ? const Color.fromARGB(255, 255, 255, 255)
                      : Colors.white),
            ),
            onTap: () async {
              if (isDownloaded && _localFilePath != null) {
                await openFile(_localFilePath!);
              } else {
                await _downloadFile();
              }
            },
          ),
        );
      default:
        return const Text('Unsupported media type');
    }
  }

  Future<void> openFile(String filePath) async {
    try {
      await launchUrl(Uri.file(filePath));
    } catch (e) {
      print('Error opening file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
      child: Column(
        crossAxisAlignment:
            widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: <Widget>[
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6.0),
              decoration: BoxDecoration(
                color: widget.isMe
                    ? const Color.fromARGB(255, 5, 51, 130)
                    : Colors.white,
                borderRadius: widget.isMe
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(20.0),
                        bottomLeft: Radius.circular(20.0),
                        bottomRight: Radius.circular(20.0),
                      )
                    : const BorderRadius.only(
                        topRight: Radius.circular(20.0),
                        bottomLeft: Radius.circular(20.0),
                        bottomRight: Radius.circular(20.0),
                      ),
                border: Border.all(
                  color: widget.isMe
                      ? const Color.fromARGB(255, 5, 51, 130)
                      : Colors.grey.shade300,
                  width: 1.0,
                ),
              ),
              child: _buildMediaContent(),
            ),
          ),
        ],
      ),
    );
  }
}

class AudioWaveformPainter extends CustomPainter {
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final Color color;

  AudioWaveformPainter({
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final waveformHeight = size.height / 2;
    final waveformWidth = size.width;
    final progress = position.inMilliseconds /
        (duration.inMilliseconds == 0 ? 1 : duration.inMilliseconds);
    final progressWidth = waveformWidth * progress;

    final barWidth = 4.0;
    final gapWidth = 2.0;
    final barCount = (waveformWidth / (barWidth + gapWidth)).floor();

    final random = Random();

    for (int i = 0; i < barCount; i++) {
      final x = i * (barWidth + gapWidth);
      final isActive = x < progressWidth;
      final barHeight = waveformHeight +
          (isActive
              ? waveformHeight * random.nextDouble()
              : waveformHeight * random.nextDouble() * 0.5);

      final barRect =
          Rect.fromLTWH(x, waveformHeight - barHeight / 2, barWidth, barHeight);
      canvas.drawRect(barRect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return isPlaying;
  }
}

class ChatService {
  // Private constructor
  ChatService._internal();

  // The single instance of the class
  static final ChatService _instance = ChatService._internal();

  // Factory constructor to return the single instance
  factory ChatService() {
    return _instance;
  }

  // Fields to hold the shared state
  String? userId;
  String? enquiryId;
  String? technicianId;

  // Method to clear the stored data if needed
  void clear() {
    userId = null;
    enquiryId = null;
    technicianId = null;
  }
}
