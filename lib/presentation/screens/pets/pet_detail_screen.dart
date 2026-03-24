import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/pet_repository.dart';
import '../../widgets/common/common_widgets.dart';

class PetDetailScreen extends StatelessWidget {
  final String petId;
  const PetDetailScreen({super.key, required this.petId});

  @override
  Widget build(BuildContext context) {
    final pet = context.watch<PetRepository>().getPetById(petId);

    if (pet == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: const EmptyStateWidget(
          emoji: '🐾',
          title: 'Pet not found',
          subtitle: 'This pet may have been removed.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppTheme.primary,
            expandedHeight: 200,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded,
                  color: Colors.white),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
                onPressed: () {
                  // Edit pet — can push edit screen
                },
              ),
              IconButton(
                icon:
                const Icon(Icons.delete_outline, color: Colors.white),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Remove ${pet.name}?'),
                      content: const Text(
                          'This will permanently delete your pet\'s profile.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Remove',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    await context
                        .read<PetRepository>()
                        .deletePet(pet.id);
                    context.pop();
                  }
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppTheme.primary,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(pet.emoji,
                            style: const TextStyle(fontSize: 46)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      pet.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${pet.breed} · ${pet.type}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Quick Info Row ───────────────────────────────────────
                  Row(
                    children: [
                      _InfoTile(
                          icon: Icons.cake_outlined,
                          label: 'Age',
                          value: pet.ageDisplay),
                      const SizedBox(width: 10),
                      _InfoTile(
                          icon: pet.gender == 'Male'
                              ? Icons.male_rounded
                              : Icons.female_rounded,
                          label: 'Gender',
                          value: pet.gender),
                      const SizedBox(width: 10),
                      _InfoTile(
                          icon: Icons.straighten_outlined,
                          label: 'Size',
                          value: pet.size),
                    ],
                  ),

                  // ── Personality ──────────────────────────────────────
                  if (pet.personalities.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('Personality',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        )),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: pet.personalities.map((p) {
                        final match = AppConstants.petPersonalities
                            .firstWhere((m) => m['label'] == p,
                            orElse: () => {'emoji': '🐾', 'label': p});
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppTheme.primarySurface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppTheme.primary.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(match['emoji']!,
                                  style: const TextStyle(fontSize: 15)),
                              const SizedBox(width: 6),
                              Text(p,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primary,
                                  )),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  if (pet.notes != null && pet.notes!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('Notes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        )),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border:
                        Border.all(color: AppTheme.divider),
                      ),
                      child: Text(
                        pet.notes!,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Book a Service ───────────────────────────────────────
                  const Text('Book a Service',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      )),
                  const SizedBox(height: 12),
                  ...AppConstants.services.map(
                        (s) => ServiceCard(
                      service: s,
                      onTap: () => context.push(
                          '${AppConstants.routeBooking}/${s['id']}'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primary, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                )),
            Text(label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                )),
          ],
        ),
      ),
    );
  }
}
