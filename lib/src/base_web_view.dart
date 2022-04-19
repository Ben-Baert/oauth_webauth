import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:webviewx/webviewx.dart';

typedef CertificateValidator = bool Function(X509Certificate certificate);

class BaseWebView extends StatefulWidget {
  static const String firstLoadHeroTag = 'firstLoadOAuthWebAuthHeroTag';
  static const String backButtonTooltipKey = 'backButtonTooltipKey';
  static const String forwardButtonTooltipKey = 'forwardButtonTooltipKey';
  static const String reloadButtonTooltipKey = 'reloadButtonTooltipKey';
  static const String clearCacheButtonTooltipKey = 'clearCacheButtonTooltipKey';
  static const String closeButtonTooltipKey = 'closeButtonTooltipKey';
  static const String clearCacheWarningMessageKey =
      'clearCacheWarningMessageKey';

  final String initialUrl;
  final List<String> redirectUrls;

  /// This function will be called when redirectUrl is loaded in web view.
  final VoidCallback? onSuccessRedirect;

  /// This function will be called if any error occurs.
  /// It will receive the error data which could be some Exception or Error
  final ValueChanged<dynamic>? onError;

  /// This function will be called when user cancels authentication.
  final VoidCallback? onCancel;

  /// This function will be called when [authorizationEndpointUrl] is first loaded.
  /// If false is returned then a CertificateException() will be thrown
  final CertificateValidator? onCertificateValidate;

  final ThemeData? themeData;
  final Map<String, String>? textLocales;
  final Locale? contentLocale;

  const BaseWebView({
    Key? key,
    required this.initialUrl,
    required this.redirectUrls,
    this.onSuccessRedirect,
    this.onError,
    this.onCancel,
    this.onCertificateValidate,
    this.themeData,
    this.textLocales,
    this.contentLocale,
  }) : super(key: key);

  @override
  BaseWebViewState<BaseWebView> createState() => BaseWebViewState<BaseWebView>();
}

