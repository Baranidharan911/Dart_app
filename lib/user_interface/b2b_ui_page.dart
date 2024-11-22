// ignore_for_file: unused_import, unused_local_variable, use_key_in_widget_constructors, library_private_types_in_public_api, use_build_context_synchronously, avoid_print, prefer_const_constructors, sized_box_for_whitespace, unnecessary_cast, deprecated_member_use, curly_braces_in_flow_control_structures, unused_element, prefer_const_literals_to_create_immutables, avoid_types_as_parameter_names

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:techwiz/auth/login_page.dart';
import 'package:techwiz/payment_gatewayb2b.dart';
import 'package:techwiz/two_way_chat/admin_chat.dart';
import 'package:techwiz/user/profile_page.dart';
import 'package:techwiz/user/submissions_page.dart';
import 'package:techwiz/user_interface/b2b_ui_page.dart';
import 'package:techwiz/webview/webview_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:techwiz/two_way_chat/two_way_chat_page.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:techwiz/main.dart';

// Content from api_service.dart
class ApiService {
  final String apiUrl = "https://ibots.in/wp-json/wp/v2/product";

  Future<List<dynamic>> fetchPostsByPage(int page) async {
    final response = await http.get(Uri.parse('$apiUrl?page=$page'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load posts');
    }
  }

  Future<int> fetchTotalPages() async {
    final response = await http.get(Uri.parse(apiUrl));
    if (response.statusCode == 200) {
      final totalPages = response.headers['x-wp-totalpages'];
      return int.tryParse(totalPages ?? '') ?? 1;
    } else {
      throw Exception('Failed to load total pages');
    }
  }
}

// Content from chat_service.dart
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

// Content from app_drawer.dart
class AppDrawer extends StatefulWidget {
  @override
  _AppDrawerState createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String username = 'User';
  String userId = '';
  String enquiryId = '';
  String technicianId = '';

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('userId') ?? '';
      enquiryId = prefs.getString('enquiryId') ?? '';
      technicianId = prefs.getString('technicianId') ?? '';
    });
    _fetchUsernameFromFirestore(); // Fetch username from Firestore
  }

  Future<void> _fetchUsernameFromFirestore() async {
    var currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      setState(() {
        username = userDoc['username'] ?? 'User';
      });
    }
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 0),
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color.fromRGBO(0, 43, 135, 1),
            ),
            child: Text(
              '\nHello! $username',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person, color: Color(0xFF6C7072)),
            title: const Text('Your Profile'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.assignment, color: Color(0xFF6C7072)),
            title: const Text('Your Submissions'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SubmissionsPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.chat, color: Color(0xFF6C7072)),
            title: const Text('Chat'),
            onTap: () {
              // Set the values in ChatService
              ChatService().userId = userId;
              ChatService().enquiryId = enquiryId;
              ChatService().technicianId = technicianId;
              Navigator.pushNamed(context, '/chat');
            },
          ),
          ListTile(
            leading: const Icon(Icons.store, color: Color(0xFF6C7072)),
            title: const Text('Shopping'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WebViewPage(url: 'https://ibots.in'),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.help, color: Color(0xFF6C7072)),
            title: const Text('Help & Support'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const HelpSupportPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFF6C7072)),
            title: const Text('Logout'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              await _clearSession();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class B2BUIPage extends StatefulWidget {
  final String username;

  const B2BUIPage({super.key, required this.username});

  @override
  _B2BUIPageState createState() => _B2BUIPageState();
}

class _B2BUIPageState extends State<B2BUIPage> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 1; // Set to 1 to start on Home
  late Timer _timer;
  List<String> _imageUrls = [];
  List<String> _localImages = [];
  final CollectionReference _imageCollection =
      FirebaseFirestore.instance.collection('b2b_images');
  bool _loading = true;
  String profileImageUrl = '';
  String username = 'User';
  int unreadNotificationsCount = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPage);
    _fetchAndCacheImages();
    _fetchProfileImage();
    _fetchUsernameAndNotifications();
  }

  Future<void> _fetchProfileImage() async {
    var currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      setState(() {
        profileImageUrl = userDoc['profileImageUrl'] ?? '';
      });
    }
  }

  Future<void> _fetchUsernameAndNotifications() async {
    var currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      setState(() {
        username = userDoc['username'] ?? 'User';
      });

      getUnreadNotificationsCount().listen((count) {
        setState(() {
          unreadNotificationsCount = count;
        });
      });
    }
  }

  Future<void> _fetchAndCacheImages() async {
    try {
      QuerySnapshot snapshot = await _imageCollection.get();
      List<String> urls =
          snapshot.docs.map((doc) => doc['url'] as String).toList();

      Directory appDocDir = await getApplicationDocumentsDirectory();
      String appDocPath = appDocDir.path;

      List<String> localPaths = [];

      for (String url in urls) {
        String fileName = url.split('/').last;
        File file = File('$appDocPath/$fileName');

        if (await file.exists()) {
          localPaths.add(file.path);
        } else {
          try {
            var response = await http.get(Uri.parse(url));
            if (response.statusCode == 200) {
              await file.writeAsBytes(response.bodyBytes);
              localPaths.add(file.path);
            } else {
              print('Error downloading image: ${response.statusCode}');
            }
          } catch (e) {
            print('Error downloading image: $e');
          }
        }
      }

      setState(() {
        _imageUrls = urls;
        _localImages = localPaths;
        _loading = false;
        _startAutoScroll();
        _preloadImages(0); // Preload initial images
      });
    } catch (e) {
      print('Error fetching images from Firestore: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 2), (Timer timer) {
      if (_pageController.hasClients && _localImages.isNotEmpty) {
        int nextPage =
            (_pageController.page!.toInt() + 1) % _localImages.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
        _preloadImages(nextPage);
      }
    });
  }

  void _preloadImages(int currentPage) {
    if (_localImages.isEmpty) return;

    int nextPage = (currentPage + 1) % _localImages.length;
    int nextNextPage = (currentPage + 2) % _localImages.length;

    _preloadImage(_localImages[nextPage]);
    _preloadImage(_localImages[nextNextPage]);
  }

  void _preloadImage(String path) {
    final fileImage = Image.file(File(path));
    precacheImage(fileImage.image, context);
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    return Scaffold(
      backgroundColor: Colors.white, // White background for the main page
      drawer: AppDrawer(),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Column(
                      children: [
                        Header(
                          profileImageUrl: profileImageUrl,
                          username: username,
                          unreadNotificationsCount: unreadNotificationsCount,
                        ),
                        ImageCarousel(
                          loading: _loading,
                          localImages: _localImages,
                          pageController: _pageController,
                          onEnquiryPressed: () {
                            Navigator.pushNamed(context, '/chat');
                          },
                        ),
                        const PopularPostsView(),
                        Padding(
                          padding: EdgeInsets.all(screenWidth * 0.04),
                          child: Row(
                            children: [
                              Image.asset(
                                'assets/icons/FAQ.png',
                                height: screenHeight * 0.05,
                                width: screenHeight * 0.05,
                              ),
                              SizedBox(width: screenWidth * 0.02),
                              Text(
                                'FAQs',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.05,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange, // Matching color from your design
                                ),
                              ),
                            ],
                          ),
                        ),
                        const FAQWidget(),
                        const SizedBox(height: 150),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: screenHeight * 0.12,
              left: 0,
              right: 0,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.10),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/chat');
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color.fromRGBO(0, 43, 135, 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: screenHeight * 0.01,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.assignment, // The icon you want to use
                        size: screenWidth * 0.05, // Adjust the size as needed
                      ),
                      SizedBox(width: 8), // Adds space between the icon and the text
                      Text(
                        'Submit Enquiry',
                        style: TextStyle(fontSize: screenWidth * 0.05),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: BottomNavBar(
                currentPage: _currentPage,
                onTap: (index) {
                  if (index == 2) {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                  setState(() {
                    _currentPage = index;
                  });
                },
                username: widget.username,
                scrollController: _scrollController,
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class BottomNavBar extends StatefulWidget {
  final int currentPage;
  final ValueChanged<int> onTap;
  final String username;
  final ScrollController scrollController;

  const BottomNavBar({
    super.key,
    required this.currentPage,
    required this.onTap,
    required this.username,
    required this.scrollController,
  });

  @override
  _BottomNavBarState createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  late int _selectedIndex;
  String username = 'User';
  String userId = '';
  String enquiryId = '';
  String technicianId = '';

  @override
  void initState() {
    super.initState();
    _selectedIndex = 2; // Set Home as the default index
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      username = prefs.getString('username') ?? 'User';
      userId = prefs.getString('userId') ?? '';
      enquiryId = prefs.getString('enquiryId') ?? '';
      technicianId = prefs.getString('technicianId') ?? '';
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    widget.onTap(index);

    switch (index) {
      case 0:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SubmissionsPage(),
          ),
        ).then((_) {
          setState(() {
            _selectedIndex = 2; // Return to home when coming back
          });
        });
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WebViewPage(url: 'https://ibots.in'),
          ),
        ).then((_) {
          setState(() {
            _selectedIndex = 2; // Return to home when coming back
          });
        });
        break;
      case 2:
        widget.scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WebViewPage(url: 'https://protowiz.in'),
          ),
        ).then((_) {
          setState(() {
            _selectedIndex = 2; // Return to home when coming back
          });
        });
        break;
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StackPage(userId: username),
          ),
        ).then((_) {
          setState(() {
            _selectedIndex = 2; // Return to home when coming back
          });
        });
        break;
      default:
        setState(() {
          _selectedIndex = 2; // Ensure home is the default
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return SizedBox(
      height: screenHeight * 0.12,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white, // Set the background color to white
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    spreadRadius: 2,
                    blurRadius: 5,
                  ),
                ],
              ),
              child: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.white, // Ensure the background is white
                currentIndex: _selectedIndex, // Maintain current index
                selectedItemColor: Colors.blue,
                unselectedItemColor: Colors.grey,
                onTap: _onItemTapped, // Use the custom function
                items: [
                  BottomNavigationBarItem(
                    icon: Image.asset(
                      'assets/icons/enquiry_icon.png',
                      height: screenHeight * 0.035,
                    ),
                    label: 'Enquiry',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(
                      Icons.shopping_cart,
                      size: screenHeight * 0.035,
                      color: Colors.black,
                    ), // Default shopping icon
                    label: 'Shopping',
                  ),
                  BottomNavigationBarItem(
                    icon: Container(
                      decoration: BoxDecoration(
                        color: _selectedIndex == 2
                            ? Color(0xFF002B87)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        'assets/icons/home_icon.png',
                        height: screenHeight * 0.035,
                      ),
                    ),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(
                      Icons.developer_mode,
                      size: screenHeight * 0.035,
                      color: Colors.black,
                    ), // Default development icon
                    label: 'Development',
                  ),
                  BottomNavigationBarItem(
                    icon: Image.asset(
                      'assets/icons/inbox_icon.png',
                      height: screenHeight * 0.035,
                    ),
                    label: 'Inbox',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FAQWidget extends StatefulWidget {
  const FAQWidget({super.key});

  @override
  _FAQWidgetState createState() => _FAQWidgetState();
}

class _FAQWidgetState extends State<FAQWidget> {
  int? _expandedIndex;
  final ScrollController _scrollController = ScrollController();
  final PageStorageKey<String> _listKey = PageStorageKey<String>('faq_list');
  List<Map<String, dynamic>> _faqs = [];
  bool _loading = true;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _loadFAQsFromLocalStorage();
    _startUpdateTimer();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFAQsFromLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final faqsString = prefs.getString('faqs');
    if (faqsString != null) {
      setState(() {
        _faqs = List<Map<String, dynamic>>.from(
            (jsonDecode(faqsString) as List<dynamic>)
                .map((item) => item as Map<String, dynamic>));
        _loading = false;
      });
    }
    _fetchAndSaveFAQs();
  }

  Future<void> _fetchAndSaveFAQs() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('B2b_FAQ')
          .doc('faq')
          .get();

      if (snapshot.exists) {
        final fetchedFaqs = (snapshot.data() as Map<String, dynamic>)
            .entries
            .map((entry) => entry.value as Map<String, dynamic>)
            .toList();

        setState(() {
          _faqs = fetchedFaqs;
          _loading = false;
        });

        final prefs = await SharedPreferences.getInstance();
        prefs.setString('faqs', jsonEncode(_faqs));
      } else {
        print("No FAQ document found.");
      }
    } catch (e) {
      print("Error loading FAQs: $e");
    }
  }

  void _startUpdateTimer() {
    _updateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _fetchAndSaveFAQs();
    });
  }

  void _scrollToExpandedItem(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        double targetOffset = 0;
        for (int i = 0; i < index; i++) {
          targetOffset += _getItemHeight(i);
        }
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  double _getItemHeight(int index) {
    return _expandedIndex == index
        ? 200.0
        : 100.0; // Adjust based on your layout
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return _loading
        ? const Center(child: CircularProgressIndicator())
        : _faqs.isEmpty
            ? const Center(child: Text('No FAQs available'))
            : SingleChildScrollView(
                controller: _scrollController,
                key: _listKey,
                child: Column(
                  children: _faqs.asMap().entries.map((entry) {
                    int index = entry.key;
                    Map<String, dynamic> faq = entry.value;
                    return Column(
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              if (_expandedIndex == index) {
                                _expandedIndex = null;
                              } else {
                                _expandedIndex = index;
                                _scrollToExpandedItem(index);
                              }
                            });
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.04, vertical: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        faq['Questions'],
                                        style: GoogleFonts.quicksand(
                                          fontSize: screenWidth * 0.04,
                                          fontWeight: FontWeight.bold,
                                          color: _expandedIndex == index
                                              ? Colors.orange
                                              : Colors.black,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      _expandedIndex == index
                                          ? Icons.remove
                                          : Icons.add,
                                      color: _expandedIndex == index
                                          ? Colors.orange
                                          : Colors.grey,
                                    ),
                                  ],
                                ),
                                if (_expandedIndex == index)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      faq['Answers'],
                                      style: GoogleFonts.montserrat(
                                        fontSize: screenWidth * 0.035,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: Colors.grey[300],
                        ),
                      ],
                    );
                  }).toList(),
                ),
              );
  }
}
//header class
class Header extends StatefulWidget {
  final String profileImageUrl;
  final String username; // The username to display
  final int unreadNotificationsCount; // The count of unread notifications

