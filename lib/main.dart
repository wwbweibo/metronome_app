import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'controllers/metronome_controller.dart';
import 'screens/home_screen.dart';
import 'screens/tuner_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  WakelockPlus.enable();
  runApp(
    ChangeNotifierProvider(
      create: (_) => MetronomeController(),
      child: const MetronomeApp(),
    ),
  );
}

class MetronomeApp extends StatelessWidget {
  const MetronomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF0B0D10);
    const surface = Color(0xFF15191F);
    const accent = Color(0xFFFF7A3D);
    const text = Color(0xFFF4F7FA);
    const muted = Color(0xFF8B98A8);

    return MaterialApp(
      title: 'Metronome',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          secondary: Color(0xFF3DDBA5),
          surface: surface,
          onSurface: text,
          onSurfaceVariant: muted,
        ),
        fontFamily: 'sans-serif',
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: text,
          displayColor: text,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: text,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: text,
            fontSize: 13,
            letterSpacing: 3,
            fontWeight: FontWeight.w700,
          ),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: accent,
          inactiveTrackColor: const Color(0xFF27303A),
          thumbColor: text,
          overlayColor: accent.withValues(alpha: 0.14),
          trackHeight: 4,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? accent : muted,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? accent.withValues(alpha: 0.28)
                : const Color(0xFF27303A),
          ),
        ),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D10),
      body: IndexedStack(
        index: _tabIndex,
        children: const [HomeScreen(), TunerScreen()],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        backgroundColor: const Color(0xFF101419),
        selectedItemColor: const Color(0xFFFF7A3D),
        unselectedItemColor: const Color(0xFF6F7B88),
        selectedFontSize: 12,
        unselectedFontSize: 11,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
        elevation: 18,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note_outlined),
            activeIcon: Icon(Icons.music_note),
            label: '节拍器',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.graphic_eq_outlined),
            activeIcon: Icon(Icons.graphic_eq),
            label: '调音器',
          ),
        ],
      ),
    );
  }
}
