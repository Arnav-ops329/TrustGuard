import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const TrustGuardApp());
}

/* ================= APP ROOT ================= */

class TrustGuardApp extends StatefulWidget {
  const TrustGuardApp({super.key});

  @override
  State<TrustGuardApp> createState() => _TrustGuardAppState();
}

class _TrustGuardAppState extends State<TrustGuardApp> {
  bool darkMode = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrustGuard AI',
      debugShowCheckedModeBanner: false,
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: _lightTheme(),
      darkTheme: _darkTheme(),
      home: MainShell(
        darkMode: darkMode,
        onToggleTheme: () => setState(() => darkMode = !darkMode),
      ),
    );
  }
}

/* ================= THEMES ================= */

ThemeData _lightTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFF6FAFF),
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF4A90E2),
      secondary: Color(0xFF7DD3FC),
    ),
    cardColor: Colors.white,
  );
}

ThemeData _darkTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFF0B1220),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF38BDF8),
      secondary: Color(0xFF22D3EE),
    ),
    cardColor: const Color(0xFF111827),
  );
}

/* ================= MAIN SHELL ================= */

class MainShell extends StatefulWidget {
  final bool darkMode;
  final VoidCallback onToggleTheme;

  const MainShell(
      {super.key, required this.darkMode, required this.onToggleTheme});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  final List<String> history = [];

  @override
  Widget build(BuildContext context) {
    final pages = [
      ScanPage(
        darkMode: widget.darkMode,
        onToggleTheme: widget.onToggleTheme,
        onResult: (r) {
          history.insert(0, r);
          if (history.length > 10) history.removeLast();
        },
      ),
      HistoryPage(history: history),
      const AboutPage(),
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: "Scan"),
          NavigationDestination(icon: Icon(Icons.history), label: "History"),
          NavigationDestination(icon: Icon(Icons.info_outline), label: "About"),
        ],
      ),
    );
  }
}

/* ================= SCAN PAGE ================= */

class ScanPage extends StatefulWidget {
  final bool darkMode;
  final VoidCallback onToggleTheme;
  final Function(String) onResult;

  const ScanPage(
      {super.key,
      required this.darkMode,
      required this.onToggleTheme,
      required this.onResult});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController controller = TextEditingController();

  bool loading = false;
  bool hasResult = false;
  String resultText = "";
  double score = 0;
  Color statusColor = Colors.green;

  late AnimationController anim;
  late Animation<double> meter;

  @override
  void initState() {
    super.initState();
    anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    meter = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    anim.dispose();
    controller.dispose();
    super.dispose();
  }