  const Header({
    Key? key,
    required this.profileImageUrl,
    required this.username, // Initialize the username
    required this.unreadNotificationsCount,
  }) : super(key: key);

  @override
  _HeaderState createState() => _HeaderState();
}

class _HeaderState extends State<Header> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Stack(
      clipBehavior: Clip.none, // Allow the search bar to overflow outside the header
      children: [
        // Background with wave
        Container(
          height: screenHeight * 0.28,
          color: const Color.fromARGB(255, 134, 169, 234), // Top dark blue color
          child: ClipPath(
            clipper: WaveClipper(),
            child: Container(
              color: const Color(0xFF0040A4), // Bottom lighter blue color
              height: screenHeight * 0.15,
            ),
          ),
        ),
        // Menu Icon with Hello Text
        Positioned(
          top: screenHeight * 0.05,
          left: screenWidth * 0.05,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.menu),
                color: Colors.white,
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              ),
              SizedBox(height: screenHeight * 0.01),
              Text(
                'Hello, ${widget.username}!', // Displaying the username from Firestore
                style: TextStyle(
                  color: Colors.white,
                  fontSize: screenWidth * 0.06,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        // Notifications Icon
        Positioned(
          top: screenHeight * 0.05,
          right: screenWidth * 0.16, // Adjust this value to position the icon correctly
          child: Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                color: Colors.white,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NotificationPage()),
                  );
                },
              ),
              if (widget.unreadNotificationsCount > 0)
                Positioned(
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${widget.unreadNotificationsCount}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Profile picture
        Positioned(
          top: screenHeight * 0.05,
          right: screenWidth * 0.05,
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
            child: CircleAvatar(
              backgroundImage: widget.profileImageUrl.isNotEmpty
                  ? NetworkImage(widget.profileImageUrl)
                      as ImageProvider<Object>
                  : const AssetImage('assets/profile.jpg')
                      as ImageProvider<Object>,
              radius: screenWidth * 0.05,
            ),
          ),
        ),
        // Search bar with input field
        Positioned(
          top: screenHeight * 0.22, // Adjust to place the search bar half in the header and half in the body
          left: screenWidth * 0.05,
          right: screenWidth * 0.05,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: screenWidth * 0.03,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(screenWidth * 0.05),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: Colors.grey),
                SizedBox(width: screenWidth * 0.02),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search any Services..',
                      border: InputBorder.none,
                    ),
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: screenWidth * 0.04,
                    ),
                  ),
                  
                ),
              ],
            ),

          ),
        ),
      ],
    );
  }
}

