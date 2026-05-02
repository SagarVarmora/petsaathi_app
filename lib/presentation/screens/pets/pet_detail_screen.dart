import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/pet_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/models/category_model.dart';
import '../../widgets/common/common_widgets.dart';

class PetDetailScreen extends StatefulWidget {
  final String petId;
  const PetDetailScreen({super.key, required this.petId});

  @override
  State<PetDetailScreen> createState() => _PetDetailScreenState();
}

class _PetDetailScreenState extends State<PetDetailScreen> {
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PetRepository>().fetchPetDetail(widget.petId);
      // Fetch categories if not already loaded
      final catRepo = context.read<CategoryRepository>();
      if (catRepo.categories.isEmpty && !catRepo.isLoading) {
        catRepo.fetchCategories();
      }
    });
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final pet = context.read<PetRepository>().getPetById(widget.petId);
    if (pet == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove ${pet.name}?'),
        content: const Text(
            "This will permanently delete your pet's profile."),
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

    if (confirm != true || !mounted) return;

    setState(() => _isDeleting = true);
    final result =
    await context.read<PetRepository>().deletePet(widget.petId);
    if (!mounted) return;
    setState(() => _isDeleting = false);

    if (result.isSuccess) {
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.error ?? 'Failed to delete pet.'),
        backgroundColor: AppTheme.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pet = context.watch<PetRepository>().getPetById(widget.petId);
    final catRepo = context.watch<CategoryRepository>();

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
          // ── Sliver App Bar ─────────────────────────────────────────────────
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
                  // TODO: push edit pet screen
                },
              ),
              if (_isDeleting)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.white),
                  onPressed: () => _confirmDelete(context),
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

          // ── Content ────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Quick info tiles ───────────────────────────────────────
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

                  // ── Personality ────────────────────────────────────────────
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
                            orElse: () =>
                            {'emoji': '🐾', 'label': p});
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

                  // ── Notes ──────────────────────────────────────────────────
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
                        border: Border.all(color: AppTheme.divider),
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

                  // ── Book a Service (Dynamic) ────────────────────────────────
                  Row(
                    children: [
                      const Text(
                        'Book a Service',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      if (catRepo.isLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primary),
                        )
                      else
                        GestureDetector(
                          onTap: () => catRepo.fetchCategories(),
                          child: const Icon(Icons.refresh_rounded,
                              color: AppTheme.primary, size: 20),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Loading skeleton
                  if (catRepo.isLoading && catRepo.categories.isEmpty)
                    _buildServiceSkeleton()

                  // Error state
                  else if (catRepo.categories.isEmpty &&
                      catRepo.error != null)
                    InfoBanner(
                      message:
                      'Could not load services. Tap refresh to try again.',
                      backgroundColor: Colors.orange.shade50,
                      iconColor: Colors.orange,
                    )

                  // Empty
                  else if (catRepo.categories.isEmpty)
                      const InfoBanner(
                          message: 'No services available at the moment.')

                    // Dynamic category cards — same as HomeScreen
                    else
                      ...catRepo.categories.map(
                            (cat) => _CategoryCard(
                          category: cat,
                          onSubCategoryTap: (subCat) => context.push(
                            '${AppConstants.routeBooking}/${subCat.id}',
                            extra: {
                              'subCategoryId': subCat.id,
                              'subCategoryName': subCat.name,
                              'categoryName': cat.name,
                              'categoryEmoji': cat.emoji,
                            },
                          ),
                        ),
                      ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceSkeleton() {
    return Column(
      children: List.generate(
        3,
            (i) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.divider),
          ),
          child: const _ShimmerBox(),
        ),
      ),
    );
  }
}

// ── Info Tile ─────────────────────────────────────────────────────────────────
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

// ── Category Card (expandable) — mirrors HomeScreen ───────────────────────────
class _CategoryCard extends StatefulWidget {
  final MainCategory category;
  final void Function(SubCategory) onSubCategoryTap;

  const _CategoryCard({
    required this.category,
    required this.onSubCategoryTap,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _animController;
  late Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _animController.forward() : _animController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;
    final hasSubCategories = cat.subCategories.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _expanded
              ? AppTheme.primary.withOpacity(0.4)
              : AppTheme.divider,
          width: _expanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
          InkWell(
            onTap: hasSubCategories ? _toggle : null,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.primarySurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(cat.emoji,
                          style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasSubCategories
                              ? '${cat.subCategories.length} services available'
                              : 'Tap to explore',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasSubCategories)
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.primary,
                        size: 24,
                      ),
                    )
                  else
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: AppTheme.textHint),
                ],
              ),
            ),
          ),

          // ── Sub-categories ────────────────────────────────────────────────
          if (hasSubCategories)
            SizeTransition(
              sizeFactor: _expandAnim,
              child: Column(
                children: [
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  const SizedBox(height: 8),
                  ...cat.subCategories.map(
                        (sub) => _SubCategoryTile(
                      subCategory: sub,
                      onTap: () => widget.onSubCategoryTap(sub),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Sub-category Tile ─────────────────────────────────────────────────────────
class _SubCategoryTile extends StatelessWidget {
  final SubCategory subCategory;
  final VoidCallback onTap;

  const _SubCategoryTile({
    required this.subCategory,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primarySurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(Icons.pets_rounded,
                    color: AppTheme.primary, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                subCategory.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Book',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shimmer placeholder ───────────────────────────────────────────────────────
class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox();

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.divider,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}