import 'package:flutter/material.dart';


/*
Themes page

Allows for changing color scheme

Can always be expanded on

 */
class Themes {

  static ThemeData sparkliTheme = ThemeData(
    colorScheme: const ColorScheme(
      primary: Color(0xFFE53D2E),
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xffe14444),
      onSecondary: Color(0xFFFFFFFF),
      tertiary: Color(0xFFA81F26),
      onTertiary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xfffffbfb),
      secondaryContainer: Color(0xfffff3f3),
      tertiaryContainer: Color(0xFFFFFFFF),
      surface: Color(0xffeeeeee),
      onSurface: Color(0xff2d2d2d),
      shadow: Color(0xff2d2c2c),
      surfaceContainer: Color(0xffeeeaea),
      onSurfaceVariant: Color(0xFFFFFFFF),
      error: Colors.transparent,
      onError: Colors.transparent,
      brightness: Brightness.light,
    ),
  );

  static Map<String, Color> themeColor = {
    'Violet': const Color(0xff655479),
    'Scarlet': const Color(0xffe14444),
    'Monochrome': const Color(0xff706f6f),
    'Dark': const Color(0xff252525),
    'Aquamarine': const Color(0xff22538d)
  };

  static Map<String, ThemeData> themeData = {
    "Scarlet": ThemeData(
      colorScheme: const ColorScheme(
        primary: Color(0xffe14444),
        onPrimary: Colors.white,
        secondary: Color(0xfffdc5c5),
        onSecondary: Color(0xff090000),
        tertiary: Color(0xffb04141),
        onTertiary: Colors.white,
        primaryContainer: Color(0xfffffbfb),
        secondaryContainer: Color(0xfffff3f3),
        tertiaryContainer: Colors.white,
        surface: Color(0xffeeeeee),
        onSurface: Color(0xff21141d),
        shadow: Color(0xff2d2c2c),
        surfaceContainer: Color(0xffeeeaea),
        onSurfaceVariant: Colors.black,
        error: Colors.transparent,
        onError: Colors.transparent,
        brightness: Brightness.light,
      ),
    ),
    "Violet": ThemeData(
      colorScheme: const ColorScheme(
        //Primary Color: Focus Color; Used for minor splashes of color and drawing attention to widgets like active switches
        primary: Color(0xff655479),
        //onPrimary Color: Color used for widgets displayed on primary-colored widgets
        onPrimary: Color(0xffeeeeee),
        //Secondary Color: Color, more faded than primary, used for minor splashes of color
        secondary: Color(0xffd0aec7),
        //onSecondary Color: Color used for widgets on Secondary color
        onSecondary: Colors.black,
        //Tertiary Color: Color used for heavily emphasizing certan UI elements (Very important buttons)
        tertiary: Color(0xff342940),
        //onTertiary Color: Color used for widgets on Tertiary color
        onTertiary: Colors.white,
        //primaryContainer Color: Primary Background Color
        primaryContainer: Color(0xfff5f5f5),
        //secondaryContainer Color: Secondary Background Color
        secondaryContainer: Color(0xfff1f1f1),
        //tertiaryContainer Color: Tertiary Background Color
        tertiaryContainer: Colors.white,
        //Surface Color: Main color used for containers and basic widgets on backgrounds
        surface: Color(0xffffffff),
        //onSurface Color: Color used for widgets, mostly text, displayed on containers
        onSurface: Color(0xff1e1e1e),
        //Shadow Color: Used for shadows (duh)
        shadow: Color(0xff363636),
        //SurfaceContainer Color: used for primary UI elements like navbar and appbar
        surfaceContainer: Color(0xffefefef),
        //onSurfaceContainer Color: used for basic widgets, mostly text, displayed on surfaceContainer
        onSurfaceVariant: Color(0xff494949),
        //Errors set to be transparent
        error: Colors.transparent,
        onError: Colors.transparent,
        //Light theme
        brightness: Brightness.light,
      ),
    ),
    "Monochrome": ThemeData(
      colorScheme: const ColorScheme(
        primary: Color(0xff252525),
        onPrimary: Color(0xffecebeb),
        secondary: Color(0xff949494),
        onSecondary: Colors.black,
        tertiary: Color(0xff181818),
        onTertiary: Colors.white,
        tertiaryContainer: Colors.white,
        primaryContainer: Color(0xffe8e8e8),
        secondaryContainer: Color(0xffdedede),
        surface: Color(0xffffffff),
        onSurface: Color(0xff1e1e1e),
        shadow: Color(0xff282828),
        surfaceContainer: Color(0xffd9d9d9),
        onSurfaceVariant: Colors.black,
        error: Colors.transparent,
        onError: Colors.transparent,
        brightness: Brightness.light,
      ),
    ),
    "Dark": ThemeData(
      colorScheme: const ColorScheme(
        primary: Color(0xff706f6f),
        onPrimary: Color(0xffefefef),
        primaryContainer: Color(0xff494949),
        secondary: Color(0xff484848),
        onSecondary: Color(0xffa9a9a9),
        secondaryContainer: Color(0xff484848),
        tertiary: Colors.black,
        onTertiary: Colors.white,
        tertiaryContainer: Color(0xff2a2a2a),
        surface: Color(0xff3a3a3a),
        onSurface: Color(0xffbbbbbb),
        shadow: Color(0xff151515),
        surfaceContainer: Color(0xff313131),
        onSurfaceVariant: Color(0xffcccccc),
        error: Colors.transparent,
        onError: Colors.transparent,
        brightness: Brightness.light,
      ),
    ),
    "Aquamarine": ThemeData(
      colorScheme: const ColorScheme(
        primary: Color(0xff22538d),
        onPrimary: Color(0xfff5f8fc),
        primaryContainer: Color(0xffd9dee5),
        secondary: Color(0xffd0dad7),
        onSecondary: Color(0xff1c252f),
        secondaryContainer: Color(0xffe1e6ec),
        tertiary: Color(0xff002472),
        onTertiary: Colors.white,
        tertiaryContainer: Color(0xfff2f6ff),
        surface: Color(0xffeeeeee),
        shadow: Color(0xff383838),
        onSurface: Color(0xff141821),
        surfaceContainer: Color(0xffd9e1e1),
        onSurfaceVariant: Colors.black,
        error: Colors.transparent,
        onError: Colors.transparent,
        brightness: Brightness.light,
      ),
    ),
  };
  static Map<String, List<String>> themeSettings = {
    /*
    navBar3 - Use tertiary for navbar
    shadeLoading - Shades the loading gif with primary
     */

    "Dark": ['invertsparkli']
  };
}