class BaseWebViewState<S extends BaseWebView> extends State<S>
    with WidgetsBindingObserver {
  bool ready = false;
  bool showToolbar = false;
  bool isLoading = true;
  bool allowGoBack = false;
  bool allowGoForward = false;
  bool tooltipsAlreadyInitialized = false;
  WebViewXController? webViewXController;
  InAppWebViewController? inAppWebViewControllerController;
  @override
  late BuildContext context;

  late Uri initialUri;
  late String backButtonTooltip;
  late String forwardButtonTooltip;
  late String reloadButtonTooltip;
  late String clearCacheButtonTooltip;
  late String closeButtonTooltip;
  late String clearCacheWarningMessage;

  late Timer toolbarTimerShow;
  late Widget webView;

  List<String> get redirectUrls => widget.redirectUrls;

  @override
  void initState() {
    super.initState();
    initialUri = Uri.parse(widget.initialUrl);
    toolbarTimerShow = Timer(const Duration(seconds: 5), () {
      setState(() {
        showToolbar = true;
      });
    });
    WidgetsBinding.instance.addObserver(this);
    webView = initWebView();
  }

  void initTooltips() {
    if (tooltipsAlreadyInitialized) return;
    backButtonTooltip =
        widget.textLocales?[BaseWebView.backButtonTooltipKey] ?? 'Go back';
    forwardButtonTooltip =
        widget.textLocales?[BaseWebView.forwardButtonTooltipKey] ??
            'Go forward';
    reloadButtonTooltip =
        widget.textLocales?[BaseWebView.reloadButtonTooltipKey] ?? 'Reload';
    clearCacheButtonTooltip =
        widget.textLocales?[BaseWebView.clearCacheButtonTooltipKey] ??
            'Clear cache';
    closeButtonTooltip =
        widget.textLocales?[BaseWebView.closeButtonTooltipKey] ??
            MaterialLocalizations.of(context).closeButtonTooltip;
    clearCacheWarningMessage =
        widget.textLocales?[BaseWebView.clearCacheWarningMessageKey] ??
            'Are you sure you want to clear cache?';
    tooltipsAlreadyInitialized = true;
  }

  Widget initWebView() {
    final Widget content;

    if (kIsWeb) {
      // content = WebView(
      //   initialUrl: authorizationUri.toString(),
      //   javascriptMode: JavascriptMode.unrestricted,
      //   userAgent: 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.103 Safari/537.36', /// This custom userAgent is mandatory due to security constraints of Google's OAuth2 policies (https://developers.googleblog.com/2021/06/upcoming-security-changes-to-googles-oauth-2.0-authorization-endpoint.html)
      //   zoomEnabled: false,
      //   gestureNavigationEnabled: false,
      //   onWebViewCreated: (controller) {
      //     webViewXController = controller;
      //   },
      //   navigationDelegate: (request) async =>
      //   onNavigateTo(request.url) ?
      //   NavigationDecision.navigate :
      //   NavigationDecision.prevent,
      //   onPageFinished: (url) => hideLoading(),
      // );

      content = WebViewX(
        width: MediaQueryData.fromWindow(window).size.width,
        height: MediaQueryData.fromWindow(window).size.height,
        initialContent: initialUri.toString(),
        initialSourceType: SourceType.url,
        javascriptMode: JavascriptMode.unrestricted,
        userAgent: 'Mozilla/5.0',

        /// This custom userAgent is mandatory due to security constraints of Google's OAuth2 policies (https://developers.googleblog.com/2021/06/upcoming-security-changes-to-googles-oauth-2.0-authorization-endpoint.html)
        onWebViewCreated: (controller) {
          webViewXController = controller;
        },
        navigationDelegate: (request) async =>
            onNavigateTo(request.content.source)
                ? NavigationDecision.navigate
                : NavigationDecision.prevent,
        onPageFinished: (url) => hideLoading(),
      );
    } else {
      /// InAppWebView is a better choice for Android and iOS than official plugin for WebViews
      /// (WebViewX uses official WebView plugin) due to the possibility to
      /// manage ServerTrustAuthRequest, which is crucial in Android because Android
      /// native WebView does not allow to access an URL with a certificate not authorized by
      /// known certification authority.
      content = InAppWebView(
        initialOptions: InAppWebViewGroupOptions(
          crossPlatform: InAppWebViewOptions(
            useShouldOverrideUrlLoading: true,
            supportZoom: false,
            userAgent: 'Mozilla/5.0', /// This custom userAgent is mandatory due to security constraints of Google's OAuth2 policies (https://developers.googleblog.com/2021/06/upcoming-security-changes-to-googles-oauth-2.0-authorization-endpoint.html)
          ),
          android: AndroidInAppWebViewOptions(
            useHybridComposition: true,
          ),
        ),
        initialUrlRequest: URLRequest(
          url: initialUri,
          headers: widget.contentLocale == null
              ? null
              : {'Accept-Language': widget.contentLocale!.toLanguageTag()},
        ),
        onReceivedServerTrustAuthRequest: (controller, challenge) async {
          return ServerTrustAuthResponse(
              action: ServerTrustAuthResponseAction.PROCEED);
        },
        onWebViewCreated: (controller) {
          inAppWebViewControllerController = controller;
        },
        shouldOverrideUrlLoading: (controller, navigationAction) async {
          final url = navigationAction.request.url?.toString() ?? '';
          return onNavigateTo(url)
              ? NavigationActionPolicy.ALLOW
              : NavigationActionPolicy.CANCEL;
        },
        onLoadStart: (controller, url) async {
          if (url == initialUri) {
            final certificate =
                (await controller.getCertificate())?.x509Certificate;
            if (certificate != null && !onCertificateValidate(certificate)) {
              onError(const CertificateException('Invalid certificate'));
            }
          }
          showLoading();
        },
        onLoadStop: (controller, url) async {
          hideLoading();
        },
        onLoadError: (controller, url, code, message) => hideLoading(),
      );
    }

    return GestureDetector(
      onLongPressDown: (details) {},

      /// To avoid long press for text selection or open link on new tab
      child: content,
    );
  }

  void showLoading() {
    if (!isLoading) {
      setState(() {
        isLoading = true;
      });
    }
  }

  Future<void> hideLoading() async {
    if (isLoading) {
      ready = true;
      showToolbar = true;
      toolbarTimerShow.cancel();
      isLoading = false;
      allowGoBack = await controllerCanGoBack();
      allowGoForward = await controllerCanGoForward();
      setState(() {});
    }
  }

  bool startsWithAnyRedirectUrl(String url) => redirectUrls.any((redirectUrl) => url.startsWith(redirectUrl));

  bool onNavigateTo(String url) {
    if (url != 'about:blank') showLoading();
    if (startsWithAnyRedirectUrl(url)) {
      onSuccess(url);
      return false;
    }
    return true;
  }

  void onSuccess(String responseRedirect) async {
    widget.onSuccessRedirect?.call();
  }

  void onError(dynamic error) {
    widget.onError?.call(error);
  }

  void onCancel() {
    widget.onCancel?.call();
  }

  bool onCertificateValidate(X509Certificate certificate) {
    return widget.onCertificateValidate?.call(certificate) ?? true;
  }

  Widget iconButton({
    required IconData iconData,
    String? tooltip,
    VoidCallback? onPressed,
    bool respectLoading = true,
  }) =>
      IconButton(
        iconSize: 30,
        tooltip: tooltip,
        icon: Icon(iconData),
        color: Theme.of(context).colorScheme.secondary,
        onPressed: respectLoading && isLoading ? null : onPressed,
      );

  @override
  Widget build(BuildContext context) {
    final content = Builder(
      builder: (context) {
        this.context = context;
        initTooltips();
        return Scaffold(
          body: Stack(
            children: [
              WillPopScope(
                child: webView,
                onWillPop: onBackPressed,
              ),
              Positioned.fill(
                child: Hero(
                  tag: BaseWebView.firstLoadHeroTag,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: !ready && isLoading
                        ? const CircularProgressIndicator()
                        : const SizedBox(),
                  ),
                ),
              ),
              AnimatedPositioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: ready && isLoading ? 5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const LinearProgressIndicator(),
              ),
            ],
          ),
          bottomNavigationBar: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: showToolbar ? null : 0,
            child: BottomAppBar(
              elevation: 8,
              color: Theme.of(context).bottomAppBarColor,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  iconButton(
                    iconData: Icons.arrow_back_ios_rounded,
                    tooltip: backButtonTooltip,
                    onPressed: !allowGoBack ? null : () => controllerGoBack(),
                  ),
                  iconButton(
                    iconData: Icons.arrow_forward_ios_rounded,
                    tooltip: forwardButtonTooltip,
                    onPressed:
                        !allowGoForward ? null : () => controllerGoForward(),
                  ),
                  iconButton(
                    iconData: Icons.refresh_rounded,
                    tooltip: reloadButtonTooltip,
                    onPressed: () => controllerReload(),
                  ),
                  iconButton(
                    iconData: Icons.cleaning_services_rounded,
                    tooltip: clearCacheButtonTooltip,
                    onPressed: () {
                      showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: Text(clearCacheButtonTooltip),
                              content: Text(clearCacheWarningMessage),
                              actions: [
                                TextButton(
                                  child: Text(MaterialLocalizations.of(context)
                                      .cancelButtonLabel),
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                ),
                                TextButton(
                                  child: Text(MaterialLocalizations.of(context)
                                      .okButtonLabel),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    controllerClearCache();
                                  },
                                ),
                              ],
                            );
                          });
                    },
                  ),
                  iconButton(
                    iconData: Icons.close,
                    tooltip: closeButtonTooltip,
                    respectLoading: false,
                    onPressed: () => onCancel(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    return widget.themeData != null
        ? Theme(
            data: widget.themeData!,
            child: content,
          )
        : content;
  }

  Future<void> controllerGoBack() async {
    showLoading();
    webViewXController?.goBack();
    inAppWebViewControllerController?.goBack();
  }

  Future<void> controllerGoForward() async {
    showLoading();
    webViewXController?.goForward();
    inAppWebViewControllerController?.goForward();
  }

  Future<void> controllerReload() async {
    showLoading();
    webViewXController?.reload();
    inAppWebViewControllerController?.reload();
  }

  Future<void> controllerClearCache() async {
    showLoading();
    await webViewXController?.clearCache();
    await inAppWebViewControllerController?.clearCache();
    hideLoading();
  }

  Future<bool> controllerCanGoForward() async {
    return await webViewXController?.canGoForward() ??
        await inAppWebViewControllerController?.canGoForward() ??
        false;
  }

  Future<bool> controllerCanGoBack() async {
    return await webViewXController?.canGoBack() ??
        await inAppWebViewControllerController?.canGoBack() ??
        false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        hideLoading();
        break;
      default:
        break;
    }
  }

  Future<bool> onBackPressed() async {
    if (await controllerCanGoBack()) {
      controllerGoBack();
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    super.dispose();
    toolbarTimerShow.cancel();
  }
}
