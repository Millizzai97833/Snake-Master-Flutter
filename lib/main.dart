
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:startapp_sdk/startapp.dart'
    show
        StartAppSdk,
        StartAppBannerAd,
        StartAppBanner,
        StartAppBannerType,
        StartAppInterstitialAd,
        StartAppNativeAd,
        StartAppNative,
        StartAppRewardedVideoAd;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SnakeMasterApp());
}

class SnakeMasterApp extends StatelessWidget {
  const SnakeMasterApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Snake Master',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF07131A),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF00D68F),
            brightness: Brightness.dark,
          ),
        ),
        home: const SnakeGamePage(),
      );
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
  final StartAppSdk startAppSdk = StartAppSdk();

  Timer? timer;
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
  bool adsReady = false;

  StartAppBannerAd? bannerAd;
  StartAppInterstitialAd? interstitialAd;
  StartAppNativeAd? nativeAd;
  StartAppRewardedVideoAd? rewardedAd;

  bool bannerLoading = false;
  bool interstitialLoading = false;
  bool nativeLoading = false;
  bool rewardedLoading = false;
  bool rewardedShowing = false;
  bool rewardedCompleted = false;

  @override
  void initState() {
    super.initState();
    resetGame();
    initializeAds();
  }

  Future<void> initializeAds() async {
    try {
      await startAppSdk.setTestAdsEnabled(kDebugMode);
      if (!mounted) return;

      setState(() => adsReady = true);

      loadBanner();
      loadInterstitial();
      loadNative();
      loadRewarded();
    } catch (e) {
      debugPrint('Start.io initialization error: $e');
    }
  }

  // BANNER AD
  Future<void> loadBanner() async {
    if (!adsReady || bannerLoading || bannerAd != null) return;

    setState(() => bannerLoading = true);

    try {
      final ad = await startAppSdk.loadBannerAd(
        StartAppBannerType.BANNER,
        onAdImpression: () => debugPrint('Banner impression'),
        onAdClicked: () => debugPrint('Banner clicked'),
      );

      if (!mounted) {
        ad.dispose();
        return;
      }

      setState(() {
        bannerAd = ad;
        bannerLoading = false;
      });
    } catch (e) {
      debugPrint('Banner load error: $e');
      if (mounted) setState(() => bannerLoading = false);
    }
  }

  Widget bannerPlacement() => Container(
        height: 60,
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(10, 5, 10, 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF10262E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: bannerAd != null
            ? StartAppBanner(bannerAd!)
            : Text(
                bannerLoading ? 'Loading banner ad…' : 'Advertisement',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
      );

  // INTERSTITIAL AD
  Future<void> loadInterstitial() async {
    if (!adsReady || interstitialLoading || interstitialAd != null) {
      return;
    }

    setState(() => interstitialLoading = true);

    try {
      final ad = await startAppSdk.loadInterstitialAd(
        onAdDisplayed: () => debugPrint('Interstitial displayed'),
        onAdImpression: () => debugPrint('Interstitial impression'),
        onAdClicked: () => debugPrint('Interstitial clicked'),
        onAdNotDisplayed: () {
          final old = interstitialAd;
          interstitialAd = null;
          old?.dispose();

          if (mounted) {
            setState(() => interstitialLoading = false);
            loadInterstitial();
          }
        },
        onAdHidden: () {
          final old = interstitialAd;
          interstitialAd = null;
          old?.dispose();

          if (mounted) {
            setState(() => interstitialLoading = false);
            loadInterstitial();
          }
        },
      );

      if (!mounted) {
        ad.dispose();
        return;
      }

      setState(() {
        interstitialAd = ad;
        interstitialLoading = false;
      });
    } catch (e) {
      debugPrint('Interstitial load error: $e');
      if (mounted) setState(() => interstitialLoading = false);
    }
  }

  Future<void> showInterstitial() async {
    final ad = interstitialAd;

    if (ad == null) {
      loadInterstitial();
      return;
    }

    interstitialAd = null;

    try {
      await ad.show();
    } catch (e) {
      debugPrint('Interstitial show error: $e');
    } finally {
      ad.dispose();
      if (mounted) loadInterstitial();
    }
  }

  // NATIVE AD
  Future<void> loadNative() async {
    if (!adsReady || nativeLoading || nativeAd != null) return;

    setState(() => nativeLoading = true);

    try {
      final ad = await startAppSdk.loadNativeAd(
        onAdImpression: () => debugPrint('Native impression'),
        onAdClicked: () => debugPrint('Native clicked'),
      );

      if (!mounted) {
        ad.dispose();
        return;
      }

      setState(() {
        nativeAd = ad;
        nativeLoading = false;
      });
    } catch (e) {
      debugPrint('Native load error: $e');
      if (mounted) setState(() => nativeLoading = false);
    }
  }

  Widget nativePlacement() {
    final ad = nativeAd;

    if (ad == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 7),
      child: StartAppNative(
        ad,
        (context, updateNativeState, native) => Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF142B33),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF31515A),
            ),
          ),
          child: Row(
            children: [
              if (native.imageUrl != null &&
                  native.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    native.imageUrl!,
                    width: 58,
                    height: 58,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      width: 58,
                      height: 58,
                      child: Icon(
                        Icons.apps,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'SPONSORED',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      native.title ?? 'Sponsored recommendation',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (native.description != null)
                      Text(
                        native.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    if (native.callToAction != null)
                      Text(
                        native.callToAction!,
                        style: const TextStyle(
                          color: Color(0xFF00E6A0),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        width: double.infinity,
        height: 90,
      ),
    );
  }

  // REWARDED VIDEO AD
  Future<void> loadRewarded() async {
    if (!adsReady ||
        rewardedLoading ||
        rewardedAd != null ||
        rewardedShowing) {
      return;
    }

    setState(() => rewardedLoading = true);

    try {
      final ad = await startAppSdk.loadRewardedVideoAd(
        onAdDisplayed: () => debugPrint('Rewarded video displayed'),
        onAdImpression: () => debugPrint('Rewarded video impression'),
        onAdClicked: () => debugPrint('Rewarded video clicked'),
        onVideoCompleted: () {
          debugPrint('Rewarded video completed');
          rewardedCompleted = true;
        },
        onAdHidden: () {
          final old = rewardedAd;
          rewardedAd = null;
          old?.dispose();

          if (!mounted) return;

          setState(() => rewardedShowing = false);

          if (rewardedCompleted) {
            rewardedCompleted = false;
            revive();
          }

          loadRewarded();
        },
        onAdNotDisplayed: () {
          final old = rewardedAd;
          rewardedAd = null;
          old?.dispose();

          if (mounted) {
            setState(() => rewardedShowing = false);
            loadRewarded();
          }
        },
      );

      if (!mounted) {
        ad.dispose();
        return;
      }

      setState(() {
        rewardedAd = ad;
        rewardedLoading = false;
      });
    } catch (e) {
      debugPrint('Rewarded load error: $e');
      if (mounted) setState(() => rewardedLoading = false);
    }
  }

  Future<void> watchRewarded() async {
    final ad = rewardedAd;

    if (ad == null || rewardedShowing) return;

    rewardedCompleted = false;
    setState(() => rewardedShowing = true);

    try {
      final shown = await ad.show();

      if (!shown && mounted) {
        setState(() => rewardedShowing = false);

        if (identical(rewardedAd, ad)) {
          rewardedAd = null;
          ad.dispose();
        }

        loadRewarded();
      }
    } catch (e) {
      debugPrint('Rewarded show error: $e');

      if (mounted) {
        setState(() => rewardedShowing = false);
      }

      if (identical(rewardedAd, ad)) {
        rewardedAd = null;
        ad.dispose();
      }

      loadRewarded();
    }
  }

  // REVIVE SNAKE AFTER REWARDED VIDEO
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

  Point<int> createFood() {
    Point<int> p;

    do {
      p = Point(
        random.nextInt(cols),
        random.nextInt(rows),
      );
    } while (snake.contains(p));

    return p;
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

  void changeDirection(Direction d) {
    final reverse =
        (direction == Direction.up && d == Direction.down) ||
        (direction == Direction.down && d == Direction.up) ||
        (direction == Direction.left && d == Direction.right) ||
        (direction == Direction.right && d == Direction.left);

    if (!reverse) nextDirection = d;
  }

  void moveSnake() {
    if (!mounted || paused || gameOver || !started) return;

    direction = nextDirection;

    final h = snake.first;

    final Point<int> next = switch (direction) {
      Direction.up => Point(h.x, h.y - 1),
      Direction.down => Point(h.x, h.y + 1),
      Direction.left => Point(h.x - 1, h.y),
      Direction.right => Point(h.x + 1, h.y),
    };

    final eating = next == food;

    final body = eating
        ? snake
        : snake.sublist(0, snake.length - 1);

    final hit = next.x < 0 ||
        next.x >= cols ||
        next.y < 0 ||
        next.y >= rows ||
        body.contains(next);

    if (hit) {
      timer?.cancel();

      setState(() {
        gameOver = true;
        started = false;
        bestScore = max(bestScore, score);
        finishedGames++;
      });

      if (finishedGames % 3 == 0) {
        showInterstitial();
      }

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

  void handleSwipe(DragUpdateDetails d) {
    if (d.delta.distance < 2) return;

    if (d.delta.dx.abs() > d.delta.dy.abs()) {
      changeDirection(
        d.delta.dx > 0 ? Direction.right : Direction.left,
      );
    } else {
      changeDirection(
        d.delta.dy > 0 ? Direction.down : Direction.up,
      );
    }
  }

  Widget scoreCard(String title, int value) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF10262E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white54),
              ),
              Text(
                '$value',
                style: const TextStyle(
                  color: Color(0xFF00E6A0),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );

  Widget directionButton(IconData icon, Direction d) => SizedBox(
        width: 56,
        height: 46,
        child: FilledButton.tonal(
          onPressed: () => changeDirection(d),
          child: Icon(icon, size: 26),
        ),
      );

  Widget gameOverlay() {
    if (started && !paused && !gameOver) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                color: Color(0xFF00E6A0),
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              gameOver
                  ? 'Your score: $score'
                  : 'Swipe to control the snake',
            ),
            const SizedBox(height: 12),
            if (gameOver) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: rewardedAd != null && !rewardedShowing
                      ? watchRewarded
                      : null,
                  icon: const Icon(Icons.play_circle_fill),
                  label: Text(
                    rewardedAd != null
                        ? 'WATCH AD TO REVIVE'
                        : rewardedLoading
                            ? 'LOADING REWARDED AD…'
                            : rewardedShowing
                                ? 'PLEASE WAIT…'
                                : 'REWARDED AD UNAVAILABLE',
                  ),
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
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 9),
              const Text(
                'SNAKE MASTER',
                style: TextStyle(
                  color: Color(0xFF00E6A0),
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
              const Text(
                'EAT • GROW • SURVIVE',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
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

              // NATIVE AD ABOVE THE GAME BOARD
              nativePlacement(),

              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: cols / rows,
                    child: GestureDetector(
                      onPanUpdate: handleSwipe,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 18,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D2028),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF1D4650),
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.cir
