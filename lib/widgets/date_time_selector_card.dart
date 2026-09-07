import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Visually rich follow-up date and time selector card with quick preset buttons
/// (Today, Tomorrow, 3 Days, Next Week), interactive calendar/clock pickers, and clear state.
class DateTimeSelectorCard extends StatelessWidget {
  final DateTime? selectedDate;
  final TimeOfDay? selectedTime;
  final ValueChanged<DateTime?> onDateChanged;
  final ValueChanged<TimeOfDay?> onTimeChanged;

  const DateTimeSelectorCard({
    super.key,
    required this.selectedDate,
    required this.selectedTime,
    required this.onDateChanged,
    required this.onTimeChanged,
  });

  Future<void> _pickDate(BuildContext context) async {
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E3A5F),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onDateChanged(picked);
      if (selectedTime == null) {
        onTimeChanged(const TimeOfDay(hour: 10, minute: 30));
      }
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    HapticFeedback.lightImpact();
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? const TimeOfDay(hour: 10, minute: 30),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E3A5F),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
            timePickerTheme: TimePickerThemeData(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onTimeChanged(picked);
    }
  }

  void _applyPreset(int daysFromNow) {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final targetDate = DateTime(now.year, now.month, now.day + daysFromNow);
    onDateChanged(targetDate);
    if (selectedTime == null) {
      onTimeChanged(const TimeOfDay(hour: 10, minute: 30));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFollowUp = selectedDate != null;

    String dateDisplay = 'No date selected';
    if (selectedDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final compare = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day);
      final diff = compare.difference(today).inDays;

      if (diff == 0) {
        dateDisplay = 'Today, ${DateFormat('dd MMM yyyy').format(selectedDate!)}';
      } else if (diff == 1) {
        dateDisplay = 'Tomorrow, ${DateFormat('dd MMM yyyy').format(selectedDate!)}';
      } else if (diff > 1 && diff <= 7) {
        dateDisplay = '${DateFormat('EEEE').format(selectedDate!)}, ${DateFormat('dd MMM').format(selectedDate!)}';
      } else {
        dateDisplay = DateFormat('dd MMM yyyy').format(selectedDate!);
      }
    }

    String timeDisplay = '10:30 AM';
    if (selectedTime != null) {
      final hour = selectedTime!.hourOfPeriod == 0 ? 12 : selectedTime!.hourOfPeriod;
      final minute = selectedTime!.minute.toString().padLeft(2, '0');
      final period = selectedTime!.period == DayPeriod.am ? 'AM' : 'PM';
      timeDisplay = '$hour:$minute $period';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick Presets
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildPresetChip(context, 'Today', () => _applyPreset(0)),
              const SizedBox(width: 8),
              _buildPresetChip(context, 'Tomorrow', () => _applyPreset(1)),
              const SizedBox(width: 8),
              _buildPresetChip(context, 'In 3 Days', () => _applyPreset(3)),
              const SizedBox(width: 8),
              _buildPresetChip(context, 'Next Week', () => _applyPreset(7)),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Interactive Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: hasFollowUp ? const Color(0xFF1E3A5F).withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasFollowUp ? const Color(0xFF1E3A5F).withValues(alpha: 0.25) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              // Date Box Clickable
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A5F).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.calendar_today_rounded,
                            size: 18,
                            color: Color(0xFF1E3A5F),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Follow-up Date',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dateDisplay,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: hasFollowUp ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Divider
              Container(
                height: 36,
                width: 1,
                color: const Color(0xFFE2E8F0),
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),

              // Time Box Clickable
              InkWell(
                onTap: () {
                  if (!hasFollowUp) {
                    onDateChanged(DateTime.now().add(const Duration(days: 1)));
                  }
                  _pickTime(context);
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.access_time_rounded,
                          size: 18,
                          color: Color(0xFFD97706),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Time',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            timeDisplay,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Clear button if date is selected
              if (hasFollowUp) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onDateChanged(null);
                    onTimeChanged(null);
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Color(0xFF94A3B8),
                  ),
                  tooltip: 'Clear follow-up',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPresetChip(BuildContext context, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.add_rounded,
              size: 14,
              color: Color(0xFF475569),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