class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0.0, size.height);

    // Adjust the control points and end points for a smoother wave
    var firstControlPoint = Offset(size.width * 0.3, size.height - 50);
    var firstEndPoint = Offset(size.width * 0.45, size.height - 40);
    var secondControlPoint = Offset(size.width * 0.7, size.height - 20);
    var secondEndPoint = Offset(size.width, size.height - 160);

    path.quadraticBezierTo(firstControlPoint.dx, firstControlPoint.dy,
        firstEndPoint.dx, firstEndPoint.dy);
    path.quadraticBezierTo(secondControlPoint.dx, secondControlPoint.dy,
        secondEndPoint.dx, secondEndPoint.dy);

    path.lineTo(size.width, 0.0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

Stream<int> getUnreadNotificationsCount() {
  // Implement your logic to get unread notifications count
  // Example:
  return FirebaseFirestore.instance
      .collection('notifications')
      .where('read', isEqualTo: false)
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
}


class ImageCarousel extends StatefulWidget {
  final bool loading;
  final List<String> localImages;
  final PageController pageController;
  final VoidCallback onEnquiryPressed;

  const ImageCarousel({
    super.key,
    required this.loading,
    required this.localImages,
    required this.pageController,
    required this.onEnquiryPressed,
  });

  @override
  _ImageCarouselState createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  late final PageController _problemPageController;
  List<Map<String, dynamic>> problemCategories = [];

  @override
  void initState() {
    super.initState();
    _problemPageController = PageController(viewportFraction: 0.33);
    fetchProblemCategories(); // Fetch problem categories from Firestore
  }

  Future<void> fetchProblemCategories() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('problem_categories')
          .get();
      setState(() {
        problemCategories = snapshot.docs.map((doc) => doc.data()).toList();
      });
      print('Fetched problem categories: $problemCategories');
    } catch (e) {
      print('Error fetching problem categories: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchImagesAndRoutes() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('b2b_images') // Assuming you are storing image URLs and routes in this collection
          .get();
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error fetching images and routes: $e');
      return [];
    }
  }

  @override
  void dispose() {
    _problemPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchImagesAndRoutes(),
      builder: (context, snapshot) {
        if (widget.loading || snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text('Error fetching images'));
        }

        final imagesAndRoutes = snapshot.data;

        if (imagesAndRoutes == null || imagesAndRoutes.isEmpty) {
          return const Center(child: Text('No images found'));
        }

        return Column(
          children: [
            SizedBox(
              height: screenHeight * 0.40,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: imagesAndRoutes.map((imageData) {
                    final imageUrl = imageData['url'];
                    final route = imageData['route']; // Fetching the route dynamically

                    return GestureDetector(
                      onTap: () {
                        if (route != null) {
                          Navigator.pushNamed(context, route); // Navigate to the fetched route
                        } else {
                          print('Route not found for image');
                        }
                      },
                      child: buildImagePage(imageUrl),
                    );
                  }).toList(),
                ),
              ),
            ),
            // Categories Section
            Padding(
              padding: EdgeInsets.all(screenWidth * 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/icons/featured.png', // Replace with your actual icon
                        height: screenHeight * 0.05,
                        width: screenHeight * 0.05,
                      ),
                      SizedBox(width: screenWidth * 0.02),
                      Text(
                        'Featured Category',
                        style: TextStyle(
                          fontSize: screenWidth * 0.05,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange, // Matching color from your design
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.01), // Reduced space
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(9, (index) {
                        final List<String> categories = [
                          'Electronics',
                          'Embedded Systems',
                          'Robotics',
                          'Internet of Things',
                          '3D Printing',
                          'Automation',
                          'Electric Vehicle',
                          'Drone',
                          'Solar'
                        ];
                        final List<String> categoryImages = [
                          'assets/category/electronics.png',
                          'assets/category/embedded.png',
                          'assets/category/robotics.png',
                          'assets/category/iot.png',
                          'assets/category/3d.png',
                          'assets/category/automation.png',
                          'assets/category/ev.png',
                          'assets/category/drone.png',
                          'assets/category/solar.png'
                        ];

                        return GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, '/chat'); // Navigates to /chat route
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
                            child: Column(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.5),
                                        spreadRadius: 2,
                                        blurRadius: 5,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  padding: EdgeInsets.all(screenWidth * 0.04),
                                  child: Image.asset(
                                    categoryImages[index],
                                    height: screenHeight * 0.06,
                                    width: screenHeight * 0.06,
                                  ),
                                ),
                                SizedBox(height: screenHeight * 0.01),
                                Text(
                                  categories[index],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.035,
                                    color: Colors.black54, // Text color
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/chat');
                    },
                    child: Image.asset(
                      'assets/chat_free.png', // Replace with the path to your full image
                      width: 415,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
            ),
            // Problem Types Section
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05, // Horizontal padding around the section
                vertical: screenHeight * 0.02, // Vertical padding around the section
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/icons/problem.png', // Use your actual icon
                        height: screenHeight * 0.05,
                        width: screenHeight * 0.05,
                      ),
                      SizedBox(width: screenWidth * 0.02),
                      Text(
                        'Problem Types',
                        style: TextStyle(
                          fontSize: screenWidth * 0.05,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange, // Matching color from your design
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, // Three items per row
                      childAspectRatio: 1, // Square items
                      crossAxisSpacing: screenWidth * 0.04, // Horizontal spacing between items
                      mainAxisSpacing: screenHeight * 0.03, // Vertical spacing between items
                    ),
                    itemCount: problemCategories.length, // Number of problem categories
                    itemBuilder: (context, index) {
                      final category = problemCategories[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/chat');
                        },
                        child: Container(
                          padding: EdgeInsets.all(screenWidth * 0.02), // Padding inside each card
                          decoration: BoxDecoration(
                            color: Colors.white, // Background color for the cards
                            borderRadius: BorderRadius.circular(12), // Rounded corners
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 3,
                                blurRadius: 5,
                                offset: Offset(0, 3), // Changes position of shadow
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.network(
                                category['image_url'], // Using network images as is
                                height: screenHeight * 0.04,
                                width: screenHeight * 0.04,
                              ),
                              SizedBox(height: screenHeight * 0.01),
                              Text(
                                category['name'],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: screenWidth * 0.035,
                                  color: Colors.black54, // Text color
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget buildImagePage(String imageUrl) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.0),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.error); // Display an error icon if the image fails to load
          },
        ),
      ),
    );
  }
}



