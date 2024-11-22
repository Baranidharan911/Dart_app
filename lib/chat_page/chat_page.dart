// ignore_for_file: library_private_types_in_public_api, avoid_print, prefer_const_constructors, no_leading_underscores_for_local_identifiers, deprecated_member_use, unused_element

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../firebase_options.dart';
import 'success_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MaterialApp(home: ChatPage()));
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _textController = TextEditingController();
  String? currentQuestionKey = "start"; // Start from the 'start' document
  List<Map<String, dynamic>> conversation = [];
  String? documentId;
  bool inputEnabled = false; // Input is disabled initially
  bool hardwareSelected = false; // Track hardware or software selection
  List<FileUploadTask> fileUploadTasks = [];
  VideoPlayerController? _videoController;

  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  String? _audioFilePath;
  bool mediaContextCreated = false; // Track if media context is created

  final ScrollController _scrollController = ScrollController(); // ScrollController for auto-scroll

  @override
  void initState() {
    super.initState();
    fetchInitialMessage();
    _initializeRecorder();
  }

  Future<void> fetchInitialMessage() async {
    try {
      var initialMessage =
          await _firestore.collection('messages').doc('start').get();
      var data = initialMessage.data();
      if (data != null) {
        List<Map<String, dynamic>> options = [];
        if (data['options'] != null) {
          options = (data['options'] as List).map((option) {
            if (option is String) {
              return {'label': option, 'image_url': null};
            } else if (option is Map<String, dynamic>) {
              return option;
            } else {
              throw Exception("Invalid option type");
            }
          }).toList();
        }
        setState(() {
          conversation.add({
            'text': data['text'],
            'options': options,
            'userInitiated': false
          });
          currentQuestionKey = 'start';
          inputEnabled = options.isEmpty; // Enable input if no options
        });
        _scrollToBottom(); // Scroll to the bottom after adding a new message
      }
    } catch (e) {
      print("Error fetching initial message: $e");
    }
  }

  Future<String> getNextDocumentId() async {
    DocumentReference counterDoc =
        _firestore.collection('counters').doc('enquiryId');
    return await _firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(counterDoc);
      if (!snapshot.exists) {
        throw Exception("Counter document does not exist!");
      }

      int current = (snapshot.data() as Map<String, dynamic>)['current'] ?? 0;
      int next = current + 1;
      transaction.update(counterDoc, {'current': next});

      return 'D2T${next.toString().padLeft(5, '0')}';
    });
  }

  Future<void> sendMessage(String message, {bool isChatEnd = false}) async {
    try {
      var currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print("No user logged in.");
        return;
      }

      documentId ??= await getNextDocumentId();

      String enquiryId = documentId!;

      DocumentReference responsesDoc =
          _firestore.collection('responses').doc(documentId);
      Timestamp currentTimestamp = Timestamp.now();

      setState(() {
        conversation.add({'text': message, 'userInitiated': true});
        inputEnabled = false; // Disable input while processing the response

        // Track the selected option if it comes from the options array
        if (currentQuestionKey != 'end') {
          for (var entry in conversation) {
            if (entry['options'] != null && entry['options'].any((option) => option['label'] == message)) {
              entry['selectedOption'] = message; // Store the selected option
              break;
            }
          }
        }
      });

      // Save the text message under the 'responses' array in Firestore
      await responsesDoc.set({
        'userId': currentUser.uid,
        'timestamp': currentTimestamp,
        'enquiryId': enquiryId,
        'status': 'pending',
        'is_deleted': false,
        'responses': FieldValue.arrayUnion([
          {
            'response': message,
            'timestamp': currentTimestamp,
            'context': isChatEnd ? 'end' : currentQuestionKey,
          }
        ]),
      }, SetOptions(merge: true));

      if (isChatEnd) {
        mediaContextCreated = false; // Reset media context flag
      }

      String? nextDocId = await fetchNextDocId(currentQuestionKey, message);

      if (nextDocId != null) {
        var nextDoc =
            await _firestore.collection('messages').doc(nextDocId).get();
        var nextData = nextDoc.data();
        if (nextData != null) {
          List<Map<String, dynamic>> options = [];
          if (nextData['options'] != null) {
            options = (nextData['options'] as List).map((option) {
              if (option is String) {
                return {'label': option, 'image_url': null};
              } else if (option is Map<String, dynamic>) {
                return option;
              } else {
                throw Exception("Invalid option type");
              }
            }).toList();
          }
          setState(() {
            conversation.add({
              'text': nextData['text'],
              'options': options,
              'userInitiated': false
            });
            currentQuestionKey = nextDocId;
            inputEnabled = options.isEmpty &&
                !isChatEnd && (!hardwareSelected || isChatEnd); // Enable input if no options and chat is not ended
          });
          _scrollToBottom(); // Scroll to the bottom after adding a new message
        }
      } else {
        setState(() {
          inputEnabled =
              !isChatEnd && (!hardwareSelected || isChatEnd); // Enable text input if no next document and chat is not ended
        });
      }

      _textController.clear();
    } catch (e) {
      print("Error sending message: $e");
    }
  }

  Future<String?> fetchNextDocId(String? currentDocId, String message) async {
    var currentDoc =
        await _firestore.collection('messages').doc(currentDocId).get();
    var currentData = currentDoc.data();
    if (currentData != null) {
      if (currentData.containsKey('next_map')) {
        var nextMap = currentData['next_map'];
        if (nextMap is Map) {
          return nextMap[message] as String?;
        }
      } else if (currentData.containsKey('next')) {
        var next = currentData['next'];
        if (next is String) {
          return next;
        }
      }
    }
    return null;
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
          UploadTask uploadTask = await _uploadFile(file);
          tasks.add(FileUploadTask(
            file: file,
            uploadTask: uploadTask,
            isVideo: isVideo,
            isDocument: isDocument,
            isAudio: isAudio,
          ));
          if (isVideo) {
            _initializeVideoController(file);
          }
        }
      }
      setState(() {
        fileUploadTasks.addAll(tasks); // Add to existing list
      });

      // Add media URLs to the media context
      List<String> downloadURLs = [];
      for (var task in fileUploadTasks) {
        await task.uploadTask;
        String downloadURL = await task.uploadTask.snapshot.ref.getDownloadURL();
        downloadURLs.add(downloadURL);
      }

      // Store media URLs in Firestore under the 'responses' array
      await _firestore.collection('responses').doc(documentId).update({
        'responses': FieldValue.arrayUnion([
          {
            'response': 'media',
            'timestamp': Timestamp.now(),
            'context': 'media',
            'urls': downloadURLs,
          }
        ]),
      });

      fileUploadTasks.clear(); // Clear the selected files after uploading
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

  bool _isAudioFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['mp3', 'wav', 'aac', 'm4a'].contains(ext);
  }

  Future<void> captureImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      File file = File(image.path);
      UploadTask uploadTask = await _uploadFile(file);
      setState(() {
        fileUploadTasks.add(FileUploadTask(
          file: file,
          uploadTask: uploadTask,
        ));
      });
    }
  }

  Future<void> captureVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.camera);
    if (video != null) {
      File file = File(video.path);
      UploadTask uploadTask = await _uploadFile(file);
      setState(() {
        fileUploadTasks.add(FileUploadTask(
          file: file,
          uploadTask: uploadTask,
          isVideo: true,
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

  Future<void> _initializeRecorder() async {
    _recorder = FlutterSoundRecorder();
    await _recorder!.openRecorder();
    await _recorder!.setSubscriptionDuration(const Duration(milliseconds: 10));

    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException("Microphone permission not granted");
    }
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
      UploadTask uploadTask = await _uploadFile(audioFile);
      fileUploadTasks.add(FileUploadTask(
        file: audioFile,
        uploadTask: uploadTask,
        isAudio: true,
      ));
    }
  }

  Future<void> _sendAudioMessage() async {
    if (_audioFilePath != null) {
      File audioFile = File(_audioFilePath!);
      var currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print("No user logged in.");
        return;
      }

      String filePath =
          'audio_messages/${currentUser.uid}/${DateTime.now().millisecondsSinceEpoch}_${audioFile.path.split('/').last}';
      UploadTask uploadTask = FirebaseStorage.instance.ref().child(filePath).putFile(audioFile);

      TaskSnapshot snapshot = await uploadTask.whenComplete(() => null);
      String downloadURL = await snapshot.ref.getDownloadURL();

      setState(() {
        conversation.add({'text': downloadURL, 'userInitiated': true});
      });

      // Store the media URL in the media context
      await _firestore.collection('responses').doc(documentId).update({
        'responses': FieldValue.arrayUnion([
          {
            'response': 'media',
            'timestamp': Timestamp.now(),
            'context': 'media',
            'urls': [downloadURL],
          }
        ]),
      });
    }
  }

  Future<UploadTask> _uploadFile(File file) async {
    var currentUser = FirebaseAuth.instance.currentUser;
    String filePath =
        'uploads/${currentUser!.uid}/${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    return FirebaseStorage.instance.ref().child(filePath).putFile(file);
  }

  void handleSendButtonPressed() {
    if (_textController.text.isNotEmpty) {
      // Check if the current context is "end"
      if (currentQuestionKey == "end") {
        sendMessage(_textController.text, isChatEnd: true);
      } else {
        sendMessage(_textController.text);
      }
    }
  }

  void handleSubmitButtonPressed() {
    if (_textController.text.isNotEmpty) {
      sendMessage(_textController.text, isChatEnd: true); // Store the text input under the 'end' context
    }

    // Find the last selected option from the options array before the "end" context
    String selectedOption = "Unknown Option"; // Default if no option is selected
    for (var entry in conversation.reversed) {
      if (entry.containsKey('selectedOption')) {
        selectedOption = entry['selectedOption']; // Get the selected option from conversation
        break;
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Confirm Submission"),
          content: Text("Are you sure you want to submit your enquiry?"),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SuccessPage(selectedOption: selectedOption),
                  ),
                );
              },
              child: Text(
                "Yes",
                style: TextStyle(color: Colors.blue),
              ),
            ),
            TextButton(
              onPressed: () {
                // Restore inputEnabled to true so that the input field and submit button are visible again
                setState(() {
                  inputEnabled = true; 
                });
                Navigator.of(context).pop(); // Close the dialog and return to the same page
              },
              child: Text(
                "No",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
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
                    _stopRecording();
                    _sendAudioMessage();
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _videoController?.dispose();
    _recorder?.closeRecorder();
    _recorder = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 20.0,
              backgroundColor: Colors.transparent,
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
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController, // Attach the ScrollController
              itemCount: conversation.length,
              itemBuilder: (context, index) {
                var entry = conversation[index];
                return Align(
                  alignment: entry['userInitiated']
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        vertical: 5.0, horizontal: 10.0),
                    padding: const EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      color: entry['userInitiated']
                          ? const Color.fromRGBO(0, 43, 135, 1)
                          : const Color.fromRGBO(232, 232, 232, 1),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20.0),
                        topRight: const Radius.circular(20.0),
                        bottomLeft: entry['userInitiated']
                            ? const Radius.circular(20.0)
                            : const Radius.circular(0),
                        bottomRight: entry['userInitiated']
                            ? const Radius.circular(0)
                            : const Radius.circular(20.0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry['text'],
                          style: TextStyle(
                            color: entry['userInitiated']
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                        if (entry.containsKey('response')) ...[
                          const SizedBox(height: 10),
                          Text(
                            entry['response'],
                            style: TextStyle(
                              color: entry['userInitiated']
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        ],
                        if (entry.containsKey('files'))
                          ...entry['files']?.map<Widget>((file) {
                                var fileUrl = file['url'] as String;
                                var fileName = file['name'] as String;
                                if (fileName.endsWith('.jpg') ||
                                    fileName.endsWith('.png')) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10.0),
                                    child: Image.network(fileUrl),
                                  );
                                } else if (fileName.endsWith('.mp4')) {
                                  return VideoPlayerWidget(url: fileUrl);
                                } else if (fileName.endsWith('.pdf')) {
                                  return ListTile(
                                    leading: const Icon(Icons.picture_as_pdf),
                                    title: Text(fileName),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              PDFViewerPage(url: fileUrl),
                                        ),
                                      );
                                    },
                                  );
                                } else if (fileName.endsWith('.mp3') ||
                                    fileName.endsWith('.wav') ||
                                    fileName.endsWith('.aac') ||
                                    fileName.endsWith('.m4a')) {
                                  return ListTile(
                                    leading: const Icon(Icons.audiotrack),
                                    title: Text(fileName),
                                    onTap: () async {
                                      await _playAudio(fileUrl);
                                    },
                                  );
                                } else {
                                  return ListTile(
                                    leading: const Icon(Icons.attach_file),
                                    title: Text(fileName),
                                    onTap: () {
                                      // Handle other file types if necessary
                                    },
                                  );
                                }
                              }).toList() ??
                              [],
                        if (entry.containsKey('options'))
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: (entry['options'] as List<dynamic>?)
                                    ?.map<Widget>((option) {
                                  String label = option['label'];
                                  String? imageUrl = option['image_url'];
                                  return ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20.0),
                                      ),
                                    ),
                                    onPressed: () {
                                      sendMessage(label);
                                      setState(() {
                                        entry['options'] =
                                            null; // Disable the options after selection
                                        inputEnabled =
                                            false; // Disable input while processing the response
                                      });
                                    },
                                    icon: imageUrl != null
                                        ? Image.network(
                                            imageUrl,
                                            width: 20,
                                            height: 20,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return const Icon(Icons.error,
                                                  size: 20, color: Colors.red);
                                            },
                                          )
                                        : Container(),
                                    label: Text(
                                      label,
                                      style:
                                          const TextStyle(color: Colors.black),
                                    ),
                                  );
                                }).toList() ??
                                [],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if ((hardwareSelected && currentQuestionKey == 'end') || (!hardwareSelected && inputEnabled)) // Show input field for end context in hardware or if input is enabled for software
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  TextField(
                    controller: _textController,
                    maxLines: 5,
                    decoration: InputDecoration(
                       hintText: "Describe your problem\n*you can add multiple files in this",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    children: [
                      ElevatedButton.icon(
                        onPressed: captureImage,
                        icon: const Icon(Icons.photo_camera),
                        label: const Text("Add Photo"),
                      ),
                      ElevatedButton.icon(
                        onPressed: captureVideo,
                        icon: const Icon(Icons.videocam),
                        label: const Text("Add Video"),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isRecording ? _stopRecording : _startRecording,
                        icon: const Icon(Icons.mic),
                        label: Text(_isRecording ? "Stop Recording" : "Add Audio"),
                      ),
                      ElevatedButton.icon(
                        onPressed: uploadMedia,
                        icon: const Icon(Icons.attach_file),
                        label: const Text("Add File"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (fileUploadTasks.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: fileUploadTasks.map((task) {
                          return Stack(
                            alignment: Alignment.topRight,
                            children: [
                              if (task.isVideo)
                                SizedBox(
                                  width: 100,
                                  height: 100,
                                  child: _videoController != null &&
                                          _videoController!.value.isInitialized
                                      ? AspectRatio(
                                          aspectRatio: _videoController!.value.aspectRatio,
                                          child: VideoPlayer(_videoController!),
                                        )
                                      : Container(
                                          color: Colors.black12,
                                        ),
                                )
                              else if (task.isDocument)
                                Container(
                                  width: 100,
                                  height: 100,
                                  color: Colors.blue[50],
                                  child: Center(
                                    child: Text(
                                      'Document\n${task.file.path.split('/').last}',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                )
                              else if (task.isAudio)
                                Container(
                                  width: 100,
                                  height: 100,
                                  color: Colors.green[50],
                                  child: Center(
                                    child: Icon(Icons.audiotrack),
                                  ),
                                )
                              else
                                Image.file(
                                  task.file,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    fileUploadTasks.remove(task);
                                    if (task.isVideo && _videoController != null) {
                                      _videoController!.dispose();
                                      _videoController = null;
                                    }
                                  });
                                },
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: handleSubmitButtonPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(0, 43, 135, 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    child: const Text('Submit', style: TextStyle(
                          color: Colors.white,
                        ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _playAudio(String url) async {
    FlutterSoundPlayer _player = FlutterSoundPlayer();
    await _player.openPlayer();
    await _player.startPlayer(
      fromURI: url,
      codec: Codec.mp3,
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String url;

  const VideoPlayerWidget({super.key, required this.url});

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.url)
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          )
        : const Center(child: CircularProgressIndicator());
  }
}

class PDFViewerPage extends StatelessWidget {
  final String url;

  const PDFViewerPage({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Viewer'),
      ),
      body: PDFView(
        filePath: url,
      ),
    );
  }
}

class FileUploadTask {
  final File file;
  final UploadTask uploadTask;
  final bool isVideo;
  final bool isDocument;
  final bool isAudio;

  FileUploadTask({
    required this.file,
    required this.uploadTask,
    this.isVideo = false,
    this.isDocument = false,
    this.isAudio = false,
  });
}
