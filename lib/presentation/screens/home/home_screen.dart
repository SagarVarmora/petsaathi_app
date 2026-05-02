import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/pet_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/models/category_model.dart';
import '../../widgets/common/common_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PetRepository>().fetchPets();
      context.read<CategoryRepository>().fetchCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthRepository>();
    final petRepo = context.watch<PetRepository>();
    final catRepo = context.watch<CategoryRepository>();
    final pets = petRepo.pets;
    final firstName = auth.userName.split(' ').first;
    final primaryPet = pets.isNotEmpty ? pets.first : null;

    return Scaffold(
      backgroundColor: AppTheme.background,

      // ── AppBar ─────────────────────────────────────────────────────────────
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
                  : 'Welcome to PetSaathi 🐾',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.85),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          if (petRepo.isLoading || catRepo.isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: () {
                context.read<PetRepository>().fetchPets();
                context.read<CategoryRepository>().fetchCategories();
              },
            ),
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

      // ── Body ───────────────────────────────────────────────────────────────
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),

            // ── My Pets ──────────────────────────────────────────────────────
            SectionHeader(
              title: 'My Pets',
              actionLabel: 'Add another pet',
              onAction: () => context.push(AppConstants.routeAddPet),
            ),
            const SizedBox(height: 14),

            if (pets.isEmpty && !petRepo.isLoading)
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
                            Text(
                                'Set up a profile for your furry friend',
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

            // ── Our Services (Dynamic Categories) ────────────────────────────
            const SectionHeader(title: 'Our Services'),
            const SizedBox(height: 14),

            if (catRepo.isLoading && catRepo.categories.isEmpty)
            // Skeleton loading
              _buildCategorySkeleton()
            else if (catRepo.categories.isEmpty && catRepo.error != null)
            // Error state
              InfoBanner(
                message: 'Could not load services. Pull to refresh.',
                backgroundColor: Colors.orange.shade50,
                iconColor: Colors.orange,
              )
            else if (catRepo.categories.isEmpty)
              // Empty state (loaded but no categories)
                const InfoBanner(
                  message: 'No services available at the moment.',
                )
              else
              // Dynamic category cards
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

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySkeleton() {
    return Column(
      children: List.generate(
        3,
            (i) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 100,
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

// ── Category Card ──────────────────────────────────────────────────────────────
// Shows main category with expandable sub-categories
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
    if (_expanded) {
      _animController.forward();
    } else {
      _animController.reverse();
    }
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
          color: _expanded ? AppTheme.primary.withOpacity(0.4) : AppTheme.divider,
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
          // ── Header Row ────────────────────────────────────────────────────
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

          // ── Sub-categories (expandable) ───────────────────────────────────
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

// ── Sub Category Tile ─────────────────────────────────────────────────────────
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

// ── Shimmer placeholder ────────────────────────────────────────────────────────
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