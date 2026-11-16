
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await YandexAds.initialize();
    debugPrint('Yandex Ads initialized');
  } catch (e) {
    debugPrint('Yandex initialization error: $e');
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

  // Yandex ad unit IDs
  static const String bannerId = 'R-M-20409416-2';
  static const String rewardedId = 'R-M-20409416-1';
  static const String interstitialId = 'R-M-20409416-3';

  static final Uri sponsorUri = Uri.parse(
    'https://auctionr.org/4/734126bad0bd8538a4233f18e7855d55',
  );

  final Random random = Random();

  final InterstitialAdLoader interstitialLoader =
      InterstitialAdLoader();

  final RewardedAdLoader rewardedLoader =
      RewardedAdLoader();

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

  BannerAd? bannerAd;
  InterstitialAd? interstitialAd;
  RewardedAd? rewardedAd;

  bool bannerReady = false;
  bool bannerRequested = false;
  bool interstitialLoading = false;
  bool rewardedLoading = false;
  bool rewardedShowing = false;

  StreamSubscription? bannerStateSubscription;
  StreamSubscription? bannerEventSubscription;

  @override
  void initState() {
    super.initState();
    resetGame();
    loadInterstitial();
    loadRewarded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!bannerRequested) {
      bannerRequested = true;
      loadBanner();
    }
  }

  // -----------------------------
  // YANDEX BANNER AD
  // -----------------------------

  void loadBanner() {
    if (bannerAd != null) return;

    try {
      final width = MediaQuery.of(context).size.width.round();

      final banner = BannerAd(
        adSize: BannerAdSize.sticky(width: width),
      );

      bannerStateSubscription =
          banner.loadStateStream.listen((state) {
        if (!mounted) return;

        if (state is BannerAdLoadStateLoaded) {
          debugPrint('Banner loaded');
          setState(() {
            bannerReady = true;
          });
        } else if (state is BannerAdLoadStateError) {
          debugPrint('Banner error: ${state.error.description}');
          setState(() {
            bannerReady = false;
          });
        }
      });

      bannerEventSubscription = banner.events.listen((event) {
        if (event is BannerAdClickedEvent) {
          debugPrint('Banner clicked');
        }

        if (event is BannerAdImpressionEvent) {
          debugPrint('Banner impression');
        }
      });

      bannerAd = banner;

      banner.load(
        const AdRequest(adUnitId: bannerId),
      );

      setState(() {});
    } catch (e) {
      debugPrint('Banner initialization error: $e');
    }
  }

  Widget bannerPlacement() {
    return Container(
      width: double.infinity,
      height: 65,
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF10262E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: bannerAd != null && bannerReady
          ? AdWidget(bannerAd: bannerAd!)
          : const Text(
              'Advertisement',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
    );
  }

  // -----------------------------
  // YANDEX INTERSTITIAL AD
  // -----------------------------

  Future<void> loadInterstitial() async {
    if (interstitialLoading || interstitialAd != null) {
      return;
    }

    interstitialLoading = true;

    try {
      final ad = await interstitialLoader.loadAd(
        adRequest: const AdRequest(
          adUnitId: interstitialId,
        ),
      );

      if (!mounted) {
        ad.destroy();
        return;
      }

      interstitialAd = ad;
      debugPrint('Interstitial loaded');
    } on AdRequestError catch (e) {
      debugPrint('Interstitial loading error: ${e.description}');
    } catch (e) {
      debugPrint('Interstitial error: $e');
    } finally {
      interstitialLoading = false;
    }
  }

  Future<void> showInterstitial() async {
    final ad = interstitialAd;

    if (ad == null) {
      loadInterstitial();
      return;
    }

    interstitialAd = null;

    ad.setAdEventListener(
      eventListener: InterstitialAdEventListener(
        onAdShown: () {
          debugPrint('Interstitial shown');
        },
        onAdClicked: () {
          debugPrint('Interstitial clicked');
        },
        onAdImpression: (data) {
          debugPrint('Interstitial impression: $data');
        },
        onAdFailedToShow: (error) {
          debugPrint('Interstitial show error: ${error.description}');
        },
        onAdDismissed: () {
          debugPrint('Interstitial dismissed');
        },
      ),
    );

    try {
      await ad.show();
      await ad.waitForDismiss();
    } catch (e) {
      debugPrint('Interstitial error: $e');
    } finally {
      ad.destroy();

      if (mounted) {
        loadInterstitial();
      }
    }
  }

  // -----------------------------
  // YANDEX REWARDED AD
  // -----------------------------

  Future<void> loadRewarded() async {
    if (rewardedLoading ||
        rewardedAd != null ||
        rewardedShowing) {
      return;
    }

    rewardedLoading = true;

    try {
      final ad = await rewardedLoader.loadAd(
        adRequest: const AdRequest(
          adUnitId: rewardedId,
        ),
      );

      if (!mounted) {
        ad.destroy();
        return;
      }

      rewardedAd = ad;
      debugPrint('Rewarded ad loaded');

      setState(() {});
    } on AdRequestError catch (e) {
      debugPrint('Rewarded loading error: ${e.description}');
    } catch (e) {
      debugPrint('Rewarded error: $e');
    } finally {
      rewardedLoading = false;

      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> watchRewarded() async {
    final ad = rewardedAd;

    if (ad == null || rewardedShowing) {
      loadRewarded();
      return;
    }

    rewardedAd = null;

    setState(() {
      rewardedShowing = true;
    });

    ad.setAdEventListener(
      eventListener: RewardedAdEventListener(
        onAdShown: () {
          debugPrint('Rewarded ad shown');
        },
        onAdClicked: () {
          debugPrint('Rewarded ad clicked');
        },
        onAdImpression: (data) {
          debugPrint('Rewarded impression: $data');
        },
        onAdFailedToShow: (error) {
          debugPrint('Rewarded show error: ${error.description}');
        },
        onAdDismissed: () {
          debugPrint('Rewarded ad dismissed');
        },
        onRewarded: (reward) {
          debugPrint(
            'Reward received: ${reward.amount} ${reward.type}',
          );
        },
      ),
    );

    try {
      await ad.show();

      final reward = await ad.waitForDismiss();

      if (reward != null) {
        debugPrint('Reward confirmed');

        if (mounted && gameOver) {
          revive();
        }
      }
    } catch (e) {
      debugPrint('Rewarded error: $e');
    } finally {
      ad.destroy();

      if (mounted) {
        setState(() {
          rewardedShowing = false;
        });

        loadRewarded();
      }
    }
  }

  // -----------------------------
  // SPONSOR LINK
  // -----------------------------

  Future<void> openSponsorLink() async {
    if (started && !paused && !gameOver) {
      timer?.cancel();

      setState(() {
        paused = true;
      });
    }

    try {
      final opened = await launchUrl(
        sponsorUri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open sponsor link.'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Sponsor link error: $e');
    }
  }

  // -----------------------------
  // GAME LOGIC
  // -----------------------------

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
      Duration(
        milliseconds: max(75, 175 - score * 2),
      ),
      (_) => moveSnake(),
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

  // -----------------------------
  // GAME CONTROLS
  // -----------------------------

  Widget directionButton(
    IconData icon,
    Direction newDirection,
  ) {
    return SizedBox(
      width: 56,
      height: 46,
      child: FilledButton.tonal(
        onPressed: () => changeDirection(newDirection),
        child: Icon(icon, size: 26),
      ),
    );
  }

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
              style: const TextStyle(
                color: Colors.white54,
              ),
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
                  onPressed:
                      rewardedAd != null && !rewardedShowing
                          ? watchRewarded
                          : null,
                  icon: const Icon(Icons.play_circle_fill),
                  label: Text(
                    rewardedAd != null
                        ? 'WATCH AD TO REVIVE'
                        : rewardedLoading
                            ? 'LOADING REWARDED AD...'
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

  // -----------------------------
  // MAIN GAME SCREEN
  // -----------------------------

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
                directionButton(
                  Icons.arrow_upward,
                  Direction.up,
                ),
              ],
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                directionButton(
                  Icons.arrow_back,
                  Direction.left,
                ),
                const SizedBox(width: 12),
                directionButton(
                  Icons.arrow_downward,
                  Direction.down,
                ),
                const SizedBox(width: 12),
                directionButton(
                  Icons.arrow_forward,
                  Direction.right,
                ),
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
                    icon: Icon(
                      paused ? Icons.play_arrow : Icons.pause,
                    ),
                    label: Text(
                      
                      paused ? 'RESUME' : 'PAUSE',
                    ),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
              ),
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
    );
  }

  // -----------------------------
  // CLEANUP
  // -----------------------------

  @override
  void dispose() {
    timer?.cancel();

    bannerStateSubscription?.cancel();
    bannerEventSubscription?.cancel();

    bannerAd?.destroy();
    interstitialAd?.destroy();
    rewardedAd?.destroy();

    super.dispose();
  }
}

// -----------------------------
// SNAKE GAME GRAPHICS
// -----------------------------

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
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 0.5;

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
      ..color = Colors.redAccent;

    canvas.drawCircle(
      Offset(
        (food.x + 0.5) * cellWidth,
        (food.y + 0.5) * cellHeight,
      ),
      min(cellWidth, cellHeight) * 0.38,
      foodPaint,
    );

    for (int i = 0; i < snake.length; i++) {
      final part = snake[i];

      final rect = Rect.fromLTWH(
        part.x * cellWidth + 1,
        part.y * cellHeight + 1,
        cellWidth - 2,
        cellHeight - 2,
      );

      final snakePaint = Paint()
        ..color = i == 0
            ? const Color(0xFF00E6A0)
            : const Color(0xFF00A878);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect,
          const Radius.circular(4),
        ),
        snakePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SnakePainter oldDelegate) {
    return true;
  }
}

