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
import '../editor/editor.dart';
import 'package:secondstudent/globals/static/custom_widgets/logo.dart';
import 'package:secondstudent/globals/stream_signal.dart';
import 'package:secondstudent/pages/calendar/calendar.dart';
import 'package:secondstudent/pages/todo/todo.dart';
import 'file_storage.dart';

/*
Home Page Class
- Home page of the application
- Persistent custom left drawer (stays open until toggled)
- Drawer width resizable by dragging its right edge
- Body set as PageView of pages
*/

class HomePage extends StatefulWidget {
  HomePage({Key? key});

  //Stream controller for home page
  static StreamController<StreamSignal> homePageStream =
      StreamController<StreamSignal>();

  @override
  State<HomePage> createState() => HomePageState();
}

class _NavItem {
  final IconData filled;
  final IconData outlined;
  final String label;
  final bool lock;
  const _NavItem({
    required this.filled,
    required this.outlined,
    required this.label,
    this.lock = false,
  });
}

class HomePageState extends State<HomePage> {
  // PageView controller; initial page 0
  final PageController _pageController = PageController(initialPage: 0);

  final TutorialSystem creationTutorial = TutorialSystem(
    id: "tutorial_custom",
    icon: Icons.favorite,
    title: "Tell us your vibe",
    description:
        "Pick a situation, time & budget– we'll craft the dates just for you.",
  );

  // Side nav items. ORDER MUST MATCH PageView children.
  final List<_NavItem> _navItems = const [
    _NavItem(
      filled: Icons.abc_rounded,
      outlined: Icons.abc_outlined,
      label: 'Editor',
      lock: false,
    ),
    _NavItem(
      filled: Icons.calendar_month,
      outlined: Icons.calendar_month_outlined,
      label: 'Calendar',
      lock: false,
    ),
    _NavItem(
      filled: Icons.check_box,
      outlined: Icons.check_box_outlined,
      label: 'To-Do',
      lock: false,
    ),
  ];

  // Index of selected page
  int pageIndex = 0;

  // Persistent drawer state & size
  bool _drawerOpen = true;
  double _drawerWidth = 320; // default
  static const double _minDrawerWidth = 260;
  static const double _maxDrawerWidth = 520;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleDrawer() {
    setState(() => _drawerOpen = !_drawerOpen);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    // Reset home stream controller
    HomePage.homePageStream = StreamController<StreamSignal>();

    // Keep tutorial hook but only run if the target page exists (index 2)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bool creationPageExists = _navItems.length > 2;
      if (creationPageExists && pageIndex == 2) {
        if (creationTutorial.run(context, false)) {
          _pageController.animateToPage(
            2,
            duration: const Duration(milliseconds: 10),
            curve: Curves.easeInOut,
          );
        }
      }
    });

    return StreamBuilder<StreamSignal>(
      stream: HomePage.homePageStream.stream,
      builder: (context, snapshot) {
        return Scaffold(
          // No Scaffold drawer: we render our own persistent drawer in the body.
          appBar: AppBar(
            centerTitle: true,
            forceMaterialTransparency: true,
            elevation: 5,
            backgroundColor: colorScheme.surfaceContainer,
            shadowColor: colorScheme.shadow,
            title: const Logo(),
            leading: IconButton(
              tooltip: _drawerOpen ? 'Close menu' : 'Open menu',
              icon: const Icon(Icons.menu),
              onPressed: _toggleDrawer, // toggle persistent drawer
            ),
            actions: [
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  context.pushSwipePage(Account(), title: "Account");
                },
                icon: Icon(
                  Icons.person_outlined,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 30,
                ),
              ).clip(),
            ],
          ),

          backgroundColor: colorScheme.primaryContainer,
          extendBody: true,

          body: Row(
            children: [
              // PERSISTENT DRAWER PANEL
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: _drawerOpen
                    ? _drawerWidth.clamp(_minDrawerWidth, _maxDrawerWidth)
                    : 0,
                // If closed, also avoid hit testing
                child: _drawerOpen
                    ? _buildPersistentDrawer(context)
                    : const SizedBox.shrink(),
              ),

              // MAIN CONTENT
              Expanded(
                child: PageView(
                  physics: const ClampingScrollPhysics(
                    parent: PageScrollPhysics(),
                  ),
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => pageIndex = index),
                  // ORDER must match _navItems above
                  children: [EditorScreen(), Calendar(), ToDo()],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPersistentDrawer(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      // give proper theme + elevation like Drawer
      color: cs.surfaceContainer,
      elevation: 8,
      child: SafeArea(
        right:
            false, // so the resize handle can extend full height to the right edge
        child: Row(
          children: [
            // CONTENT
            Expanded(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  const Logo(),
                  const Divider(),

                  // NAV ITEMS
                  Expanded(
                    child: ListView.builder(
                      itemCount: _navItems.length,
                      itemBuilder: (ctx, i) {
                        final item = _navItems[i];
                        final selected = pageIndex == i;
                        return ListTile(
                          leading: Icon(
                            selected ? item.filled : item.outlined,
                            color: selected ? cs.primary : cs.onSurfaceVariant,
                          ),
                          title: Text(item.label),
                          selected: selected,
                          onTap: () {
                            final needsAuth = item.lock;
                            if (!AuthService.authorized(anon: false) &&
                                needsAuth) {
                              context.pushSwipePage(
                                const WelcomePage(),
                                showAppBar: true,
                              );
                              return;
                            }
                            _pageController.animateToPage(
                              i,
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const Divider(),

                  // SETTINGS
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Settings'),
                    onTap: () =>
                        context.pushSwipePage(Settings(), title: "Settings"),
                  ),
                  // FILE STORAGE LOCATION

                  ListTile(
                    leading: const Icon(Icons.file_copy_outlined),
                    title: const Text('File Location'),
                    onTap: () => context.pushSwipePage(
                      FileStorage(),
                      title: "File Selection",
                    ),
                  ),

                  // OPTIONAL FIXED WIDTH ADJUST (keep if you still want a slider UI)
                  // Padding(
                  //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  //   child: Column(
                  //     crossAxisAlignment: CrossAxisAlignment.start,
                  //     children: [
                  //       Text('Drawer width', style: Theme.of(context).textTheme.labelMedium),
                  //       Slider(
                  //         min: _minDrawerWidth,
                  //         max: _maxDrawerWidth,
                  //         value: _drawerWidth,
                  //         label: _drawerWidth.toStringAsFixed(0),
                  //         onChanged: (v) => setState(() => _drawerWidth = v),
                  //       ),
                  //     ],
                  //   ),
                  // ),
                ],
              ),
            ),

            // RESIZE HANDLE (touch/drag on drawer's right edge)
            // Drags horizontally to resize the drawer.
            MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _drawerWidth = (_drawerWidth + details.delta.dx).clamp(
                      _minDrawerWidth,
                      _maxDrawerWidth,
                    );
                  });
                },
                child: Container(
                  width: 10,
                  height: double.infinity,
                  alignment: Alignment.center,
                  // subtle visual grabber
                  child: Container(
                    width: 3,
                    height: 36,
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} // class