  void clearAll() {
    anim.stop();
    anim.reset();
    setState(() {
      controller.text = "";
      loading = false;
      hasResult = false;
      score = 0;
      resultText = "";
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> check(String type) async {
    if (controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter some text")),
      );
      return;
    }

    if (controller.text.trim().length < 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter more meaningful text")),
      );
      return;
    }

    setState(() {
      loading = true;
      hasResult = false;
    });

    try {
      String text = controller.text.trim();
      if (text.length > 300) {
        text = text.substring(0, 300);
      }

      final url = type == "news"
          ? "http://127.0.0.1:8000/check-news"
          : "http://127.0.0.1:8000/check-scam";

      final res = await http
          .post(
            Uri.parse(url),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"text": text}),
          )
          .timeout(const Duration(seconds: 5));

      final data = jsonDecode(res.body);
      bool safe;

      if (type == "news") {
        safe = data["news"] == "Real";
        score = safe ? 88 : 22;
        resultText =
            safe ? "Content appears trustworthy" : "Content is likely fake";
        statusColor = safe ? Colors.green : Colors.red;
      } else {
        safe = !data["is_scam"];
        score = safe ? 82 : 15;
        resultText =
            safe ? "No scam patterns detected" : "High risk of online scam";
        statusColor = safe ? Colors.green : Colors.orange;
      }

      meter = Tween<double>(begin: 0, end: score).animate(
        CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
      );

      setState(() {
        loading = false;
        hasResult = true;
      });

      widget.onResult(resultText);
      anim.forward(from: 0);
    } catch (e) {
      setState(() {
        loading = false;
        hasResult = true;
        resultText = "Analysis took too long. Try shorter text.";
        statusColor = Colors.orange;
        score = 40;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: hasResult
          ? AnimatedScale(
              scale: hasResult ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: FloatingActionButton(
                onPressed: clearAll,
                child: const Icon(Icons.refresh),
              ),
            )
          : null,
      body: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("TrustGuard",
                      style:
                          TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: Icon(
                        widget.darkMode ? Icons.light_mode : Icons.dark_mode),
                    onPressed: widget.onToggleTheme,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 20,
                      color: Colors.black.withOpacity(0.08),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: controller,
                  maxLines: 6,
                  onChanged: (_) {
                    if (hasResult) clearAll();
                  },
                  decoration: const InputDecoration(
                    hintText: "Paste news, SMS, or message here…",
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: AnimatedScale(
                      scale: loading ? 0.95 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: ElevatedButton(
                        onPressed: loading ? null : () => check("news"),
                        child: const Text("Check News"),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnimatedScale(
                      scale: loading ? 0.95 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: OutlinedButton(
                        onPressed: loading ? null : () => check("scam"),
                        child: const Text("Check Scam"),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (loading)
                Column(
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text("Analyzing content…"),
                  ],
                ),
              if (hasResult)
                AnimatedSlide(
                  offset: hasResult ? Offset.zero : const Offset(0, 0.2),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: hasResult ? 1 : 0,
                    duration: const Duration(milliseconds: 400),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withOpacity(0.4),
                                blurRadius: 25,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: SizedBox(
                            height: 120,
                            width: 120,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                AnimatedBuilder(
                                  animation: meter,
                                  builder: (_, __) => CircularProgressIndicator(
                                    value: meter.value / 100,
                                    strokeWidth: 10,
                                    color: statusColor,
                                  ),
                                ),
                                Center(
                                  child: Text(
                                    "${meter.value.toInt()}%",
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          resultText,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ================= HISTORY PAGE ================= */

class HistoryPage extends StatelessWidget {
  final List<String> history;

  const HistoryPage({super.key, required this.history});

  IconData _iconForResult(String text) {
    if (text.toLowerCase().contains("fake") ||
        text.toLowerCase().contains("scam")) {
      return Icons.warning_amber_rounded;
    }
    return Icons.verified_rounded;
  }

  Color _colorForResult(BuildContext context, String text) {
    if (text.toLowerCase().contains("fake") ||
        text.toLowerCase().contains("scam")) {
      return Colors.redAccent;
    }
    return Theme.of(context).colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------- TITLE ----------
            const Text(
              "Scan History",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              "Your recent content checks and trust decisions",
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),

            const SizedBox(height: 24),

            // ---------- EMPTY STATE ----------
            if (history.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_toggle_off,
                        size: 64,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.6),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "No scans yet",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Your checked news and messages will appear here.",
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

            // ---------- HISTORY LIST ----------
            if (history.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final item = history[index];
                    final icon = _iconForResult(item);
                    final color = _colorForResult(context, item);

                    return AnimatedSlide(
                      offset: Offset(0, index == 0 ? 0 : 0.05),
                      duration: Duration(milliseconds: 300 + (index * 80)),
                      curve: Curves.easeOut,
                      child: AnimatedOpacity(
                        opacity: 1,
                        duration: Duration(milliseconds: 300 + (index * 80)),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 18,
                                color: Colors.black.withOpacity(0.08),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color.withOpacity(0.15),
                                ),
                                child: Icon(icon, color: color),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      index == 0
                                          ? "Most recent scan"
                                          : "Previous scan",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/* ================= ABOUT PAGE ================= */

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Widget infoCard(BuildContext context,
      {required IconData icon,
      required String title,
      required String description}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            color: Colors.black.withOpacity(0.08),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const SizedBox(height: 10),

            // ---------- TITLE ----------
            const Text(
              "About TrustGuard",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Text(
              "Your AI-powered shield against misinformation and online scams.",
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),

            const SizedBox(height: 24),

            // ---------- PROBLEM ----------
            infoCard(
              context,
              icon: Icons.warning_amber_rounded,
              title: "The Problem",
              description:
                  "Fake news and online scams spread faster than ever, "
                  "misleading people, causing financial loss, and even risking lives. "
                  "Most users cannot easily verify what to trust.",
            ),

            // ---------- SOLUTION ----------
            infoCard(
              context,
              icon: Icons.shield_outlined,
              title: "Our Solution",
              description:
                  "TrustGuard analyzes content using a hybrid AI approach — "
                  "combining rule-based safety checks with machine learning — "
                  "to quickly flag suspicious or misleading information.",
            ),

            // ---------- HOW IT WORKS ----------
            infoCard(
              context,
              icon: Icons.auto_graph,
              title: "How It Works",
              description: "• User submits news or messages\n"
                  "• Fast safety rules detect obvious threats\n"
                  "• AI model performs deeper linguistic analysis\n"
                  "• A trust score and clear explanation are shown",
            ),

            // ---------- TECHNOLOGY ----------
            infoCard(
              context,
              icon: Icons.memory,
              title: "Technology Stack",
              description: "• Flutter for cross-platform UI\n"
                  "• FastAPI for backend services\n"
                  "• Machine Learning for pattern detection\n"
                  "• Secure local processing for privacy",
            ),

            // ---------- ETHICS ----------
            infoCard(
              context,
              icon: Icons.balance,
              title: "Responsible AI",
              description: "TrustGuard does not claim absolute truth. "
                  "Instead, it highlights risk and provides explainable results, "
                  "empowering users to make informed decisions.",
            ),

            // ---------- FOOTER ----------
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.verified_user,
                    size: 36,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Built for awareness. Designed for trust.",
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
