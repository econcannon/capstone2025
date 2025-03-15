import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'components/constants.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  _FriendsPageState createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  List<String> friends = [];
  final TextEditingController _friendIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchFriends();
  }

  Future<void> _fetchFriends() async {
    try {
      final endpoint = "$BASE_URL/player/friends?playerID=$PLAYERID";
      final response = await http.get(Uri.parse(endpoint), headers: HEADERS);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print(response.body);
        setState(() {
          friends = List<String>.from(data['friends']);
        });
      } else {
        print("Failed to fetch friends list.");
      }
    } catch (e) {
      print("Error fetching friends: $e");
    }
  }

  Future<void> _addFriend(String friendId) async {
    try {
      final endpoint =
          "$BASE_URL/player/send-friend-request?playerID=$PLAYERID&friendID=$friendId";
      final response = await http.post(Uri.parse(endpoint), headers: HEADERS);

      if (response.statusCode == 200) {
        print("Friend request sent to $friendId.");
      } else {
        print(
            "Failed to send friend request. Status code: ${response.statusCode}");
        print("Response body: ${response.body}");
      }
    } catch (e) {
      print("Error sending friend request: $e");
    }
  }

  // Remove a friend?
  // Future<void> _removeFriend(String friendId) async {
  //   try {
  //     final endpoint = "$BASE_URL/player/";
  //     final response = await http.post(Uri.parse(endpoint), headers: HEADERS);

  //     if (response.statusCode == 200) {
  //       setState(() {
  //         friends.remove(friendId);
  //       });
  //     } else {
  //       print("Failed to remove friend.");
  //     }
  //   } catch (e) {
  //     print("Error removing friend: $e");
  //   }
  // }

  // Challenge a friend
  Future<void> _challengeFriend(String friendId) async {
    try {
      final endpoint =
          "$BASE_URL/player/challenge-friend?playerID=$PLAYERID&friendID=$friendId";
      final response = await http.post(Uri.parse(endpoint), headers: HEADERS);

      if (response.statusCode == 200) {
        print(response.body);
        print("Challenge sent to $friendId.");
      } else {
        print(response.body);
        print(response.statusCode);
        print("Failed to send challenge.");
      }
    } catch (e) {
      print("Error challenging friend: $e");
    }
  }

  Future<void> _acceptChallenge(String friendId) async {
    try {
      final endpoint =
          "$BASE_URL/player/accept-challenge?playerID=$PLAYERID&friendID=$friendId";
      final response = await http.post(Uri.parse(endpoint), headers: HEADERS);

      if (response.statusCode == 200) {
        print(response.body);
        print("Challenge accepted.");
      } else {
        print(response.body);
        print(response.statusCode);
        print("Failed to accept challenge.");
      }
    } catch (e) {
      print("Error accepting challenge: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('Add Friend'),
                    content: TextField(
                      controller: _friendIdController,
                      decoration: const InputDecoration(
                        labelText: 'Friend ID',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          final friendId = _friendIdController.text.trim();
                          if (friendId.isNotEmpty) {
                            _addFriend(friendId);
                            Navigator.pop(context);
                          }
                        },
                        child: const Text('Add'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const FriendRequestsPage()),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: friends.length,
        itemBuilder: (context, index) {
          final friend = friends[index];
          return ListTile(
            title: Text(friend),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.sports_esports),
                  onPressed: () {
                    _challengeFriend(friend);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: () {
                    _acceptChallenge(friend);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    //_removeFriend(friend);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class FriendRequestsPage extends StatefulWidget {
  const FriendRequestsPage({super.key});

  @override
  _FriendRequestsPageState createState() => _FriendRequestsPageState();
}

class _FriendRequestsPageState extends State<FriendRequestsPage> {
  List<String> incomingRequests = [];
  List<String> outgoingRequests = [];

  @override
  void initState() {
    super.initState();
    _fetchFriendRequests();
  }

  Future<void> _fetchFriendRequests() async {
    try {
      final endpoint =
          "$BASE_URL/player/see-friend-requests?playerID=$PLAYERID";
      final response = await http.get(Uri.parse(endpoint), headers: HEADERS);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("response body:");
        print(response.body);
        setState(() {
          incomingRequests = List<String>.from(data['incoming_requests']);
          outgoingRequests = List<String>.from(data['outgoing_requests']);
        });
      } else {
        print("Failed to fetch friend requests.");
      }
    } catch (e) {
      print("Error fetching friend requests: $e");
    }
  }

  Future<void> _acceptFriendRequest(String friendId) async {
    try {
      final endpoint =
          "$BASE_URL/player/accept-friend-request?playerID=$PLAYERID&friendID=$friendId";
      final response = await http.post(Uri.parse(endpoint), headers: HEADERS);

      if (response.statusCode == 200) {
        setState(() {
          incomingRequests.remove(friendId);
        });
        print("Friend request accepted.");
      } else {
        print(response.body);
        print("Failed to accept friend request.");
      }
    } catch (e) {
      print("Error accepting friend request: $e");
    }
  }

  // Reject a friend request?
  // Future<void> _rejectFriendRequest(String friendId) async {
  //   try {
  //     final endpoint = "$BASE_URL/player/";
  //     final response = await http.post(Uri.parse(endpoint), headers: HEADERS);

  //     if (response.statusCode == 200) {
  //       setState(() {
  //         incomingRequests.remove(friendId);
  //       });
  //       print("Friend request rejected.");
  //     } else {
  //       print("Failed to reject friend request.");
  //     }
  //   } catch (e) {
  //     print("Error rejecting friend request: $e");
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friend Requests'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: incomingRequests.length,
              itemBuilder: (context, index) {
                final friendId = incomingRequests[index];
                return ListTile(
                  title: Text(friendId),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check),
                        onPressed: () {
                          _acceptFriendRequest(friendId);

                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          //_rejectFriendRequest(friendId);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: outgoingRequests.length,
              itemBuilder: (context, index) {
                final friendId = outgoingRequests[index];
                return ListTile(
                  title: Text(friendId),
                  trailing: const Icon(Icons.hourglass_top),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
