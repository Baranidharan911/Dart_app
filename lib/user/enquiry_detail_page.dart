// ignore_for_file: unused_import, avoid_print, library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flick_video_player/flick_video_player.dart';
import 'package:techwiz/chat/b2b_chat_page.dart';
import 'package:video_player/video_player.dart'; // For video preview
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart'; // For image preview
import 'package:audioplayers/audioplayers.dart';

class EnquiryDetailPage extends StatefulWidget {
  final String enquiryId;

  const EnquiryDetailPage({super.key, required this.enquiryId});

  @override
  _EnquiryDetailPageState createState() => _EnquiryDetailPageState();
}

class _EnquiryDetailPageState extends State<EnquiryDetailPage> {
  late Future<Map<String, dynamic>?> _enquiryDetailsFuture;

  @override
  void initState() {
    super.initState();
    _enquiryDetailsFuture = _fetchEnquiryDetails();
  }

  Future<Map<String, dynamic>?> _fetchEnquiryDetails() async {
    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('responses')
        .doc(widget.enquiryId)
        .get();

    if (doc.exists && doc.data() != null) {
      return doc.data() as Map<String, dynamic>?;
    } else {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchQuestionDetails(String context) async {
    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('messages')
        .doc(context)
        .get();

    if (doc.exists && doc.data() != null) {
      return doc.data() as Map<String, dynamic>?;
    } else {
      return null;
    }
  }

  String getCategoryIconPath(String category) {
    String sanitizedCategory = category.toLowerCase().replaceAll(' ', '-');
    if (sanitizedCategory == '3d-printing') {
      sanitizedCategory = 'printing-3d'; // Adjusting for the renamed file
    }
    return 'assets/icons/$sanitizedCategory.png';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enquiry Details'),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _enquiryDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData && snapshot.data != null) {
            var enquiry = snapshot.data!;
            var responses = enquiry['responses'] as List<dynamic>?;
            var category = 'No category';
            if (responses != null) {
              for (var response in responses) {
                if (response['context'] == 'field_of_category_troubleshoot' ||
                    response['context'] == 'field_of_category_new_project') {
                  category = response['response'] ?? 'No category';
                  break;
                }
              }
            }
            var timestamp = enquiry['timestamp'] != null
                ? (enquiry['timestamp'] as Timestamp).toDate()
                : null;
            var iconPath = getCategoryIconPath(category);

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  Row(
                    children: [
                      Image.asset(iconPath, width: 40, height: 40,
                          errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.insert_drive_file);
                      }),
                      const SizedBox(width: 10),
                      Text(
                        'Enquiry ID: ${widget.enquiryId}',
                        style: const TextStyle(
                            fontSize: 20.0, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10.0),
                  Text(
                    category,
                    style: const TextStyle(fontSize: 18.0),
                  ),
                  const SizedBox(height: 10.0),
                  if (timestamp != null)
                    Text(
                      'Time: ${timestamp.toLocal()}',
                      style:
                          const TextStyle(fontSize: 16.0, color: Colors.grey),
                    ),
                  const SizedBox(height: 20.0),
                  if (responses != null && responses.isNotEmpty)
                    ...responses.map((response) =>
                        FutureBuilder<Map<String, dynamic>?>(
                          future: _fetchQuestionDetails(response['context']),
                          builder: (context, questionSnapshot) {
                            if (questionSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const CircularProgressIndicator();
                            } else if (questionSnapshot.hasError) {
                              return Text('Error: ${questionSnapshot.error}');
                            } else if (questionSnapshot.hasData && questionSnapshot.data != null) {
                              var question = questionSnapshot.data!;
                              var questionText =
                                  question['text'] ?? 'No question found';
                              return ChatBubble(
                                question: questionText,
                                response: response['response'] ?? 'No response',
                                contextText: response['context'],
                                timestamp: (response['timestamp'] as Timestamp)
                                    .toDate(),
                                isUserResponse: true,
                              );
                            } else {
                              return const Text('No question found.');
                            }
                          },
                        )),
                ],
              ),
            );
          } else {
            return const Center(child: Text('No details found.'));
          }
        },
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final String question;
  final String response;
  final String contextText;
  final DateTime timestamp;
  final bool isUserResponse;

  const ChatBubble({
    super.key,
    required this.question,
    required this.response,
    required this.contextText,
    required this.timestamp,
    required this.isUserResponse,
  });

  Widget _buildResponseWidget(String response) {
    final uriRegExp = RegExp(
        r'((https?|ftp):\/\/)?([a-zA-Z0-9\-.]+)\.([a-zA-Z]{2,3})(\/\S*)?');

    final matches = uriRegExp.allMatches(response);
    List<Widget> widgets = [];
    int currentIndex = 0;

    for (var match in matches) {
      if (match.start > currentIndex) {
        widgets.add(Text(response.substring(currentIndex, match.start)));
      }

      final url = response.substring(match.start, match.end);
      widgets.add(_handleUrl(url));

      currentIndex = match.end;
    }

    if (currentIndex < response.length) {
      widgets.add(Text(response.substring(currentIndex)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _handleUrl(String url) {
    if (url.contains('.jpg') || url.contains('.png')) {
      return CachedNetworkImage(
        imageUrl: url,
        placeholder: (context, url) => const CircularProgressIndicator(),
        errorWidget: (context, url, error) => const Icon(Icons.error),
      );
    } else if (url.contains('.mp4')) {
      return VideoPlayerWidget(url: url);
    } else if (url.contains('.mp3') || url.contains('.aac')) {
      return AudioPlayerWidget(url: url);
    } else if (url.contains('.pdf')) {
      return TextButton(
        onPressed: () {
          // Open the PDF in a new screen or use any pdf viewer plugin
        },
        child: const Text('View Document'),
      );
    }
    return Text(url);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20.0),
                topRight: Radius.circular(20.0),
                bottomLeft: Radius.circular(0),
                bottomRight: Radius.circular(20.0),
              ),
            ),
            child: Text(
              question,
              style: const TextStyle(color: Colors.black),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
            padding: const EdgeInsets.all(10.0),
            decoration: const BoxDecoration(
              color: Colors.blueAccent,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20.0),
                topRight: Radius.circular(20.0),
                bottomLeft: Radius.circular(20.0),
                bottomRight: Radius.circular(0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildResponseWidget(response),
              ],
            ),
          ),
        ),
      ],
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
  late FlickManager flickManager;
  bool initialized = false;
  late String localFilePath;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;
    String fileName = widget.url.split('/').last;
    localFilePath = '$appDocPath/$fileName';

    if (!await File(localFilePath).exists()) {
      await _downloadVideo(widget.url, localFilePath);
    }

    flickManager = FlickManager(
      videoPlayerController: VideoPlayerController.file(File(localFilePath)),
    );

    setState(() {
      initialized = true;
    });
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
    flickManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return initialized
        ? FlickVideoPlayer(flickManager: flickManager)
        : const CircularProgressIndicator();
  }
}

