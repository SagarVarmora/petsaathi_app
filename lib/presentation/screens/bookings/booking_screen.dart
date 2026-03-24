import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/pet_repository.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../widgets/common/common_widgets.dart';

class BookingScreen extends StatefulWidget {
  final String serviceId;
  const BookingScreen({super.key, required this.serviceId});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  String? _selectedPetId;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final _notesController = TextEditingController();
  bool _isLoading = false;

  Map<String, dynamic> get _service => AppConstants.services.firstWhere(
        (s) => s['id'] == widget.serviceId,
        orElse: () => AppConstants.services.first,
      );

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _book() async {
    if (_selectedPetId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please select a pet')));
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select date and time')));
      return;
    }

    setState(() => _isLoading = true);

    final petRepo = context.read<PetRepository>();
    final bookingRepo = context.read<BookingRepository>();
    final pet = petRepo.getPetById(_selectedPetId!);

    final scheduledAt = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    final booking = await bookingRepo.createBooking(
      serviceId: _service['id'],
      serviceTitle: _service['title'],
      petId: _selectedPetId!,
      petName: pet?.name ?? '',
      scheduledAt: scheduledAt,
      price: _service['price'],
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

    context.pushReplacement(AppConstants.routeBookingConfirm, extra: {
      'booking': booking,
      'service': _service,
      'petName': pet?.name ?? '',
    });
  }

  @override
  Widget build(BuildContext context) {
    final pets = context.watch<PetRepository>().pets;
    final s = _service;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(s['title'] ?? ''),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // ── Service Summary ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(s['icon'] ?? '🐾',
                        style: const TextStyle(fontSize: 28)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['title'] ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          )),
                      const SizedBox(height: 4),
                      Text(s['description'] ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text('₹${s['price']}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                              )),
                          const SizedBox(width: 4),
                          Text(s['unit'] ?? '',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary)),
                          const Spacer(),
                          const Icon(Icons.access_time_rounded,
                              size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 3),
                          Text(s['duration'] ?? '',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Select Pet ────────────────────────────────────────────────────
          const Text('Select Pet *',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 12),

          if (pets.isEmpty)
            InfoBanner(
              message: 'No pets added yet. Add a pet first to book a service.',
              backgroundColor: Colors.orange.shade50,
              iconColor: Colors.orange,
            )
          else
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: pets.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => PetAvatarCard(
                  name: pets[i].name,
                  breed: pets[i].breed,
                  emoji: pets[i].emoji,
                  isSelected: _selectedPetId == pets[i].id,
                  onTap: () => setState(() => _selectedPetId = pets[i].id),
                ),
              ),
            ),

          const SizedBox(height: 24),

          // ── Select Date ───────────────────────────────────────────────────
          const Text('Select Date *',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedDate != null
                      ? AppTheme.primary
                      : AppTheme.inputBorder,
                  width: _selectedDate != null ? 2 : 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded,
                      color: _selectedDate != null
                          ? AppTheme.primary
                          : AppTheme.textHint,
                      size: 20),
                  const SizedBox(width: 10),
                  Text(
                    _selectedDate != null
                        ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                        : 'Choose a date',
                    style: TextStyle(
                      fontSize: 15,
                      color: _selectedDate != null
                          ? AppTheme.textPrimary
                          : AppTheme.textHint,
                      fontWeight: _selectedDate != null
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Select Time ───────────────────────────────────────────────────
          const Text('Select Time *',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _pickTime,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedTime != null
                      ? AppTheme.primary
                      : AppTheme.inputBorder,
                  width: _selectedTime != null ? 2 : 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time_rounded,
                      color: _selectedTime != null
                          ? AppTheme.primary
                          : AppTheme.textHint,
                      size: 20),
                  const SizedBox(width: 10),
                  Text(
                    _selectedTime != null
                        ? _selectedTime!.format(context)
                        : 'Choose a time',
                    style: TextStyle(
                      fontSize: 15,
                      color: _selectedTime != null
                          ? AppTheme.textPrimary
                          : AppTheme.textHint,
                      fontWeight: _selectedTime != null
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Notes ─────────────────────────────────────────────────────────
          const Text('Special Instructions (optional)',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 10),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'e.g., My dog gets nervous around strangers...',
            ),
          ),

          const SizedBox(height: 32),

          // ── Price Summary ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primarySurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Amount',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                Text('₹${s['price']}',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          PrimaryButton(
            label: 'Confirm Booking',
            onPressed: _book,
            isLoading: _isLoading,
            icon: Icons.check_circle_outline_rounded,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
