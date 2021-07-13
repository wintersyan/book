import 'dart:io';

import 'package:book/common/Http.dart';
import 'package:book/common/common.dart';
import 'package:book/entity/ParseContentConfig.dart';
import 'package:book/event/event.dart';
import 'package:book/model/ColorModel.dart';
import 'package:book/model/ReadModel.dart';
import 'package:book/model/ShelfModel.dart';
import 'package:book/route/Routes.dart';
import 'package:book/service/TelAndSmsService.dart';
import 'package:book/store/Store.dart';
import 'package:book/view/book/BookShelf.dart';
import 'package:book/view/person/Me.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:dio/dio.dart';
import 'package:fluro/fluro.dart';
import 'package:flustars/flustars.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:jpush_flutter/jpush_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

GetIt locator = GetIt.instance;
// FirebaseAnalytics analytics = FirebaseAnalytics();
// FirebaseAnalyticsObserver observer =
//     FirebaseAnalyticsObserver(analytics: analytics);
// FirebaseAuth auth = FirebaseAuth.instance;
// GoogleSignIn googleSignIn = GoogleSignIn(
//   scopes: <String>[
//     'email',
//     'https://www.googleapis.com/auth/contacts.readonly',
//   ],
// );
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GestureBinding.instance.resamplingEnabled = true;
  if (await Permission.storage.request().isGranted) {
    await SpUtil.getInstance();
    locator.registerSingleton(TelAndSmsService());
    final router = FluroRouter();
    Routes.configureRoutes(router);
    Routes.router = router;
    runApp(Store.init(child: MyApp()));
    await DirectoryUtil.getInstance();
    // await Firebase.initializeApp();
    if (Platform.isAndroid) {
      SystemUiOverlayStyle systemUiOverlayStyle =
          SystemUiOverlayStyle(statusBarColor: Colors.transparent);
      SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
    }
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Store.connect<ColorModel>(
        builder: (context, ColorModel model, child) {
      return MaterialApp(
        title: '即刻追书',
        home: MainPage(),
        builder: BotToastInit(),
        navigatorObservers: [
          BotToastNavigatorObserver(),
        ],
        onGenerateRoute: Routes.router.generator,
        theme: model.theme,
      );
    });
  }
}

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _tabIndex = 0;
  bool isMovie = false;
  static final GlobalKey<ScaffoldState> q = new GlobalKey();

  /// 跳转应用市场升级
  // _launchURL(url) async {
  //   if (await canLaunch(url)) {
  //     await launch(url);
  //   } else {
  //     throw 'Could not launch $url';
  //   }
  // }

  var _pageController = PageController();
  List<BottomNavigationBarItem> bottoms = [
    BottomNavigationBarItem(
      icon: ImageIcon(
        AssetImage("images/book_shelf.png"),
        size: 27,
      ),
      label: '书架',
    ),
    // BottomNavigationBarItem(
    //   icon: ImageIcon(
    //     AssetImage("images/good.png"),
    //     size: 27,
    //   ),
    //   label: '精选',
    // ),
  ];

  /*
   * 存储的四个页面，和Fragment一样
   */
  var _pages = [BookShelf()];

  // var _pages = [BookShelf(), GoodBook(), Video(), YoutubePlayerDemoApp()];

  // var _pages = [Video(), VoiceBook()];
  initEnv() async {
    getConfigFromServer();
    // await Firebase.initializeApp();
  }

  getConfigFromServer() async {
    Response res = await HttpUtil().http().get(Common.config);
    List msg1 = await parseJson(res.data['data']);

    List<ParseContentConfig> configs =
        msg1.map((e) => ParseContentConfig.fromJson(e)).toList();
    SpUtil.putObjectList(Common.parse_html_config, configs);
  }

  @override
  void initState() {
    var widgetsBinding = WidgetsBinding.instance;
    widgetsBinding.addPostFrameCallback((callback) {
      Store.value<ReadModel>(context);
    });
    initEnv();
    super.initState();
    JPush jpush = new JPush();
    jpush.setup(
      appKey: "f90562283a6e6bffa036d5dd",
      channel: "flutter_channel",
      production: true,
      debug: false, //是否打印debug日志
    );

    eventBus.on<OpenEvent>().listen((openEvent) {
      if (openEvent.name == "m") {
        isMovie = true;
      } else {
        isMovie = false;
      }
      if (mounted) {
        setState(() {});
      }
      q.currentState.openDrawer();
    });
    eventBus.on<NavEvent>().listen((navEvent) {
      _pageController.jumpToPage(navEvent.idx);
    });
    eventBus.on<CleanEvent>().listen((navEvent) {
      BotToast.cleanAll();
    });
    // _checkUpdate();
    // Store.value<ReadModel>(context).getEveryNote();
  }

  @override
  Widget build(BuildContext context) {
    return Store.connect<ColorModel>(
        builder: (context, ColorModel model, child) {
      return Store.connect<ShelfModel>(
          builder: (context, ShelfModel shelfModel, child) {
        return Scaffold(
          drawer: Drawer(
            child: Me(),
          ),
          key: q,
          body: PageView.builder(
              //要点1
              physics: NeverScrollableScrollPhysics(),
              //禁止页面左右滑动切换
              controller: _pageController,
              onPageChanged: _pageChanged,
              //回调函数
              itemCount: _pages.length,
              itemBuilder: (context, index) => _pages[index]),
          // bottomNavigationBar: BottomNavigationBar(
          //   unselectedItemColor: model.dark ? Colors.white : Colors.black,
          //   elevation: 3,
          //   items: bottoms,
          //   type: BottomNavigationBarType.fixed,
          //   currentIndex: _tabIndex,
          //   onTap: (index) {
          //     _pageController.jumpToPage(index);
          //   },
          // ),
        );
      });
    });
  }

  void _pageChanged(int index) {
    setState(() {
      if (_tabIndex != index) _tabIndex = index;
    });
  }
}
