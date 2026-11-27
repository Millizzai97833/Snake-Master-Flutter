import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

const String bannerId = 'R-M-20409416-2';
const String rewardedId = 'R-M-20409416-1';
const String interstitialId = 'R-M-20409416-3';

const Color green = Color(0xFF00E6A0);
const Color background = Color(0xFF07131A);
const Color panel = Color(0xFF10262E);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    try {
      await YandexAds.setLogging(true);
      await YandexAds.initialize();
      debugPrint('YANDEX SDK INITIALIZED');
    } catch (error, stack) {
      debugPrint('YANDEX INITIALIZATION ERROR: $error');
      debugPrint('$stack');
    }
  }

  runApp(const SnakeMasterApp());
}

class SnakeMasterApp extends StatelessWidget {
  const SnakeMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snake Master',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: green,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SnakeGamePage(),
    );
  }
}

enum Direction { up, down, left, right }

class SnakeGamePage extends StatefulWidget {
  const SnakeGamePage({super.key});

  @override
  State<SnakeGamePage> createState() => _SnakeGamePageState();
}

class _SnakeGamePageState extends State<SnakeGamePage> {
  static const int cols = 18;
  static const int rows = 24;

  final Random random = Random();
  final InterstitialAdLoader interstitialLoader = InterstitialAdLoader();
  final RewardedAdLoader rewardedLoader = RewardedAdLoader();

  final Uri sponsorUri = Uri.parse(
    'https://auctionr.org/4/734126bad0bd8538a4233f18e7855d55',
  );

  Timer? timer;
  Timer? bannerTimer;

  List<Point<int>> snake = [];
  Point<int> food = const Point(8, 12);

  Direction direction = Direction.right;
  Direction nextDirection = Direction.right;

  int score = 0;
  int bestScore = 0;
  int finishedGames = 0;

  bool started = false;
  bool paused = false;
  bool gameOver = false;

  bool bannerReady = false;
  bool bannerLoading = false;
  bool rewardedLoading = false;
  bool rewardedShowing = false;
  bool interstitialLoading = false;

  String bannerMessage = 'Loading advertisement...';
  String rewardedMessage = 'Rewarded ad not ready';

  BannerAd? bannerAd;
  RewardedAd? rewardedAd;
  InterstitialAd? interstitialAd;

  StreamSubscription? bannerStateSubscription;
  StreamSubscription? bannerEventSubscription;

