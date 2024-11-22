// ignore_for_file: library_private_types_in_public_api, avoid_print, deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../firebase_options.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MaterialApp(home: B2BChatPage()));
}

class B2BChatPage extends StatefulWidget {
  const B2BChatPage({super.key});

  @override
  _B2BChatPageState createState() => _B2BChatPageState();
}

class _B2BChatPageState extends State<B2BChatPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _textController = TextEditingController();
  String? currentQuestionKey = "start"; // Start from the 'start' document
  List<Map<String, dynamic>> conversation = [];
  String? documentId;
  bool inputEnabled = false; // Input is disabled initially
  List<FileUploadTask> fileUploadTasks = [];
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    fetchInitialMessage();
  }

  Future<void> fetchInitialMessage() async {
    try {
      var initialMessage =
          await _firestore.collection('b2b_messages').doc('start').get();
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
      });

      // Handle file uploads
      for (var task in fileUploadTasks) {
        await task.uploadTask;
        String downloadURL =
            await task.uploadTask.snapshot.ref.getDownloadURL();
        message = "$message\n$downloadURL";
      }

      fileUploadTasks.clear(); // Clear the selected files after uploading

      await responsesDoc.set({
        'userId': currentUser.uid,
        'timestamp': currentTimestamp,
        'enquiryId': enquiryId,
        'status': 'pending',
        'responses': FieldValue.arrayUnion([
          {
            'response': message,
            'timestamp': currentTimestamp,
            'context': currentQuestionKey,
          }
        ]),
      }, SetOptions(merge: true));

      String? nextDocId = await fetchNextDocId(currentQuestionKey, message);

      if (nextDocId != null) {
        var nextDoc =
            await _firestore.collection('b2b_messages').doc(nextDocId).get();
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
                !isChatEnd; // Enable input if no options and chat is not ended
          });
        }
      } else {
        setState(() {
          inputEnabled =
              !isChatEnd; // Enable text input if no next document and chat is not ended
        });
      }

      _textController.clear();
    } catch (e) {
      print("Error sending message: $e");
    }
  }

  Future<String?> fetchNextDocId(String? currentDocId, String message) async {
    var currentDoc =
        await _firestore.collection('b2b_messages').doc(currentDocId).get();
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
          UploadTask uploadTask = await _uploadFile(file);
          tasks.add(FileUploadTask(
            file: file,
            uploadTask: uploadTask,
            isVideo: isVideo,
            isDocument: isDocument,
          ));
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

  Future<void> recordAudio() async {
    // Implement audio recording logic here
  }

  Future<UploadTask> _uploadFile(File file) async {
    var currentUser = FirebaseAuth.instance.currentUser;
    String filePath =
        'uploads/${currentUser!.uid}/${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    return FirebaseStorage.instance.ref().child(filePath).putFile(file);
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
                leading: const Icon(Icons.mic),
                title: const Text('Audio'),
                onTap: () {
                  Navigator.pop(context);
                  recordAudio();
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

  @override
  void dispose() {
    _textController.dispose();
    _videoController?.dispose();
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
                          ? Colors.blueAccent
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
                                      backgroundColor: const Color.fromARGB(
                                          255, 206, 158, 126),
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
                                    label: Text(label,
                                        style: const TextStyle(
                                            color: Colors.white)),
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
          if (fileUploadTasks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
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
                                        aspectRatio:
                                            _videoController!.value.aspectRatio,
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
                            else
                              Image.file(
                                task.file,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle,
                                  color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  fileUploadTasks.remove(task);
                                  if (task.isVideo &&
                                      _videoController != null) {
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
                  const SizedBox(height: 8.0),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _showAttachmentOptions,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          decoration: const InputDecoration(
                            hintText: "Type your response",
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: handleSendButtonPressed,
                      ),
                    ],
                  ),
                ],
              ),
            )
          else if (inputEnabled)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _showAttachmentOptions,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: "Type your response",
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: handleSendButtonPressed,
                  ),
                ],
              ),
            ),
        ],
      ),
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

  FileUploadTask({
    required this.file,
    required this.uploadTask,
    this.isVideo = false,
    this.isDocument = false,
  });
}