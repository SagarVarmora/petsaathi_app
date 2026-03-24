import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/pet_repository.dart';
import '../../widgets/common/common_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthRepository>();
    final petRepo = context.watch<PetRepository>();
    final pets = petRepo.pets;
    final firstName = auth.userName.split(' ').first;
    final primaryPet = pets.isNotEmpty ? pets.first : null;

    return Scaffold(
      backgroundColor: AppTheme.background,

      // ── Normal AppBar ────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 70,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, $firstName! 👋',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Text(
              primaryPet != null
                  ? 'How can we care for ${primaryPet.name} today?'
                  : 'Welcome to PetCare 🐾',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.85),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  auth.userName.isNotEmpty
                      ? auth.userName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      // ── Body ─────────────────────────────────────────────────────────────
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),

            // My Pets
            SectionHeader(
              title: 'My Pets',
              actionLabel: 'Add another pet',
              onAction: () => context.push(AppConstants.routeAddPet),
            ),
            const SizedBox(height: 14),

            if (pets.isEmpty)
              GestureDetector(
                onTap: () => context.push(AppConstants.routeAddPet),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppTheme.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text('🐾',
                              style: TextStyle(fontSize: 24)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Add your first pet',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                  fontSize: 15,
                                )),
                            SizedBox(height: 2),
                            Text('Set up a profile for your furry friend',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                )),
                          ],
                        ),
                      ),
                      const Icon(Icons.add_circle_rounded,
                          color: AppTheme.primary, size: 24),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: pets.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    if (i == pets.length) {
                      return GestureDetector(
                        onTap: () =>
                            context.push(AppConstants.routeAddPet),
                        child: Container(
                          width: 88,
                          decoration: BoxDecoration(
                            color: AppTheme.primarySurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppTheme.primary.withOpacity(0.3)),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_circle_outline,
                                  color: AppTheme.primary, size: 28),
                              SizedBox(height: 6),
                              Text('Add pet',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                  )),
                            ],
                          ),
                        ),
                      );
                    }
                    final pet = pets[i];
                    return PetAvatarCard(
                      name: pet.name,
                      breed: pet.breed,
                      emoji: pet.emoji,
                      photoUrl: pet.photoUrl,
                      onTap: () => context.push(
                          '${AppConstants.routePetDetail}/${pet.id}'),
                    );
                  },
                ),
              ),

            const SizedBox(height: 28),

            // Services
            const SectionHeader(title: 'Our Services'),
            const SizedBox(height: 14),

            ...AppConstants.services.map(
                  (s) => ServiceCard(
                service: s,
                onTap: () => context
                    .push('${AppConstants.routeBooking}/${s['id']}'),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}