class AudioPlayerWidget extends StatefulWidget {
  final String url;

  const AudioPlayerWidget({super.key, required this.url});

  @override
  _AudioPlayerWidgetState createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _audioPlayer;
  bool isPlaying = false;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _audioPlayer.setSourceUrl(widget.url).then((_) {
      _audioPlayer.getDuration().then((newDuration) {
        setState(() {
          duration = newDuration ?? Duration.zero;
        });
      });

      _audioPlayer.onDurationChanged.listen((newDuration) {
        setState(() {
          duration = newDuration;
        });
      });

      _audioPlayer.onPositionChanged.listen((newPosition) {
        setState(() {
          position = newPosition;
        });
      });

      _audioPlayer.onPlayerStateChanged.listen((state) {
        setState(() {
          isPlaying = state == PlayerState.playing;
        });
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (duration > Duration.zero)
          Slider(
            min: 0,
            max: duration.inSeconds.toDouble(),
            value: position.inSeconds.toDouble(),
            onChanged: (value) async {
              final newPosition = Duration(seconds: value.toInt());
              await _audioPlayer.seek(newPosition);

              // Optionally resume the audio if it was paused
              if (!isPlaying) {
                await _audioPlayer.resume();
              }
            },
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: () async {
                if (isPlaying) {
                  await _audioPlayer.pause();
                } else {
                  await _audioPlayer.play(UrlSource(widget.url));
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: () async {
                await _audioPlayer.stop();
                setState(() {
                  position = Duration.zero;
                });
              },
            ),
          ],
        ),
        Text(
          '${position.toString().split('.').first}/${duration.toString().split('.').first}',
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }
}
