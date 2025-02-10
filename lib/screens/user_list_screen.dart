import 'package:flutter/material.dart';
import '../services/user_list_service.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final UserListService _userListService = UserListService();
  List<User>? _users;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await _userListService.getUsers();
      if (mounted) {
        setState(() {
          _users = users;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error: $_error',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadUsers,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _users == null
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _users!.length,
                  itemBuilder: (context, index) {
                    final user = _users![index];
                    return ListTile(
                      leading: user.photoUrl != null
                          ? CircleAvatar(
                              backgroundImage: NetworkImage(user.photoUrl!),
                            )
                          : const CircleAvatar(
                              child: Icon(Icons.person),
                            ),
                      title: Text(user.displayName),
                      subtitle: Text(user.email),
                    );
                  },
                ),
    );
  }
} 