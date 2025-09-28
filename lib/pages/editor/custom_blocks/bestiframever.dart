import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/*
Shop page currently only works for IOS!

*/
// Import for Android features.
import 'package:webview_flutter_android/webview_flutter_android.dart';

// Import for iOS/macOS features.
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class Shop extends StatefulWidget {
	@override
	State<Shop> createState() => _ShopState();
}

class _ShopState extends State<Shop> {
	late final WebViewController controller;
	bool isLoading = true;

	void setupWebView(){

		// Initialize platform-specific WebViewController creation params
		late final PlatformWebViewControllerCreationParams params;
		if (WebViewPlatform.instance is WebKitWebViewPlatform) {
			// iOS/macOS-specific params
			params = WebKitWebViewControllerCreationParams(
				allowsInlineMediaPlayback: true,
				mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
			);
		} else {
			// Android and other platform params
			params = const PlatformWebViewControllerCreationParams();
		}

		// Create the controller using the params
		controller = WebViewController.fromPlatformCreationParams(params)
			..setJavaScriptMode(JavaScriptMode.unrestricted)
			..setNavigationDelegate(
				NavigationDelegate(
					onPageStarted: (url) {
						setState(() {
							isLoading = true;
						});
					},
					onPageFinished: (url) {
						setState(() {
							isLoading = false;
						});
					},
					onWebResourceError: (error) {
						print("Web resource error: ${error.description}");
					},
				),
			)
			..loadRequest(Uri.parse(
					'https://excalidraw.com/#room=31cd33dac04dc4e7f37f,cJKZfPrbfb4Xs0kNk8sXCg'));

		// Additional platform-specific settings for Android
		if (controller.platform is AndroidWebViewController) {
			AndroidWebViewController.enableDebugging(true);
			(controller.platform as AndroidWebViewController)
					.setMediaPlaybackRequiresUserGesture(false);
		}
	}

	@override
	void initState() {
		super.initState();
		WidgetsBinding.instance.addPostFrameCallback((_) {
			setupWebView();
		});
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			body: Stack(
				children: [
					WebViewWidget(
							// define controller
							controller: controller,
							// define gestures
							gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
								Factory<VerticalDragGestureRecognizer>(
									() => VerticalDragGestureRecognizer(),
								),
								Factory<HorizontalDragGestureRecognizer>(
									() => HorizontalDragGestureRecognizer(),
								),
							}),
					// loading bar
					if (isLoading)
						const Center(
							child: CircularProgressIndicator(),
						),
				],
			),
		);
	}
}