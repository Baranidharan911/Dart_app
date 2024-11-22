// ignore_for_file: library_private_types_in_public_api, prefer_const_constructors, unused_import

import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:async';

class Admin extends StatefulWidget {
  final String userId;
  final String enquiryId;

  const Admin({
    Key? key,
    required this.userId,
    required this.enquiryId,
  }) : super(key: key);

  @override
  _AdminState createState() => _AdminState();
}

class _AdminState extends State<Admin> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  late SharedPreferences _prefs;
  File? _backgroundImageFile;

  @override
  void initState() {
    super.initState();
    _initializePreferences();
    _loadBackgroundImage();
  }

  Future<void> _initializePreferences() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> _loadBackgroundImage() async {
    _backgroundImageFile = await _loadLocalFile('chat.jpg');

    _backgroundImageFile ??= await _saveBackgroundImageLocally();
    setState(() {});
  }

  Future<File?> _saveBackgroundImageLocally() async {
    final byteData = await DefaultAssetBundle.of(context).load('assets/chat.jpg');
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/chat.jpg';
    final file = File(filePath);
    await file.writeAsBytes(byteData.buffer.asUint8List());

    // Save the file path to shared preferences
    await _prefs.setString('backgroundImage', filePath);
    return file;
  }

  Future<File?> _loadLocalFile(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName';
    File file = File(filePath);

    if (await file.exists()) {
      return file;
    }
    return null;
  }

  Future<void> _sendMessage(String text, {String? imageUrl}) async {
    if (text.isEmpty && imageUrl == null) return;

    final message = {
      'text': text,
      'imageUrl': imageUrl,
      'senderId': widget.userId,
      'timestamp': Timestamp.now(),
    };

    await FirebaseFirestore.instance
        .collection('admin_chat')
        .doc(widget.enquiryId)
        .collection('chats')
        .add(message);

    _textController.clear();
    _scrollToBottom();
  }

  Future<void> _sendImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      bool confirmed = await _showConfirmationDialog(pickedFile);

      if (confirmed) {
        setState(() {
          _isLoading = true;
        });

        File imageFile = File(pickedFile.path);
        String fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';
        var storageRef = FirebaseStorage.instance
            .ref()
            .child('admin_chat/${widget.userId}/$fileName');
        var uploadTask = storageRef.putFile(imageFile);

        await uploadTask.whenComplete(() async {
          String downloadUrl = await storageRef.getDownloadURL();
          await _saveFileLocally(imageFile, fileName);
          await _sendMessage('', imageUrl: downloadUrl);
          setState(() {
            _isLoading = false;
          });
        });
      }
    }
  }

  Future<void> _saveFileLocally(File file, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName';
    await file.copy(filePath);

    // Save the file path to shared preferences
    List<String>? savedFiles = _prefs.getStringList('savedFiles');
    savedFiles = savedFiles ?? [];
    savedFiles.add(filePath);
    await _prefs.setStringList('savedFiles', savedFiles);
  }

  Future<bool> _showConfirmationDialog(XFile pickedFile) async {
    return await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Image Send'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.file(
                File(pickedFile.path),
                width: 150,
                height: 150,
                fit: BoxFit.cover,
              ),
              SizedBox(height: 20),
              Text('Do you want to send this image?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text('Send'),
            ),
          ],
        );
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Chat'),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: _backgroundImageFile != null
              ? DecorationImage(
                  image: FileImage(_backgroundImageFile!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('admin_chat')
                    .doc(widget.enquiryId)
                    .collection('chats')
                    .orderBy('timestamp')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

                  var messages = snapshot.data!.docs;

                  _scrollToBottom();

                  return ListView.builder(
                    controller: _scrollController,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      var message =
                          messages[index].data() as Map<String, dynamic>;
                      bool isMe = message['senderId'] == widget.userId;

                      return Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: EdgeInsets.symmetric(
                              vertical: 8.0, horizontal: 16.0),
                          padding: EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: isMe
                                ? Colors.blueAccent
                                : Colors.grey.shade200.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (message['imageUrl'] != null)
                                FutureBuilder<File?>(
                                  future: _loadLocalFile(message['imageUrl']),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      return Image.file(
                                        snapshot.data!,
                                        width: 150,
                                        height: 150,
                                        fit: BoxFit.cover,
                                      );
                                    } else {
                                      return Image.network(
                                        message['imageUrl'],
                                        width: 150,
                                        height: 150,
                                        fit: BoxFit.cover,
                                      );
                                    }
                                  },
                                ),
                              if (message['text'].isNotEmpty)
                                Text(
                                  message['text'],
                                  style: TextStyle(
                                    color: isMe
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              Text(
                                message['timestamp'] != null
                                    ? (message['timestamp'] as Timestamp)
                                        .toDate()
                                        .toString()
                                    : '',
                                style: TextStyle(
                                  color: isMe
                                      ? Colors.white70
                                      : Colors.black54,
                                  fontSize: 10.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            _isLoading
                ? LinearProgressIndicator()
                : Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.photo),
                          onPressed: _sendImage,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20.0),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey[200]?.withOpacity(0.7),
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 10.0,
                                horizontal: 20.0,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: () => _sendMessage(_textController.text),
                        ),
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class FullScreenImage extends StatelessWidget {
  final String imageUrl;

  const FullScreenImage({Key? key, required this.imageUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          Navigator.of(context).pop(); 
        },
        child: Center(
          child: Hero(
            tag: imageUrl,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
