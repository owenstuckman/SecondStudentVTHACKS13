import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:secondstudent/globals/static/extensions/build_context_extension.dart';
import 'database.dart';

/*
Handles all auth functionalities (supabase auth)

Frequently referenced in account page and login/sign-in process

 */

class AuthService {
  // guest sign in
  Future<void> signUpAnon(BuildContext context) async {
    try {
      await supabase.auth.signInAnonymously();
      await DataBase.init();
    } on AuthException catch (error) {
      if (context.mounted) {
        context.showSnackBar(error.message);
      }
    }
  }

  // log out of current session
  static void logOutAccount() async {
    await supabase.auth.signOut();
  }

  // remove account row from profiles
  static void resetAccount() async {
    await supabase
        .from('profiles')
        .delete()
        .eq('id', supabase.auth.currentUser!.id);
  }

  // deletes current user's account (based on the current session/user) and resets them to home
  // will work with both anonymous sessions and actual accounts to clear all of their data
  static Future<void> deleteAccount() async {
    try {
      if (supabase.auth.currentUser == null) {
        throw Error();
      }
      // call edge function
      await supabase.functions.invoke('delete-user');
    } catch (error) {
      print('Error when deleting a user.');
    } finally {
      // sign out, push back to home page
      await supabase.auth.signOut();
    }
  }

  //Checks that auth still exists
  static Future<bool> verifyAuth() async {
    try {
      await supabase.from('profiles').select().single();
    } catch (e) {
      return false;
    }
    return true;
  }

  // send email to reset password
  // see : https://supabase.com/docs/reference/javascript/auth-resetpasswordforemail
  static void sendPasswordResetEmail(String email) async {
    await supabase.auth.resetPasswordForEmail(email);
  }

  // update a user's password
  static void updatePassword(newPassword) async {
    await supabase.auth.updateUser(
      UserAttributes(
        email: supabase.auth.currentUser?.email,
        password: newPassword,
      ),
    );
  }

  static void updateEmail(newEmail) async {
    await supabase.auth.updateUser(UserAttributes(email: newEmail));
  }

  // verifies email address
  static bool checkEmail() {
    final String? response = supabase.auth.currentUser?.email;
    return response != null;
  }

  // update account information
  static Future<void> updateAccount(int pkey, Map map) async {
    await supabase.auth.updateUser(map as UserAttributes);
  }

  /// Performs Apple sign in and sign up on iOS or macOS
  static Future<AuthorizationCredentialAppleID> signInWithApple() async {
    final rawNonce = supabase.auth.generateRawNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );
    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException(
        'Could not find ID Token from generated credential.',
      );
    }

    await supabase.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );
    return credential;
  }

  /// checks if oath account is created, if not, create it
  static Future<bool> checkOauthAccount() async {
    final acc = supabase.auth.currentUser?.id;
    if (acc == null) {
      return false;
    }
    String uuid = acc;
    final profileList = await getProfileByUUID(uuid);
    return profileList.isNotEmpty &&
        profileList.first.containsKey('theme') &&
        profileList.first['theme'] != null;
  }

  /// check if user is authorized
  static bool authorized({bool anon = true}) {
    return supabase.auth.currentSession != null &&
        (anon || !supabase.auth.currentUser!.isAnonymous);
  }

  /// await auth
  static Future<void> awaitAuth() async {
    while (!AuthService.authorized()) {
      Future.delayed(const Duration(milliseconds: 500));
    }
  }

  /// get profile by uuid
  static Future<List<Map<String, dynamic>>> getProfileByUUID(
    String uuid,
  ) async {
    return supabase.from('profiles').select().eq('id', uuid);
  }

  Future<void> nativeGoogleSignIn() async {
    /// TODO: update the Web client ID with your own.
    ///
    /// Web Client ID that you registered with Google Cloud.
    const webClientId = 'my-web.apps.googleusercontent.com';

    /// TODO: update the iOS client ID with your own.
    ///
    /// iOS Client ID that you registered with Google Cloud.
    const iosClientId = 'my-ios.apps.googleusercontent.com';
    final scopes = ['email', 'profile'];
    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize(
      serverClientId: webClientId,
      clientId: iosClientId,
    );
    final googleUser = await googleSignIn.attemptLightweightAuthentication();
    // or await googleSignIn.authenticate(); which will return a GoogleSignInAccount or throw an exception
    if (googleUser == null) {
      throw AuthException('Failed to sign in with Google.');
    }

    /// Authorization is required to obtain the access token with the appropriate scopes for Supabase authentication,
    /// while also granting permission to access user information.
    final authorization =
        await googleUser.authorizationClient.authorizationForScopes(scopes) ??
        await googleUser.authorizationClient.authorizeScopes(scopes);
    final idToken = googleUser.authentication.idToken;
    if (idToken == null) {
      throw AuthException('No ID Token found.');
    }
    await supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: authorization.accessToken,
    );
  }
}

/// need functions to update and get profile information
