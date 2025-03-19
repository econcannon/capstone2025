import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../components/constants.dart';
import 'package:logger/logger.dart';

var logger = Logger();

mixin FriendsHandler {
  List<String> friends = [];
  List<String> incomingRequests = [];
  List<String> outgoingRequests = [];
  bool _isFetching = false;

  Future<List<String>> fetchFriends() async {
    if (_isFetching) return friends;
    _isFetching = true;

    try {
      final endpoint = "$BASE_URL/player/friends?playerID=$PLAYERID";
      final response = await http.get(Uri.parse(endpoint), headers: HEADERS);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        logger.i(response.body);
        friends = List<String>.from(data['friends']);
      } else {
        logger.e("Failed to fetch friends list.");
      }
    } catch (e) {
      logger.e("Error fetching friends: $e");
    }

    _isFetching = false;
    return friends;
  }

  Future<void> addFriend(String friendId) async {
    try {
      final endpoint =
          "$BASE_URL/player/send-friend-request?playerID=$PLAYERID&friendID=$friendId";
      final response = await http.post(Uri.parse(endpoint), headers: HEADERS);

      if (response.statusCode == 200) {
        logger.i("Friend request sent to $friendId.");
      } else {
        logger.e(
            "Failed to send friend request. Status code: ${response.statusCode}");
        logger.e("Response body: ${response.body}");
      }
    } catch (e) {
      logger.e("Error sending friend request: $e");
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

  Future<void> challengeFriend(String friendId) async {
    try {
      final endpoint =
          "$BASE_URL/player/challenge-friend?playerID=$PLAYERID&friendID=$friendId";
      final response = await http.post(Uri.parse(endpoint), headers: HEADERS);

      if (response.statusCode == 200) {
        logger.i(response.body);
        logger.i("Challenge sent to $friendId.");
      } else {
        logger.e(response.body);
        logger.e(response.statusCode);
        logger.e("Failed to send challenge.");
      }
    } catch (e) {
      logger.e("Error challenging friend: $e");
    }
  }

  Future<void> acceptChallenge(String friendId) async {
    try {
      final endpoint =
          "$BASE_URL/player/accept-challenge?playerID=$PLAYERID&friendID=$friendId";
      final response = await http.post(Uri.parse(endpoint), headers: HEADERS);

      if (response.statusCode == 200) {
        logger.i(response.body);
        logger.i("Challenge accepted.");
      } else {
        logger.e(response.body);
        logger.e(response.statusCode);
        logger.e("Failed to send challenge.");
      }
    } catch (e) {
      logger.e("Error accepting challenge: $e");
    }
  }

  Future<void> fetchFriendRequests() async {
    try {
      final endpoint =
          "$BASE_URL/player/see-friend-requests?playerID=$PLAYERID";
      final response = await http.get(Uri.parse(endpoint), headers: HEADERS);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        logger.i("response body:");
        logger.i(response.body);
        incomingRequests = List<String>.from(data['incoming_requests']);
        outgoingRequests = List<String>.from(data['outgoing_requests']);
      } else {
        logger.e("Failed to fetch friend requests.");
      }
    } catch (e) {
      logger.e("Error fetching friend requests: $e");
    }
  }

  Future<void> acceptFriendRequest(String friendId) async {
    try {
      final endpoint =
          "$BASE_URL/player/accept-friend-request?playerID=$PLAYERID&friendID=$friendId";
      final response = await http.post(Uri.parse(endpoint), headers: HEADERS);

      if (response.statusCode == 200) {
        incomingRequests.remove(friendId);
        logger.i("Friend request accepted.");
      } else {
        logger.e(response.body);
        logger.e("Failed to accept friend request.");
      }
    } catch (e) {
      logger.e("Error accepting friend request: $e");
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
}
