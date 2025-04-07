// Flutter package imports
import 'package:flutter/material.dart';

// Third-party package imports
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';

// Project imports
import 'package:chessapp/components/constants.dart';
import 'package:chessapp/game/get_data/friends.dart';
import 'package:chessapp/components/popup_menu.dart';
import 'package:chessapp/game/main_menu_component/player_stats.dart';

class SideMenu extends StatefulWidget {
  const SideMenu({super.key});

  @override
  _SideMenuState createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> with FriendsHandler {
  Future<List<String>>? _currentFriendsList;
  Future<List<String>>? _incomingRequests;
  Future<List<String>>? _outgoingRequests;
  Future<List<String>>? _incomingChallenges;
  Future<List<String>>? _outgoingChallenges;
  String _title = "Friends List";
  bool _showingRequests = false;

  @override
  void initState() {
    super.initState();
    _fetchFriendsAndRequests();
  }

  void _fetchFriendsAndRequests() {
    setState(() {
      _currentFriendsList = fetchFriends();
      fetchFriendRequests().then((_) {
        setState(() {
          _incomingRequests = Future.value(incomingRequests);
          _outgoingRequests = Future.value(outgoingRequests);
        });
      });
      fetchChallenges().then((_) {
        setState(() {
          _incomingChallenges = Future.value(incomingChallenges);
          _outgoingChallenges = Future.value(outgoingChallenges);
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Row(
              children: [
                Expanded(
                  child: Text(
                    PLAYERID,
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PlayerStatsScreen(),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 4.0),
                    child: Row(
                      children: [
                        Text(
                          'Stats',
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios,
                            color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            accountEmail: const Text(""),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                PLAYERID[0],
                style: GoogleFonts.dmSans(
                  fontSize: 35,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _title,
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                _buildFriendsOptionsMenu(),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<String>>(
              future:
                  _showingRequests ? _incomingRequests : _currentFriendsList,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text("Error fetching data."));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text("No $_title available."));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final user = snapshot.data![index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: HexColor("#44564A"),
                        child: Text(
                          user[0],
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      title: Text(user),
                      trailing: _showingRequests
                          ? _buildFriendRequestActions(user)
                          : _buildFriendActions(user),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(),
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => InputDialog(
                  title: "Add Friend",
                  hintText: "Enter Friend ID",
                  buttonText: "Add",
                  onConfirm: (friendId) {
                    addFriend(friendId);
                    setState(() {
                      _fetchFriendsAndRequests();
                      _title = "Friends List";
                    });
                  },
                ),
              );
            },
            icon: const Icon(Icons.person_add),
            label: const Text("Add Friend"),
            style: ElevatedButton.styleFrom(
              backgroundColor: HexColor("#44564A"),
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildFriendsOptionsMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        setState(() {
          if (value == "View Friend Requests") {
            _showingRequests = true;
            _title = "Friend Requests";
          } else if (value == "Show Friends List") {
            _showingRequests = false;
            _title = "Friends List";
          } else if (value == "Refresh List") {
            _fetchFriendsAndRequests();
          }
        });
      },
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem(
          value: "View Friend Requests",
          child: ListTile(
            leading: Icon(Icons.notifications, color: Colors.orange),
            title: Text("View Friend Requests"),
          ),
        ),
        const PopupMenuItem(
          value: "Show Friends List",
          child: ListTile(
            leading: Icon(Icons.people, color: Colors.blue),
            title: Text("Show Friends List"),
          ),
        ),
        const PopupMenuItem(
          value: "Refresh List",
          child: ListTile(
            leading: Icon(Icons.refresh, color: Colors.green),
            title: Text("Refresh List"),
          ),
        ),
      ],
    );
  }

  Widget _buildFriendActions(String friend) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.sports_esports, color: Colors.green),
          onPressed: () {
            challengeFriend(friend);
          },
        ),
        IconButton(
          icon: const Icon(Icons.check, color: Colors.blue),
          onPressed: () {
            acceptChallenge(friend);
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () {
            //removeFriend(friend);
          },
        ),
      ],
    );
  }

  /// Actions for friend requests (Accept or Decline)
  Widget _buildFriendRequestActions(String friendId) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.check, color: Colors.blue),
          onPressed: () {
            acceptFriendRequest(friendId);
            setState(() {
              _fetchFriendsAndRequests();
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.red),
          onPressed: () {
            //declineFriendRequest(friendId);
            setState(() {
              _fetchFriendsAndRequests();
            });
          },
        ),
      ],
    );
  }
}
