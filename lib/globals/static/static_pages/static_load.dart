import 'package:flutter/material.dart';

/*
intermediary loading page
 */

class StaticLoad extends StatelessWidget {
  StaticLoad({super.key});
  @override
  Widget build(BuildContext context){
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    bool gif = true;

    return Scaffold(
      body: SizedBox(
        width: mediaQuery.size.width,
        height: mediaQuery.size.height,
        child: ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: Stack(
              children: [
                Image.asset('assets/images/splash.png'),
                StatefulBuilder(builder: (context, setState){
                  Future.delayed(const Duration(milliseconds: 3600), (){
                    if(context.mounted){
                      setState(() {
                        gif = false;
                      });
                    }
                  });
                  if(gif){
                    return Image.asset('assets/images/loading.gif');
                  }
                  return Container();
                })
              ],
            )
          ),
        ),
      ),
    );
  }
}
