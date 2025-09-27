import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localstorage/localstorage.dart';

// pages
import 'pages/startup/splash_page.dart';
import 'package:secondstudent/globals/database.dart';
import 'package:secondstudent/globals/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // init supabase
  await DataBase.tryInitialize();

  // set orientation for chrome
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // notifs
  await NotificationService.setup();

  // init local storage
  await initLocalStorage();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'SecondStudent',
      home: const SplashPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
