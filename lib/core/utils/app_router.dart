import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../data/repositories/auth_repository.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/otp_screen.dart';
import '../../presentation/screens/auth/setup_name_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/pets/add_pet_screen.dart';
import '../../presentation/screens/pets/pet_detail_screen.dart';
import '../../presentation/screens/bookings/bookings_screen.dart';
import '../../presentation/screens/bookings/booking_screen.dart';
import '../../presentation/screens/bookings/booking_confirm_screen.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/profile/edit_profile_screen.dart';
import '../constants/app_constants.dart';

class AppRouter {
  static GoRouter createRouter(AuthRepository authRepo) {
    return GoRouter(
      initialLocation: AppConstants.routeSplash,
      redirect: (context, state) {
        final isLoggedIn = authRepo.isLoggedIn;
        final isAuthRoute = state.matchedLocation == AppConstants.routeLogin ||
            state.matchedLocation == AppConstants.routeOtp ||
            state.matchedLocation == AppConstants.routeSetupName ||
            state.matchedLocation == AppConstants.routeSplash;

        if (!isLoggedIn && !isAuthRoute) {
          return AppConstants.routeLogin;
        }
        if (isLoggedIn && isAuthRoute) {
          return AppConstants.routeHome;
        }
        return null;
      },
      routes: [
        // ── Splash ──────────────────────────────────────────────────────────
        GoRoute(
          path: AppConstants.routeSplash,
          builder: (context, state) => const SplashScreen(),
        ),

        // ── Auth ────────────────────────────────────────────────────────────
        GoRoute(
          path: AppConstants.routeLogin,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: AppConstants.routeOtp,
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            final phone = extra['phone'] as String? ?? '';
            final flow  = extra['flow']  as String? ?? 'login';
            return OtpScreen(phone: phone, flow: flow);
          },
        ),
        GoRoute(
          path: AppConstants.routeSetupName,
          builder: (context, state) {
            final phone = state.extra as String? ?? '';
            return SetupNameScreen(phone: phone);
          },
        ),

        // ── Main App (Shell with Bottom Nav) ────────────────────────────────
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(
              path: AppConstants.routeHome,
              builder: (context, state) => const HomeScreen(),
            ),
            GoRoute(
              path: AppConstants.routeBookings,
              builder: (context, state) => const BookingsScreen(),
            ),
            GoRoute(
              path: AppConstants.routeProfile,
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),

        // ── Pets ────────────────────────────────────────────────────────────
        GoRoute(
          path: AppConstants.routeAddPet,
          builder: (context, state) => const AddPetScreen(),
        ),
        GoRoute(
          path: '${AppConstants.routePetDetail}/:id',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return PetDetailScreen(petId: id);
          },
        ),

        // ── Services & Booking ───────────────────────────────────────────────
        GoRoute(
          path: '${AppConstants.routeBooking}/:serviceId',
          builder: (context, state) {
            final serviceId = state.pathParameters['serviceId'] ?? '';
            return BookingScreen(serviceId: serviceId);
          },
        ),
        GoRoute(
          path: AppConstants.routeBookingConfirm,
          builder: (context, state) {
            final data = state.extra as Map<String, dynamic>? ?? {};
            return BookingConfirmScreen(bookingData: data);
          },
        ),

        // ── Profile ──────────────────────────────────────────────────────────
        GoRoute(
          path: AppConstants.routeEditProfile,
          builder: (context, state) => const EditProfileScreen(),
        ),
      ],
    );
  }
}

// ── Splash Screen ─────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _scaleAnim = Tween<double>(begin: 0.7, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    final auth = context.read<AuthRepository>();
    if (auth.isLoggedIn) {
      context.go(AppConstants.routeHome);
    } else {
      context.go(AppConstants.routeLogin);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A5C38),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('🐾', style: TextStyle(fontSize: 52)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'PetSaathi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "India's most trusted pet care platform",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Main Shell (Bottom Nav) ───────────────────────────────────────────────────
class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  static const _routes = [
    AppConstants.routeHome,
    AppConstants.routeBookings,
    AppConstants.routeProfile,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFE8F5EE),
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
            context.go(_routes[index]);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today_rounded),
              label: 'Bookings',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}