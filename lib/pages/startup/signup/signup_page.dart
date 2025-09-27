// packages
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// pages
import '../../../globals/account_service.dart';
import '../../../globals/auth_service.dart';
import '../../../globals/database.dart';
import '../../../globals/static/custom_widgets/styled_check_box.dart';
import '../../../globals/static/custom_widgets/text_bubble.dart';
import 'package:secondstudent/pages/account/avatar.dart';
import 'package:secondstudent/globals/http_manager.dart';
import 'package:secondstudent/globals/static/extensions/build_context_extension.dart';
import 'package:secondstudent/globals/static/custom_widgets/slide_show.dart';
import 'package:secondstudent/globals/static/themes.dart';
import 'package:secondstudent/pages/startup/home_page.dart';

/*
Signup Page
- Page used to create a new account
- Uses custom widget "progression" as slide show
- Handles new auth
 */

class Signup extends StatefulWidget {
  Signup({super.key, this.auth = true});

  final bool auth;

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  static ColorScheme colorScheme = Themes.sparkliTheme.colorScheme;

  bool isBusy = false;
  int progress = 0;

  String ppString = '';
  bool ppAgree = false;

  // text controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool hidePassword = true;

  DateTime? bday;

  String? gender;

  final TextEditingController _genderController = TextEditingController();
  final FocusNode _genderFocus = FocusNode();
  bool setGender = false;

  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  final FocusNode _stateFocus = FocusNode();
  final FocusNode _cityFocus = FocusNode();

  String? avatarUrl;
  String theme = 'Scarlet';

  final Wrapper<Future<void> Function()?> progressWrapper =
      Wrapper<Future<void> Function()>();

  // send sign up to supabase
  Future<void> _signUp() async {
    final String email = _emailController.text;
    final String password = _passwordController.text;
    await supabase.auth.signUp(email: email, password: password);
    DataBase.init();
  }

  Future<void> _finishAccount() async {
    try {
      await AccountService.updateProfile({
        'name': _nameController.text,
        'privacy_policy': ppString,
        'avatar_url': avatarUrl,
        'theme': theme,
        'gender': gender,
        'birthday': bday == null ? null : (bday?.toIso8601String()),
        'location': '${_cityController.text}, ${_stateController.text}',
      });
    } catch (e) {
      if (mounted) {
        context.showSnackBar(e.toString());
      }
    }
    Navigator.of(context).pushAndRemoveUntil(
      CupertinoPageRoute(builder: (context) => HomePage()),
      (route) => false,
    );
  }

