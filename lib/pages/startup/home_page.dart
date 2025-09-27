// packages
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:secondstudent/globals/auth_service.dart';
import 'package:secondstudent/globals/tutorial_system.dart';
import 'package:secondstudent/globals/static/extensions/widget_extension.dart';
import 'package:secondstudent/pages/startup/welcome_page.dart';

// pages
import '../account/account.dart';
import '../settings/settings.dart';
import '../../globals/static/custom_widgets/swipe_page_route.dart';
import '../../../editor.dart';
import 'package:secondstudent/globals/static/custom_widgets/logo.dart';
import 'package:secondstudent/globals/stream_signal.dart';

/*
Home Page Class
- Home page of the application
- Provides primary scaffold w/ appbar and bottom navbar
- Body set as pageview of pages
- can change navigation setup to a sidebar
 */

class HomePage extends StatefulWidget {
  HomePage({Key? key});

  //Stream controller for home page
  static StreamController<StreamSignal> homePageStream =
      StreamController<StreamSignal>();

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  //PageView controller; initial page 1 (explore page)
  final PageController _pageController = PageController(initialPage: 1);
  final TutorialSystem creationTutorial = TutorialSystem(
    id: "tutorial_custom",
    icon: Icons.favorite,
    title: "Tell us your vibe",
    description:
        "Pick a situation, time & budget– we'll craft the dates just for you.",
  );

  //Disposes of context and page controller
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  //Index of navbar page option
  int pageIndex = 1;

  @override
  Widget build(BuildContext context) {
    //Colorscheme of build context
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    //Resets home stream controller
    HomePage.homePageStream = StreamController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (pageIndex == 2) {
        if (creationTutorial.run(context, false)) {
          _pageController.animateToPage(
            2,
            duration: const Duration(milliseconds: 10),
            curve: Curves.easeInOut,
          );
        }
      }
    });

    //Returns scaffold which refreshes on stream update
    return StreamBuilder<StreamSignal>(
      stream: HomePage.homePageStream.stream,
      builder: (context, snapshot) {
        return Scaffold(
          body: PageView(
            //If on map or shop page, cannot scroll so that applications absorb gestures
            physics: pageIndex == 0 || pageIndex == 3
                ? const NeverScrollableScrollPhysics()
                : const ClampingScrollPhysics(parent: PageScrollPhysics()),
            controller: _pageController,
            //On page change, reset navbar index
            onPageChanged: (index) {
              setState(() {
                pageIndex = index;
              });
            },
            //List of all active pages
            children: [EditorScreen(), Account()],
          ),
          //Top Bar
          appBar: AppBar(
            centerTitle: true,
            forceMaterialTransparency: true,
            //Elevated for shadow
            elevation: 5,
            backgroundColor: colorScheme.surfaceContainer,
            shadowColor: colorScheme.shadow,
            title: const Logo(),
            leading: Container(),
            actions: [
              const SizedBox(width: 15),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                constraints: BoxConstraints(maxWidth: pageIndex == 3 ? 65 : 0),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    onPressed: () {
                      setState(() {
                        context.pushSwipePage(Settings(), title: "Settings");
                      });
                    },
                    icon: Icon(
                      Icons.settings_outlined,
                      color: Theme.of(context).colorScheme.onSurface,
                      size: 30,
                    ),
                  ).clip(),
                ),
              ),
            ],
          ),
          backgroundColor: colorScheme.primaryContainer,
          extendBody: true,
          bottomNavigationBar: _buildNavBar(context),
        );
      },
    );
  }

  // builds the bottom navigation bar
  Widget _buildNavBar(BuildContext context) {
    double bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 60 + bottomPadding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        // border radius rounds the bottom bar
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow,
            spreadRadius: 1,
            blurRadius: 2,
          ),
        ],
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      // on click, changes page index and fills in the icon
      // doing this automatically updates the page that is displayed
      // uses a row, akin to the column in Detail, that allows multiple children to be laid in a row
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // sets up icon buttons that on pressed, changes which page is active
          // additionally, on press changes from outlined to filled in
          _buildNavIcon(context, Icons.map, Icons.map_outlined, 0),
          _buildNavIcon(context, Icons.explore, Icons.explore_outlined, 1),
          _buildNavIcon(context, Icons.favorite, Icons.favorite_outline, 2),
          _buildNavIcon(
            context,
            Icons.person,
            Icons.person_outline,
            3,
            accountLocked: true,
          ),
        ],
      ),
    );
  }

  Widget _buildNavIcon(
    BuildContext context,
    IconData icon1,
    IconData icon2,
    int index, {
    bool accountLocked = false,
  }) {
    return IconButton(
      enableFeedback: false,
      onPressed: () {
        if (!AuthService.authorized(anon: false) && accountLocked) {
          context.pushSwipePage(const WelcomePage(), showAppBar: true);
        } else {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
      },
      icon: Icon(
        pageIndex == index ? icon1 : icon2,
        color: pageIndex == index
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
        size: 32.5,
      ),
    );
  }
} // class
