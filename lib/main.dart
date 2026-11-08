import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'resource_launcher.dart' as resource_launcher;

const ink = Color(0xff14213d),
    teal = Color(0xff0f766e),
    canvas = Color(0xfff5f6fc),
    line = Color(0xffe2e8f0),
    muted = Color(0xff64748b);
final progressProvider = StateProvider<Map<String, Set<String>>>((ref) {
  final raw =
      Hive.box('pathfinder').get('progress', defaultValue: <String, dynamic>{})
          as Map;
  return raw.map(
    (key, value) => MapEntry(
      key.toString(),
      (value as List).map((v) => v.toString()).toSet(),
    ),
  );
});
final savedProvider = StateProvider<Set<String>>(
  (ref) =>
      (Hive.box('pathfinder').get('saved', defaultValue: <dynamic>[]) as List)
          .map((v) => v.toString())
          .toSet(),
);
final compareProvider = StateProvider<Set<String>>((ref) => {});
final homeCategoryProvider = StateProvider<String>((ref) => 'All paths');
final studyLogProvider = StateProvider<Map<String, double>>((ref) {
  final raw =
      Hive.box('pathfinder').get('studyLog', defaultValue: <String, double>{})
          as Map;
  return raw.map(
    (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
  );
});
final weeklyGoalProvider = StateProvider<int>(
  (ref) => (Hive.box('pathfinder').get('weeklyGoal', defaultValue: 15) as num)
      .toInt(),
);
final displayNameProvider = StateProvider<String>(
  (ref) =>
      Hive.box('pathfinder').get('displayName', defaultValue: '') as String,
);
final notificationsProvider = StateProvider<Map<String, bool>>((ref) {
  final raw =
      Hive.box('pathfinder').get(
            'notifications',
            defaultValue: <String, bool>{
              'weeklyReminder': true,
              'productUpdates': false,
            },
          )
          as Map;
  return raw.map((key, value) => MapEntry(key.toString(), value as bool));
});
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  final value =
      Hive.box('pathfinder').get('themeMode', defaultValue: 'system') as String;
  return value == 'dark'
      ? ThemeMode.dark
      : value == 'light'
      ? ThemeMode.light
      : ThemeMode.system;
});
final dataProvider = FutureProvider<AppData>((ref) async {
  final careersJson = await rootBundle.loadString('data/careers.seed.json');
  final quizJson = await rootBundle.loadString('data/quiz.seed.json');
  return AppData(jsonDecode(careersJson), jsonDecode(quizJson));
});
final authStateProvider = StreamProvider<User?>(
  (ref) => Firebase.apps.isEmpty
      ? Stream<User?>.value(null)
      : FirebaseAuth.instance.authStateChanges(),
);

class AppData {
  AppData(this.careersJson, this.quizJson)
    : records = (careersJson['records'] as List).cast<Map<String, dynamic>>(),
      quiz = quizJson;
  final Map<String, dynamic> careersJson, quizJson;
  final List<Map<String, dynamic>> records;
  final Map<String, dynamic> quiz;
  Map<String, dynamic> byId(String id) => records.firstWhere(
    (r) => r['career']['id'] == id,
    orElse: () => records.first,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('pathfinder');
  const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  if (apiKey.isNotEmpty) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: apiKey,
        authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
        projectId: String.fromEnvironment(
          'FIREBASE_PROJECT_ID',
          defaultValue: 'pathfinder-4de02',
        ),
        messagingSenderId: String.fromEnvironment(
          'FIREBASE_MESSAGING_SENDER_ID',
        ),
        appId: String.fromEnvironment('FIREBASE_APP_ID'),
      ),
    );
    const appCheckDebug = bool.fromEnvironment(
      'PATHFINDER_APPCHECK_DEBUG',
      defaultValue: false,
    );
    const appCheckSiteKey = String.fromEnvironment(
      'FIREBASE_APPCHECK_SITE_KEY',
    );
    if (appCheckSiteKey.isNotEmpty) {
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaEnterpriseProvider(appCheckSiteKey),
      );
    } else if (appCheckDebug) {
      await FirebaseAppCheck.instance.activate(providerWeb: WebDebugProvider());
    }
  }
  runApp(const ProviderScope(child: PathfinderApp()));
}

final router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomePage()),
        GoRoute(path: '/explore', builder: (_, _) => const ExplorePage()),
        GoRoute(
          path: '/career/:id',
          builder: (_, s) => CareerPage(id: s.pathParameters['id']!),
        ),
        GoRoute(path: '/journey', builder: (_, _) => const JourneyPage()),
        GoRoute(path: '/saved', builder: (_, _) => const SavedPage()),
        GoRoute(path: '/quiz', builder: (_, _) => const QuizPage()),
        GoRoute(path: '/compare', builder: (_, _) => const ComparePage()),
        GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
      ],
    ),
  ],
);

class PathfinderApp extends ConsumerWidget {
  const PathfinderApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Pathfinder — Career Guidance & Roadmaps',
    debugShowCheckedModeBanner: false,
    routerConfig: router,
    themeMode: ref.watch(themeModeProvider),
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: teal,
        surface: const Color(0xfff8f9ff),
        onSurface: ink,
      ),
      textTheme: GoogleFonts.loraTextTheme().apply(
        bodyColor: ink,
        displayColor: ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: teal, width: 1.5),
        ),
      ),
    ),
    darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff63c7b8),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xff101a2d),
      textTheme: GoogleFonts.loraTextTheme(ThemeData.dark().textTheme),
      cardTheme: CardThemeData(
        color: const Color(0xff18243a),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xff344258)),
        ),
      ),
    ),
  );
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;
  int get tab =>
      location.startsWith('/explore') || location.startsWith('/career')
      ? 1
      : location.startsWith('/journey')
      ? 2
      : location.startsWith('/saved')
      ? 3
      : location.startsWith('/profile')
      ? 4
      : 0;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final wide = screenWidth > 760;
    final compactHeader = screenWidth < 900;
    final user = ref.watch(authStateProvider).asData?.value;
    final localName = ref.watch(displayNameProvider);
    final careerRecords =
        ref.watch(dataProvider).asData?.value.records ??
        const <Map<String, dynamic>>[];
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth < 520 ? 12 : 26,
                  ),
                  child: SizedBox(
                    height: 72,
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => context.go('/'),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: teal,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.route,
                                  color: Colors.white,
                                  size: 21,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'pathfinder',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: wide ? 24 : 0),
                        if (wide) ...[
                          navLink(context, 'Home', '/'),
                          navLink(context, 'Explore', '/explore'),
                          navLink(context, 'My Journey', '/journey'),
                          navLink(context, 'Saved', '/saved'),
                        ],
                        const Spacer(),
                        if (MediaQuery.sizeOf(context).width > 800)
                          SizedBox(
                            width: 260,
                            height: 42,
                            child: careerSearchField(
                              records: careerRecords,
                              hintText: 'Search careers',
                              onSubmitted: (v) => context.go(
                                '/explore?q=${Uri.encodeComponent(v)}',
                              ),
                            ),
                          ),
                        if (!compactHeader)
                          IconButton(
                            tooltip: 'Saved careers',
                            onPressed: () => context.go('/saved'),
                            icon: const Icon(Icons.bookmark_border, color: ink),
                          ),
                        if (screenWidth >= 900)
                          IconButton(
                            tooltip: 'Notifications',
                            onPressed: () =>
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'You are all caught up. Updates appear here when available.',
                                    ),
                                  ),
                                ),
                            icon: const Icon(
                              Icons.notifications_none,
                              color: ink,
                            ),
                          ),
                        IconButton(
                          tooltip: 'Profile',
                          onPressed: () => context.go('/profile'),
                          icon: CircleAvatar(
                            radius: 15,
                            backgroundColor: const Color(0xffdcece8),
                            child: Text(
                              (user?.displayName ?? localName).trim().isEmpty
                                  ? 'P'
                                  : (user?.displayName ?? localName)
                                        .trim()[0]
                                        .toUpperCase(),
                              style: const TextStyle(
                                color: teal,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
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
          const Divider(height: 1, color: line),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 760
          ? NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) => context.go(
                ['/', '/explore', '/journey', '/saved', '/profile'][i],
              ),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.explore_outlined),
                  label: 'Explore',
                ),
                NavigationDestination(
                  icon: Icon(Icons.route_outlined),
                  label: 'Journey',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bookmark_border),
                  label: 'Saved',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  label: 'Profile',
                ),
              ],
            )
          : null,
    );
  }
}

Widget navLink(BuildContext c, String t, String path) => TextButton(
  onPressed: () => c.go(path),
  child: Text(
    t,
    style: const TextStyle(color: muted, fontWeight: FontWeight.w500),
  ),
);

class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.child, this.width = 1180});
  final Widget child;
  final double width;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width < 700 ? 18 : 30,
            vertical: 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [child, const SizedBox(height: 32), const AppFooter()],
          ),
        ),
      ),
    ),
  );
}

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Divider(height: 1, color: line),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < 650
              ? const Column(
                  children: [
                    Text(
                      '✦  Pathfinder',
                      style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '© 2026 Pathfinder Career Platform. Build a path that fits you.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted, fontSize: 11),
                    ),
                  ],
                )
              : Row(
                  children: [
                    const Text(
                      '✦  Pathfinder',
                      style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                    ),
                    const Spacer(),
                    const Text(
                      '© 2026 Pathfinder Career Platform. Build a path that fits you.',
                      style: TextStyle(color: muted, fontSize: 11),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => showAboutDialog(
                        context: context,
                        applicationName: 'Pathfinder',
                        applicationVersion: '1.0',
                        children: const [
                          Text(
                            'Career guidance and learning roadmaps. Your learning timelines are estimates and do not guarantee employment outcomes.',
                          ),
                        ],
                      ),
                      child: const Text('About & help'),
                    ),
                  ],
                ),
        ),
      ),
    ],
  );
}

Text heading(String text, {double size = 28}) => Text(
  text,
  style: GoogleFonts.playfairDisplay(
    fontSize: size,
    fontWeight: FontWeight.w700,
    color: ink,
    height: 1.18,
  ),
);
Widget sectionTitle(String title, String? sub) => Padding(
  padding: const EdgeInsets.only(bottom: 18),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading(title),
      if (sub != null) ...[
        const SizedBox(height: 7),
        Text(sub, style: const TextStyle(color: muted, fontSize: 15)),
      ],
    ],
  ),
);

Widget careerSearchField({
  required List<Map<String, dynamic>> records,
  required String hintText,
  required ValueChanged<String> onSubmitted,
}) => RawAutocomplete<Map<String, dynamic>>(
  displayStringForOption: (record) => record['career']['name'] as String,
  optionsBuilder: (value) {
    final queryWords = value.text
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9+#]+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (queryWords.isEmpty) return const Iterable<Map<String, dynamic>>.empty();
    return records
        .where((record) {
          final career = record['career'] as Map<String, dynamic>;
          if (queryWords.length == 1 && queryWords.single.length == 1) {
            return (career['name'] as String).trim().toLowerCase().startsWith(
              queryWords.single,
            );
          }
          final searchableWords =
              [
                    career['name'],
                    career['category'],
                    career['summary'],
                    ...(career['skills'] as List? ?? const []).map(
                      (skill) => skill['name'],
                    ),
                  ]
                  .whereType<Object>()
                  .join(' ')
                  .toLowerCase()
                  .split(RegExp(r'[^a-z0-9+#]+'))
                  .where((word) => word.isNotEmpty);
          return queryWords.every(
            (queryWord) =>
                searchableWords.any((word) => word.startsWith(queryWord)),
          );
        })
        .take(6);
  },
  onSelected: (record) {
    final career = record['career'] as Map<String, dynamic>;
    router.go('/career/${career['id']}');
  },
  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) =>
      TextField(
        controller: controller,
        focusNode: focusNode,
        onSubmitted: (value) {
          onSubmitted(value);
          onFieldSubmitted();
        },
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search, size: 19),
          contentPadding: EdgeInsets.zero,
        ),
      ),
  optionsViewBuilder: (context, onSelected, options) => Align(
    alignment: Alignment.topLeft,
    child: Material(
      elevation: 8,
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 340, maxWidth: 440),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 6),
          shrinkWrap: true,
          itemCount: options.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final record = options.elementAt(index);
            final career = record['career'] as Map<String, dynamic>;
            return ListTile(
              dense: true,
              leading: const Icon(Icons.work_outline, color: teal),
              title: Text(career['name'] as String),
              subtitle: Text(
                '${career['category']} · ${career['summary']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => onSelected(record),
            );
          },
        ),
      ),
    ),
  ),
);

