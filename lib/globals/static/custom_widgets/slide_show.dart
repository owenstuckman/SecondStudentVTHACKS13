import 'dart:async';

import 'package:flutter/material.dart';

class Wrapper<T>{
  Wrapper({this.value});
  T? value;
  void setValue(T? value){
    this.value = value;
  }
  Wrapper clone(){
    return Wrapper(value: value);
  }
}

class SlideShow extends StatefulWidget {
  const SlideShow({
    super.key,
    required this.children,
    this.colorScheme,
    this.startPage = 0,
    this.colors,
    this.labelprogress = true,
    this.height,
    this.nextTexts,
    this.conditions,
    this.regressMethods,
    this.progressMethods,
    this.buttonWrapper,
    this.progressDots = true,
    this.scroll = false,
  });

  final List<Widget> children;
  final ColorScheme? colorScheme;
  final bool labelprogress;
  final int startPage;
  final List<Color>? colors;
  final double? height;
  final bool progressDots;
  final bool scroll;
  final List<String>? nextTexts;
  final List<bool Function(bool)>? conditions;
  final List<FutureOr<void> Function(void Function())>? regressMethods;
  final List<FutureOr<void> Function(void Function())>? progressMethods;
  final Wrapper<FutureOr<void> Function()?>? buttonWrapper;

  @override
  State<SlideShow> createState() => _SlideShowState();
}

class _SlideShowState extends State<SlideShow> {
  late PageController _controller;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.startPage);
    _currentPage = widget.startPage;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Color> colors = widget.colors ?? [];
    final List<String> nextTexts = widget.nextTexts ?? [];

    final ColorScheme colorScheme = widget.colorScheme ?? Theme.of(context).colorScheme;
    final MediaQueryData mediaQuery = MediaQuery.of(context);

    return Container(
      color: colors.length > _currentPage
          ? colors[_currentPage]
          : colorScheme.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: PageView(
              physics: widget.scroll ? null : const NeverScrollableScrollPhysics(),
              controller: _controller,
              onPageChanged: (page) {
                setState(() {
                  _currentPage = page;
                });
              },
              children: List<Widget>.generate(widget.children.length, (i) {
                return Container(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_currentPage > 0)
                        IconButton(
                          onPressed: () => _navigateBack(),
                          icon: Icon(
                            Icons.arrow_back_ios,
                            color: colorScheme.onSurface,
                            size: 20,
                          ),
                        ),
                      SizedBox(
                        height: widget.height,
                        width: MediaQuery.of(context).size.width * 3 / 4,
                        child: Card(
                          color: colorScheme.surface,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: widget.height,
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(10),
                                  ),
                                  child: SingleChildScrollView(
                                    child: widget.children[i],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 5,
                                  horizontal: 20,
                                ),
                                child: Opacity(
                                  opacity: !widget.labelprogress || _canProgress(false) ? 1 : 0.75,
                                  child: ElevatedButton(
                                    onPressed: () => _handleButtonPress(),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      backgroundColor: colorScheme.primary,
                                    ),
                                    child: Container(
                                      alignment: Alignment.center,
                                      width: MediaQuery.of(context).size.width / 2,
                                      child: Text(
                                        nextTexts.length > i ? nextTexts[i] : 'Continue',
                                        style: TextStyle(
                                          fontFamily: 'Pridi',
                                          fontSize: 20,
                                          color: colorScheme.onPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_currentPage > 0) const SizedBox(width: 40),
                    ],
                  ),
                );
              }),
            ),
          ),
          if (widget.progressDots)
            Padding(
              padding: EdgeInsets.only(bottom: mediaQuery.padding.bottom + 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(widget.children.length, (e) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: CircleAvatar(
                      radius: 5,
                      backgroundColor: e <= _currentPage
                          ? colorScheme.primary
                          : colorScheme.surface,
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  void _navigateToPage(int page) {
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _navigateNext() {
    if (_currentPage + 1 < widget.children.length) {
      _navigateToPage(_currentPage + 1);
    }
  }

  Future<void> _navigateBack() async {
    final regressMethods = widget.regressMethods ?? [];
    if (_currentPage < regressMethods.length) {
      await regressMethods[_currentPage](() {
        _navigateToPage(_currentPage - 1);
      });
    } else {
      _navigateToPage(_currentPage - 1);
    }
  }

  bool _canProgress(bool active) {
    final conditions = widget.conditions ?? [];
    if (_currentPage < conditions.length) {
      return conditions[_currentPage](active);
    }
    return true;
  }

  Future<void> _handleButtonPress() async {
    if (_canProgress(true)) {
      final progressMethods = widget.progressMethods ?? [];
      if (_currentPage < progressMethods.length) {
        await progressMethods[_currentPage](_navigateNext);
      } else {
        _navigateNext();
      }
    }
  }
}