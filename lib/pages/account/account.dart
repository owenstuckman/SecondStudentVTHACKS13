import 'dart:async';
import 'package:flutter/material.dart';

import 'package:secondstudent/globals/account_service.dart';
import '../account/avatar.dart';
import 'package:secondstudent/globals/database.dart';

/*
Account Page will be accessible by button in top right

Current Account Page for DB based accounts
 */

class Account extends StatefulWidget {
  Account({Key? key});

  @override
  State<Account> createState() => _AccountState();
}

class _AccountState extends State<Account> {
  String? _avatarUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  void fetchProfile() async {
    await AccountService.fetchProfile();
    _loading = true;

    try {
      final userId = supabase.auth.currentSession!.user.id;
      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      _avatarUrl = (data['avatar_url'] ?? '') as String;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unexpected error retrieving avatar occurred'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// Called when image has been uploaded to Supabase storage from within Avatar widget
  Future<void> _onUpload(String imageUrl) async {
    try {
      final userId = supabase.auth.currentUser!.id;
      await supabase.from('profiles').upsert({
        'id': userId,
        'avatar_url': imageUrl,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Updated your profile image!')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unexpected error occurred'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _avatarUrl = imageUrl;
    });
  }

  void _deleteAccount() async {
    // Logic to delete the account
    try {
      final userId = supabase.auth.currentUser!.id;
      await supabase.from('profiles').delete().eq('id', userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted successfully!')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error deleting account'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _logout() async {
    // Logic to log out the user
    await supabase.auth.signOut();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged out successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final Map<String, dynamic> profile = AccountService.account;

    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: mediaQuery.size.width * .05,
            ),
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              boxShadow: [BoxShadow(color: colorScheme.shadow, blurRadius: 3)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Avatar(imageUrl: _avatarUrl, onUpload: _onUpload),
                    ),
                    Container(
                      padding: const EdgeInsets.only(left: 15),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          profile['name'] ?? "Sparkli User",
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _logout,
                  child: const Text('Log Out'),
                ),
                ElevatedButton(
                  onPressed: _deleteAccount,
                  child: const Text('Delete Account'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
