import 'package:flutter/material.dart';
import 'package:rflutter_alert/rflutter_alert.dart';

import '../themes.dart';

class ServerError extends StatelessWidget {
  ServerError({super.key, required this.error});

  final String error;

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
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  const Text(
                    "Server Error Occurred",
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "An Error Occurred with Our Servers!",
                    maxLines: 1,
                    style: TextStyle(
                      color: Color(0xffd75454),
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Icon(Icons.wifi_tethering_error,
                      color: Color(0xffd75454), size: 50),
                  const FittedBox(
                    fit: BoxFit.contain,
                    child: Text(
                      "Please Be Patient While We Fix It!",
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xffd75454),
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Alert(
                          context: context,
                          content: Text(
                            error,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16
                            ),
                          ),
                          buttons: [
                            DialogButton(
                                color: Colors.grey,
                                child: const Text("Got it!",
                                    maxLines: 1,
                                    style: TextStyle(
                                        fontSize: 20, color: Colors.black)),
                                onPressed: () {
                                  Navigator.pop(context);
                                }),
                          ]).show();
                    },
                    style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(10), // Rounded corners
                        ),
                        fixedSize: const Size(275, 30),
                        padding: const EdgeInsets.symmetric(vertical: 7.5),
                        backgroundColor: Theme.of(context).colorScheme.primary),
                    child: Text(
                      "More Details",
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary),
                    ),
                  ),
                ],
              ),
            )),
      ),
    );
  }
}
