
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show kDebugMode;
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
  StartAppInterstitialAd? interstitialAd;

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

  @override
  void initState() {
    super.initState();
    resetGame();
    initializeAds();
  }

  Future<void> initializeAds() async {
    try {
      // Test ads are enabled only in debug builds.
      // Release APKs use real ads.
      await startAppSdk.setTestAdsEnabled(kDebugMode);

      if (!mounted) return;

      adsInitialized = true;

      await Future.wait([
        loadBanner(),
        loadInterstitial(),
      ]);
    } catch (e) {
      debugPrint('Start.io initialization error: $e');
    }
  }

  Future<void> loadBanner() async {
    try {
      final ad = await startAppSdk.loadBannerAd(
        StartAppBannerType.BANNER,
      );

      if (!mounted) {
        ad.dispose();
        return;
      }

      setState(() {
        bannerAd?.dispose();
        bannerAd = ad;
      });
    } catch (e) {
      debugPrint('Banner loading error: $e');
    }
  }

  Future<void> loadInterstitial() async {
    if (!adsInitialized) return;

    try {
      final ad = await startAppSdk.loadInterstitialAd();

      if (!mounted) {
        ad.dispose();
        return;
      }

      interstitialAd?.dispose();
      interstitialAd = ad;
    } catch (e) {
      debugPrint('Interstitial loading error: $e');
    }
  }

  Future<void> showInterstitial() async {
    final ad = interstitialAd;

    if (ad == null) {
      debugPrint('Interstitial is not ready yet.');
      return;
    }

    interstitialAd = null;

    try {
      await ad.show();
    } catch (e) {
      debugPrint('Interstitial display error: $e');
    } finally {
      ad.dispose();

      if (mounted) {
        await loadInterstitial();
      }
    }
  }

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

    timer?.cancel();

    timer = Timer.periodic(
      Duration(milliseconds: max(75, 175 - score * 2)),
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
      timer = Timer.periodic(
        Duration(milliseconds: max(75, 175 - score * 2)),
        (_) => moveSnake(),
      );
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

    if (next.x < 0 ||
        next.x >= cols ||
        next.y < 0 ||
        next.y >= rows ||
        body.contains(next)) {
      timer?.cancel();

      setState(() {
        gameOver = true;
        started = false;
        bestScore = max(bestScore, score);
      });

      showInterstitial();
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
                      margin: const EdgeInsets.symmetric(horizontal: 18),
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
                            if (!started || paused || gameOver)
                              Container(
                                color: Colors.black54,
                                child: Center(
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
                                      ),
                                      const SizedBox(height: 15),
                                      FilledButton(
                                        onPressed: startGame,
                                        child: Text(
                                          gameOver
                                              ? 'PLAY AGAIN'
                                              : 'START GAME',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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
                  label: Text(paused ? 'RESUME' : 'PAUSE'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: resetGame,
                  icon: const Icon(Icons.refresh),
                  label: const Text('RESTART'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (bannerAd != null)
              SizedBox(
                height: 60,
                child: StartAppBanner(bannerAd!),
              )
            else
              const SizedBox(height: 60),
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
    super.dispose();
  }
}

class SnakePainter extends CustomPainter {
  SnakePainter({
    required this.snake,
    required this.food,
    required this.cols,
    required this.rows,
  });

  final List<Point<int>> snake;
  final Point<int> food;
  final int cols;
  final int rows;

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / cols;
    final cellH = size.height / rows;

    final gridPaint = Paint()
      ..color = const Color(0xFF18343B)
      ..strokeWidth = 0.5;

    for (int x = 1; x < cols; x++) {
      canvas.drawLine(
        Offset(x * cellW, 0),
        Offset(x * cellW, size.height),
        gridPaint,
      );
    }

    for (int y = 1; y < rows; y++) {
      canvas.drawLine(
        Offset(0, y * cellH),
        Offset(size.width, y * cellH),
        gridPaint,
      );
    }

    final foodPaint = Paint()
      ..color = const Color(0xFFFF5577);

    canvas.drawCircle(
      Offset(
        (food.x + 0.5) * cellW,
        (food.y + 0.5) * cellH,
      ),
      min(cellW, cellH) * 0.34,
      foodPaint,
    );

    for (int i = snake.length - 1; i >= 0; i--) {
      final part = snake[i];

      final rect = Rect.fromLTWH(
        part.x * cellW + 1.5,
        part.y * cellH + 1.5,
        cellW - 3,
        cellH - 3,
      );

      final paint = Paint()
        ..color = i == 0
            ? const Color(0xFF8CFFCB)
            : const Color(0xFF00B879);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect,
          const Radius.circular(5),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SnakePainter oldDelegate) => true;
}
Swipe to control the snake',
                                      ),
                                      const SizedBox(height: 15),
                                      FilledButton(
                                        onPressed: startGame,
                                        child: Text(
                                          gameOver
                                              ? 'PLAY AGAIN'
                                              : 'START GAME',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            directionButton(Icons.keyboard_arrow_up, Direction.up),
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
                  label: Text(paused ? 'RESUME' : 'PAUSE'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: resetGame,
                  icon: const Icon(Icons.refresh),
                  label: const Text('RESTART'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (bannerAd != null)
              SizedBox(
                height: 60,
                child: StartAppBanner(bannerAd!),
              )
            else
              const SizedBox(height: 60),
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
    super.dispose();
  }
}

class SnakePainter extends CustomPainter {
  SnakePainter({
    required this.snake,
    required this.food,
    required this.cols,
    required this.rows,
  });

  final List<Point<int>> snake;
  final Point<int> food;
  final int cols;
  final int rows;

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / cols;
    final cellH = size.height / rows;

    final gridPaint = Paint()
      ..color = const Color(0xFF18343B)
      ..strokeWidth = 0.5;

    for (int x = 1; x < cols; x++) {
      canvas.drawLine(
        Offset(x * cellW, 0),
        Offset(x * cellW, size.height),
        gridPaint,
      );
    }

    for (int y = 1; y < rows; y++) {
      canvas.drawLine(
        Offset(0, y * cellH),
        Offset(size.width, y * cellH),
        gridPaint,
      );
    }

    final foodPaint = Paint()
      ..color = const Color(0xFFFF5577);

    canvas.drawCircle(
      Offset(
        (food.x + 0.5) * cellW,
        (food.y + 0.5) * cellH,
      ),
      min(cellW, cellH) * 0.34,
      foodPaint,
    );

    for (int i = snake.length - 1; i >= 0; i--) {
      final part = snake[i];

      final rect = Rect.fromLTWH(
        part.x * cellW + 1.5,
        part.y * cellH + 1.5,
        cellW - 3,
        cellH - 3,
      );

      final paint = Paint()
        ..color = i == 0
            ? const Color(0xFF8CFFCB)
            : const Color(0xFF00B879);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect,
          const Radius.circular(5),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SnakePainter oldDelegate) => true;
}
