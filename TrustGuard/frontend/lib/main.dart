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
        vsync: this, duration: const Duration(milliseconds: 700));
    meter = Tween<double>(begin: 0, end: 0).animate(anim);
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
      hasResult = false;
      resultText = "";
      score = 0;
      loading = false;
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> check(String type) async {
    // -------- INPUT VALIDATION --------
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
      loading = true; // 🔹 loader ON
      hasResult = false;
    });

    try {
      // -------- LIMIT TEXT LENGTH --------
      String text = controller.text.trim();
      if (text.length > 300) {
        text = text.substring(0, 300);
      }

      final url = type == "news"
          ? "http://127.0.0.1:8000/check-news"
          : "http://127.0.0.1:8000/check-scam";

      // -------- HTTP CALL WITH TIMEOUT --------
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

      // -------- STEP 2 IS HERE --------
      setState(() {
        loading = false; // 🔹 loader OFF  ✅ (THIS IS STEP 2)
        hasResult = true;
      });

      widget.onResult(resultText);
      anim.forward(from: 0);
    } catch (e) {
      // -------- ERROR / TIMEOUT HANDLING --------
      setState(() {
        loading = false; // 🔹 loader OFF even on error
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
          ? FloatingActionButton(
              onPressed: clearAll,
              child: const Icon(Icons.refresh),
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("TrustGuard",
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: Icon(
                        widget.darkMode ? Icons.light_mode : Icons.dark_mode),
                    onPressed: widget.onToggleTheme,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
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
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: loading ? null : () => check("news"),
                      child: const Text("Check News"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: loading ? null : () => check("scam"),
                      child: const Text("Check Scam"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (loading)
                Column(
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text(
                      "Analyzing content…",
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              if (hasResult)
                AnimatedBuilder(
                  animation: meter,
                  builder: (_, __) => Column(
                    children: [
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 120,
                        width: 120,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(
                              value: meter.value / 100,
                              strokeWidth: 10,
                              color: statusColor,
                            ),
                            Center(
                              child: Text(
                                "${meter.value.toInt()}%",
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                            )
                          ],
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
                      ),
                    ],
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Scan History",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (history.isEmpty) const Text("No scans yet."),
            ...history.map(
              (h) => Card(
                child: ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(h),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

/* ================= ABOUT PAGE ================= */

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("About TrustGuard",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text(
              "TrustGuard is an AI-powered application that helps users "
              "identify fake news and online scams using machine learning, "
              "rule-based analysis, and modern user experience principles.",
            ),
          ],
        ),
      ),
    );
  }
}
