// packages
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// pages
import '../../../globals/database.dart';
import '../home_page.dart';
import 'package:secondstudent/globals/static/extensions/build_context_extension.dart';
import 'package:secondstudent/globals/static/themes.dart';

/*
Login Page Class
- Displays page for logging in process
- Handles existing auth
*/

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  //Custom Sparkli Theme
  final ColorScheme colorScheme = Themes.sparkliTheme.colorScheme;

  //If loading
  bool _isLoading = false;

  //Text controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  //Text focus nodes
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  // Sign in user with email and password
  Future<void> _signIn() async {
    //Refreshes page to display loading
    setState(() {
      _isLoading = true;
    });
    try {
      //Logs in
      await supabase.auth.signInWithPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      //Init db
      await DataBase.init();
      if (mounted) {
        //Remove page, open home page if no errors
        Navigator.of(context).pushAndRemoveUntil(
          CupertinoPageRoute(builder: (context) => HomePage()),
          (route) => false,
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        context.showSnackBar(error.message);
      }
    }
    //Stop loading
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  //Disposes of context and text controllers
  @override
  void dispose() {
    _emailController.dispose();
    _emailFocus.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  //Adds event listener to given focus node to remove focus on tap away from focus
  void tapAwayListener(FocusNode focusNode) {
    focusNode.addListener(() {
      if (!focusNode.hasFocus) {
        setState(() {});
      }
    });
  }

  //Inits context and adds tapAwayListener to focus nodes
  @override
  void initState() {
    super.initState();
    tapAwayListener(_emailFocus);
    tapAwayListener(_passwordFocus);
  }

  //Text form stencil
  Widget _buildTextForm(
      {required TextEditingController controller,
      required String text,
      FocusNode? focus,
      bool obscuretext = false,
      TextInputType? input,
      void Function(String?)? onSubmit}) {
    //Returns text form
    return TextFormField(
      focusNode: focus,
      controller: controller,
      onFieldSubmitted: onSubmit,
      decoration: InputDecoration(
        labelText: text,
        labelStyle: TextStyle(color: colorScheme.onSurface),
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.primary),
        ),
      ),
      obscureText: obscuretext,
      keyboardType: input,
    );
  }

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);

    //Returns page
    return Scaffold(
      //Set size w/ gradient decoration
      body: Container(
          width: mediaQuery.size.width,
          height: mediaQuery.size.height,
          alignment: Alignment.center,
          //Radial gradient decoration
          decoration: BoxDecoration(
              color: colorScheme.tertiary,
              gradient: RadialGradient(
                  radius: 1,
                  colors: [colorScheme.primary, colorScheme.tertiary])),
          //Center card as child
          child: Card(
            color: colorScheme.surface,
            margin: EdgeInsets.symmetric(horizontal: mediaQuery.size.width / 6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              //Column of title and options
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  //Sign in title
                  Text(
                    "Sign In",
                    style: TextStyle(
                        fontSize: 30,
                        color: colorScheme.onSurface,
                        fontFamily: "Georama",
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  // Email input field
                  _buildTextForm(
                      controller: _emailController,
                      focus: _emailFocus,
                      text: 'Email',
                      input: TextInputType.emailAddress,
                      onSubmit: (text) {
                        //Focus password text box
                        _passwordFocus.requestFocus();
                      }),
                  const SizedBox(height: 15),
                  // Password input field
                  _buildTextForm(
                      controller: _passwordController,
                      focus: _passwordFocus,
                      text: 'Password',
                      obscuretext: true,
                      onSubmit: (text) {
                        //If not already loading, log in asynchronously
                        if (!_isLoading) {
                          _signIn();
                        }
                      }),
                  // Login button
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Opacity(
                        opacity: _emailController.text.isNotEmpty &&
                                _passwordController.text.isNotEmpty
                            ? 1
                            : 0.75,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _signIn,
                          style: ElevatedButton.styleFrom(
                            fixedSize:
                                Size(mediaQuery.size.width * 2 / 3 - 60, 40),
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator()
                              : Text('Sign In',
                                  style: TextStyle(
                                      fontFamily: 'Pridi',
                                      fontSize: 20,
                                      color: colorScheme.onPrimary)),
                        ),
                      )),

                  /*
                  SizedBox(
                    width: mediaQuery.size.width * 2 / 3 - 40,
                    height: 25,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                            child: Container(
                                height: 2.5, color: colorScheme.onSurface)),
                        Text(" or ",
                            style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 17,
                                height: 0.5,
                                fontFamily: 'ProstoOne')),
                        Expanded(
                            child: Container(
                                height: 2.5, color: colorScheme.onSurface)),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: mediaQuery.size.width * 2 / 3, // Match width to other buttons
                    height: 50, // Match height to other buttons
                    child: SignInWithAppleButton(
                      onPressed: () {
                        try {
                          AuthService.signInWithApple();
                        } catch(e){
                          context.showSnackBar(e.toString());
                        }
                        if (supabase.auth.currentUser != null) {
                          GlobalWidgets.swipePage(HomePage());
                        }
                      },
                      text: "Sign in with Apple",
                      style: SignInWithAppleButtonStyle.white, // Match the Apple button style
                      borderRadius: BorderRadius.circular(8), // Add same roundness
                    ),
                  ),
                   */
                ],
              ),
            ),
          )),
    );
  }
}
