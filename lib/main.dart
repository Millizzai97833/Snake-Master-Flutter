
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
        StartAppRewardedVideoAd;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SnakeMasterApp());
}

class SnakeMasterApp extends StatelessWidget {
  const SnakeMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snake Master',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF07131A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00D68F),
          brightness: Brightness.dark,
        ),
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
  final StartAppSdk startAppSdk = StartAppSdk();

  Timer? timer;

  StartAppBannerAd? bannerAd;
  StartAppRewardedVideoAd? rewardedAd;

  List<Point<int>> snake = [];
  Point<int> food = const Point(8, 12);

  Direction direction = Direction.right;
  Direction nextDirection = Direction.right;

  int score = 0;
  int bestScore = 0;

  bool started = false;
  bool paused = false;
  bool gameOver = false;

  bool adsInitialized = false;
  bool bannerLoading = false;
  bool bannerFailed = false;

  bool rewardedLoading = false;
  bool rewardedCompleted = false;
  bool rewardedUsed = false;
  bool rewardedShowing = false;

  @override
  void initState() {
    super.initState();
    resetGame();
    initializeAds();
  }

  // ---------------------------------------
  // START.IO INITIALIZATION
  // ---------------------------------------

  Future<void> initializeAds() async {
    try {
      // Debug builds use test ads.
      // Release builds use live ads.
      await startAppSdk.setTestAdsEnabled(kDebugMode);

      if (!mounted) return;

      adsInitialized = true;

      loadBanner();
      loadRewardedAd();
    } catch (e) {
      debugPrint('Start.io initialization error: $e');
    }
  }

  // ---------------------------------------
  // BANNER AD
  // ---------------------------------------

  Future<void> loadBanner() async {
    if (!mounted || bannerLoading || bannerAd != null) return;

    setState(() {
      bannerLoading = true;
      bannerFailed = false;
    });

    try {
      final ad = await startAppSdk.loadBannerAd(
        StartAppBannerType.BANNER,
        onAdImpression: () {
          debugPrint('Start.io banner impression.');
        },
        onAdClicked: () {
          debugPrint('Start.io banner clicked.');
        },
      );

      if (!mounted) {
        ad.dispose();
        return;
      }

      setState(() {
        bannerAd = ad;
        bannerLoading = false;
        bannerFailed = false;
      });
    } catch (e) {
      debugPrint('Banner loading error: $e');

      if (mounted) {
        setState(() {
          bannerLoading = false;
          bannerFailed = true;
        });
      }
    }
  }

  Widget buildBannerArea() {
    return Container(
      width: double.infinity,
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF10262E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: bannerAd != null
          ? Center(
              child: StartAppBanner(bannerAd!),
            )
          : bannerLoading
              ? const Text(
                  'Loading advertisement...',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.ads_click,
                      size: 17,
                      color: Colors.white54,
                    ),
                    const SizedBox(width: 7),
                    const Text(
                      'Advertisement',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                    if (bannerFailed)
                      TextButton(
                        onPressed: loadBanner,
                        child: const Text('RETRY'),
                      ),
                  ],
                ),
    );
  }

  // ---------------------------------------
  // REWARDED VIDEO AD
  // ---------------------------------------

  Future<void> loadRewardedAd() async {
    if (!mounted ||
        !adsInitialized ||
        rewardedLoading ||
        rewardedAd != null ||
        rewardedUsed) {
      return;
    }

    setState(() {
      rewardedLoading = true;
    });

    try {
      final ad = await startAppSdk.loadRewardedVideoAd(
        onAdDisplayed: () {
          debugPrint('Rewarded video displayed.');
        },
        onAdImpression: () {
          debugPrint('Rewarded video impression.');
        },
        onVideoCompleted: () {
          debugPrint('Rewarded video completed.');

          rewardedCompleted = true;
        },
        onAdHidden: () {
          debugPrint('Rewarded video closed.');

          final oldAd = rewardedAd;
          rewardedAd = null;
          oldAd?.dispose();

          if (!mounted) return;

          setState(() {
            rewardedShowing = false;
            rewardedLoading = false;
          });

          if (rewardedCompleted) {
            rewardedCompleted = false;
            continueAfterReward();
          } else {
            loadRewardedAd();
          }
        },
        onAdNotDisplayed: () {
          debugPrint('Rewarded video was not displayed.');

          final oldAd = rewardedAd;
          rewardedAd = null;
          oldAd?.dispose();

          if (!mounted) return;

          setState(() {
            rewardedShowing = false;
            rewardedLoading = false;
          });

          loadRewardedAd();
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

      debugPrint('Rewarded video ready.');
    } catch (e) {
      debugPrint('Rewarded ad loading error: $e');

      if (mounted) {
        setState(() {
          rewardedLoading = false;
        });
      }
    }
  }

  Future<void> watchRewardedAd() async {
    if (rewardedAd == null ||
        rewardedShowing ||
        rewardedUsed) {
      return;
    }

    rewardedCompleted = false;

    setState(() {
      rewardedShowing = true;
    });

    try {
      final shown = await rewardedAd!.show();

      if (!shown && mounted) {
        debugPrint('Rewarded video could not be shown.');

        setState(() {
          rewardedShowing = false;
        });

        final oldAd = rewardedAd;
        rewardedAd = null;
        oldAd?.dispose();

        loadRewardedAd();
      }
    } catch (e) {
      debugPrint('Rewarded video display error: $e');

      if (mounted) {
        setState(() {
          rewardedShowing = false;
        });
      }

      final oldAd = rewardedAd;
      rewardedAd = null;
      oldAd?.dispose();

      loadRewardedAd();
    }
  }

  // ---------------------------------------
  // REWARD: CONTINUE GAME
  // ---------------------------------------

  void continueAfterReward() {
    if (!mounted || !gameOver || rewardedUsed) return;

    timer?.cancel();

    snake = [
      const Point(5, 10),
      const Point(4, 10),
      const Point(3, 10),
    ];

    food = newFood();

    direction = Direction.right;
    nextDirection = Direction.right;

    rewardedUsed = true;

    setState(() {
      gameOver = false;
      started = true;
      paused = false;
      rewardedLoading = false;
    });

    startTimer();

    debugPrint('Player received one game revive.');
  }

  // ---------------------------------------
  // GAME LOGIC
  // ---------------------------------------

  Point<int> newFood() {
    Point<int> point;

    do {
      point = Point(
        random.nextInt(cols),
        random.nextInt(rows),
      );
    } while (snake.contains(point));

    return point;
  }

  void resetGame() {
    timer?.cancel();

    snake = [
      const Point(5, 10),
      const Point(4, 10),
      const Point(3, 10),
    ];

    food = newFood();

    direction = Direction.right;
    nextDirection = Direction.right;

    score = 0;

    started = false;
    paused = false;
    gameOver = false;

    rewardedUsed = false;
    rewardedCompleted = false;
    rewardedShowing = false;

    if (mounted) {
      setState(() {});
      loadRewardedAd();
    }
  }

  void startTimer() {
    timer?.cancel();

    timer = Timer.periodic(
      Duration(milliseconds: max(75, 175 - score * 2)),
      (_) => moveSnake(),
    );
  }

  void startGame() {
    if (gameOver) {
      resetGame();
    }

    if (started && !paused) return;

    setState(() {
      started = true;
      paused = false;
    });

    startTimer();
  }

  void togglePause() {
    if (!started || gameOver) return;

    setState(() {
      paused = !paused;
    });

    timer?.cancel();

    if (!paused) {
      startTimer();
    }
  }

  void changeDirection(Direction value) {
    final reverse =
        (direction == Direction.up && value == Direction.down) ||
        (direction == Direction.down && value == Direction.up) ||
        (direction == Direction.left && value == Direction.right) ||
        (direction == Direction.right && value == Direction.left);

    if (!reverse) {
      nextDirection = value;
    }
  }

  void moveSnake() {
    if (!mounted || paused || gameOver || !started) return;

    direction = nextDirection;

    final head = snake.first;

    final Point<int> next = switch (direction) {
      Direction.up => Point(head.x, head.y - 1),
      Direction.down => Point(head.x, head.y + 1),
      Direction.left => Point(head.x - 1, head.y),
      Direction.right => Point(head.x + 1, head.y),
    };

    final eating = next == food;

    final body = eating
        ? snake
        : snake.sublist(0, snake.length - 1);

    final collision =
        next.x < 0 ||
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
      });

      // No automatic interstitial here:
      // the player gets the option to watch a rewarded video.
      if (rewardedAd == null && !rewardedLoading) {
        loadRewardedAd();
      }

      return;
    }

    setState(() {
      snake.insert(0, next);

      if (eating) {
        score++;
        bestScore = max(bestScore, score);
        food = newFood();
      } else {
        snake.removeLast();
      }
    });
  }

  void handleSwipe(DragUpdateDetails details) {
    final delta = details.delta;

    if (delta.distance < 2) return;

    if (delta.dx.abs() > delta.dy.abs()) {
      changeDirection(
        delta.dx > 0 ? Direction.right : Direction.left,
      );
    } else {
      changeDirection(
        delta.dy > 0 ? Direction.down : Direction.up,
      );
    }
  }

  // ---------------------------------------
  // UI COMPONENTS
  // ---------------------------------------

  Widget directionButton(
    IconData icon,
    Direction value,
  ) {
    return SizedBox(
      width: 58,
      height: 52,
      child: FilledButton.tonal(
        onPressed: () => changeDirection(value),
        child: Icon(icon, size: 28),
      ),
    );
  }

  Widget scoreCard(String label, int value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF10262E),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                letterSpacing: 2,
              ),
            ),
            Text(
              '$value',
              style: const TextStyle(
                color: Color(0xFF00E6A0),
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
    if (started && !paused && !gameOver) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.black54,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
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
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00E6A0),
                ),
              ),

              const SizedBox(height: 10),

              Text(
                gameOver
                    ? 'Your score: $score'
                    : 'Swipe to control the snake',
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 14),

              // REWARDED VIDEO BUTTON
              if (gameOver && !rewardedUsed) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        rewardedAd != null && !rewardedShowing
                            ? watchRewardedAd
                            : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF087B58),
                      padding: const EdgeInsets.symmetric(
                        vertical: 13,
                      ),
                    ),
                    icon: const Icon(Icons.play_circle_fill),
                    label: Text(
                      rewardedShowing
                          ? 'PLEASE WAIT...'
                          : rewardedAd != null
                              ? 'WATCH AD TO CONTINUE'
                              : rewardedLoading
                                  ? 'LOADING REWARD VIDEO...'
                                  : 'REWARD AD UNAVAILABLE',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                if (rewardedAd == null &&
                    !rewardedLoading &&
                    !rewardedShowing)
                  TextButton.icon(
                    onPressed: loadRewardedAd,
                    icon: const Icon(Icons.refresh, size: 17),
                    label: const Text('RETRY REWARD AD'),
                  ),

                const SizedBox(height: 6),
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
      ),
    );
  }

  // ---------------------------------------
  // MAIN SCREEN
  // ---------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 15),

            const Text(
              'SNAKE MASTER',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                color: Color(0xFF00E6A0),
              ),
            ),

            const Text(
              'EAT • GROW • SURVIVE',
              style: TextStyle(color: Colors.white54),
            ),

            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  scoreCard('SCORE', score),
                  const SizedBox(width: 12),
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
                      margin: const EdgeInsets.symmetric(
                        horizontal: 18,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D2028),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFF1D4650),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
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
            ),

            const SizedBox(height: 12),

            directionButton(
              Icons.keyboard_arrow_up,
              Direction.up,
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                directionButton(
                  Icons.keyboard_arrow_left,
                  Direction.left,
                ),

                const SizedBox(width: 58),

                directionButton(
                  Icons.keyboard_arrow_right,
                  Direction.right,
                ),
              ],
            ),

            directionButton(
              Icons.keyboard_arrow_down,
              Direction.down,
            ),

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: togglePause,
                  icon: Icon(
                    paused ? Icons.play_arrow : Icons.pause,
                  ),
                  label: Text(
                    paused ? 'RESUME' : 'PAUSE',
                  ),
                ),

                const SizedBox(width: 12),

                OutlinedButton.icon(
                  onPressed: resetGame,
                  icon: const Icon(Icons.refresh),
