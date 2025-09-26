//this is for app wide helpers

import 'package:flutter/material.dart';

//enums for types of screen
//can be expanded in the future
enum ScreenType {
  setupScreen,
  gameScreen,
}

Future<bool> backConfirmation ({
required BuildContext context,
required ScreenType screenType,
}) async {
  //for now we only have two options so i can make this part simple, but we may need to add more options later
  final String title =
  screenType == ScreenType.gameScreen ? 'Leave Game?' : 'Leave Screen?';

  final bool? shouldLeave = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: const Text('Are you sure you want to leave?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false); // Stay
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true); // Leave
            },
            child: const Text('Leave'),
          ),
        ],
      );
    },
  );

  return shouldLeave ?? false;


}