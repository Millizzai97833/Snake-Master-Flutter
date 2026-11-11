
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:startapp_sdk/startapp.dart';

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

  @override
  void initState() {
    super.initState();
    resetGame();
    initializeAds();
  }

  // START.IO INITIALIZATION

  Future<void> initializeAds() async {
    try {
      await startAppSdk.setTestAdsEnabled(kDebugMode);

      if (!mounted) return;

      setState(() {
        adsReady = true;
      });

      loadBanner();
      loadInterstitial();
      loadNative();
      loadRewarded();
    } catch (error) {
      debugPrint('Start.io initialization error: $error');
    }
  }

  // BANNER AD

  Future<void> loadBanner() async {
    if (!adsReady || bannerLoading || bannerAd != null) return;

    if (mounted) {
      setState(() => bannerLoading = true);
    }

    try {
      final ad = await startAppSdk.loadBannerAd(
        StartAppBannerType.BANNER,
        onAdImpression: () {
          debugPrint('Banner impression');
        },
        onAdClicked: () {
          debugPrint('Banner clicked');
        },
      );

      if (!mounted) {
        ad.dispose();
        return;
      }

      setState(() {
        bannerAd = ad;
        bannerLoading = false;
      });
    } catch (error) {
      debugPrint('Banner loading error: $error');

      if (mounted) {
        setState(() => bannerLoading = false);
      }
    }
  }

  Widget bannerPlacement() {
    return Container(
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
              bannerLoading
                  ? 'Loading advertisement...'
                  : 'Advertisement',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
    );
  }

  // INTERSTITIAL AD

  Future<void> loadInterstitial() async {
    if (!adsReady || interstitialLoading || interstitialAd != null) {
      return;
    }

    if (mounted) {
      setState(() => interstitialLoading = true);
    }

    try {
      final ad = await startAppSdk.loadInterstitialAd(
        onAdDisplayed: () {
          debugPrint('Interstitial displayed');
        },
        onAdImpression: () {
          debugPrint('Interstitial impression');
        },
        onAdClicked: () {
          debugPrint('Interstitial clicked');
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
    } catch (error) {
      debugPrint('Interstitial loading error: $error');

      if (mounted) {
        setState(() => interstitialLoading = false);
      }
    }
  }

  Future<void> showInterstitial() async {
    final ad = interstitialAd;

    if (ad == null) {
      loadInterstitial();
      return;
    }

    setState(() {
      interstitialAd = null;
    });

    try {
      await ad.show();
    } catch (error) {
      debugPrint('Interstitial display error: $error');
    } finally {
      ad.dispose();

      if (mounted) {
        loadInterstitial();
      }
    }
  }

  // NATIVE AD

  Future<void> loadNative() async {
    if (!adsReady || nativeLoading || nativeAd != null) return;

    if (mounted) {
      setState(() => nativeLoading = true);
    }

    try {
      final ad = await startAppSdk.loadNativeAd(
        onAdImpression: () {
          debugPrint('Native ad impression');
        },
        onAdClicked: () {
          debugPrint('Native ad clicked');
        },
      );

      if (!mounted) {
        ad.dispose();
        return;
      }

      setState(() {
        nativeAd = ad;
        nativeLoading = false;
      });
    } catch (error) {
      debugPrint('Native loading error: $error');

      if (mounted) {
        setState(() => nativeLoading = false);
      }
    }
  }

  Widget nativePlacement() {
    final ad = nativeAd;

    if (ad == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: StartAppNative(
        ad,
        (context, updateNativeState, native) {
          return Container(
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
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox(
                          width: 58,
                          height: 58,
                          child: Icon(
                            Icons.apps,
                            color: Colors.white54,
                          ),
                        );
                      },
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
          );
        },
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

    if (mounted) {
      setState(() => rewardedLoading = true);
    }

    try {
      bool videoCompleted = false;

      final ad = await startAppSdk.loadRewardedVideoAd(
        onAdDisplayed: () {
          debugPrint('Rewarded video displayed');
        },
        onAdImpression: () {
          debugPrint('Rewarded video impression');
        },
        onAdClicked: () {
          debugPrint('Rewarded video clicked');
        },
        onVideoCompleted: () {
          debugPrint('Rewarded video completed');
          videoCompleted = true;
        },
        onAdHidden: () {
          debugPrint('Rewarded video hidden');

          if (!mounted) return;

          setState(() {
            rewardedShowing = false;
          });

          if (videoCompleted && gameOver) {
            revive();
          }
        },
        onAdNotDisplayed: () {
          debugPrint('Rewarded video was not displayed');

          if (mounted) {
            setState(() {
              rewardedShowing = false;
            });
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
    } catch (error) {
      debugPrint('Rewarded loading error: $error');

      if (mounted) {
        setState(() => rewardedLoading = false);
      }
    }
  }

  Future<void> watchRewarded() async {
    final ad = rewardedAd;

    if (ad == null || rewardedShowing) return;

    setState(() {
      rewardedShowing = true;
      rewardedAd = null;
    });

    try {
      await ad.show();
    } catch (error) {
      debugPrint('Rewarded display error: $error');
    } finally {
      ad.dispose();

      if (mounted) {
        setState(() {
          rewardedShowing = false;
        });

        loadRewarded();
      }
    }
  }

  // REVIVE GAME

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

  // GAME LOGIC

  Point<int> createFood() {
    Point<int> position;

    do {
      position = Point(
        random.nextInt(cols),
        random.nextInt(rows),
      );
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

    if (mounted) {
      setState(() {});
    }
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

  void startTimer() {
    timer?.cancel();

    timer = Timer.periodic(
      Duration(milliseconds: max(75, 175 - score * 2)),
      (timer) {
        moveSnake();
      },
    );
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

  void changeDirection(Direction newDirection) {
    final reverse =
        (direction == Direction.up &&
            newDirection == Direction.down) ||
        (direction == Direction.down &&
            newDirection == Direction.up) ||
        (direction == Direction.left &&
            newDirection == Direction.right) ||
        (direction == Direction.right &&
            newDirection == Direction.left);

    if (!reverse) {
      nextDirection = newDirection;
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

    final bool eating = next == food;

    final body = eating
        ? snake
        : snake.sublist(0, snake.length - 1);

    final bool collision =
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

  void handleSwipe(DragUpdateDetails details) {
    if (details.delta.distance < 2) return;

    if (details.delta.dx.abs() > details.delta.dy.abs()) {
      changeDirection(
        details.delta.dx > 0
            ? Direction.right
            : Direction.left,
      );
    } else {
      changeDirection(
        details.delta.dy > 0
            ? Direction.down
            : Direction.up,
      );
    }
  }

  // GAME UI

  Widget scoreCard(String title, int value) {
    return Expanded(
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
  }

  Widget directionButton(IconData icon, Direction newDirection) {
    return SizedBox(
      width: 56,
      height: 46,
      child: FilledButton.tonal(
        onPressed: () => changeDirection(newDirection),
        child: Icon(icon, size: 26),
      ),
    );
  }

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
                            ? 'LOADING REWARDED AD...'
                            : rewardedShowing
                                ? 'PLEASE WAIT...'
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
  Widget build(BuildContext context) {
    return Scaffold(
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
                          color: const Color(0xFF00E6A0),
                          width: 1.5,
                        ),
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

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                directionButton(Icons.arrow_upward, Direction.up),
              ],
            ),

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
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: togglePause,
                      child: Text(paused ? 'RESUME' : 'PAUSE'),
                    ),
                  ),
                ],
              ),
            ),

            bannerPlacement(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    bannerAd?.dispose();
    interstitialAd?.dispose();
    nativeAd?.dispose();
    rewardedAd?.dispose();
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
    final cellWidth = size.width / cols;
    final cellHeight = size.height / rows;

    final gridPaint = Paint()
      ..color = const Color(0xFF19313A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.4;

    for (int x = 0; x <= cols; x++) {
      canvas.drawLine(
        Offset(x * cellWidth, 0),
        Offset(x * cellWidth, size.height),
        gridPaint,
      );
    }

    for (int y = 0; y <= rows; y++) {
      canvas.drawLine(
        Offset(0, y * cellHeight),
        Offset(size.width, y * cellHeight),
        gridPaint,
      );
    }

    final foodPaint = Paint()
      ..color = const Color(0xFFFF5252);

    canvas.drawCircle(
      Offset(
        (food.x + 0.5) * cellWidth,
        (food.y + 0.5) * cellHeight,
      ),
      cellWidth * 0.36,
      foodPaint,
    );

    for (int i = 0; i < snake.length; i++) {
      final segment = snake[i];

      final rect = Rect.fromLTWH(
        segment.x * cellWidth + 1,
        segment.y * cellHeight + 1,
        cellWidth - 2,
        cellHeight - 2,
      );

      final paint = Paint()
        ..color = i == 0
            ? const Color(0xFF00E6A0)
            : const Color(0xFF00A878);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect,
          Radius.circular(cellWidth * 0.2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SnakePainter oldDelegate) {
    return true;
  }
}