Widget pill(String text, {Color color = teal}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
  decoration: BoxDecoration(
    color: color.withValues(alpha: .09),
    borderRadius: BorderRadius.circular(30),
  ),
  child: Text(
    text,
    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
  ),
);
Widget primaryButton(String text, VoidCallback onPressed, {IconData? icon}) =>
    FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.arrow_forward, size: 18),
      label: Text(text),
      style: FilledButton.styleFrom(
        backgroundColor: teal,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
        minimumSize: const Size(44, 48),
        shape: const StadiumBorder(),
      ),
    );

class HomePage extends ConsumerWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(dataProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('Could not load the career library: $error')),
        data: (data) {
          final tracks = ref.watch(progressProvider);
          final category = ref.watch(homeCategoryProvider);
          final featuredIds = [
            'data-scientist',
            'cloud-engineer',
            'ux-ui-designer',
            'cybersecurity-analyst',
            'full-stack-developer',
            'product-manager',
          ];
          Map<String, dynamic>? activeRecord;
          for (final record in data.records) {
            if (tracks.containsKey(record['career']['id'])) {
              activeRecord = record;
              break;
            }
          }
          final categories = [
            'All paths',
            ...data.records
                .map((record) => record['career']['category'] as String)
                .toSet(),
          ];
          final featured =
              data.records
                  .where(
                    (record) =>
                        featuredIds.contains(record['career']['id']) &&
                        (category == 'All paths' ||
                            record['career']['category'] == category),
                  )
                  .toList()
                ..sort(
                  (a, b) => featuredIds
                      .indexOf(a['career']['id'])
                      .compareTo(featuredIds.indexOf(b['career']['id'])),
                );
          return PageFrame(
            width: 1280,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(
                    MediaQuery.sizeOf(context).width < 700 ? 24 : 40,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xfff3f7fc), Color(0xffeaf6f4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      pill(
                        'CAREER GUIDANCE & ROADMAPS',
                        color: const Color(0xffad6d18),
                      ),
                      const SizedBox(height: 18),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Text(
                          'Find clarity in tech, design & data careers.',
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: MediaQuery.sizeOf(context).width < 380
                                ? 32
                                : MediaQuery.sizeOf(context).width < 700
                                ? 38
                                : 54,
                            fontWeight: FontWeight.w700,
                            color: ink,
                            height: 1.08,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const SizedBox(
                        width: double.infinity,
                        child: Text(
                          'Clear multi-stage blueprints, real practitioner reviews, and personalized diagnostic assessments.',
                          style: TextStyle(
                            fontSize: 17,
                            color: muted,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final search = careerSearchField(
                            records: data.records,
                            hintText:
                                "Try 'Cloud Engineer', 'UX Research', or 'Data Analyst'...",
                            onSubmitted: (value) => context.go(
                              '/explore?q=${Uri.encodeComponent(value)}',
                            ),
                          );
                          final button = primaryButton(
                            'Explore',
                            () => context.go('/explore'),
                            icon: Icons.arrow_forward,
                          );
                          return constraints.maxWidth < 520
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    search,
                                    const SizedBox(height: 10),
                                    button,
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(child: search),
                                    const SizedBox(width: 8),
                                    button,
                                  ],
                                );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories
                      .map(
                        (value) => ChoiceChip(
                          label: Text(
                            value == 'All paths' ? 'All Paths' : value,
                          ),
                          selected: category == value,
                          onSelected: (_) =>
                              ref.read(homeCategoryProvider.notifier).state =
                                  value,
                          selectedColor: teal.withValues(alpha: .14),
                        ),
                      )
                      .toList(),
                ),
                if (activeRecord != null) ...[
                  const SizedBox(height: 22),
                  Builder(
                    builder: (context) {
                      final record = activeRecord!;
                      final career = record['career'];
                      final roadmap = record['roadmap'];
                      final done = tracks[career['id']] ?? <String>{};
                      final tasks = (roadmap['stages'] as List)
                          .expand((stage) => stage['tasks'] as List)
                          .toList();
                      final next = tasks
                          .where((task) => !done.contains(task['id']))
                          .firstOrNull;
                      final ratio = tasks.isEmpty
                          ? 0.0
                          : done.length / tasks.length;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: teal,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          'CONTINUE YOUR JOURNEY',
                                          style: TextStyle(
                                            color: teal,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: .8,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        pill(
                                          'Stage ${((done.length / (tasks.length / (roadmap['stages'] as List).length)).floor() + 1).clamp(1, (roadmap['stages'] as List).length)} of ${(roadmap['stages'] as List).length} in progress',
                                          color: const Color(0xffa96511),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    heading(career['name'], size: 22),
                                    Text(
                                      next == null
                                          ? 'Roadmap complete'
                                          : 'Next up: ${next['title']}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: muted),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 18),
                              SizedBox(
                                width: 190,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Core Track Completion ${(ratio * 100).round()}%',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    LinearProgressIndicator(
                                      value: ratio,
                                      color: teal,
                                      backgroundColor: line,
                                    ),
                                    Text(
                                      '${done.length} of ${tasks.length} skills checked',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: muted,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          context.go('/career/${career['id']}'),
                                      child: const Text('Jump back in  →'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          heading('Suggested career paths', size: 29),
                          const SizedBox(height: 4),
                          const Text(
                            'Hand-picked trajectories matching your interests and foundational skills.',
                            style: TextStyle(color: muted),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => context.go('/explore'),
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('View all 43 paths'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (featured.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No featured path in this area yet. Explore all careers to see every available roadmap.',
                      style: TextStyle(color: muted),
                    ),
                  )
                else
                  CareerGrid(records: featured),
                const SizedBox(height: 28),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(
                    MediaQuery.sizeOf(context).width < 700 ? 20 : 26,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xfff1f8f7), Color(0xffeff3ff)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: line),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 18,
                    runSpacing: 14,
                    children: [
                      SizedBox(
                        width: 660,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PERSONALIZED DISCOVERY',
                              style: TextStyle(
                                color: Color(0xff9b5a16),
                                fontWeight: FontWeight.w700,
                                letterSpacing: .8,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 7),
                            heading('Not sure where to start?', size: 26),
                            const SizedBox(height: 5),
                            const Text(
                              'Take our 5-minute career interest quiz to get personalized recommendations tailored to your working style and goals.',
                              style: TextStyle(color: muted),
                            ),
                          ],
                        ),
                      ),
                      primaryButton(
                        'Take the career quiz',
                        () => context.go('/quiz'),
                        icon: Icons.auto_awesome,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class CareerGrid extends StatelessWidget {
  const CareerGrid({super.key, required this.records});
  final List<Map<String, dynamic>> records;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (c, box) {
      final cols = box.maxWidth > 950
          ? 3
          : box.maxWidth > 620
          ? 2
          : 1;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: records.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          mainAxisExtent: 222,
        ),
        itemBuilder: (c, i) => CareerCard(record: records[i]),
      );
    },
  );
}

class CareerCard extends ConsumerWidget {
  const CareerCard({super.key, required this.record});
  final Map<String, dynamic> record;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final career = record['career'] as Map<String, dynamic>;
    final road = record['roadmap'] as Map<String, dynamic>;
    final id = career['id'] as String;
    final saved = ref.watch(savedProvider).contains(id);
    final skills = (career['skills'] as List)
        .take(3)
        .map((s) => s['name'])
        .join(' · ');
    final duration = career['timeToEntry'];
    return InkWell(
      onTap: () => context.go('/career/$id'),
      borderRadius: BorderRadius.circular(14),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: pill(career['category'])),
                  IconButton(
                    tooltip: saved ? 'Remove saved career' : 'Save career',
                    onPressed: () =>
                        ref.read(savedProvider.notifier).update((s) {
                          final n = <String>{...s};
                          saved ? n.remove(id) : n.add(id);
                          Hive.box('pathfinder').put('saved', n.toList());
                          return n;
                        }),
                    icon: Icon(
                      saved ? Icons.bookmark : Icons.bookmark_border,
                      color: teal,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Add to compare',
                    onPressed: () =>
                        ref.read(compareProvider.notifier).update((ids) {
                          final next = <String>{...ids};
                          next.contains(id) ? next.remove(id) : next.add(id);
                          if (next.length > 3) next.remove(next.first);
                          context.go('/compare');
                          return next;
                        }),
                    icon: const Icon(Icons.compare_arrows, color: muted),
                  ),
                ],
              ),
              Text(
                career['name'],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Expanded(
                child: Text(
                  career['summary'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
              Text(
                '${duration['minMonths']}–${duration['maxMonths']} months  ·  ${(road['stages'] as List).length} stages',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                skills,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: teal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});
  @override
  ConsumerState<ExplorePage> createState() => _ExploreState();
}

class _ExploreState extends ConsumerState<ExplorePage> {
  String query = '';
  String category = 'All paths';
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    query = Uri.base.queryParameters['q'] ?? query;
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(dataProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Text('$e'),
        data: (d) {
          final cats = [
            'All paths',
            ...d.records.map((r) => r['career']['category'] as String).toSet(),
          ];
          final list = d.records.where((r) {
            final c = r['career'];
            final searchable =
                '${c['name']} ${c['category']} ${c['summary']} ${(c['skills'] as List).map((s) => s['name']).join(' ')}'
                    .toLowerCase();
            return (category == 'All paths' || category == c['category']) &&
                searchable.contains(query.toLowerCase());
          }).toList();
          return PageFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                sectionTitle(
                  'Explore career paths',
                  'Find a direction, then follow a clear roadmap to build the skills.',
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: TextField(
                    onChanged: (v) => setState(() => query = v),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search careers, skills, or categories',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: cats
                      .map(
                        (c) => ChoiceChip(
                          label: Text(c),
                          selected: category == c,
                          onSelected: (_) => setState(() => category = c),
                          selectedColor: teal.withValues(alpha: .14),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 22),
                Text(
                  '${list.length} career paths',
                  style: const TextStyle(color: muted),
                ),
                const SizedBox(height: 14),
                CareerGrid(records: list),
              ],
            ),
          );
        },
      );
}

class CareerPage extends ConsumerWidget {
  const CareerPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(dataProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('Could not load this career: $error')),
        data: (data) {
          final item = data.byId(id);
          final career = item['career'] as Map<String, dynamic>;
          final roadmap = item['roadmap'] as Map<String, dynamic>;
          final skills = (career['skills'] as List)
              .cast<Map<String, dynamic>>();
          final stages = (roadmap['stages'] as List)
              .cast<Map<String, dynamic>>();
          final checked = ref.watch(progressProvider)[id] ?? <String>{};
          final saved = ref.watch(savedProvider).contains(id);
          final selectedForCompare = ref.watch(compareProvider).contains(id);
          final allTasks = stages
              .expand((stage) => stage['tasks'] as List)
              .length;
          final ratio = allTasks == 0 ? 0.0 : checked.length / allTasks;
          final currentStageIndex = stages.indexWhere(
            (stage) => !(stage['tasks'] as List).every(
              (task) => checked.contains(task['id']),
            ),
          );
          final safeCurrentStage = currentStageIndex < 0
              ? stages.length - 1
              : currentStageIndex;
          final overviewKey = GlobalKey(),
              skillsKey = GlobalKey(),
              roadmapKey = GlobalKey(),
              aiGuideKey = GlobalKey(),
              experiencesKey = GlobalKey(),
              outlookKey = GlobalKey();
          final tabs = <String, GlobalKey>{
            'Overview': overviewKey,
            'Skills Breakdown': skillsKey,
            'Roadmap': roadmapKey,
            'AI Guidance': aiGuideKey,
            'Experiences': experiencesKey,
            'Career outlook': outlookKey,
          };
          return PageFrame(
            width: 1280,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: () => context.go('/explore'),
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Back to all careers'),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Home  /  Explore  /  ${career['category']}  /  ${career['name']}',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  key: overviewKey,
                  width: double.infinity,
                  padding: EdgeInsets.all(
                    MediaQuery.sizeOf(context).width < 700 ? 24 : 34,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xff203348), Color(0xff173f48)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          pill(
                            career['category'],
                            color: const Color(0xffd2f4ed),
                          ),
                          pill(
                            'Career roadmap',
                            color: const Color(0xfff7d7a7),
                          ),
                          pill(
                            '${stages.length} learning stages',
                            color: const Color(0xffc5d5f3),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        career['name'],
                        style: GoogleFonts.playfairDisplay(
                          fontSize: MediaQuery.sizeOf(context).width < 700
                              ? 34
                              : 46,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 780),
                        child: Text(
                          career['summary'],
                          style: const TextStyle(
                            color: Color(0xffe4eaf2),
                            fontSize: 17,
                            height: 1.55,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 36,
                        runSpacing: 18,
                        children: [
                          _heroMetric(
                            'TIME TO ROLE READINESS',
                            '${career['timeToEntry']['minMonths']}–${career['timeToEntry']['maxMonths']} months',
                          ),
                          _heroMetric(
                            'ROADMAP STAGES',
                            '${stages.length} stages',
                          ),
                          _heroMetric(
                            'SKILL AREAS',
                            '${skills.length} competencies',
                          ),
                          _heroMetric(
                            'YOUR PROGRESS',
                            '${(ratio * 100).round()}% complete',
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          primaryButton('Start this roadmap', () {
                            ref.read(progressProvider.notifier).update((all) {
                              final next = <String, Set<String>>{...all};
                              next.putIfAbsent(id, () => <String>{});
                              Hive.box('pathfinder').put(
                                'progress',
                                next.map(
                                  (key, value) => MapEntry(key, value.toList()),
                                ),
                              );
                              return next;
                            });
                            final user = Firebase.apps.isEmpty
                                ? null
                                : FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .collection('careerTracks')
                                  .doc(id)
                                  .set({
                                    'careerId': id,
                                    'roadmapVersionId': roadmap['id'],
                                    'status': 'active',
                                    'startedAt': FieldValue.serverTimestamp(),
                                  }, SetOptions(merge: true));
                            }
                            context.go('/journey');
                          }, icon: Icons.route),
                          OutlinedButton.icon(
                            onPressed: () {
                              ref.read(savedProvider.notifier).update((all) {
                                final next = <String>{...all};
                                saved ? next.remove(id) : next.add(id);
                                Hive.box(
                                  'pathfinder',
                                ).put('saved', next.toList());
                                final user = Firebase.apps.isEmpty
                                    ? null
                                    : FirebaseAuth.instance.currentUser;
                                if (user != null) {
                                  final doc = FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(user.uid)
                                      .collection('savedCareers')
                                      .doc(id);
                                  if (saved) {
                                    doc.delete();
                                  } else {
                                    doc.set({
                                      'careerId': id,
                                      'savedAt': FieldValue.serverTimestamp(),
                                    }, SetOptions(merge: true));
                                  }
                                }
                                return next;
                              });
                            },
                            icon: Icon(
                              saved ? Icons.bookmark : Icons.bookmark_border,
                              color: Colors.white,
                            ),
                            label: Text(saved ? 'Saved' : 'Save career'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xff92a8b6)),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              ref.read(compareProvider.notifier).update((all) {
                                final next = <String>{...all};
                                if (selectedForCompare) {
                                  next.remove(id);
                                } else if (next.length < 3) {
                                  next.add(id);
                                }
                                return next;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    selectedForCompare
                                        ? 'Removed from comparison.'
                                        : 'Added to comparison. Add another career to compare up to three.',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.compare_arrows),
                            label: Text(
                              selectedForCompare ? 'In comparison' : 'Compare',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xff92a8b6)),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _shareCareer(context, career),
                            icon: const Icon(
                              Icons.ios_share,
                              color: Colors.white,
                              size: 17,
                            ),
                            label: const Text(
                              'Share pathway',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: tabs.entries
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: TextButton(
                              onPressed: () {
                                final target = entry.value.currentContext;
                                if (target != null)
                                  Scrollable.ensureVisible(
                                    target,
                                    duration: const Duration(milliseconds: 450),
                                    curve: Curves.easeInOut,
                                    alignment: .04,
                                  );
                              },
                              child: Text(entry.key),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                _journeyProgressCard(stages, checked, ratio),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 940;
                    final roadmapColumn = Column(
                      key: roadmapKey,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: heading('Your roadmap journey', size: 28),
                            ),
                            pill('${stages.length} stages'),
                          ],
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Work through the milestones in order. Every task can be checked off and revisited.',
                          style: TextStyle(color: muted),
                        ),
                        const SizedBox(height: 18),
                        ...stages.asMap().entries.map(
                          (entry) => _roadmapStage(
                            context,
                            ref,
                            id,
                            skills,
                            roadmap['id'],
                            entry.key,
                            entry.value,
                            checked,
                            safeCurrentStage,
                          ),
                        ),
                      ],
                    );
                    final sidebar = Column(
                      children: [
                        Container(key: skillsKey, child: _skillsPanel(skills)),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                pill('KEEP MOVING'),
                                const SizedBox(height: 10),
                                heading('A clear next step', size: 21),
                                const SizedBox(height: 6),
                                const Text(
                                  'Your checklist and saved paths stay on this device in guest mode, and sync to your account after sign-in.',
                                  style: TextStyle(color: muted, height: 1.45),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () => context.go('/journey'),
                                  icon: const Icon(Icons.route),
                                  label: const Text('Open My Journey'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                    return wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 7, child: roadmapColumn),
                              const SizedBox(width: 20),
                              Expanded(flex: 4, child: sidebar),
                            ],
                          )
                        : Column(
                            children: [
                              roadmapColumn,
                              const SizedBox(height: 16),
                              sidebar,
                            ],
                          );
                  },
                ),
                const SizedBox(height: 30),
                Container(
                  key: aiGuideKey,
                  child: _AiCareerGuide(
                    career: career,
                    stages: stages,
                    completedTaskIds: checked,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  key: experiencesKey,
                  child: _experienceSection(id, career['name'], career),
                ),
                const SizedBox(height: 24),
                Container(
                  key: outlookKey,
                  child: _outlookPanel(career, roadmap),
                ),
                const SizedBox(height: 24),
                sectionTitle(
                  'Related careers',
                  'Explore adjacent roles that build on similar interests and skills.',
                ),
                CareerGrid(
                  records: data.records
                      .where(
                        (record) => (career['relatedCareerIds'] as List)
                            .contains(record['career']['id']),
                      )
                      .toList(),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Roadmap timelines are planning estimates, not promises. Role readiness depends on prior experience, practice time, and local hiring expectations.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          );
        },
      );
}

Widget _heroMetric(String label, String value) => SizedBox(
  width: 180,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: Color(0xffbac9d4),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: .8,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: GoogleFonts.playfairDisplay(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  ),
);

Widget _journeyProgressCard(
  List<Map<String, dynamic>> stages,
  Set<String> checked,
  double ratio,
) {
  final counts = stages
      .map(
        (stage) => (stage['tasks'] as List)
            .where((task) => checked.contains(task['id']))
            .length,
      )
      .toList();
  final current = stages.indexWhere(
    (stage) =>
        !(stage['tasks'] as List).every((task) => checked.contains(task['id'])),
  );
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YOUR ROADMAP JOURNEY',
                      style: TextStyle(
                        color: muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    heading(
                      '${checked.length == 0 ? 'Stage 1' : 'Stage ${(current < 0 ? stages.length - 1 : current) + 1}'} of ${stages.length} in progress  (${(ratio * 100).round()}% complete)',
                      size: 21,
                    ),
                  ],
                ),
              ),
              pill('${checked.length} tasks completed'),
            ],
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: ratio,
            color: teal,
            backgroundColor: const Color(0xffe3e9f5),
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: stages.asMap().entries.map((entry) {
              final done =
                  counts[entry.key] == (entry.value['tasks'] as List).length;
              final active =
                  entry.key == (current < 0 ? stages.length - 1 : current);
              return pill(
                '${done
                    ? '✓'
                    : active
                    ? '●'
                    : '○'}  Stage ${entry.key + 1} ${done
                    ? 'Complete'
                    : active
                    ? 'In Progress'
                    : 'Upcoming'}',
                color: done
                    ? teal
                    : active
                    ? const Color(0xffb8741a)
                    : muted,
              );
            }).toList(),
          ),
        ],
      ),
    ),
  );
}

Widget _roadmapStage(
  BuildContext context,
  WidgetRef ref,
  String careerId,
  List<Map<String, dynamic>> careerSkills,
  String roadmapVersionId,
  int index,
  Map<String, dynamic> stage,
  Set<String> checked,
  int currentIndex,
) {
  final tasks = (stage['tasks'] as List).cast<Map<String, dynamic>>();
  final skillNamesById = {
    for (final skill in careerSkills)
      skill['id'].toString(): skill['name'].toString(),
  };
  final completed = tasks.where((task) => checked.contains(task['id'])).length;
  final done = completed == tasks.length;
  final active = !done && index == currentIndex;
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 34,
          child: Column(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: done
                    ? teal
                    : active
                    ? Colors.white
                    : const Color(0xffe7ecf4),
                foregroundColor: done
                    ? Colors.white
                    : active
                    ? teal
                    : muted,
                child: done
                    ? const Icon(Icons.check, size: 16)
                    : Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              if (index < 3) Container(width: 2, height: 44, color: line),
            ],
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Card(
            color: active ? const Color(0xfffcfdff) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: active ? teal.withValues(alpha: .5) : line,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(19),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            pill(
                              'Stage ${index + 1} · ${done
                                  ? 'Completed'
                                  : active
                                  ? 'Current stage'
                                  : 'Upcoming'}',
                              color: done
                                  ? teal
                                  : active
                                  ? const Color(0xffa96511)
                                  : muted,
                            ),
                            Text(
                              '${stage['estimatedDurationWeeks']} weeks',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$completed of ${tasks.length} tasks',
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  heading(stage['title'], size: 23),
                  const SizedBox(height: 6),
                  Text(
                    stage['description'],
                    style: const TextStyle(color: muted, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xffeef2ff),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MILESTONE OUTCOME',
                          style: TextStyle(
                            color: teal,
                            fontSize: 10,
                            letterSpacing: .8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          stage['outcome'],
                          style: const TextStyle(height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...tasks.map((task) {
                    final isDone = checked.contains(task['id']);
                    final linkedSkillNames = ((task['skillIds'] as List?) ?? [])
                        .map((skillId) => skillNamesById[skillId.toString()])
                        .whereType<String>()
                        .toList();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: isDone,
                            visualDensity: VisualDensity.compact,
                            onChanged: (value) {
                              ref.read(progressProvider.notifier).update((all) {
                                final map = <String, Set<String>>{...all};
                                final ids = <String>{
                                  ...(map[careerId] ?? <String>{}),
                                };
                                if (value == true) {
                                  ids.add(task['id']);
                                } else {
                                  ids.remove(task['id']);
                                }
                                map[careerId] = ids;
                                Hive.box('pathfinder').put(
                                  'progress',
                                  map.map(
                                    (key, values) =>
                                        MapEntry(key, values.toList()),
                                  ),
                                );
                                return map;
                              });
                              final user = Firebase.apps.isEmpty
                                  ? null
                                  : FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                final track = FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(user.uid)
                                    .collection('careerTracks')
                                    .doc(careerId);
                                track.set({
                                  'careerId': careerId,
                                  'roadmapVersionId': roadmapVersionId,
                                  'status': 'active',
                                  'updatedAt': FieldValue.serverTimestamp(),
                                }, SetOptions(merge: true));
                                final doc = track
                                    .collection('taskProgress')
                                    .doc(task['id']);
                                if (value == true) {
                                  doc.set({
                                    'status': 'completed',
                                    'completedAt': FieldValue.serverTimestamp(),
                                  }, SetOptions(merge: true));
                                } else {
                                  doc.delete();
                                }
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task['title'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.35,
                                    decoration: isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  task['description']?.toString() ?? '',
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 13,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${task['estimatedHours']} hrs · Linked skills',
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 12,
                                  ),
                                ),
                                if (linkedSkillNames.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 5,
                                    children: linkedSkillNames
                                        .map((name) => pill(name))
                                        .toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if ((stage['resources'] as List).isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: const Color(0xfff4f7fc),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.menu_book_outlined,
                                color: teal,
                                size: 17,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                'LEARNING REFERENCES & GUIDES (${(stage['resources'] as List).length})',
                                style: const TextStyle(
                                  color: teal,
                                  fontSize: 10,
                                  letterSpacing: .7,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...(stage['resources'] as List).map<Widget>((
                            resource,
                          ) {
                            final resourceUri = Uri.tryParse(
                              resource['url']?.toString() ?? '',
                            );
                            return InkWell(
                              onTap: resourceUri == null
                                  ? null
                                  : () =>
                                        resource_launcher.openLearningResource(
                                          resourceUri.toString(),
                                        ),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 7,
                                  horizontal: 4,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.open_in_new,
                                      size: 15,
                                      color: teal,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            resource['title']?.toString() ??
                                                'Learning resource',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            resource['kind']?.toString() ??
                                                resource['cost']?.toString() ??
                                                'Learning resource',
                                            style: const TextStyle(
                                              color: muted,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _skillsPanel(List<Map<String, dynamic>> skills) {
  final groups = <String, List<Map<String, dynamic>>>{
    'core': [],
    'tool': [],
    'soft': [],
  };
  for (final skill in skills) {
    groups
        .putIfAbsent(skill['type']?.toString() ?? 'core', () => [])
        .add(skill);
  }
  const labels = {
    'core': 'CORE COMPETENCIES',
    'tool': 'TOOLS & FRAMEWORKS',
    'soft': 'BUSINESS & COMMUNICATION',
  };
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading('Required skills & competencies', size: 21),
          const SizedBox(height: 5),
          Text(
            'Skills mapped to this roadmap · ${skills.length} total',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          const Divider(height: 24),
          ...groups.entries
              .where((entry) => entry.value.isNotEmpty)
              .map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        labels[entry.key] ?? entry.key.toUpperCase(),
                        style: const TextStyle(
                          color: muted,
                          fontSize: 10,
                          letterSpacing: .8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...entry.value.map(
                        (skill) => Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  skill['name'],
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              pill(
                                '${skill['level']}',
                                color: skill['importance'] == 'core'
                                    ? teal
                                    : muted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    ),
  );
}

Future<void> _shareCareer(
  BuildContext context,
  Map<String, dynamic> career,
) async {
  final uri = Uri.base.resolve('/career/${career['id']}');
  try {
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Explore the ${career['name']} career roadmap on Pathfinder: $uri',
        subject: 'Pathfinder career roadmap',
      ),
    );
  } catch (_) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sharing is unavailable in this browser.'),
        ),
      );
  }
}

Widget _experienceSection(
  String careerId,
  String careerName,
  Map<String, dynamic> career,
) {
  if (careerId != 'data-scientist') {
    final skills = (career['skills'] as List? ?? const [])
        .map((skill) => skill['name'].toString())
        .take(3)
        .toList();
    final skillFocus = skills.isEmpty
        ? 'the core tools and workflows in this field'
        : skills.join(', ');
    final summary =
        career['summary']?.toString() ??
        'build practical skills and solve role-relevant problems';
    final dayInLife = (career['dayInLife'] as List? ?? const [])
        .map((item) => item.toString())
        .take(2)
        .toList();
    final dayOne = dayInLife.isNotEmpty
        ? dayInLife.first
        : 'practice a realistic task from the role';
    final dayTwo = dayInLife.length > 1
        ? dayInLife[1]
        : 'present the result and explain your decisions';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      pill('PRACTITIONER INSIGHTS'),
                      const SizedBox(height: 8),
                      heading('Experience examples for $careerName', size: 24),
                      const SizedBox(height: 5),
                      const Text(
                        'Illustrative examples tailored to this career. These are sample perspectives, not quotes or verified practitioner reviews.',
                        style: TextStyle(color: muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                pill('Examples'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _illustrativeExperience(
          'Building the foundations',
          'Early-career learning example · $careerName',
          'Core skills focus',
          'A strong starting point is learning how to $summary',
          'Choose one core skill area—$skillFocus—and use it to complete a small, finished task. Document what you tried, what changed, and how you checked the result.',
          'The work connects learning to a concrete outcome: $dayOne.',
          'It can be difficult to know which topic to study first. Use job descriptions and the roadmap to keep the scope focused.',
          0,
          'Example perspective',
        ),
        _illustrativeExperience(
          'Practicing the day-to-day work',
          'Project-based learning example · $careerName',
          'Workflow practice',
          'Practice the whole workflow, including the hand-offs and quality checks around the main task.',
          'Build a small portfolio project around $dayOne, then explain the decisions and trade-offs to someone unfamiliar with the work.',
          'Realistic exercises make it easier to show how the skills apply beyond tutorials.',
          'Projects take longer when requirements are vague. Write down the expected result and a few checks before starting.',
          0,
          'Example perspective',
        ),
        _illustrativeExperience(
          'Growing toward role readiness',
          'Career-transition example · $careerName',
          'Portfolio & communication',
          'Role readiness comes from showing both how you work and how you communicate the result.',
          'Practice $dayTwo. Keep evidence of the outcome, note one limitation, and ask for feedback on the work itself.',
          'Clear communication helps teams understand the value and limits of your work.',
          'Tools and expectations differ between employers. Compare several local role descriptions and adapt your next project accordingly.',
          0,
          'Example perspective',
        ),
      ],
    );
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    pill('PRACTITIONER INSIGHTS'),
                    const SizedBox(height: 8),
                    heading('Experience examples for $careerName', size: 24),
                    const SizedBox(height: 5),
                    const Text(
                      'The three profiles below reproduce the Stitch sample content and are illustrative, not verified practitioner reviews.',
                      style: TextStyle(color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              pill('Illustrative'),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      _illustrativeExperience(
        'Elena Rostova',
        'Senior Data Scientist at Fintech Scale-up · 6 yrs experience',
        'Transitioned from Economics',
        '“The hardest part isn’t the math—it’s convincing stakeholders that clean data takes 80% of the timeline.”',
        'Master SQL and data storytelling before obsessing over deep learning transformers. If you can cleanly explain variance to a non-technical product manager, you will always be irreplaceable.',
        'High autonomy over research trajectories, direct participation in strategic product roadmaps, and very generous compensation packages once past senior level.',
        'Extremely ambiguous business requirements, inherited spaghetti data pipelines with minimal documentation, and managing ungrounded AI hype cycles from management.',
        42,
        '3 weeks ago',
      ),
      _illustrativeExperience(
        'Marcus Chen',
        'Machine Learning Scientist at HealthTech AI · 4 yrs experience',
        'CS Bootcamp Graduate',
        '“Rigorous A/B testing and productionizing models is what separates hobbyists from enterprise engineers.”',
        'Deploy at least two models end-to-end with FastAPI and Docker so you understand production constraints. A model that only exists in a Jupyter Notebook is not software.',
        'Direct, meaningful clinical impact when algorithms assist diagnostics accurately. Incredible pace of daily engineering learning alongside multidisciplinary researchers.',
        'Stressful on-call rotations tracking production data drift, coupled with extensive healthcare regulatory compliance and HIPAA red tape when sourcing real cohorts.',
        67,
        '1 month ago',
      ),
      _illustrativeExperience(
        'Sarah Al-Mansoor',
        'Lead Analytics Engineer & Data Scientist at SaaS Enterprise · 8 yrs experience',
        'Ex-Mechanical Engineer',
        '“Do not fear switching careers; domain expertise in your prior field is your unique leverage.”',
        'Build projects that answer real business questions, not just Kaggle competitions with curated CSVs. Companies hire you to solve ambiguous, messy bottlenecks, not achieve 99.4% accuracy on synthetic sets.',
        'Exceptional remote flexibility, strong influence spanning engineering, product, and finance leadership, and the power to validate enterprise strategies with rigorous math.',
        'Tool fatigue and endless framework migrations (dbt, Snowflake, Databricks, Ray). You have to ruthlessly protect your time from buzzword initiatives.',
        51,
        '2 months ago',
      ),
    ],
  );
}

String _roadmapDurationLabel(dynamic rawWeeks) {
  final weeks = (rawWeeks as num?)?.toInt() ?? 0;
  final months = weeks / 4.345;
  return '$weeks weeks (~${months.toStringAsFixed(1)} months)';
}

class _AiCareerGuide extends StatefulWidget {
  const _AiCareerGuide({
    required this.career,
    required this.stages,
    required this.completedTaskIds,
  });

  final Map<String, dynamic> career;
  final List<Map<String, dynamic>> stages;
  final Set<String> completedTaskIds;

  @override
  State<_AiCareerGuide> createState() => _AiCareerGuideState();
}

class _AiCareerGuideState extends State<_AiCareerGuide> {
  final _inputController = TextEditingController();
  final List<({bool fromUser, String text})> _messages = [];
  ChatSession? _chat;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _messages.add((
      fromUser: false,
      text:
          'Hi! I’m your AI Career Guide for ${widget.career['name']}. Ask me about the role, skills to focus on, portfolio ideas, or your next roadmap step.',
    ));
  }

  @override
  void didUpdateWidget(covariant _AiCareerGuide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.career['id'] != widget.career['id']) {
      _chat = null;
      _messages
        ..clear()
        ..add((
          fromUser: false,
          text:
              'Hi! I’m your AI Career Guide for ${widget.career['name']}. Ask me about the role, skills to focus on, portfolio ideas, or your next roadmap step.',
        ));
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  String get _careerContext {
    final career = widget.career;
    final skills = (career['skills'] as List? ?? const [])
        .take(10)
        .map((skill) => skill['name'].toString())
        .join(', ');
    final stages = widget.stages
        .map((stage) {
          final tasks = stage['tasks'] as List? ?? const [];
          final completed = tasks
              .where((task) => widget.completedTaskIds.contains(task['id']))
              .length;
          final remainingTasks = tasks
              .where((task) => !widget.completedTaskIds.contains(task['id']))
              .take(3)
              .map((task) => task['title'].toString())
              .join('; ');
          return '- ${stage['title']}: $completed/${tasks.length} tasks complete'
              '${remainingTasks.isEmpty ? '' : '; next tasks: $remainingTasks'}';
        })
        .join('\n');
    final taskCount = widget.stages.fold<int>(
      0,
      (total, stage) => total + (stage['tasks'] as List).length,
    );
    final progress = taskCount == 0
        ? 0
        : (widget.completedTaskIds.length / taskCount * 100).round();
    return '''Career: ${career['name']} (${career['category']})
Overview: ${career['summary']}
Core skills: $skills
Learner progress: $progress% (${'${widget.completedTaskIds.length} of $taskCount'} tasks complete)
Roadmap stages:
$stages''';
  }

  Future<void> _send([String? suggestedPrompt]) async {
    final question = (suggestedPrompt ?? _inputController.text).trim();
    if (question.isEmpty || _sending) return;
    _inputController.clear();
    setState(() {
      _messages.add((fromUser: true, text: question));
      _sending = true;
    });
    try {
      if (Firebase.apps.isEmpty) {
        throw StateError('Firebase is not configured for this build.');
      }
      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-3.6-flash',
        generationConfig: GenerationConfig(
          temperature: 0.4,
          maxOutputTokens: 1200,
        ),
        systemInstruction: Content.system(
          'You are Pathfinder’s AI Career Guide. Give supportive, practical, concise career guidance for the career in the context. '
          'Use the supplied career and roadmap facts. Connect recommendations to the learner’s current progress and name specific next tasks when helpful. '
          'Never claim to be a human mentor or invent personal experience, credentials, salaries, job openings, or verified reviews. '
          'Flag uncertainty about local hiring requirements and avoid guaranteeing employment outcomes. Give an actionable answer in plain language, usually in 3–5 short sentences, and always finish the final sentence.',
        ),
      );
      _chat ??= model.startChat();
      final response = await _chat!.sendMessage(
        Content.text('''Current Pathfinder context:
$_careerContext

Learner question: $question'''),
      );
      final answer = response.text?.trim();
      if (answer == null || answer.isEmpty) {
        throw StateError('The AI guide returned an empty response.');
      }
      if (!mounted) return;
      setState(() => _messages.add((fromUser: false, text: answer)));
    } catch (error) {
      if (!mounted) return;
      final detail = error.toString();
      final message = detail.contains('Firebase is not configured')
          ? 'AI guidance is not connected in this build yet. Configure Firebase AI Logic for the Pathfinder Firebase project, then try again.'
          : 'I couldn’t reach the AI guide just now. Check that Firebase AI Logic is enabled for this project and try again.';
      setState(() => _messages.add((fromUser: false, text: message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startNewChat() {
    _chat = null;
    setState(() {
      _messages
        ..clear()
        ..add((
          fromUser: false,
          text:
              'Hi! I’m your AI Career Guide for ${widget.career['name']}. Ask me about the role, skills to focus on, portfolio ideas, or your next roadmap step.',
        ));
    });
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xffe7f3ef),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.auto_awesome, color: teal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading('AI Career Guide', size: 24),
                    const Text(
                      'Career and progress-aware guidance',
                      style: TextStyle(color: muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Start a new conversation',
                onPressed: _sending ? null : _startNewChat,
                icon: const Icon(Icons.add_comment_outlined),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 300,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xfff7f8fc),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: line),
            ),
            child: ListView.builder(
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (context, index) {
                if (_sending && index == _messages.length) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final message = _messages[index];
                return Align(
                  alignment: message.fromUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 680),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: message.fromUser ? teal : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: message.fromUser ? null : Border.all(color: line),
                    ),
                    child: SelectableText(
                      message.text,
                      style: TextStyle(
                        color: message.fromUser ? Colors.white : ink,
                        height: 1.45,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                [
                      'What should I focus on next?',
                      'What does a typical day look like?',
                      'Suggest a portfolio project',
                    ]
                    .map(
                      (prompt) => ActionChip(
                        label: Text(prompt),
                        onPressed: _sending ? null : () => _send(prompt),
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'Ask about this career or your next step…',
                    prefixIcon: Icon(Icons.chat_bubble_outline),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _sending ? null : () => _send(),
                style: FilledButton.styleFrom(
                  backgroundColor: teal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(52, 52),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'AI generated guidance can be inaccurate. Your question, career details, and roadmap progress are sent to Google Gemini to generate a reply. This conversation is not saved to your Pathfinder profile.',
            style: TextStyle(color: muted, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    ),
  );
}

Widget _outlookPanel(
  Map<String, dynamic> career,
  Map<String, dynamic> roadmap,
) => Card(
  child: Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading('Career outlook & planning', size: 24),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _metric(
                'PLANNING ESTIMATE',
                _roadmapDurationLabel(roadmap['estimatedDurationWeeks']),
              ),
            ),
            Expanded(
              child: _metric(
                'DIFFICULTY',
                career['difficulty'].toString().replaceAll('_', ' '),
              ),
            ),
            Expanded(child: _metric('CATEGORY', career['category'])),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          career['readinessNote'] ??
              'Timelines are estimates that vary by experience and local expectations.',
          style: const TextStyle(color: muted, height: 1.4),
        ),
        const SizedBox(height: 4),
        const Text(
          'Estimate adds the roadmap stage durations. Missing stage estimates are inferred from task hours at 15 study hours per week.',
          style: TextStyle(color: muted, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 5),
        const Text(
          'Pathfinder does not make salary, job availability, or employment outcome guarantees.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ],
    ),
  ),
);

Widget _illustrativeExperience(
  String name,
  String role,
  String transition,
  String quote,
  String advice,
  String good,
  String challenging,
  int helpful,
  String posted,
) => Card(
  child: Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    role,
                    style: const TextStyle(color: muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            pill('Illustrative'),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: pill(transition, color: const Color(0xffa96511)),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xffeef2ff),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            quote,
            style: const TextStyle(
              fontSize: 15,
              fontStyle: FontStyle.italic,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth < 780
                ? constraints.maxWidth
                : (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: itemWidth,
                  child: _insightColumn('The good', good, teal),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _insightColumn(
                    'The challenging',
                    challenging,
                    const Color(0xffa44b46),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _insightColumn('Advice for beginners', advice, teal),
        const Divider(height: 26),
        Row(
          children: [
            Text(
              'Helpful ($helpful)',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
            const Spacer(),
            Text(
              'Posted $posted',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
      ],
    ),
  ),
);
Widget _insightColumn(String title, String body, Color color) => Container(
  padding: const EdgeInsets.all(13),
  decoration: BoxDecoration(
    color: color.withValues(alpha: .06),
    borderRadius: BorderRadius.circular(9),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          letterSpacing: .7,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 5),
      Text(body, style: const TextStyle(fontSize: 13, height: 1.45)),
    ],
  ),
);

Widget _metric(String label, String value) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        color: muted,
        fontWeight: FontWeight.w700,
        letterSpacing: .6,
      ),
    ),
    const SizedBox(height: 3),
    Text(
      value,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
    ),
  ],
);

class JourneyPage extends ConsumerWidget {
  const JourneyPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(dataProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('$error')),
        data: (data) {
          final tracks = ref.watch(progressProvider);
          final savedIds = ref.watch(savedProvider);
          final studyLog = ref.watch(studyLogProvider);
          final weeklyGoal = ref.watch(weeklyGoalProvider);
          final active = data.records
              .where((record) => tracks.containsKey(record['career']['id']))
              .toList();
          final now = DateTime.now();
          final dateKeys = List.generate(7, (index) {
            final day = DateTime(
              now.year,
              now.month,
              now.day,
            ).subtract(Duration(days: 6 - index));
            return '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
          });
          final loggedThisWeek = dateKeys.fold<double>(
            0,
            (hours, key) => hours + (studyLog[key] ?? 0),
          );
          var streak = 0;
          for (var offset = 0; offset < 365; offset++) {
            final day = DateTime(
              now.year,
              now.month,
              now.day,
            ).subtract(Duration(days: offset));
            final key =
                '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
            if ((studyLog[key] ?? 0) > 0) {
              streak++;
            } else {
              break;
            }
          }
          final completedTasks = tracks.values.fold<int>(
            0,
            (sum, ids) => sum + ids.length,
          );
          return PageFrame(
            width: 1280,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) => constraints.maxWidth < 620
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            pill('ACTIVE WORKSPACE'),
                            const SizedBox(height: 8),
                            heading('My Learning Journey', size: 32),
                            const SizedBox(height: 5),
                            const Text(
                              'Track your career pathways, weekly study goals, and milestones.',
                              style: TextStyle(color: muted, fontSize: 15),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () => _showLogHours(context, ref),
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('Log study hours'),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  pill('ACTIVE WORKSPACE'),
                                  const SizedBox(height: 8),
                                  heading('My Learning Journey', size: 36),
                                  const SizedBox(height: 5),
                                  const Text(
                                    'Track your career pathways, weekly study goals, and milestones.',
                                    style: TextStyle(
                                      color: muted,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: () => _showLogHours(context, ref),
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('Log study hours'),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final weekly = Card(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'WEEKLY COMMITMENT',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: muted,
                                          letterSpacing: .8,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      RichText(
                                        text: TextSpan(
                                          style: const TextStyle(color: ink),
                                          children: [
                                            TextSpan(
                                              text: loggedThisWeek
                                                  .toStringAsFixed(
                                                    loggedThisWeek % 1 == 0
                                                        ? 0
                                                        : 1,
                                                  ),
                                              style:
                                                  GoogleFonts.playfairDisplay(
                                                    fontSize: 31,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            TextSpan(
                                              text: ' / $weeklyGoal hrs logged',
                                              style: const TextStyle(
                                                fontSize: 15,
                                                color: muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                pill(
                                  '$streak-day study streak',
                                  color: const Color(0xffa96511),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: List.generate(7, (index) {
                                final hours = studyLog[dateKeys[index]] ?? 0.0;
                                final maxHeight = 104.0;
                                final scale = (hours / (weeklyGoal / 5)).clamp(
                                  0.0,
                                  1.0,
                                );
                                final day = DateTime.parse(dateKeys[index]);
                                return Expanded(
                                  child: Column(
                                    children: [
                                      SizedBox(
                                        height: maxHeight,
                                        child: Align(
                                          alignment: Alignment.bottomCenter,
                                          child: Container(
                                            width: 28,
                                            height: hours == 0
                                                ? 4
                                                : 18 + scale * 78,
                                            decoration: BoxDecoration(
                                              color: hours > 0
                                                  ? teal
                                                  : const Color(0xffdbe5ed),
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        [
                                          'M',
                                          'T',
                                          'W',
                                          'T',
                                          'F',
                                          'S',
                                          'S',
                                        ][day.weekday - 1],
                                        style: const TextStyle(
                                          color: muted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 13),
                            LinearProgressIndicator(
                              value: weeklyGoal <= 0
                                  ? 0
                                  : (loggedThisWeek / weeklyGoal).clamp(
                                      0.0,
                                      1.0,
                                    ),
                              color: teal,
                              backgroundColor: line,
                              minHeight: 7,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${(weeklyGoal - loggedThisWeek).clamp(0, weeklyGoal).toStringAsFixed(1)} hrs to your weekly goal',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                    final summary = Column(
                      children: [
                        _journeyStat(
                          'ACTIVE CAREER TRACKS',
                          '${active.length}',
                          Icons.route,
                          active.isEmpty
                              ? 'Start a roadmap to begin'
                              : 'In progress',
                        ),
                        _journeyStat(
                          'MILESTONES COMPLETED',
                          '$completedTasks',
                          Icons.emoji_events_outlined,
                          'Tasks checked off',
                        ),
                        _journeyStat(
                          'STUDY HOURS THIS WEEK',
                          loggedThisWeek.toStringAsFixed(1),
                          Icons.schedule,
                          'Of $weeklyGoal hrs planned',
                        ),
                      ],
                    );
                    if (constraints.maxWidth < 800)
                      return Column(
                        children: [weekly, const SizedBox(height: 12), summary],
                      );
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: weekly),
                        const SizedBox(width: 16),
                        Expanded(flex: 4, child: summary),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: sectionTitle(
                        'Active careers',
                        'Structured learning paths currently in your workspace.',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => context.go('/explore'),
                      icon: const Icon(Icons.add),
                      label: const Text('Add a track'),
                    ),
                  ],
                ),
                if (active.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xffe6f4f1),
                            child: Icon(Icons.route, color: teal),
                          ),
                          const SizedBox(width: 15),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your workspace is ready',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Choose a career roadmap to create your first active track. Your progress will appear here as you complete tasks.',
                                  style: TextStyle(color: muted),
                                ),
                              ],
                            ),
                          ),
                          primaryButton(
                            'Explore paths',
                            () => context.go('/explore'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth > 850 ? 2 : 1;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: active.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                          mainAxisExtent: 310,
                        ),
                        itemBuilder: (context, index) {
                          final record = active[index];
                          final career = record['career'];
                          final roadmap = record['roadmap'];
                          final tasks = (roadmap['stages'] as List)
                              .expand((stage) => stage['tasks'] as List)
                              .toList();
                          final done = tracks[career['id']] ?? <String>{};
                          final ratio = tasks.isEmpty
                              ? 0.0
                              : done.length / tasks.length;
                          final next = tasks
                              .where((task) => !done.contains(task['id']))
                              .firstOrNull;
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: heading(
                                          career['name'],
                                          size: 22,
                                        ),
                                      ),
                                      pill(
                                        index == 0 ? 'Primary' : 'Secondary',
                                        color: index == 0
                                            ? teal
                                            : const Color(0xff52617b),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    career['category'],
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 17),
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Overall mastery',
                                          style: TextStyle(
                                            color: muted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${(ratio * 100).round()}%',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: ratio,
                                    color: teal,
                                    backgroundColor: line,
                                    minHeight: 7,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    '${done.length} of ${tasks.length} tasks checked',
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(13),
                                    decoration: BoxDecoration(
                                      color: const Color(0xffeef2ff),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'NEXT MILESTONE TASK',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: muted,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          next == null
                                              ? 'Roadmap complete'
                                              : next['title'],
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: FilledButton.tonalIcon(
                                      onPressed: () =>
                                          context.go('/career/${career['id']}'),
                                      icon: const Icon(Icons.arrow_forward),
                                      label: const Text('Continue roadmap'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                const SizedBox(height: 28),
                Builder(
                  builder: (context) {
                    final savedRecords = data.records
                        .where(
                          (record) => savedIds.contains(record['career']['id']),
                        )
                        .toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        sectionTitle(
                          'Saved careers & blueprints',
                          'Alternative roadmaps you bookmarked for later.',
                        ),
                        if (savedRecords.isEmpty)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.bookmark_border,
                                    color: teal,
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'Saved career paths will appear here.',
                                      style: TextStyle(color: muted),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => context.go('/explore'),
                                    child: const Text('Explore'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          CareerGrid(records: savedRecords.take(6).toList()),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),
                sectionTitle(
                  'Recent learning activity',
                  'Your locally logged study time and completed milestones.',
                ),
                if (completedTasks == 0 && loggedThisWeek == 0)
                  const Text(
                    'No learning activity recorded yet. Log study hours or check off your first roadmap task to see it here.',
                    style: TextStyle(color: muted),
                  ),
                if (completedTasks > 0)
                  Text(
                    '$completedTasks roadmap tasks completed across ${tracks.length} active career track(s).',
                    style: const TextStyle(color: muted),
                  ),
              ],
            ),
          );
        },
      );
}

Widget _journeyStat(
  String title,
  String value,
  IconData icon,
  String caption,
) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Card(
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xffeaf0fb),
        child: Icon(icon, color: teal),
      ),
      title: Text(
        value,
        style: GoogleFonts.playfairDisplay(
          fontSize: 23,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        title,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: muted,
        ),
      ),
      trailing: Text(
        caption,
        style: const TextStyle(color: muted, fontSize: 11),
      ),
    ),
  ),
);

Future<void> _showLogHours(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController(text: '1');
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Log study hours'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How long did you study today?'),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              suffixText: 'hours',
              hintText: 'e.g. 1.5',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final hours = double.tryParse(controller.text.trim());
            if (hours == null || hours <= 0 || hours > 16) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Enter a study duration between 0 and 16 hours.',
                  ),
                ),
              );
              return;
            }
            final now = DateTime.now();
            final key =
                '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
            final next = <String, double>{...ref.read(studyLogProvider)};
            next[key] = (next[key] ?? 0) + hours;
            ref.read(studyLogProvider.notifier).state = next;
            Hive.box('pathfinder').put('studyLog', next);
            final user = Firebase.apps.isEmpty
                ? null
                : FirebaseAuth.instance.currentUser;
            if (user != null) {
              FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                'studyHoursByDate': next,
              }, SetOptions(merge: true));
            }
            Navigator.pop(dialogContext);
          },
          child: const Text('Save hours'),
        ),
      ],
    ),
  );
}

class SavedPage extends ConsumerWidget {
  const SavedPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(dataProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Text('$e'),
        data: (d) {
          final saved = ref.watch(savedProvider);
          final records = d.records
              .where((r) => saved.contains(r['career']['id']))
              .toList();
          return PageFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                sectionTitle(
                  'Saved careers',
                  'Your bookmarked roadmaps, ready when you are.',
                ),
                if (records.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.bookmark_border,
                            color: teal,
                            size: 40,
                          ),
                          const SizedBox(height: 10),
                          heading('Your saved list starts here', size: 21),
                          const SizedBox(height: 7),
                          const Text(
                            'Bookmark a career path to keep it close while you explore.',
                            style: TextStyle(color: muted),
                          ),
                          const SizedBox(height: 14),
                          primaryButton(
                            'Explore career paths',
                            () => context.go('/explore'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  CareerGrid(records: records),
              ],
            ),
          );
        },
      );
}

class QuizPage extends ConsumerStatefulWidget {
  const QuizPage({super.key});
  @override
  ConsumerState<QuizPage> createState() => _QuizState();
}

class _QuizState extends ConsumerState<QuizPage> {
  int index = 0;
  final answers = <int, int>{};
  bool resultsSaved = false;

  @override
  void initState() {
    super.initState();
    final draft =
        Hive.box('pathfinder').get('quizAnswers', defaultValue: <String, int>{})
            as Map;
    answers.addAll(
      draft.map(
        (key, value) => MapEntry(int.parse(key.toString()), value as int),
      ),
    );
    while (answers.containsKey(index) && index < 10) {
      index++;
    }
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(dataProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('$error')),
        data: (data) {
          final questions = (data.quiz['questions'] as List)
              .cast<Map<String, dynamic>>();
          if (index >= questions.length) return _results(context, data);
          final question = questions[index];
          final options = (question['options'] as List)
              .cast<Map<String, dynamic>>();
          final traits = data.quiz['version']['traits'] as Map<String, dynamic>;
          return PageFrame(
            width: 1120,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(
                  MediaQuery.sizeOf(context).width < 700 ? 20 : 34,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'CAREER ASSESSMENT  /  QUESTION ${index + 1} OF ${questions.length}',
                            style: const TextStyle(
                              color: teal,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .7,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.schedule_outlined,
                          size: 16,
                          color: muted,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${((questions.length - index) * .45).ceil()} min remaining',
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    LinearProgressIndicator(
                      value: (index + 1) / questions.length,
                      color: teal,
                      backgroundColor: const Color(0xffe4e9f7),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Expanded(
                          child: Text(
                            'Interest profile  ·  ${(index + 1) * 100 ~/ questions.length}% complete',
                            style: const TextStyle(color: muted, fontSize: 12),
                          ),
                        ),
                        pill(
                          'Question ${index + 1}',
                          color: const Color(0xff52617b),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    pill(
                      'PHASE ${(index ~/ 3) + 1}: WORK TENDENCIES',
                      color: const Color(0xffdff4f1),
                    ),
                    const SizedBox(height: 13),
                    heading(
                      question['prompt'],
                      size: MediaQuery.sizeOf(context).width < 700 ? 25 : 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      question['helperText'] ??
                          'Select the approach that comes naturally rather than what you feel you should do.',
                      style: const TextStyle(color: muted, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 680 ? 2 : 1;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: options.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                mainAxisExtent: 150,
                              ),
                          itemBuilder: (context, optionIndex) {
                            final option = options[optionIndex];
                            final selected = answers[index] == optionIndex;
                            final optionScores =
                                option['scores'] as Map<String, dynamic>;
                            final trait = optionScores.keys.isEmpty
                                ? 'Career interests'
                                : traits[optionScores.keys.first] ??
                                      'Career interests';
                            return Card(
                              color: selected
                                  ? const Color(0xffedf7f5)
                                  : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                                side: BorderSide(
                                  color: selected ? teal : line,
                                  width: selected ? 1.5 : 1,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(13),
                                onTap: () => setState(() {
                                  answers[index] = optionIndex;
                                  Hive.box('pathfinder').put(
                                    'quizAnswers',
                                    answers.map(
                                      (key, value) =>
                                          MapEntry(key.toString(), value),
                                    ),
                                  );
                                }),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 13,
                                            backgroundColor: selected
                                                ? teal
                                                : const Color(0xffedf1fb),
                                            child: selected
                                                ? const Icon(
                                                    Icons.check,
                                                    color: Colors.white,
                                                    size: 15,
                                                  )
                                                : Text(
                                                    String.fromCharCode(
                                                      65 + optionIndex,
                                                    ),
                                                    style: const TextStyle(
                                                      color: ink,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Option ${String.fromCharCode(65 + optionIndex)}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Flexible(
                                            child: pill(
                                              trait,
                                              color: selected
                                                  ? teal
                                                  : const Color(0xff52617b),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Expanded(
                                        child: Text(
                                          option['label'],
                                          style: GoogleFonts.playfairDisplay(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                      if (selected)
                                        const Text(
                                          'Selected',
                                          style: TextStyle(
                                            color: teal,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          onPressed: index > 0
                              ? () => setState(() => index--)
                              : () => context.go('/'),
                          child: const Text('Previous question'),
                        ),
                        const Text(
                          'Draft saved automatically',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                        FilledButton.icon(
                          onPressed: answers.containsKey(index)
                              ? () => setState(() => index++)
                              : null,
                          icon: const Icon(Icons.arrow_forward, size: 17),
                          label: Text(
                            index == questions.length - 1
                                ? 'See my matches'
                                : 'Next question',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

  Widget _results(BuildContext context, AppData data) {
    final traitScores = <String, int>{};
    final possibleByTrait = <String, int>{};
    answers.forEach((questionIndex, selectedIndex) {
      final options = data.quiz['questions'][questionIndex]['options'] as List;
      final scores = options[selectedIndex]['scores'] as Map<String, dynamic>;
      scores.forEach(
        (key, value) =>
            traitScores[key] = (traitScores[key] ?? 0) + (value as num).toInt(),
      );
      final questionMax = <String, int>{};
      for (final option in options) {
        (option['scores'] as Map<String, dynamic>).forEach((key, value) {
          final points = (value as num).toInt();
          if (points > (questionMax[key] ?? 0)) questionMax[key] = points;
        });
      }
      questionMax.forEach(
        (key, value) =>
            possibleByTrait[key] = (possibleByTrait[key] ?? 0) + value,
      );
    });
    final weights =
        data.quiz['version']['traitWeightsByCareer'] as Map<String, dynamic>;
    final traitNames = data.quiz['version']['traits'] as Map<String, dynamic>;
    final ranked =
        data.records.map((record) {
          final career = record['career'];
          final careerWeights =
              weights[career['id']] as Map<String, dynamic>? ??
              <String, dynamic>{};
          var earned = 0.0, possible = 0.0;
          careerWeights.forEach((trait, weight) {
            final factor = (weight as num).toDouble();
            earned += (traitScores[trait] ?? 0) * factor;
            possible += (possibleByTrait[trait] ?? 0) * factor;
          });
          return {
            'record': record,
            'score': possible == 0 ? 0.0 : earned / possible,
          };
        }).toList()..sort(
          (a, b) => (b['score'] as double).compareTo(a['score'] as double),
        );
    final top = ranked.take(3).toList();
    if (!resultsSaved) {
      resultsSaved = true;
      final answerData = answers.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final careerIds = top
          .map(
            (entry) =>
                (entry['record'] as Map<String, dynamic>)['career']['id']
                    as String,
          )
          .toList();
      final resultData = {
        'quizVersionId': 'v1',
        'answers': answerData,
        'recommendedCareerIds': careerIds,
      };
      Hive.box('pathfinder').put('quizResult', resultData);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final user = Firebase.apps.isEmpty
            ? null
            : FirebaseAuth.instance.currentUser;
        if (user != null) {
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('quizResults')
              .add({...resultData, 'createdAt': FieldValue.serverTimestamp()});
        }
      });
    }
    return PageFrame(
      width: 1120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          pill('LIVE ALIGNMENT ENGINE'),
          const SizedBox(height: 10),
          heading('Your Top 3 Career Matches', size: 34),
          const SizedBox(height: 5),
          const Text(
            'Dynamic recommendations synthesized from the interests you selected.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 16),
          ...top.asMap().entries.map((entry) {
            final record = entry.value['record'] as Map<String, dynamic>;
            final career = record['career'];
            final score = entry.value['score'] as double;
            final careerWeights =
                weights[career['id']] as Map<String, dynamic>? ??
                <String, dynamic>{};
            final matchingTraits = careerWeights.entries.toList()
              ..sort(
                (a, b) => ((traitScores[b.key] ?? 0) * (b.value as num).toInt())
                    .compareTo(
                      (traitScores[a.key] ?? 0) * (a.value as num).toInt(),
                    ),
              );
            final reason = matchingTraits
                .where((item) => (traitScores[item.key] ?? 0) > 0)
                .take(2)
                .map((item) => traitNames[item.key])
                .join(' · ');
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(19),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xffe7f2ef),
                      foregroundColor: teal,
                      child: Text('${entry.key + 1}'),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: heading(career['name'], size: 23),
                              ),
                              pill('${(score * 100).round()}% match'),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            career['summary'],
                            style: const TextStyle(color: muted),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (reason.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 7),
                              child: Text(
                                'Strong interest match: $reason',
                                style: const TextStyle(
                                  color: teal,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () => context.go('/career/${career['id']}'),
                      child: const Text('View roadmap'),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => context.go('/explore'),
                icon: const Icon(Icons.explore_outlined),
                label: const Text('Explore all careers'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(compareProvider.notifier).state = top
                      .map(
                        (entry) =>
                            (entry['record']
                                    as Map<String, dynamic>)['career']['id']
                                as String,
                      )
                      .toSet();
                  context.go('/compare');
                },
                icon: const Icon(Icons.compare_arrows),
                label: const Text('Compare all three'),
              ),
              TextButton.icon(
                onPressed: () => setState(() {
                  answers.clear();
                  index = 0;
                  resultsSaved = false;
                  Hive.box('pathfinder').delete('quizAnswers');
                }),
                icon: const Icon(Icons.refresh),
                label: const Text('Retake assessment'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ComparePage extends ConsumerWidget {
  const ComparePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(dataProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('$error')),
        data: (data) {
          final selected = ref.watch(compareProvider);
          final records = data.records
              .where((record) => selected.contains(record['career']['id']))
              .toList();
          return PageFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                sectionTitle(
                  'Compare career paths',
                  'Line up a few options and compare the skills, timelines, and roadmap structure.',
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: data.records.map((record) {
                    final career = record['career'];
                    final id = career['id'] as String;
                    final active = selected.contains(id);
                    return FilterChip(
                      label: Text(career['name']),
                      selected: active,
                      onSelected: (_) =>
                          ref.read(compareProvider.notifier).update((ids) {
                            final next = <String>{...ids};
                            active ? next.remove(id) : next.add(id);
                            return next;
                          }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                if (records.length < 2)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Row(
                        children: [
                          const Icon(Icons.compare_arrows, color: teal),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Select at least two careers to compare. Selected: ${records.length}',
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go('/explore'),
                            child: const Text('Browse careers'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 700;
                      return SingleChildScrollView(
                        scrollDirection: compact
                            ? Axis.horizontal
                            : Axis.vertical,
                        child: compact
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: records
                                    .map(
                                      (record) => SizedBox(
                                        width: 300,
                                        child: _compareCard(record, ref),
                                      ),
                                    )
                                    .toList(),
                              )
                            : Column(
                                children: records
                                    .map((record) => _compareCard(record, ref))
                                    .toList(),
                              ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      );
  Widget _compareCard(Map<String, dynamic> record, WidgetRef ref) {
    final career = record['career'];
    final roadmap = record['roadmap'];
    final id = career['id'] as String;
    final skills = (career['skills'] as List)
        .map((skill) => skill['name'])
        .join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: heading(career['name'], size: 21)),
                IconButton(
                  tooltip: 'Remove from comparison',
                  onPressed: () => ref
                      .read(compareProvider.notifier)
                      .update((ids) => {...ids}..remove(id)),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(career['summary'], style: const TextStyle(color: muted)),
            const Divider(height: 24),
            _compareRow(
              'Time to role readiness',
              '${career['timeToEntry']['minMonths']}–${career['timeToEntry']['maxMonths']} months',
            ),
            _compareRow(
              'Roadmap',
              '${(roadmap['stages'] as List).length} stages',
            ),
            _compareRow('Skills', skills),
          ],
        ),
      ),
    );
  }

  Widget _compareRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(value),
      ],
    ),
  );
}

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(dataProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('$error')),
        data: (data) {
          final user = Firebase.apps.isEmpty
              ? null
              : FirebaseAuth.instance.currentUser;
          final savedName = ref.watch(displayNameProvider);
          final name = user?.displayName?.trim().isNotEmpty == true
              ? user!.displayName!
              : savedName.isNotEmpty
              ? savedName
              : 'Guest learner';
          final progress = ref.watch(progressProvider);
          final saved = ref.watch(savedProvider);
          final study = ref.watch(studyLogProvider);
          final weeklyGoal = ref.watch(weeklyGoalProvider);
          final result = Hive.box('pathfinder').get('quizResult') as Map?;
          final resultIds = (result?['recommendedCareerIds'] as List? ?? [])
              .map((value) => value.toString())
              .toList();
          final activeIds = progress.keys.toList();
          final totalHours = study.values.fold<double>(
            0,
            (total, hours) => total + hours,
          );
          final tasksComplete = progress.values.fold<int>(
            0,
            (total, ids) => total + ids.length,
          );
          final overviewKey = GlobalKey(),
              alignmentKey = GlobalKey(),
              credentialsKey = GlobalKey(),
              scheduleKey = GlobalKey(),
              accountKey = GlobalKey();
          final nav = <String, GlobalKey>{
            'Profile overview': overviewKey,
            'Career alignment & quiz': alignmentKey,
            'Learning goals & schedule': scheduleKey,
            'Progress milestones': credentialsKey,
            'Account & privacy': accountKey,
          };
          return PageFrame(
            width: 1280,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.home_outlined, size: 16),
                      label: const Text('Home'),
                    ),
                    const Text('›'),
                    const Text(
                      'Account settings  ›  Profile overview',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    pill(
                      user == null
                          ? 'Guest profile · This device'
                          : 'Signed in · Cloud sync',
                      color: user == null ? muted : teal,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  key: overviewKey,
                  child: Padding(
                    padding: EdgeInsets.all(
                      MediaQuery.sizeOf(context).width < 700 ? 18 : 28,
                    ),
                    child: Column(
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final avatar = CircleAvatar(
                              radius: 34,
                              backgroundColor: const Color(0xffe1f0ed),
                              child: Text(
                                name.trim().isEmpty
                                    ? 'P'
                                    : name
                                          .trim()
                                          .characters
                                          .first
                                          .toUpperCase(),
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w700,
                                  color: teal,
                                ),
                              ),
                            );
                            final details = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Text(
                                      name,
                                      style: GoogleFonts.playfairDisplay(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w700,
                                        color: ink,
                                      ),
                                    ),
                                    if (user != null) pill('MEMBER'),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user?.email ??
                                      'Your progress stays in this browser until you sign in.',
                                  style: const TextStyle(color: muted),
                                ),
                                const SizedBox(height: 10),
                                if (activeIds.isNotEmpty)
                                  Text(
                                    'Active pathway: ${data.byId(activeIds.first)['career']['name']} · $tasksComplete tasks completed',
                                    style: const TextStyle(
                                      color: teal,
                                      fontSize: 13,
                                    ),
                                  ),
                              ],
                            );
                            final actions = Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _editProfile(context, ref, name, user),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 17,
                                  ),
                                  label: const Text('Edit profile'),
                                ),
                                if (user == null)
                                  FilledButton.tonal(
                                    onPressed: Firebase.apps.isEmpty
                                        ? null
                                        : () => showDialog(
                                            context: context,
                                            builder: (_) => const AuthDialog(),
                                          ),
                                    child: const Text('Sign in'),
                                  ),
                              ],
                            );
                            if (constraints.maxWidth < 900) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      avatar,
                                      const SizedBox(width: 16),
                                      Expanded(child: details),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  actions,
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                avatar,
                                const SizedBox(width: 16),
                                Expanded(child: details),
                                const SizedBox(width: 16),
                                actions,
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 22),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final cols = constraints.maxWidth > 780 ? 4 : 2;
                            final stats = [
                              _profileStat(
                                '${totalHours.toStringAsFixed(1)}',
                                'Study hours logged',
                                Icons.schedule,
                              ),
                              _profileStat(
                                '$tasksComplete',
                                'Tasks completed',
                                Icons.flag_outlined,
                              ),
                              _profileStat(
                                '${saved.length}',
                                'Saved career paths',
                                Icons.bookmark_border,
                              ),
                              _profileStat(
                                '${resultIds.length}',
                                'Quiz matches',
                                Icons.auto_awesome,
                              ),
                            ];
                            return GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: cols,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: cols == 4 ? 2.4 : 2.0,
                              children: stats,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final details = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          key: alignmentKey,
                          child: Padding(
                            padding: const EdgeInsets.all(21),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.track_changes,
                                      color: teal,
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: heading(
                                        'Career transition target & propensities',
                                        size: 22,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => context.go('/quiz'),
                                      child: const Text('Retake quiz'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  'Recommendations reflect your quiz choices and stay on this device in guest mode.',
                                  style: TextStyle(color: muted),
                                ),
                                const SizedBox(height: 14),
                                if (resultIds.isEmpty)
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Take the career interest quiz to create a personalized shortlist.',
                                          style: TextStyle(color: muted),
                                        ),
                                      ),
                                      FilledButton.tonal(
                                        onPressed: () => context.go('/quiz'),
                                        child: const Text('Start quiz'),
                                      ),
                                    ],
                                  )
                                else
                                  ...resultIds
                                      .take(3)
                                      .toList()
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                        final record = data.byId(entry.value);
                                        final career = record['career'];
                                        return ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: CircleAvatar(
                                            backgroundColor: const Color(
                                              0xffeaf0fb,
                                            ),
                                            child: Text(
                                              '${entry.key + 1}',
                                              style: const TextStyle(
                                                color: teal,
                                              ),
                                            ),
                                          ),
                                          title: Text(
                                            career['name'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          subtitle: Text(
                                            career['summary'],
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          trailing: TextButton(
                                            onPressed: () => context.go(
                                              '/career/${career['id']}',
                                            ),
                                            child: const Text('View path'),
                                          ),
                                        );
                                      }),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Card(
                          key: credentialsKey,
                          child: Padding(
                            padding: const EdgeInsets.all(21),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.workspace_premium_outlined,
                                      color: teal,
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: heading(
                                        'Progress milestones & portfolio',
                                        size: 22,
                                      ),
                                    ),
                                    pill('$tasksComplete complete'),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  'Your completed roadmap work is tracked here. Pathfinder does not label work as verified unless it has been reviewed.',
                                  style: TextStyle(color: muted),
                                ),
                                const Divider(height: 24),
                                if (tasksComplete == 0)
                                  const Text(
                                    'No milestones completed yet. Check off roadmap tasks as you complete them to build your learning record.',
                                    style: TextStyle(color: muted),
                                  )
                                else
                                  ...activeIds.map((careerId) {
                                    final career = data.byId(
                                      careerId,
                                    )['career'];
                                    final count =
                                        progress[careerId]?.length ?? 0;
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(
                                        Icons.check_circle_outline,
                                        color: teal,
                                      ),
                                      title: Text(career['name']),
                                      subtitle: Text(
                                        '$count roadmap task${count == 1 ? '' : 's'} completed',
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Card(
                          key: scheduleKey,
                          child: Padding(
                            padding: const EdgeInsets.all(21),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_month_outlined,
                                      color: teal,
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: heading(
                                        'Learning schedule & habit preferences',
                                        size: 22,
                                      ),
                                    ),
                                    pill('$weeklyGoal hrs / week'),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  'Set a realistic weekly target, then log time from My Journey.',
                                  style: TextStyle(color: muted),
                                ),
                                const SizedBox(height: 15),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final days = List.generate(7, (i) {
                                      final date = DateTime.now().subtract(
                                        Duration(days: 6 - i),
                                      );
                                      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                                    });
                                    final values = days
                                        .map((key) => study[key] ?? 0)
                                        .toList();
                                    final maxValue = values.fold<double>(
                                      1,
                                      (maximum, value) =>
                                          value > maximum ? value : maximum,
                                    );
                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: List.generate(
                                        7,
                                        (i) => Expanded(
                                          child: Column(
                                            children: [
                                              SizedBox(
                                                height: 70,
                                                child: Align(
                                                  alignment:
                                                      Alignment.bottomCenter,
                                                  child: Container(
                                                    width: 23,
                                                    height:
                                                        6 +
                                                        58 *
                                                            values[i] /
                                                            maxValue,
                                                    decoration: BoxDecoration(
                                                      color: values[i] > 0
                                                          ? teal
                                                          : const Color(
                                                              0xffdbe5ed,
                                                            ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                [
                                                  'M',
                                                  'T',
                                                  'W',
                                                  'T',
                                                  'F',
                                                  'S',
                                                  'S',
                                                ][DateTime.parse(
                                                      days[i],
                                                    ).weekday -
                                                    1],
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: muted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _editWeeklyGoal(context, ref, weeklyGoal),
                                  icon: const Icon(Icons.tune),
                                  label: const Text('Change weekly study goal'),
                                ),
                                const Divider(height: 25),
                                const Text(
                                  'NOTIFICATIONS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: muted,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: .7,
                                  ),
                                ),
                                _notificationSetting(
                                  context,
                                  ref,
                                  'weeklyReminder',
                                  'Weekly progress reminder',
                                  'A gentle reminder to check in on your roadmap.',
                                ),
                                _notificationSetting(
                                  context,
                                  ref,
                                  'productUpdates',
                                  'Career roadmap updates',
                                  'Updates when career content is reviewed and refreshed.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                    final sidebar = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ACCOUNT NAVIGATION',
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: .8,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                ...nav.entries.map(
                                  (entry) => TextButton.icon(
                                    onPressed: () {
                                      final target = entry.value.currentContext;
                                      if (target != null)
                                        Scrollable.ensureVisible(
                                          target,
                                          duration: const Duration(
                                            milliseconds: 400,
                                          ),
                                          alignment: .05,
                                        );
                                    },
                                    icon: const Icon(
                                      Icons.chevron_right,
                                      size: 18,
                                    ),
                                    label: Text(entry.key),
                                    style: TextButton.styleFrom(
                                      alignment: Alignment.centerLeft,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(17),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.contrast, color: teal),
                                const SizedBox(height: 8),
                                heading('Appearance', size: 20),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  children: ThemeMode.values
                                      .map(
                                        (mode) => ChoiceChip(
                                          label: Text(mode.name),
                                          selected:
                                              ref.watch(themeModeProvider) ==
                                              mode,
                                          onSelected: (_) {
                                            ref
                                                    .read(
                                                      themeModeProvider
                                                          .notifier,
                                                    )
                                                    .state =
                                                mode;
                                            Hive.box(
                                              'pathfinder',
                                            ).put('themeMode', mode.name);
                                            _syncUserField(user, {
                                              'theme': mode.name,
                                            });
                                          },
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          key: accountKey,
                          child: Padding(
                            padding: const EdgeInsets.all(17),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                heading('Account & privacy', size: 20),
                                const SizedBox(height: 8),
                                if (user != null)
                                  TextButton.icon(
                                    onPressed: () async {
                                      await FirebaseAuth.instance.signOut();
                                    },
                                    icon: const Icon(Icons.logout),
                                    label: const Text('Sign out'),
                                  ),
                                if (user != null)
                                  TextButton.icon(
                                    onPressed: () =>
                                        _confirmDeleteAccount(context, user),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    label: const Text(
                                      'Delete account',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                const Text(
                                  'Your career choices and progress are private to your account.',
                                  style: TextStyle(color: muted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                    if (constraints.maxWidth < 920)
                      return Column(
                        children: [
                          details,
                          const SizedBox(height: 14),
                          sidebar,
                        ],
                      );
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: details),
                        const SizedBox(width: 18),
                        Expanded(flex: 3, child: sidebar),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      );
}

Widget _profileStat(String value, String label, IconData icon) => Card(
  child: Padding(
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xffe9f2f1),
          child: Icon(icon, color: teal, size: 18),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: GoogleFonts.playfairDisplay(
                  fontWeight: FontWeight.w700,
                  fontSize: 21,
                ),
              ),
              Text(
                label,
                maxLines: 2,
                style: const TextStyle(color: muted, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
);

Widget _notificationSetting(
  BuildContext context,
  WidgetRef ref,
  String key,
  String title,
  String subtitle,
) {
  final settings = ref.watch(notificationsProvider);
  return SwitchListTile(
    contentPadding: EdgeInsets.zero,
    value: settings[key] ?? false,
    title: Text(title, style: const TextStyle(fontSize: 14)),
    subtitle: Text(
      subtitle,
      style: const TextStyle(fontSize: 12, color: muted),
    ),
    onChanged: (value) {
      final next = <String, bool>{...settings, key: value};
      ref.read(notificationsProvider.notifier).state = next;
      Hive.box('pathfinder').put('notifications', next);
      final user = Firebase.apps.isEmpty
          ? null
          : FirebaseAuth.instance.currentUser;
      if (user != null)
        FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'notificationPreferences': next,
        }, SetOptions(merge: true));
    },
  );
}

Future<void> _editProfile(
  BuildContext context,
  WidgetRef ref,
  String currentName,
  User? user,
) async {
  final controller = TextEditingController(
    text: currentName == 'Guest learner' ? '' : currentName,
  );
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Edit profile'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 60,
        decoration: const InputDecoration(labelText: 'Display name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final name = controller.text.trim();
            if (name.isEmpty) return;
            ref.read(displayNameProvider.notifier).state = name;
            Hive.box('pathfinder').put('displayName', name);
            if (user != null) {
              await user.updateDisplayName(name);
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .set({'displayName': name}, SetOptions(merge: true));
            }
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          },
          child: const Text('Save profile'),
        ),
      ],
    ),
  );
}

Future<void> _editWeeklyGoal(
  BuildContext context,
  WidgetRef ref,
  int current,
) async {
  var goal = current.toDouble();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Weekly study goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${goal.round()} hours per week',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            Slider(
              value: goal,
              min: 2,
              max: 40,
              divisions: 38,
              label: '${goal.round()} hrs',
              onChanged: (value) => setState(() => goal = value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(weeklyGoalProvider.notifier).state = goal.round();
              Hive.box('pathfinder').put('weeklyGoal', goal.round());
              final user = Firebase.apps.isEmpty
                  ? null
                  : FirebaseAuth.instance.currentUser;
              if (user != null)
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .set({
                      'weeklyHours': goal.round(),
                    }, SetOptions(merge: true));
              Navigator.pop(dialogContext);
            },
            child: const Text('Save goal'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _syncUserField(User? user, Map<String, dynamic> fields) async {
  if (user != null)
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(fields, SetOptions(merge: true));
}

Future<void> _confirmDeleteAccount(BuildContext context, User user) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete your account?'),
      content: const Text(
        'This permanently removes your Pathfinder profile, saved careers, quiz results, tracks, task progress, and sign-in account.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Delete account'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    final root = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final tracks = await root.collection('careerTracks').get();
    for (final track in tracks.docs) {
      final tasks = await track.reference.collection('taskProgress').get();
      for (var i = 0; i < tasks.docs.length; i += 400) {
        final batch = FirebaseFirestore.instance.batch();
        for (final task in tasks.docs.skip(i).take(400)) {
          batch.delete(task.reference);
        }
        await batch.commit();
      }
      await track.reference.delete();
    }
    for (final collection in ['savedCareers', 'quizResults']) {
      final docs = await root.collection(collection).get();
      for (var i = 0; i < docs.docs.length; i += 400) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in docs.docs.skip(i).take(400)) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }
    await root.delete();
    await user.delete();
    Hive.box('pathfinder').clear();
    if (context.mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Account deleted.')));
  } catch (error) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Account deletion failed. Sign in again if Firebase requires recent authentication. $error',
          ),
        ),
      );
  }
}

class AuthDialog extends ConsumerStatefulWidget {
  const AuthDialog({super.key});
  @override
  ConsumerState<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends ConsumerState<AuthDialog> {
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  bool register = false, busy = false;
  String? error;
  Future<void> mergeProgress(User user) async {
    final db = FirebaseFirestore.instance;
    final uid = user.uid;
    final box = Hive.box('pathfinder');
    final appData = await ref.read(dataProvider.future);
    final profileRef = db.collection('users').doc(uid);
    final remoteProfile = await profileRef.get();
    final remoteData = remoteProfile.data() ?? <String, dynamic>{};
    final remoteSaved = await profileRef.collection('savedCareers').get();
    final mergedSaved = <String>{
      ...ref.read(savedProvider),
      ...remoteSaved.docs.map((doc) => doc.id),
    };
    final mergedProgress = <String, Set<String>>{
      ...ref
          .read(progressProvider)
          .map((key, value) => MapEntry(key, <String>{...value})),
    };
    final remoteTracks = await profileRef.collection('careerTracks').get();
    for (final track in remoteTracks.docs) {
      final tasks = await track.reference.collection('taskProgress').get();
      mergedProgress
          .putIfAbsent(track.id, () => <String>{})
          .addAll(tasks.docs.map((doc) => doc.id));
    }
    final remoteStudy = remoteData['studyHoursByDate'] is Map
        ? remoteData['studyHoursByDate'] as Map
        : <String, dynamic>{};
    final localStudy = ref.read(studyLogProvider);
    final mergedStudy = <String, double>{};
    remoteStudy.forEach(
      (key, value) => mergedStudy[key.toString()] = (value as num).toDouble(),
    );
    localStudy.forEach((key, value) {
      mergedStudy[key] = value > (mergedStudy[key] ?? 0)
          ? value
          : mergedStudy[key]!;
    });
    final int goal =
        (remoteData['weeklyHours'] as num?)?.toInt() ??
        ref.read(weeklyGoalProvider);
    final notificationsData = remoteData['notificationPreferences'];
    final mergedNotifications = notificationsData is Map
        ? notificationsData.map(
            (key, value) => MapEntry(key.toString(), value as bool),
          )
        : ref.read(notificationsProvider);
    ref.read(savedProvider.notifier).state = mergedSaved;
    ref.read(progressProvider.notifier).state = mergedProgress;
    ref.read(studyLogProvider.notifier).state = mergedStudy;
    ref.read(weeklyGoalProvider.notifier).state = goal;
    ref.read(notificationsProvider.notifier).state = Map<String, bool>.from(
      mergedNotifications,
    );
    box.put('saved', mergedSaved.toList());
    box.put(
      'progress',
      mergedProgress.map((key, value) => MapEntry(key, value.toList())),
    );
    box.put('studyLog', mergedStudy);
    box.put('weeklyGoal', goal);
    box.put('notifications', mergedNotifications);
    final localResult = box.get('quizResult');
    final operations = <void Function(WriteBatch)>[];
    final profileFields = <String, dynamic>{
      'email': user.email,
      'updatedAt': FieldValue.serverTimestamp(),
      'studyHoursByDate': mergedStudy,
      'weeklyHours': goal,
      'notificationPreferences': mergedNotifications,
    };
    final displayName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName
        : box.get('displayName') as String?;
    if (displayName != null && displayName.isNotEmpty) {
      profileFields['displayName'] = displayName;
    }
    operations.add(
      (batch) => batch.set(profileRef, profileFields, SetOptions(merge: true)),
    );
    for (final id in mergedSaved) {
      final doc = profileRef.collection('savedCareers').doc(id);
      operations.add(
        (batch) => batch.set(doc, {
          'careerId': id,
          'savedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
      );
    }
    for (final entry in mergedProgress.entries) {
      final track = profileRef.collection('careerTracks').doc(entry.key);
      operations.add(
        (batch) => batch.set(track, {
          'careerId': entry.key,
          'roadmapVersionId': appData.byId(entry.key)['roadmap']['id'],
          'status': 'active',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
      );
      for (final taskId in entry.value) {
        final task = track.collection('taskProgress').doc(taskId);
        operations.add(
          (batch) => batch.set(task, {
            'status': 'completed',
            'completedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)),
        );
      }
    }
    if (localResult is Map) {
      final doc = profileRef.collection('quizResults').doc('guest-latest');
      operations.add(
        (batch) => batch.set(doc, {
          ...Map<String, dynamic>.from(localResult),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
      );
    }
    for (var i = 0; i < operations.length; i += 400) {
      final batch = db.batch();
      for (final operation in operations.skip(i).take(400)) {
        operation(batch);
      }
      await batch.commit();
    }
    box.put('signedInUid', uid);
  }

  Future<void> submit({bool google = false}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      UserCredential credential;
      if (google) {
        credential = await auth.signInWithPopup(GoogleAuthProvider());
      } else if (register) {
        credential = await auth.createUserWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
        await credential.user?.updateDisplayName(name.text.trim());
      } else {
        credential = await auth.signInWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
      if (credential.user != null) await mergeProgress(credential.user!);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(
        () => error = e.toString().replaceFirst('FirebaseAuthException: ', ''),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      register ? 'Create your account' : 'Welcome back',
      style: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w700),
    ),
    content: SizedBox(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (register)
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'Your name',
                border: OutlineInputBorder(),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy ? null : () => submit(google: true),
            icon: const Icon(Icons.account_circle_outlined),
            label: const Text('Continue with Google'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => setState(() {
          register = !register;
          error = null;
        }),
        child: Text(register ? 'I have an account' : 'Create account'),
      ),
      FilledButton(
        onPressed: busy ? null : () => submit(),
        child: Text(
          busy
              ? 'Please wait…'
              : register
              ? 'Create account'
              : 'Sign in',
        ),
      ),
    ],
  );
}
