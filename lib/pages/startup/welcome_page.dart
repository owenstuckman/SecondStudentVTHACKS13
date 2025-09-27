import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:secondstudent/globals/auth_service.dart';
import 'package:secondstudent/globals/static/extensions/build_context_extension.dart';
import 'package:secondstudent/globals/static/themes.dart';
import 'package:secondstudent/pages/startup/signup/login_page.dart';
import 'package:secondstudent/pages/startup/signup/signup_page.dart';

import '../../globals/database.dart';
import '../../globals/static/custom_widgets/swipe_page_route.dart';
import 'home_page.dart';

/*
Welcome Page Class
- First screen displayed when opening app without db auth
- Displays logo and options to login, signup, sign in via apple, or view as guest
- Additionally options to oauth (currently just apple)
 */

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    ColorScheme colorScheme = Themes.sparkliTheme.colorScheme;

    return Scaffold(
      body: Container(
        width: mediaQuery.size.width,
        height: mediaQuery.size.height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: colorScheme.tertiary,
            gradient: RadialGradient(
                radius: 1,
                colors: [colorScheme.primary, colorScheme.tertiary])),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 50),
            SizedBox(
              width: mediaQuery.size.width / 3,
              height: mediaQuery.size.height / 3,
              child: Image.asset('assets/images/sparkli.png'),
            ),
            const SizedBox(height: 25),
            // sign in button
            ElevatedButton(
              onPressed: () {
                context.pushSwipePage(const Login(), showAppBar: true);
              },
              style: ElevatedButton.styleFrom(
                  side: BorderSide(color: colorScheme.onSurface, width: 1),
                  fixedSize: Size(mediaQuery.size.width * 2 / 3, 30),
                  backgroundColor: colorScheme.secondary),
              child: Text('Sign In',
                  style: TextStyle(
                      fontFamily: 'Pridi',
                      fontSize: 20,
                      color: colorScheme.onSecondary)),
            ),
            // 'or' between
            SizedBox(
              width: mediaQuery.size.width / 2,
              height: 25,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                      child:
                          Container(height: 2.5, color: colorScheme.onSurface)),
                  Text(" or ",
                      style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 17,
                          height: 0.5,
                          fontFamily: 'ProstoOne')),
                  Expanded(
                      child:
                          Container(height: 2.5, color: colorScheme.onSurface)),
                ],
              ),
            ),
            // Create account button
            ElevatedButton(
              onPressed: () {
                context.pushSwipePage(Signup(), showAppBar: true);
              },
              style: ElevatedButton.styleFrom(
                  side: BorderSide(color: colorScheme.onSurface, width: 1),
                  fixedSize: Size(mediaQuery.size.width * 2 / 3, 50),
                  backgroundColor: colorScheme.primary),
              child: Text('Create Account',
                  style: TextStyle(
                      fontFamily: 'Pridi',
                      fontSize: 20,
                      color: colorScheme.onPrimary)),
            ),
            // 'or' between
            SizedBox(
              width: mediaQuery.size.width / 2,
              height: 25,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                      child:
                          Container(height: 2.5, color: colorScheme.onSurface)),
                  Text(" or ",
                      style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 17,
                          height: 0.5,
                          fontFamily: 'ProstoOne')),
                  Expanded(
                      child:
                          Container(height: 2.5, color: colorScheme.onSurface)),
                ],
              ),
            ),
            // sign in with apple
            Column(
              children: [
                SizedBox(
                  width: mediaQuery.size.width * 2 / 3,
                  height: 50,
                  child: SignInWithAppleButton(
                    onPressed: () async {
                      try {
                        await AuthService.signInWithApple();
                        DataBase.init();
                        if (context.mounted) {
                          Navigator.pushAndRemoveUntil(
                              context,
                              CupertinoPageRoute(
                                  builder: (context) => Signup(auth: false)),
                              (_) => false);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          context.showSnackBar("Failed to Sign up with Apple");
                        }
                      }
                    },
                    text: "Sign up with Apple",
                    style: SignInWithAppleButtonStyle.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: mediaQuery.size.width * 2 / 3,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await AuthService().nativeGoogleSignIn();
                        DataBase.init();
                        if (context.mounted) {
                          Navigator.pushAndRemoveUntil(
                              context,
                              CupertinoPageRoute(
                                  builder: (context) => Signup(auth: false)),
                              (_) => false);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          context
                              .showSnackBar("Failed to Sign up with Google ");
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Sign up with Google"),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // sign in as guest
            TextButton(
                onPressed: () async {
                  await AuthService().signUpAnon(context);
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => HomePage()),
                      (route) => false,
                    );
                  }
                },
                child: Text(
                  "Continue as Guest",
                  style: TextStyle(
                      decoration: TextDecoration.underline,
                      color: colorScheme.onPrimary,
                      decorationColor: colorScheme.onPrimary,
                      fontFamily: "Pridi",
                      fontWeight: FontWeight.w400,
                      fontSize: 17),
                ))
          ],
        ),
      ),
    );
  }
}