  Future<void> pickDate() async {
    DateTime? selectedDate = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 36500)),
      initialDate: DateTime.now(),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            datePickerTheme: DatePickerThemeData(
              headerHelpStyle: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
                fontSize: 23,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (selectedDate != null) {
      setState(() {
        bday = selectedDate;
      });
    }
  }

  Widget _buildTextForm({
    required TextEditingController controller,
    required String text,
    void Function(String?)? onSubmit,
    FocusNode? focus,
    bool obscuretext = false,
    bool autocorrect = false,
    TextInputType? input,
    Widget? suffix,
  }) {
    return TextFormField(
      focusNode: focus,
      controller: controller,
      onFieldSubmitted: onSubmit,
      decoration: InputDecoration(
        labelText: text,
        labelStyle: TextStyle(
          color: colorScheme.onSurface,
          fontFamily: 'Inter',
        ),
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.primary),
        ),
        suffixIcon: suffix,
      ),
      obscureText: obscuretext,
      autocorrect: autocorrect,
      keyboardType: input,
      textInputAction: TextInputAction.done,
    );
  }

  Widget _buildPP() {
    final ColorScheme colorScheme = Themes.sparkliTheme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scale: 1.5,
          child: Checkbox(
            value: ppAgree,
            activeColor: colorScheme.primary,
            checkColor: colorScheme.onPrimary,
            onChanged: (bool? value) async {
              final String ip =
                  await HttpManager.getIp() ?? " unknown IP adress";

              ppString = 'Agreed to Privacy Policy on ${DateTime.now()} at $ip';
              setState(() {
                ppAgree = value ?? false;
              });
            },
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: RichText(
              softWrap: true,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: " I agree to Sparkli's",
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                      fontFamily: 'Inter',
                    ),
                  ),
                  TextSpan(
                    text: "\n Privacy Policy",
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        HttpManager.launchURL(
                          'https://sparkli.com/policies/privacy-policy',
                        );
                      },
                    style: TextStyle(
                      color: colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThemeSelector() {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final MediaQueryData mediaQuery = MediaQuery.of(context);

    return SizedBox(
      height: 60,
      width: mediaQuery.size.width * .75 - 40,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: Themes.themeData.keys.length,
            itemBuilder: (context, i) {
              final String themeKey = Themes.themeData.keys.elementAt(i);
              final ColorScheme themeColorScheme =
                  Themes.themeData[themeKey]!.colorScheme;

              return TextBubble(
                text: themeKey,
                textColor: themeColorScheme.onPrimary,
                color: Themes.themeColor[themeKey],
                borderColor: themeKey == theme
                    ? themeColorScheme.onSurface
                    : null,
                margin: const EdgeInsets.symmetric(horizontal: 7.5),
                onPressed: () {
                  setState(() {
                    theme = themeKey;
                  });
                },
              );
            },
          ),
          Container(
            height: 60,
            width: 10,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.surface, colorScheme.surface.withAlpha(0)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              height: 60,
              width: 10,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.surface,
                    colorScheme.surface.withAlpha(0),
                  ],
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void tapAwayListener(FocusNode focusNode) {
    focusNode.addListener(() {
      if (!focusNode.hasFocus) {
        setState(() {});
      }
    });
  }

  @override
  void initState() {
    super.initState();
    tapAwayListener(_nameFocus);
    tapAwayListener(_emailFocus);
    tapAwayListener(_passwordFocus);
    tapAwayListener(_genderFocus);
    tapAwayListener(_stateFocus);
    tapAwayListener(_cityFocus);
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);

    return Scaffold(
      body: Container(
        width: mediaQuery.size.width,
        height: mediaQuery.size.height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.tertiary,
          gradient: RadialGradient(
            radius: 1,
            colors: [colorScheme.primary, colorScheme.tertiary],
          ),
        ),
        child: SlideShow(
          colorScheme: colorScheme,
          startPage: progress,
          buttonWrapper: progressWrapper,
          regressMethods: List<Future<void> Function(void Function())>.generate(
            7,
            (p) {
              return (void Function() back) async {
                progress = p - 1;
                back();
              };
            },
          ),
          progressMethods:
              List<Future<void> Function(void Function())>.generate(7, (p) {
                return (void Function() next) async {
                  if (!isBusy) {
                    try {
                      int page = p;
                      if (!widget.auth) {
                        page += 1;
                      }
                      if (page == 1 && !AuthService.authorized(anon: false)) {
                        isBusy = true;
                        await _signUp();
                      }
                      if (page == 3 && setGender) {
                        gender = _genderController.text;
                      }
                      if (page >= 5) {
                        await _finishAccount();
                      }
                      progress = p + 1;
                      next();
                    } on AuthException catch (e) {
                      if (context.mounted) {
                        context.showSnackBar(e.message);
                      }
                    }
                    isBusy = false;
                  }
                };
              }),
          nextTexts: widget.auth ? ['Continue', 'Register'] : null,
          conditions: [
            if (widget.auth) ...[
              (bool active) {
                if (!ppAgree) {
                  if (active) {
                    context.showSnackBar('Please agree to the privacy policy.');
                  }
                  return false;
                }
                if (_nameController.text.isNotEmpty &&
                    _emailController.text.isNotEmpty) {
                  return true;
                }
                if (active) {
                  context.showSnackBar('Name and Email are required.');
                }
                return false;
              },
              (bool active) {
                if (_passwordController.text.length < 6 &&
                    !AuthService.authorized(anon: false)) {
                  if (active) {
                    context.showSnackBar(
                      "Password must be 6 or more characters long.",
                    );
                  }
                  return false;
                }
                return !isBusy;
              },
            ] else
              (bool active) {
                if (!ppAgree) {
                  if (active) {
                    context.showSnackBar('Please agree to the privacy policy.');
                  }
                  return false;
                }
                if (_nameController.text.isEmpty) {
                  context.showSnackBar('Name is required.');
                  return false;
                }
                return true;
              },
            (bool _) => true,
            (bool active) {
              if (gender != null) {
                return true;
              }
              if (active) {
                context.showSnackBar("Please provide your gender.");
              }
              return false;
            },
          ],
          colors: [
            Colors.transparent,
            Colors.transparent,
            Colors.transparent,
            Colors.transparent,
            Colors.transparent,
            Colors.transparent,
            Colors.transparent,
          ],
          children: [
            if (widget.auth) ...[
              Container(
                color: colorScheme.surface,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "Register",
                        style: TextStyle(
                          fontSize: 30,
                          color: colorScheme.onSurface,
                          fontFamily: "TheSeasons",
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Email input field
                    _buildTextForm(
                      controller: _nameController,
                      focus: _nameFocus,
                      text: 'Name',
                      onSubmit: (text) {
                        setState(() {
                          _emailFocus.requestFocus();
                        });
                      },
                    ),
                    const SizedBox(height: 15),
                    // Password input field
                    _buildTextForm(
                      controller: _emailController,
                      focus: _emailFocus,
                      text: 'Email',
                      input: TextInputType.emailAddress,
                      onSubmit: (_) {
                        _emailFocus.unfocus();
                        progressWrapper.value?.call();
                      },
                    ),
                    const SizedBox(height: 15),
                    _buildPP(),
                  ],
                ),
              ),
              Container(
                color: colorScheme.surface,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "Create a Password",
                        style: TextStyle(
                          fontSize: 30,
                          color: colorScheme.onSurface,
                          fontFamily: "TheSeasons",
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Email input field
                    Opacity(
                      opacity: AuthService.authorized(anon: false) ? 0.5 : 1,
                      child: IgnorePointer(
                        ignoring: AuthService.authorized(anon: false),
                        child: _buildTextForm(
                          controller: _passwordController,
                          focus: _passwordFocus,
                          text: 'Password',
                          obscuretext: hidePassword,
                          onSubmit: (_) {
                            _passwordFocus.unfocus();
                          },
                          suffix: Padding(
                            padding: const EdgeInsets.only(right: 5),
                            child: IconButton(
                              onPressed: () {
                                setState(() {
                                  hidePassword = !hidePassword;
                                });
                              },
                              icon: Icon(
                                hidePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: colorScheme.onSurface,
                                size: 27.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      alignment: Alignment.centerLeft,
                      margin: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Text(
                        "Password with 6 or more characters",
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 11,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              Container(
                color: colorScheme.surface,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "What is your Name?",
                        style: TextStyle(
                          fontSize: 30,
                          color: colorScheme.onSurface,
                          fontFamily: "TheSeasons",
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Email input field
                    _buildTextForm(
                      controller: _nameController,
                      focus: _nameFocus,
                      text: 'Name',
                      onSubmit: (text) {
                        setState(() {
                          _emailFocus.requestFocus();
                        });
                      },
                    ),
                    const SizedBox(height: 15),
                    _buildPP(),
                  ],
                ),
              ),
            Container(
              color: colorScheme.surface,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    alignment: Alignment.centerLeft,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "How old are you, ${_nameController.text.split(' ').first}?",
                        style: TextStyle(
                          fontSize: 30,
                          color: colorScheme.onSurface,
                          fontFamily: "TheSeasons",
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    alignment: Alignment.centerLeft,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      "This helps us personalize your feed. Don't worry, we won't show this on your profile.",
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 12,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: colorScheme.onSurface,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          bday == null
                              ? '--/--/----'
                              : '${bday?.month}/${bday?.day}/${bday?.year}',
                          style: TextStyle(
                            fontSize: 20,
                            color: colorScheme.onSurface,
                            fontFamily: 'Nunito',
                          ),
                        ),
                        IconButton(
                          onPressed: pickDate,
                          icon: Icon(
                            Icons.calendar_month,
                            color: colorScheme.secondary,
                            size: 25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: colorScheme.surface,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    alignment: Alignment.centerLeft,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "How do you identify?",
                        style: TextStyle(
                          fontSize: 30,
                          color: colorScheme.onSurface,
                          fontFamily: "TheSeasons",
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    alignment: Alignment.centerLeft,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      "This helps us show you more relevant content.",
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 12,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                  StyledCheckBox(
                    value: gender == 'Male',
                    text: 'Male',
                    onPressed: () {
                      setState(() {
                        gender = 'Male';
                        setGender = false;
                      });
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: StyledCheckBox(
                      value: gender == 'Female',
                      text: 'Female',
                      onPressed: () {
                        setState(() {
                          gender = 'Female';
                          setGender = false;
                        });
                      },
                    ),
                  ),
                  StyledCheckBox(
                    value: gender == _genderController.text,
                    text: 'Other',
                    onPressed: () {
                      setState(() {
                        gender = _genderController.text;
                        setGender = true;
                      });
                    },
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    height: setGender ? 70 : 0,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 7.5,
                    ),
                    child: _buildTextForm(
                      controller: _genderController,
                      focus: _genderFocus,
                      autocorrect: true,
                      text: "Gender Identity",
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: colorScheme.surface,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    alignment: Alignment.centerLeft,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "Where will you spark?",
                        style: TextStyle(
                          fontSize: 30,
                          color: colorScheme.onSurface,
                          fontFamily: "TheSeasons",
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    alignment: Alignment.centerLeft,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      "This helps us show you the best local date spots!",
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 12,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 7.5,
                    ),
                    child: _buildTextForm(
                      controller: _stateController,
                      focus: _stateFocus,
                      autocorrect: true,
                      onSubmit: (_) {
                        _cityFocus.requestFocus();
                      },
                      text: "State",
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    height: _stateController.text.isNotEmpty ? 70 : 0,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 7.5,
                    ),
                    child: _buildTextForm(
                      controller: _cityController,
                      focus: _cityFocus,
                      autocorrect: true,
                      text: "City",
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: colorScheme.surface,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      "Customize Appearance",
                      style: TextStyle(
                        fontSize: 30,
                        color: colorScheme.onSurface,
                        fontFamily: "TheSeasons",
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Avatar(
                    imageUrl: avatarUrl,
                    onUpload: (imageUrl) {
                      setState(() {
                        avatarUrl = imageUrl;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Divider(color: colorScheme.onSurface, height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      "Select Color Scheme",
                      style: TextStyle(
                        fontSize: 26,
                        color: colorScheme.onSurface,
                        fontFamily: "Georama",
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  _buildThemeSelector(),
                  Divider(color: colorScheme.onSurface, height: 2),
                ],
              ),
            ),
            Container(
              color: colorScheme.surface,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    alignment: Alignment.centerLeft,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: "Welcome to Sparkli",
                              style: TextStyle(
                                fontSize: 35,
                                color: colorScheme.onPrimary,
                                fontFamily: "TheSeasons",
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text: "!",
                              style: TextStyle(
                                fontSize: 35,
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