// Content from notification_page.dart
class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  late FirebaseMessaging _firebaseMessaging;
  final List<DocumentSnapshot> _notifications = [];
  late String _currentUserId;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _firebaseMessaging = FirebaseMessaging.instance;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        _showNotificationDialog(message.notification!.body ?? '', message.data);
      }

      _handleMessage(message.data);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
      _handleMessage(message.data);
    });

    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('Initial message data: ${message.data}');
        _handleMessage(message.data);
      }
    });

    _fetchNotifications();
  }

  // Override the back button behavior
  Future<bool> _onWillPop() async {
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    return false;
  }

  void _showNotificationDialog(String message, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(data['title'] ?? 'New Notification'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMessageWithButtons(message, data),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMessageWithButtons(String message, Map<String, dynamic> data) {
    List<Widget> messageParts = [];

    message.split('\n').forEach((line) {
      if (line.contains('<PAY>')) {
        messageParts.add(
          ElevatedButton(
            onPressed: () {
              print("Pay button pressed!"); // Debug to ensure button is triggered
              _handleAction('PAY_ACTION', data);
            },
            child: Text('Pay'),
          ),
        );
      } else if (line.contains('<SCHEDULE MEETING>')) {
        messageParts.add(
          ElevatedButton(
            onPressed: () {
              _handleAction('SCHEDULE_ACTION', data);
            },
            child: Text('Schedule Meeting'),
          ),
        );
      } else if (line.contains('<CHAT WITH OUR ADMIN>')) {
        messageParts.add(
          ElevatedButton(
            onPressed: () {
              print('Chat with Admin button pressed');
              _handleAction('CHAT_ACTION', data);
            },
            child: Text('Chat with Admin'),
          ),
        );
      } else {
        messageParts.add(Text(line));
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: messageParts,
    );
  }

  /// Helper function to parse advanceAmount correctly
  String parseAdvanceAmount(dynamic amount) {
    try {
      if (amount is int) {
        return amount.toDouble().toString(); // Handle integers
      } else if (amount is double) {
        return amount.toString(); // Handle floats
      } else if (amount is String) {
        return double.parse(amount).toString(); // Parse string as double
      }
    } catch (e) {
      print('Error parsing advanceAmount: $e');
    }
    return '0.0'; // Default value if parsing fails
  }

  void _handleAction(String action, Map<String, dynamic> data) {
    if (action == 'PAY_ACTION') {
      String enquiryId = data['enquiryId'] ?? 'defaultEnquiryId';
      String userId = data['userId'] ?? _currentUserId;

      // Fetch advanceAmount from Firebase using enquiryId
      FirebaseFirestore.instance
          .collection('notifications')
          .where('enquiryId', isEqualTo: enquiryId)
          .where('userId', isEqualTo: userId)
          .where('display', isEqualTo: true)
          .get()
          .then((querySnapshot) {
        if (querySnapshot.docs.isNotEmpty) {
          var notificationData = querySnapshot.docs.first.data() as Map<String, dynamic>;
          String advanceAmount = parseAdvanceAmount(notificationData['advanceAmount']); // Use helper function

          // Mark notification as read
          _markAsRead(querySnapshot.docs.first);

          // Navigate to PaymentsGateway with the fetched advanceAmount
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => B2BPaymentsGateway(
                paymentAmount: advanceAmount, // Set the payment amount from Firebase
                orderId: enquiryId, // Use enquiryId as orderId if needed
                userId: userId, // Pass the userId
              ),
            ),
          );
        } else {
          print('No matching notification found');
        }
      }).catchError((error) {
        print('Error fetching advanceAmount: $error');
      });
    } else if (action == 'SCHEDULE_ACTION') {
      _sendScheduleMessageFromData(data);
    } else if (action == 'CHAT_ACTION') {
      try {
        print("Chat with Admin action detected");

        String enquiryId = data['enquiryId'] ?? 'defaultEnquiryId';
        String userId = data['userId'] ?? 'defaultUserId';

        if (userId != 'defaultUserId' && enquiryId != 'defaultEnquiryId') {
          Navigator.pushNamed(
            context,
            '/adminChat',
            arguments: {
              'userId': userId,
              'enquiryId': enquiryId,
            },
          );
        } else {
          print('Navigation failed: Invalid userId or enquiryId');
        }
      } catch (e) {
        print("Exception caught during navigation: $e");
      }
    }
  }

  Future<void> _fetchNotifications() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserId = user.uid;

      FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: _currentUserId)
          .where('display', isEqualTo: true)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _notifications.clear();
            _notifications.addAll(snapshot.docs);
            _unreadCount = snapshot.docs
                .where((doc) =>
                    (doc.data() as Map<String, dynamic>)['status'] == 'unread')
                .length;
          });
        }
      });
    }
  }

  Future<void> _markAsRead(DocumentSnapshot notification) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notification.id)
        .update({'status': 'read'});
    if (mounted) {
      setState(() {
        _unreadCount--;
      });
    }
  }

  Future<void> _deleteNotification(DocumentSnapshot notification) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notification.id)
        .update({'display': false});
    if (mounted) {
      setState(() {
        _notifications.remove(notification);
      });
    }
  }

  void _handleNotificationTap(DocumentSnapshot notification) {
    var data = notification.data() as Map<String, dynamic>;
    if (data['status'] == 'unread') {
      _markAsRead(notification);
    }

    if (data.containsKey('route')) {
      Navigator.pushNamed(context, data['route']);
    } else if (data.containsKey('url')) {
      _launchURL(data['url']);
    } else {
      print('Notification tapped with message: ${data['message']}');
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<void> _sendScheduleMessageFromData(Map<String, dynamic> data) async {
    String enquiryId = data['enquiryId'] ?? '';
    Timestamp currentTimestamp = Timestamp.now();
    if (enquiryId.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('DASHBOARD_CHAT')
          .doc(enquiryId)
          .update({
        'customer_to_admin': FieldValue.arrayUnion([
          {
            'sender': 'customer',
            'text': 'Schedule',
            'timestamp': currentTimestamp,
          }
        ])
      });
      print("Schedule message sent");

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Stay tuned..!'),
            content: Text("We're connecting you to our technical engineer"),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  void _handleMessage(Map<String, dynamic> data) {
    if (data['action'] == 'SCHEDULE_ACTION') {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Stay tuned..!'),
            content: Text("We're connecting you to our technical engineer"),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    } else if (data['action'] == 'PAY_ACTION') {
      _handleAction('PAY_ACTION', data);
    } else if (data['action'] == 'CHAT_ACTION') {
      Future.delayed(Duration(milliseconds: 100), () {
        Navigator.pushNamed(
          context,
          '/adminChat',
          arguments: {
            'userId': _currentUserId,
            'enquiryId': data['enquiryId'] ?? 'enquiryId',
          },
        );
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return WillPopScope(
      onWillPop: _onWillPop, // Handles back button press
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
            },
          ),
        ),
        body: ListView.builder(
          itemCount: _notifications.length,
          itemBuilder: (context, index) {
            var notification =
                _notifications[index].data() as Map<String, dynamic>;
            bool isUnread = notification['status'] == 'unread';
            bool isAdmin = notification['userType'] == 'Admin';
            return GestureDetector(
              onTap: () => _handleNotificationTap(_notifications[index]),
              child: Container(
                margin: EdgeInsets.symmetric(
                    vertical: screenHeight * 0.01,
                    horizontal: screenWidth * 0.04),
                padding: EdgeInsets.all(screenWidth * 0.04),
                decoration: BoxDecoration(
                  color: isUnread
                      ? Color.fromRGBO(0, 43, 135, 1)
                      : Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Stack(
                  children: [
                    if (isAdmin)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: Icon(
                          Icons.person,
                          color: isUnread ? Colors.white : Colors.black,
                          size: screenWidth * 0.1,
                        ),
                      ),
                    Positioned(
                      right: 0,
                      child: IconButton(
                        icon: Icon(Icons.close,
                            color: isUnread ? Colors.white : Colors.black),
                        onPressed: () =>
                            _deleteNotification(_notifications[index]),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                          left: isAdmin ? screenWidth * 0.12 : 0,
                          right: screenWidth * 0.1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification['userType'] ?? 'Unknown',
                            style: TextStyle(
                              color: isUnread ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: screenWidth * 0.04,
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.01),
                          _buildMessageWithButtons(
                              notification['message'] ?? '', {
                            'userId': notification['userId'],
                            'enquiryId': notification['enquiryId'],
                            'orderId': notification['orderId'],
                            'url': notification['url'], // Add URL if available
                          }),
                          SizedBox(height: screenHeight * 0.01),
                          Text(
                            notification['timestamp'] != null
                                ? (notification['timestamp'] as Timestamp)
                                    .toDate()
                                    .toString()
                                : 'No Timestamp',
                            style: TextStyle(
                              color: isUnread
                                  ? Colors.white.withOpacity(0.7)
                                  : Colors.black.withOpacity(0.7),
                              fontSize: screenWidth * 0.03,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}



class PopularPostsView extends StatefulWidget {
  const PopularPostsView({super.key});

  @override
  _PopularPostsViewState createState() => _PopularPostsViewState();
}

class _PopularPostsViewState extends State<PopularPostsView> {
  late Future<List<dynamic>> futurePosts;
  final ApiService apiService = ApiService();
  final PageController _pageController = PageController(initialPage: 1);
  late Timer _timer;
  List<dynamic> posts = [];

  @override
  void initState() {
    super.initState();
    futurePosts = apiService.fetchPostsByPage(1);
    futurePosts.then((data) {
      if (data.isNotEmpty) {
        setState(() {
          posts = [data.last] + data + [data.first]; // Add clones at the ends
        });
        _startAutoScroll();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel(); // Cancel the timer when the widget is disposed
    _pageController.dispose(); // Dispose of the page controller
    super.dispose();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (_pageController.hasClients) {
        int nextPage = _pageController.page!.toInt() + 1;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });

    _pageController.addListener(() {
      if (_pageController.page == posts.length - 1) {
        // Reached the last page (duplicate of the first)
        _pageController.jumpToPage(1); // Jump back to the first original page
      } else if (_pageController.page == 0) {
        // Reached the first page (duplicate of the last)
        _pageController
            .jumpToPage(posts.length - 2); // Jump to the last original page
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const double cardHeight = 150.0;

    return Container(
      color: Color(0xFF0040A4), // Blue background color
      padding: EdgeInsets.symmetric(
          vertical: 20.0,
          horizontal: screenWidth * 0.05), // Adjust padding as needed
      child: FutureBuilder<List<dynamic>>(
        future: futurePosts,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator();
          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Text('No posts found');
          } else {
            return Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.trending_up,
                      color: Colors.white,
                      size: screenWidth * 0.07,
                    ),
                    SizedBox(width: screenWidth * 0.03),
                    Text(
                      'Popular Products',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: screenWidth * 0.05,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.0), // Adjust space as needed
                SizedBox(
                  height: cardHeight + 40, // Extra space for scaling effect
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      final imageUrl =
                          post['yoast_head_json']['og_image'][0]['url'];
                      final postLink = post['link'];

                      return GestureDetector(
                        onTap: () => launch(
                            postLink), // Navigate directly to the web link
                        child: Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8.0),
                          color: Colors.white, // White background for cards
                          child: Container(
                            width: screenWidth * 0.6,
                            height: cardHeight,
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  ),
                                ),
                                const SizedBox(height: 8.0),
                                Text(
                                  post['title']['rendered'],
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}

List<int> generatePagination(int currentPage, int totalPages) {
  List<int> pages = [];

  if (totalPages <= 7) {
    for (int i = 1; i <= totalPages; i++) {
      pages.add(i);
    }
  } else {
    pages.add(1);
    pages.add(2);

    if (currentPage > 4) pages.add(-1); // Use -1 to represent "..."

    int startPage = (currentPage - 2).clamp(3, totalPages - 2);
    int endPage = (currentPage + 2).clamp(5, totalPages - 2);

    for (int i = startPage; i <= endPage; i++) {
      pages.add(i);
    }

    if (currentPage < totalPages - 3)
      pages.add(-1); // Use -1 to represent "..."
    pages.add(totalPages - 1);
    pages.add(totalPages);
  }

  return pages;
}

class PostDetailPage extends StatelessWidget {
  final String postLink;

  const PostDetailPage({super.key, required this.postLink});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Details'),
      ),
      body: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Center(
          child: ElevatedButton(
            onPressed: () {
              // Open the link in the browser
              // Use url_launcher package for this
              launch(postLink);
            },
            child: const Text('Open Post'),
          ),
        ),
      ),
    );
  }
}

// Content from stack_page.dart
class StackPage extends StatelessWidget {
  final String userId;

  const StackPage({super.key, required this.userId});

  String getCategoryIconPath(String category) {
    String sanitizedCategory = category.toLowerCase().replaceAll(' ', '-');
    if (sanitizedCategory == '3d-printing') {
      sanitizedCategory = 'printing-3d'; // Adjusting for the renamed file
    }
    return 'assets/icons/$sanitizedCategory.png';
  }

  Future<String> getCategoryForEnquiry(String enquiryId) async {
    var currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('responses')
          .doc(enquiryId)
          .get();

      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        var responses = data['responses'] as List<dynamic>? ?? [];
        for (var response in responses) {
          if (response['context'] == 'field_of_category_troubleshoot' ||
              response['context'] == 'field_of_category_new_project') {
            return response['response'] ?? 'No category';
          }
        }
      }
    }
    return 'No category';
  }

  Future<Map<String, dynamic>> getLastMessage(DocumentSnapshot chatDoc) async {
    var chatData = chatDoc.data() as Map<String, dynamic>?;
    if (chatData != null && chatData.containsKey('messages')) {
      var messages = chatData['messages'] as List<dynamic>;
      if (messages.isNotEmpty) {
        var lastMessage = messages.last as Map<String, dynamic>;

        // Check if the last message contains a media file or document
        if (lastMessage.containsKey('mediaUrl') ||
            lastMessage.containsKey('documentUrl')) {
          return {
            'text': 'Media/File received',
            'timestamp': lastMessage['timestamp']
          };
        }

        return lastMessage;
      }
    }
    return {'text': 'No messages yet', 'timestamp': null};
  }

  String formatTimestamp(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    DateTime now = DateTime.now();
    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      return DateFormat('HH:mm').format(date);
    } else {
      return DateFormat('dd/MM/yy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    ChatService().userId = userId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 24),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chat')
            .where('userId', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: Text('Loading chats...'));
          } else if (snapshot.hasError) {
            return const Center(child: Text('Error loading chats.'));
          } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No chats available.'));
          }

          var chatDocs = snapshot.data!.docs;
          chatDocs.sort((a, b) {
            var aData = a.data() as Map<String, dynamic>;
            var bData = b.data() as Map<String, dynamic>;
            var aMessages = aData['messages'] as List<dynamic>;
            var bMessages = bData['messages'] as List<dynamic>;
            var aLastMessage = aMessages.isNotEmpty
                ? aMessages.last as Map<String, dynamic>
                : null;
            var bLastMessage = bMessages.isNotEmpty
                ? bMessages.last as Map<String, dynamic>
                : null;
            var aTimestamp =
                aLastMessage != null && aLastMessage.containsKey('timestamp')
                    ? aLastMessage['timestamp'] as Timestamp
                    : Timestamp(0, 0);
            var bTimestamp =
                bLastMessage != null && bLastMessage.containsKey('timestamp')
                    ? bLastMessage['timestamp'] as Timestamp
                    : Timestamp(0, 0);
            return bTimestamp.compareTo(aTimestamp);
          });

          return ListView.builder(
            itemCount: chatDocs.length,
            itemBuilder: (context, index) {
              var chat = chatDocs[index];
              var chatData = chat.data() as Map<String, dynamic>;
              var enquiryId = chatData['enquiryId'];
              var technicianId = chatData['technicianId'];

              return FutureBuilder<String>(
                future: getCategoryForEnquiry(enquiryId),
                builder: (context, categorySnapshot) {
                  if (categorySnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center();
                  } else if (categorySnapshot.hasError) {
                    return ListTile(
                      title: Text('Enquiry $enquiryId'),
                      subtitle: const Text('Error fetching category'),
                      trailing:
                          Icon(Icons.arrow_forward_ios, color: Colors.grey),
                    );
                  }

                  var category = categorySnapshot.data ?? 'No category';
                  var iconPath = getCategoryIconPath(category);

                  return FutureBuilder<Map<String, dynamic>>(
                    future: getLastMessage(chat),
                    builder: (context, messageSnapshot) {
                      if (messageSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (messageSnapshot.hasError) {
                        return ListTile(
                          title: Text('Enquiry $enquiryId'),
                          subtitle: const Text('Error fetching last message'),
                          trailing:
                              Icon(Icons.arrow_forward_ios, color: Colors.grey),
                        );
                      }

                      var lastMessageData = messageSnapshot.data ??
                          {'text': 'No messages yet', 'timestamp': null};
                      var lastMessage = lastMessageData['text'];
                      var timestamp =
                          lastMessageData['timestamp'] as Timestamp?;

                      return Column(
                        children: [
                          ListTile(
                            leading:
                                Image.asset(iconPath, width: 40, height: 40,
                                    errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.insert_drive_file);
                            }),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Enquiry $enquiryId',
                                  style: const TextStyle(
                                      fontSize: 18.0,
                                      fontWeight: FontWeight.bold),
                                ),
                                if (timestamp != null)
                                  Text(
                                    formatTimestamp(timestamp),
                                    style: const TextStyle(
                                        fontSize: 14.0, color: Colors.grey),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              lastMessage,
                              style: const TextStyle(fontSize: 16.0),
                            ),
                            trailing: Icon(Icons.arrow_forward_ios,
                                color: Colors.grey),
                            onTap: () {
                              ChatService().enquiryId = enquiryId;
                              ChatService().technicianId = technicianId;

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TwoWayChatPage(
                                    userId: userId,
                                    enquiryId: enquiryId,
                                    technicianId: technicianId,
                                  ),
                                ),
                              );
                            },
                          ),
                          Divider(
                            height: 1,
                            color: Colors.grey[300],
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
      backgroundColor: Colors.white,
    );
  }
}

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({Key? key}) : super(key: key);

  @override
  _HelpSupportPageState createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  String location = '';
  String locationLink = '';
  List<String> emails = [];
  List<String> phones = [];

  @override
  void initState() {
    super.initState();
    _fetchHelpSupportData();
  }

  Future<void> _fetchHelpSupportData() async {
    try {
      DocumentSnapshot document = await FirebaseFirestore.instance
          .collection('help_support')
          .doc('contact_info')
          .get();

      if (document.exists) {
        setState(() {
          location = document['location'] ?? 'No location available';
          locationLink = document['location_link'] ?? '';
          emails = List<String>.from(document['emails'] ?? []);
          phones = List<String>.from(document['phones'] ?? []);
        });
      }
    } catch (e) {
      print('Error fetching help & support data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 24),
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: screenHeight * 0.02),
            _buildSupportItem(Icons.location_on, location,
                onTap: () => _launchMap(locationLink)),
            SizedBox(height: screenHeight * 0.02),
            ...emails.map((email) => _buildSupportItem(
                  Icons.email,
                  email,
                  onTap: () => _launchEmail(email),
                )),
            SizedBox(height: screenHeight * 0.02),
            ...phones.map((phone) => _buildSupportItem(
                  Icons.phone,
                  phone,
                  onTap: () => _launchPhoneDialer(phone),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportItem(IconData icon, String text, {VoidCallback? onTap}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: screenWidth * 0.08),
          SizedBox(width: screenWidth * 0.04),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: screenWidth * 0.045),
            ),
          ),
        ],
      ),
    );
  }

  void _launchEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
    );
    if (await canLaunch(emailUri.toString())) {
      await launch(emailUri.toString());
    } else {
      _showErrorDialog(
          'Could not launch email app. Please check if you have an email app installed.');
    }
  }

  void _launchPhoneDialer(String phone) async {
    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: phone,
    );
    if (await canLaunch(phoneUri.toString())) {
      await launch(phoneUri.toString());
    } else {
      _showErrorDialog(
          'Could not launch phone dialer. Please check if you have a phone app installed.');
    }
  }

  void _launchMap(String mapLink) async {
    if (await canLaunch(mapLink)) {
      await launch(mapLink);
    } else {
      _showErrorDialog(
          'Could not launch Google Maps. Please check if you have a maps app installed.');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
