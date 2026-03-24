import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/pet_model.dart';
import '../../../data/repositories/pet_repository.dart';
import '../../widgets/common/common_widgets.dart';

class AddPetScreen extends StatefulWidget {
  const AddPetScreen({super.key});

  @override
  State<AddPetScreen> createState() => _AddPetScreenState();
}

class _AddPetScreenState extends State<AddPetScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedGender = 'Male';
  String _selectedSize   = 'Medium';
  DateTime? _birthday;
  bool _isLoading = false;

  // Personality: multi-select (store selected labels)
  final Set<String> _selectedPersonalities = {};

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _birthdayController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.subtract(const Duration(days: 365)),
      firstDate: DateTime(2000),
      lastDate: now,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppTheme.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _birthday = picked;
        _birthdayController.text =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final pet = PetModel(
      id:             'pet_${DateTime.now().millisecondsSinceEpoch}',
      name:           _nameController.text.trim(),
      breed:          _breedController.text.trim(),
      type:           'Dog', // default; can be inferred from breed later
      birthday:       _birthday,
      gender:         _selectedGender,
      size:           _selectedSize,
      personalities:  _selectedPersonalities.toList(),
      notes:          _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    await context.read<PetRepository>().addPet(pet);
    setState(() => _isLoading = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${pet.name} added successfully! 🐾'),
        backgroundColor: AppTheme.primary,
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Add Pet'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [

            // ── Info Banner ───────────────────────────────────────────────
            const InfoBanner(
              message:
              'Basic profile is required before booking. You can add more details later.',
            ),
            const SizedBox(height: 24),

            // ── Pet Name ──────────────────────────────────────────────────
            _label('Pet Name *'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'e.g., Buddy'),
              validator: (v) =>
              v == null || v.isEmpty ? 'Pet name is required' : null,
            ),

            const SizedBox(height: 20),

            // ── Breed ─────────────────────────────────────────────────────
            _label('Breed *'),
            const SizedBox(height: 10),
            Autocomplete<String>(
              optionsBuilder: (text) {
                final all = [
                  ...AppConstants.dogBreeds,
                  ...AppConstants.catBreeds,
                ];
                if (text.text.isEmpty) return all;
                return all.where((b) =>
                    b.toLowerCase().contains(text.text.toLowerCase()));
              },
              onSelected: (val) => _breedController.text = val,
              fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                _breedController.text = controller.text;
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'e.g., Golden Retriever',
                  ),
                  validator: (v) =>
                  v == null || v.isEmpty ? 'Breed is required' : null,
                );
              },
            ),

            const SizedBox(height: 20),

            // ── Birthday ──────────────────────────────────────────────────
            _label('Birthday *'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _birthdayController,
              readOnly: true,
              onTap: _pickDate,
              decoration: const InputDecoration(
                hintText: 'YYYY-MM-DD',
                suffixIcon: Icon(Icons.calendar_today_outlined,
                    color: AppTheme.primary),
              ),
              validator: (v) =>
              v == null || v.isEmpty ? 'Birthday is required' : null,
            ),

            const SizedBox(height: 20),

            // ── Gender ────────────────────────────────────────────────────
            _label('Gender *'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _GenderButton(
                    label: 'Male',
                    icon: Icons.male_rounded,
                    selected: _selectedGender == 'Male',
                    onTap: () => setState(() => _selectedGender = 'Male'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GenderButton(
                    label: 'Female',
                    icon: Icons.female_rounded,
                    selected: _selectedGender == 'Female',
                    onTap: () => setState(() => _selectedGender = 'Female'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Size ──────────────────────────────────────────────────────
            _label('Size *'),
            const SizedBox(height: 10),
            Row(
              children: AppConstants.petSizes.map((size) {
                final selected = _selectedSize == size;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedSize = size),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(
                        right: size != AppConstants.petSizes.last ? 8 : 0,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.primary : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? AppTheme.primary
                              : AppTheme.inputBorder,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _sizeEmoji(size),
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            size,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // ── Personality ───────────────────────────────────────────────
            Row(
              children: [
                _label('Personality'),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Pick up to 4',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Helps caretakers understand your pet better',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),

            // Personality grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppConstants.petPersonalities.map((p) {
                final label    = p['label']!;
                final emoji    = p['emoji']!;
                final selected = _selectedPersonalities.contains(label);
                return _PersonalityChip(
                  emoji: emoji,
                  label: label,
                  selected: selected,
                  onTap: () {
                    setState(() {
                      if (selected) {
                        _selectedPersonalities.remove(label);
                      } else if (_selectedPersonalities.length < 4) {
                        _selectedPersonalities.add(label);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'You can select up to 4 personalities'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      }
                    });
                  },
                );
              }).toList(),
            ),

            // Selected preview
            if (_selectedPersonalities.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        color: AppTheme.primary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedPersonalities.join(' • '),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ── Notes ─────────────────────────────────────────────────────
            _label('Additional Notes (optional)'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText:
                'Medical conditions, diet preferences, allergies...',
              ),
            ),

            const SizedBox(height: 32),

            // ── Save Button ───────────────────────────────────────────────
            PrimaryButton(
              label: 'Save Pet Profile',
              onPressed: _save,
              isLoading: _isLoading,
              icon: Icons.pets_rounded,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _sizeEmoji(String size) {
    switch (size) {
      case 'Small':      return '🐩';
      case 'Medium':     return '🐕';
      case 'Large':      return '🦮';
      case 'Extra Large': return '🐘';
      default:           return '🐾';
    }
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: AppTheme.textPrimary,
    ),
  );
}

// ── Gender Button ─────────────────────────────────────────────────────────────
class _GenderButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _GenderButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.inputBorder,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Personality Chip ──────────────────────────────────────────────────────────
class _PersonalityChip extends StatelessWidget {
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PersonalityChip({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.inputBorder,
            width: 1.5,
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 4),
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 14),
            ],
          ],
        ),
      ),
    );
  }
}
