import 'package:flutter/material.dart';

import '../themes.dart';

/*
All errors that get called throughout the application

Screen to display in case of any errors so the users get these rather than a debug screen
 */

class ClientError extends StatelessWidget {
  ClientError({super.key});

  final ColorScheme colorScheme = Themes.sparkliTheme.colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: colorScheme.tertiary,
          gradient: RadialGradient(
              radius: 1,
              colors: [colorScheme.primary, colorScheme.tertiary])),
      child: Center(
        child: Card(
            color: Colors.white,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              height: 250,
              width: 350,
              child: const Column(
                children: [
                  SizedBox(height: 20),
                  Text(
                    "Client Error Occurred",
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    "An Error Occurred on Client Side.",
                    maxLines: 1,
                    style: TextStyle(
                      color: Color(0xffd75454),
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(Icons.wifi_off,
                      color: Color(0xffd75454), size: 50),
                  FittedBox(
                    fit: BoxFit.contain,
                    child: Text(
                      "Try Checking Your Internet Connection!",
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xffd75454),
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            )),
      ),
    );
  }
}