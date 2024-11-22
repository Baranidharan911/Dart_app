// ignore_for_file: library_private_types_in_public_api, avoid_print, deprecated_member_use, prefer_const_constructors, duplicate_ignore

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'enquiry_detail_page.dart';

class SubmissionsPage extends StatefulWidget {
  const SubmissionsPage({super.key});

  @override
  _SubmissionsPageState createState() => _SubmissionsPageState();
}

class _SubmissionsPageState extends State<SubmissionsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  Future<List<Map<String, dynamic>>> _fetchUserSubmissions(String status) async {
    var currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      Query query = FirebaseFirestore.instance
          .collection('responses')
          .where('userId', isEqualTo: currentUser.uid)
          .where('is_deleted', isEqualTo: false) // Filter out deleted entries
          .orderBy('timestamp', descending: true); // Order by timestamp in descending order
      if (status != 'All') {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }
      QuerySnapshot querySnapshot = await query.get();
      return querySnapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        var responses = data['responses'] as List<dynamic>? ?? [];
        var category = 'No category';
        for (var response in responses) {
          if (response['context'] == 'field_of_category_troubleshoot' ||
              response['context'] == 'field_of_category_new_project') {
            category = response['response'] ?? 'No category';
            break;
          }
        }
        return {
          'enquiryId': data['enquiryId'] ?? '',
          'status': data['status'] ?? 'pending',
          'timestamp': data['timestamp'] != null
              ? (data['timestamp'] as Timestamp).toDate()
              : null,
          'category': category,
          'files': data['files'] as List<dynamic>? ?? [],
          'docId': doc.id, // Store document ID for editing/deleting
        };
      }).toList();
    }
    return [];
  }

  String getCategoryIconPath(String category) {
    String sanitizedCategory = category.toLowerCase().replaceAll(' ', '-');
    if (sanitizedCategory == '3d-printing') {
      sanitizedCategory = 'printing-3d'; // Adjusting for the renamed file
    }
    return 'assets/icons/$sanitizedCategory.png';
  }

  Widget _buildSubmissionList(String status) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchUserSubmissions(status),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (snapshot.hasData) {
          var submissions = snapshot.data ?? [];
          if (submissions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.insert_drive_file,
                      size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                      'You Have No ${status == 'Pending' ? 'Pending' : 'Completed'} Enquiries'),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: submissions.length,
            itemBuilder: (context, index) {
              var submission = submissions[index];
              var enquiryId = submission['enquiryId'];
              var status = submission['status'];
              var category = submission['category'];
              var timestamp = submission['timestamp'];
              var files = submission['files'] as List<dynamic>;
              var iconPath = getCategoryIconPath(category);

              return Card(
                margin: const EdgeInsets.all(10.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                elevation: 5.0,
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 16.0),
                      child: ListTile(
                        leading: Image.asset(iconPath, width: 40, height: 40,
                            errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.insert_drive_file);
                        }),
                        title: Text(
                          'Enquiry ID: $enquiryId',
                          style: const TextStyle(
                              fontSize: 18.0, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$category',
                              style: const TextStyle(fontSize: 16.0),
                            ),
                            if (timestamp != null)
                              Text(
                                '${timestamp.toLocal()}',
                                style: const TextStyle(
                                    fontSize: 14.0, color: Colors.grey),
                              ),
                            const SizedBox(height: 10),
                            Wrap(
                              children: files.map((file) {
                                var fileUrl = file['url'] as String;
                                var fileName = file['name'] as String;
                                return Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: GestureDetector(
                                    onTap: () {
                                      _playVideo(context, fileUrl);
                                    },
                                    child: Chip(
                                      label: Text(fileName),
                                      avatar: const Icon(Icons.attach_file),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        trailing: Chip(
                          label: Text(
                            status,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                          backgroundColor: status == 'completed'
                              ? Colors.green
                              : const Color.fromRGBO(0, 43, 135, 1),
                          padding: const EdgeInsets.all(0),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  EnquiryDetailPage(enquiryId: enquiryId),
                            ),
                          );
                        },
                      ),
                    ),
Positioned(
  right: 40,
  top: 2,
  child: Container(
    decoration: BoxDecoration(
      color: Colors.red, // Background color for the button
      borderRadius: BorderRadius.circular(8), // Rounded corners
    ),
    // ignore: prefer_const_constructors
    constraints: BoxConstraints(
      maxWidth: 80, // Set the max width for the button (slightly bigger)
      maxHeight: 35, // Set the max height for the button (slightly bigger)
    ),
    child: TextButton(
      onPressed: () {
        _showDeleteConfirmationDialog(submission['docId']);
      },
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Small padding
        tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Reduce hit area
      ),
      child: const Text(
        'Delete',
        style: TextStyle(
          color: Color.fromARGB(255, 233, 229, 228), // Text color
          fontSize: 14, // Slightly bigger text size
        ),
      ),
    ),
  ),
),



                  ],
                ),
              );
            },
          );
        } else {
          return const Center(child: Text('No submissions found.'));
        }
      },
    );
  }

  Future<void> _showDeleteConfirmationDialog(String docId) async {
    bool? deleteConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Are you sure to delete this enquiry?'),
          actions: [
            TextButton(
              child: const Text('No'),
              onPressed: () {
                Navigator.of(context).pop(false); // User chose not to delete
              },
            ),
            TextButton(
              child: const Text('Yes'),
              onPressed: () {
                Navigator.of(context).pop(true); // User confirmed deletion
              },
            ),
          ],
        );
      },
    );

    if (deleteConfirmed == true) {
      _deleteSubmission(docId);
    }
  }

  Future<void> _deleteSubmission(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('responses')
          .doc(docId)
          .update({'is_deleted': true});
      setState(() {}); // Refresh the list after deletion
    } catch (e) {
      print('Error deleting submission: $e');
    }
  }

  void _playVideo(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) {
        return VideoPlayerDialog(url: url);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enquiry History'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Completed'),
            Tab(text: 'Pending'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSubmissionList('All'),
          _buildSubmissionList('completed'),
          _buildSubmissionList('pending'),
        ],
      ),
    );
  }
}

class VideoPlayerDialog extends StatefulWidget {
  final String url;

  const VideoPlayerDialog({Key? key, required this.url}) : super(key: key);

  @override
  _VideoPlayerDialogState createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
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
    return Dialog(
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: _controller.value.isInitialized
            ? VideoPlayer(_controller)
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
