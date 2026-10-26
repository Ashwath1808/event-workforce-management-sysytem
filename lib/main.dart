
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'theme/crewsync_theme.dart';

// ============================================================
// MAIN FUNCTION
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase before starting CrewSync.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    debugPrint('Firebase initialized successfully.');

    runApp(const ClassicoAS());
  } catch (e) {
    debugPrint('Firebase initialization error: $e');

    // Show an error screen instead of starting the app
    // without a working Firebase connection.
    runApp(
      CrewSyncInitializationError(
        error: e.toString(),
      ),
    );
  }
}

// ============================================================
// CREWSYNC APPLICATION
// ============================================================

class ClassicoAS extends StatelessWidget {
  const ClassicoAS({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'CREWSYNC',

      theme: CrewSyncTheme.light,

      // Keep the existing SplashScreen.
      // It handles navigation to the correct login
      // or dashboard page.
      home: const SplashScreen(),
    );
  }
}

// ============================================================
// FIREBASE INITIALIZATION ERROR SCREEN
// ============================================================

class CrewSyncInitializationError
    extends StatelessWidget {
  final String error;

  const CrewSyncInitializationError({
    super.key,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor:
        const Color(0xFFF7F8FC),

        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment:
                MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 75,
                    color: Colors.redAccent,
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Unable to Start CrewSync',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Firebase could not be initialized. '
                        'Please check your Firebase '
                        'configuration and restart the app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                      BorderRadius.circular(12),
                    ),
                    child: SelectableText(
                      error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  ElevatedButton.icon(
                    onPressed: () {
                      // Retry initialization without
                      // requiring a full app restart.
                      main();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