  @override
  void initState() {
    super.initState();
    resetGame();

    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        loadBanner();
        loadRewarded();
        loadInterstitial();
      });
    }
  }

  // ---------------- BANNER ----------------

  Future<void> loadBanner() async {
    if (kIsWeb || !mounted || bannerLoading) return;

    bannerTimer?.cancel();
    await bannerStateSubscription?.cancel();
    await bannerEventSubscription?.cancel();

    bannerAd?.destroy();
    bannerAd = null;

    setState(() {
      bannerLoading = true;
      bannerReady = false;
      bannerMessage = 'Requesting Yandex banner...';
    });

    try {
      final int width = MediaQuery.of(context).size.width.round();
      final BannerAd banner = BannerAd(
        adSize: BannerAdSize.sticky(width: width),
      );

      bannerStateSubscription = banner.loadStateStream.listen((state) {
        if (!mounted) return;

        if (state is BannerAdLoadStateLoaded) {
          bannerTimer?.cancel();
          debugPrint('YANDEX BANNER LOADED');
          setState(() {
            bannerReady = true;
            bannerLoading = false;
            bannerMessage = 'Banner loaded';
          });
        } else if (state is BannerAdLoadStateError) {
          bannerTimer?.cancel();
          final String error = state.error.description;
          debugPrint('YANDEX BANNER ERROR: $error');
          setState(() {
            bannerReady = false;
            bannerLoading = false;
            bannerMessage = 'Banner error: $error';
          });
        }
      });

      bannerEventSubscription = banner.events.listen((event) {
        if (event is BannerAdClickedEvent) {
          debugPrint('YANDEX BANNER CLICKED');
        }
        if (event is BannerAdImpressionEvent) {
          debugPrint('YANDEX BANNER IMPRESSION');
        }
      });

      bannerAd = banner;
      banner.load(const AdRequest(adUnitId: bannerId));

      bannerTimer = Timer(const Duration(seconds: 25), () {
        if (!mounted || bannerReady) return;
        setState(() {
          bannerLoading = false;
          bannerMessage = 'Banner timeout. Tap retry.';
        });
        debugPrint('YANDEX BANNER TIMEOUT');
      });
    } catch (error, stack) {
      debugPrint('YANDEX BANNER EXCEPTION: $error');
      debugPrint('$stack');
      if (mounted) {
        setState(() {
          bannerLoading = false;
          bannerMessage = 'Banner error: $error';
        });
      }
    }
  }

  Widget bannerPlacement() {
    return Container(
      width: double.infinity,
      height: 75,
      margin: const EdgeInsets.fromLTRB(10, 5, 10, 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(10),
      ),
      child: bannerReady && bannerAd != null
          ? AdWidget(bannerAd: bannerAd!)
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Advertisement',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Text(
                    bannerMessage,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                    ),
                  ),
                ),
                if (!bannerLoading && !kIsWeb)
                  TextButton(
                    onPressed: loadBanner,
                    child: const Text('RETRY'),
                  ),
              ],
            ),
    );
  }

  // ---------------- REWARDED ----------------

  Future<void> loadRewarded() async {
    if (kIsWeb ||
        rewardedLoading ||
        rewardedAd != null ||
        rewardedShowing) {
      return;
    }

    setState(() {
      rewardedLoading = true;
      rewardedMessage = 'Loading rewarded ad...';
    });

    debugPrint('YANDEX REWARDED REQUEST');

    try {
      final RewardedAd ad = await rewardedLoader
          .loadAd(adRequest: const AdRequest(adUnitId: rewardedId))
          .timeout(const Duration(seconds: 30));

      if (!mounted) {
        ad.destroy();
        return;
      }

      rewardedAd = ad;
      debugPrint('YANDEX REWARDED LOADED');

      setState(() {
        rewardedLoading = false;
        rewardedMessage = 'Rewarded ad ready';
      });
    } on TimeoutException {
      debugPrint('YANDEX REWARDED TIMEOUT');
      if (mounted) {
        setState(() {
          rewardedLoading = false;
          rewardedMessage = 'Request timed out. Retry.';
        });
      }
    } on AdRequestError catch (error) {
      debugPrint('YANDEX REWARDED LOAD ERROR: ${error.description}');
      if (mounted) {
        setState(() {
          rewardedLoading = false;
          rewardedMessage = error.description;
        });
      }
    } catch (error, stack) {
      debugPrint('YANDEX REWARDED EXCEPTION: $error');
      debugPrint('$stack');
      if (mounted) {
        setState(() {
          rewardedLoading = false;
          rewardedMessage = 'Ad error: $error';
        });
      }
    }
  }

  Future<void> watchRewarded() async {
    if (kIsWeb || rewardedShowing) return;

    final RewardedAd? ad = rewardedAd;
    if (ad == null) {
      await loadRewarded();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ad is not ready. Please wait and try again.'),
          ),
        );
      }
      return;
    }

    rewardedAd = null;
    setState(() {
      rewardedShowing = true;
      rewardedMessage = 'Showing ad...';
    });

    bool earned = false;

    ad.setAdEventListener(
      eventListener: RewardedAdEventListener(
        onAdShown: () => debugPrint('REWARDED SHOWN'),
        onAdClicked: () => debugPrint('REWARDED CLICKED'),
        onAdImpression: (data) => debugPrint('REWARDED IMPRESSION: $data'),
        onAdFailedToShow: (error) =>
            debugPrint('REWARDED SHOW ERROR: ${error.description}'),
        onAdDismissed: () => debugPrint('REWARDED DISMISSED'),
        onRewarded: (reward) {
          earned = true;
          debugPrint('REWARD: ${reward.amount} ${reward.type}');
        },
      ),
    );

    try {
      await ad.show();
      final dynamic reward = await ad.waitForDismiss();
      if (reward != null) earned = true;

      if (mounted && earned && gameOver) {
        revive();
      }
    } catch (error, stack) {
      debugPrint('REWARDED SHOW EXCEPTION: $error');
      debugPrint('$stack');
    } finally {
      ad.destroy();
      if (mounted) {
        setState(() {
          rewardedShowing = false;
          rewardedMessage = 'Preparing next ad...';
        });
        loadRewarded();
      }
    }
  }

  // ---------------- INTERSTITIAL ----------------

  Future<void> loadInterstitial() async {
    if (kIsWeb || interstitialLoading || interstitialAd != null) return;

    interstitialLoading = true;
    debugPrint('YANDEX INTERSTITIAL REQUEST');

    try {
      final InterstitialAd ad = await interstitialLoader
          .loadAd(adRequest: const AdRequest(adUnitId: interstitialId))
          .timeout(const Duration(seconds: 30));

      if (!mounted) {
        ad.destroy();
        return;
      }

      interstitialAd = ad;
      debugPrint('YANDEX INTERSTITIAL LOADED');
    } on TimeoutException {
      debugPrint('YANDEX INTERSTITIAL TIMEOUT');
    } on AdRequestError catch (error) {
      debugPrint('YANDEX INTERSTITIAL ERROR: ${error.description}');
    } catch (error, stack) {
      debugPrint('YANDEX INTERSTITIAL EXCEPTION: $error');
      debugPrint('$stack');
    } finally {
      interstitialLoading = false;
    }
  }

  Future<void> showInterstitial() async {
    if (kIsWeb) return;

    final InterstitialAd? ad = interstitialAd;
    if (ad == null) {
      loadInterstitial();
      return;
    }

    interstitialAd = null;

    ad.setAdEventListener(
      eventListener: InterstitialAdEventListener(
        onAdShown: () => debugPrint('INTERSTITIAL SHOWN'),
        onAdClicked: () => debugPrint('INTERSTITIAL CLICKED'),
        onAdImpression: (data) => debugPrint('INTERSTITIAL IMPRESSION: $data'),
        onAdFailedToShow: (error) =>
            debugPrint('INTERSTITIAL SHOW ERROR: ${error.description}'),
        onAdDismissed: () => debugPrint('INTERSTITIAL DISMISSED'),
      ),
    );

    try {
      await ad.show();
      await ad.waitForDismiss();
    } catch (error, stack) {
      debugPrint('INTERSTITIAL SHOW EXCEPTION: $error');
      debugPrint('$stack');
    } finally {
      ad.destroy();
      if (mounted) loadInterstitial();
    }
  }

  // ---------------- SPONSOR ----------------

  Future<void> openSponsorLink() async {
    if (started && !paused && !gameOver) {
      timer?.cancel();
      setState(() => paused = true);
    }

    try {
      final bool opened = await launchUrl(
        sponsorUri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open sponsor link.')),
        );
      }
    } catch (error) {
      debugPrint('SPONSOR ERROR: $error');
    }
  }

  // ---------------- GAME LOGIC ----------------

  Point<int> createFood() {
    Point<int> position;
    do {
      position = Point(random.nextInt(cols), random.nextInt(rows));
    } while (snake.contains(position));
    return position;
  }

  void resetGame() {
    timer?.cancel();
    snake = [
      const Point(5, 10),
      const Point(4, 10),
      const Point(3, 10),
    ];
    food = createFood();
    direction = Direction.right;
    nextDirection = Direction.right;
    score = 0;
    started = false;
    paused = false;
    gameOver = false;
    if (mounted) setState(() {});
  }

  void startGame() {
    if (gameOver) resetGame();
    if (started && !paused) return;
    setState(() {
      started = true;
      paused = false;
    });
    startTimer();
  }

  void startTimer() {
    timer?.cancel();
    timer = Timer.periodic(
      Duration(milliseconds: max(75, 175 - score * 2)),
      (_) => moveSnake(),
    );
  }

  void togglePause() {
    if (!started || gameOver) return;
    setState(() => paused = !paused);
    timer?.cancel();
    if (!paused) startTimer();
  }

  void changeDirection(Direction newDirection) {
    final bool reverse =
        (direction == Direction.up && newDirection == Direction.down) ||
        (direction == Direction.down && newDirection == Direction.up) ||
        (direction == Direction.left && newDirection == Direction.right) ||
        (direction == Direction.right && newDirection == Direction.left);

    if (!reverse) nextDirection = newDirection;
  }

  void moveSnake() {
    if (!mounted || paused || gameOver || !started) return;

    direction = nextDirection;
    final Point<int> head = snake.first;

    final Point<int> next = switch (direction) {
      Direction.up => Point(head.x, head.y - 1),
      Direction.down => Point(head.x, head.y + 1),
      Direction.left => Point(head.x - 1, head.y),
      Direction.right => Point(head.x + 1, head.y),
    };

    final bool eating = next == food;
    final List<Point<int>> body =
        eating ? snake : snake.sublist(0, snake.length - 1);

    final bool collision = next.x < 0 ||
        next.x >= cols ||
        next.y < 0 ||
        next.y >= rows ||
        body.contains(next);

    if (collision) {
      timer?.cancel();
      setState(() {
        gameOver = true;
        started = false;
        bestScore = max(bestScore, score);
        finishedGames++;
      });
      if (finishedGames % 3 == 0) showInterstitial();
      return;
    }

    setState(() {
      snake.insert(0, next);
      if (eating) {
        score++;
        bestScore = max(bestScore, score);
        food = createFood();
      } else {
        snake.removeLast();
      }
    });
  }

  void revive() {
    if (!mounted || !gameOver) return;
    timer?.cancel();
    snake = [
      const Point(5, 10),
      const Point(4, 10),
      const Point(3, 10),
    ];
    food = createFood();
    direction = Direction.right;
    nextDirection = Direction.right;
    setState(() {
      gameOver = false;
      started = true;
      paused = false;
    });
    startTimer();
  }

  void handleSwipe(DragUpdateDetails details) {
    if (details.delta.distance < 2) return;
    if (details.delta.dx.abs() > details.delta.dy.abs()) {
      changeDirection(
        details.delta.dx > 0 ? Direction.right : Direction.left,
      );
    } else {
      changeDirection(
        details.delta.dy > 0 ? Direction.down : Direction.up,
      );
    }
  }

  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final LogicalKeyboardKey key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
      changeDirection(Direction.up);
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.keyS) {
      changeDirection(Direction.down);
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.keyA) {
      changeDirection(Direction.left);
    } else if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      changeDirection(Direction.right);
    } else if (key == LogicalKeyboardKey.space) {
      if (!started || paused || gameOver) {
        startGame();
      } else {
        togglePause();
      }
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ---------------- WIDGETS ----------------

  Widget directionButton(IconData icon, Direction newDirection) {
    return SizedBox(
      width: 62,
      height: 50,
      child: FilledButton.tonal(
        onPressed: () => changeDirection(newDirection),
        child: Icon(icon, size: 27),
      ),
    );
  }

  Widget scoreCard(String title, int value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(title, style: const TextStyle(color: Colors.white54)),
            Text(
              '$value',
              style: const TextStyle(
                color: green,
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget gameOverlay() {
    if (started && !paused && !gameOver) return const SizedBox.shrink();

    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Container(
        width: 235,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xF9071718),
          border: Border.all(color: green),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              gameOver
                  ? 'GAME OVER'
                  : paused
                      ? 'PAUSED'
                      : 'READY?',
              style: const TextStyle(
                color: green,
                fontSize: 27,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              gameOver ? 'Your score: $score' : 'Swipe to control the snake',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (gameOver) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: rewardedAd != null && !rewardedShowing
                      ? watchRewarded
                      : rewardedLoading
                          ? null
                          : loadRewarded,
                  icon: const Icon(Icons.play_circle_fill),
                  label: Text(
                    rewardedAd != null
                        ? 'WATCH AD TO REVIVE'
                        : rewardedLoading
                            ? 'LOADING REWARDED AD...'
                            : 'RETRY REWARDED AD',
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                rewardedMessage,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 9,
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: startGame,
                child: Text(
                  gameOver
                      ? 'PLAY AGAIN'
                      : paused
                          ? 'RESUME'
                          : 'START GAME',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Focus(
        autofocus: true,
        onKeyEvent: handleKeyEvent,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 9),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      width: 38,
                      height: 38,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'SNAKE MASTER',
                    style: TextStyle(
                      color: green,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              const Text(
                'EAT • GROW • SURVIVE',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    scoreCard('SCORE', score),
                    const SizedBox(width: 10),
                    scoreCard('BEST', bestScore),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: cols / rows,
                    child: GestureDetector(
                      onPanUpdate: handleSwipe,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D2028),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: green, width: 1.5),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CustomPaint(
                              painter: SnakePainter(
                                snake: snake,
                                food: food,
                                cols: cols,
                                rows: rows,
                              ),
                            ),
                            gameOverlay(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              directionButton(Icons.arrow_upward, Direction.up),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  directionButton(Icons.arrow_back, Direction.left),
                  const SizedBox(width: 12),
                  directionButton(Icons.arrow_downward, Direction.down),
                  const SizedBox(width: 12),
                  directionButton(Icons.arrow_forward, Direction.right),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: togglePause,
                      icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                      label: Text(paused ? 'RESUME' : 'PAUSE'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: resetGame,
                      icon: const Icon(Icons.refresh),
                      label: const Text('NEW GAME'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: openSponsorLink,
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text('VISIT SPONSOR'),
                  ),
                ),
              ),
              bannerPlacement(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    bannerTimer?.cancel();
    bannerStateSubscription?.cancel();
    bannerEventSubscription?.cancel();
    bannerAd?.destroy();
    rewardedAd?.destroy();
    interstitialAd?.destroy();
    super.dispose();
  }
}

class SnakePainter extends CustomPainter {
  final List<Point<int>> snake;
  final Point<int> food;
  final int cols;
  final int rows;

  SnakePainter({
    required this.snake,
    required this.food,
    required this.cols,
    required this.rows,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cellW = size.width / cols;
    final double cellH = size.height / rows;

    final Paint grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 0.5;

    for (int x = 0; x <= cols; x++) {
      canvas.drawLine(
        Offset(x * cellW, 0),
        Offset(x * cellW, size.height),
        grid,
      );
    }

    for (int y = 0; y <= rows; y++) {
      canvas.drawLine(
        Offset(0, y * cellH),
        Offset(size.width, y * cellH),
        grid,
      );
    }

    canvas.drawCircle(
      Offset((food.x + 0.5) * cellW, (food.y + 0.5) * cellH),
      min(cellW, cellH) * 0.38,
      Paint()..color = Colors.redAccent,
    );

    for (int i = 0; i < snake.length; i++) {
      final Point<int> point = snake[i];
      final Rect rect = Rect.fromLTWH(
        point.x * cellW + 1,
        point.y * cellH + 1,
        cellW - 2,
        cellH - 2,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()
          ..color = i == 0 ? green : const Color(0xFF00A878),
      );
    }
  }

  @override
  bool shouldRepaint(covariant SnakePainter oldDelegate) => true;
}
