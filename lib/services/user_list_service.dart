import 'dart:convert';
import 'package:http/http.dart' as http;

class User {
  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;

  User({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      uid: json['uid'] as String,
      displayName: json['displayName'] as String,
      email: json['email'] as String,
      photoUrl: json['photoUrl'] as String?,
    );
  }
}

class UserListService {
  static const String _baseUrl = 'https://us-central1-ohftok-gauntlet.cloudfunctions.net';

  Future<List<User>> getUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/listAllUsers'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> usersJson = data['users'];
        return usersJson.map((json) => User.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load users: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load users: $e');
    }
  }
} 