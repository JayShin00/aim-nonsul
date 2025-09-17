import 'package:flutter/material.dart';
import 'package:aim_nonsul/screens/home_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:aim_nonsul/firebase_options.dart';
import 'package:aim_nonsul/theme/app_theme.dart';
import 'package:home_widget/home_widget.dart';
import 'package:aim_nonsul/services/notification_service.dart';
import 'package:aim_nonsul/services/background_notification_service.dart';
import 'package:aim_nonsul/services/in_app_update_service.dart';
import 'package:upgrader/upgrader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Firebase 초기화 전에 필수
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ); // Firebase 초기화

  // Home Widget App Group ID 설정
  await HomeWidget.setAppGroupId('group.com.aim.aimNonsul.ExamWidget');

  // Notification Services
  await NotificationService().initialize();
  await BackgroundNotificationService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    BackgroundNotificationService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    BackgroundNotificationService.onAppLifecycleChanged(state);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AIM 논술 D-Day',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      // 2. home 속성을 UpgradeAlert 위젯으로 변경
      home: UpgradeAlert(
        upgrader: Upgrader(
          countryCode: 'KR',
        ),
        child: const InAppUpdateWrapper(child: HomeScreen()), // 인앱 업데이트 래퍼 추가
      ),
    );
  }
}

/// 인앱 업데이트를 처리하는 래퍼 위젯
class InAppUpdateWrapper extends StatefulWidget {
  final Widget child;
  
  const InAppUpdateWrapper({super.key, required this.child});

  @override
  State<InAppUpdateWrapper> createState() => _InAppUpdateWrapperState();
}

class _InAppUpdateWrapperState extends State<InAppUpdateWrapper> {
  @override
  void initState() {
    super.initState();
    // 앱 시작 시 백그라운드에서 업데이트 확인
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdatesInBackground();
    });
  }

  Future<void> _checkForUpdatesInBackground() async {
    // 앱이 시작된 후 3초 뒤에 업데이트 확인
    await Future.delayed(const Duration(seconds: 3));
    
    if (mounted) {
      await InAppUpdateService.checkForUpdatesInBackground(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
