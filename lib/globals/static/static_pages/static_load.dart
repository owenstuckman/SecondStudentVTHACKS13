import 'package:flutter/material.dart';

/*
intermediary loading page
 */

class StaticLoad extends StatefulWidget {
  const StaticLoad({super.key});
  @override
  State<StaticLoad> createState() => _StaticLoadState();
}

class _StaticLoadState extends State<StaticLoad> {
  bool _showLoading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 3600), (){
      if (mounted) {
        setState(() {
          _showLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context){
    final MediaQueryData mediaQuery = MediaQuery.of(context);

    return Scaffold(
      body: SizedBox(
        width: mediaQuery.size.width,
        height: mediaQuery.size.height,
        child: ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: Stack(
              children: [
                Image.asset('assets/assets/images/splash.gif'),
                if (_showLoading)
                  Image.asset('assets/assets/images/loading.gif'),
              ],
            )
          ),
        ),
      ),
    );
  }
}
