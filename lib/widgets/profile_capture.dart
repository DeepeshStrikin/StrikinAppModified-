import 'package:flutter/material.dart';
import '../theme.dart';
import 'ui.dart';

/// The four gender options stored on the backend (value, label).
const kGenderOptions = <List<String>>[
  ['male', 'Male'],
  ['female', 'Female'],
  ['other', 'Other'],
  ['prefer_not_to_say', 'Prefer not to say'],
];

/// A row of selectable pills for gender. [value] is the backend value
/// (e.g. 'female') or null; [onChanged] fires with the chosen value.
class GenderSelector extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;
  const GenderSelector({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: kGenderOptions.map((o) {
        final selected = value == o[0];
        return GestureDetector(
          onTap: () => onChanged(o[0]),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: selected ? AppColors.primary : AppColors.border),
            ),
            child: Text(
              o[1],
              style: TextStyle(
                color: selected ? AppColors.textOnAccent : AppColors.text,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Opens a dark date picker for a date of birth. Returns the chosen date or null.
Future<DateTime?> pickDob(BuildContext context, DateTime? current) {
  FocusScope.of(context).unfocus();
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: current ?? DateTime(now.year - 25, now.month, now.day),
    firstDate: DateTime(1920),
    lastDate: now,
    helpText: 'SELECT YOUR DATE OF BIRTH',
    builder: (ctx, child) => Theme(
      data: Theme.of(ctx).copyWith(
        colorScheme: ColorScheme.dark(
          primary: AppColors.primary,
          onPrimary: AppColors.textOnAccent,
          surface: AppColors.surface,
          onSurface: AppColors.text,
        ),
      ),
      child: child!,
    ),
  );
}

/// A tappable date-of-birth field styled to match [AppField].
class DobField extends StatelessWidget {
  final DateTime? value;
  final VoidCallback onTap;
  final String hint;
  const DobField({super.key, required this.value, required this.onTap, this.hint = 'Date of birth'});

  @override
  Widget build(BuildContext context) {
    final d = value;
    final label = d == null
        ? hint
        : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          const Icon(Icons.cake_outlined, size: 18, color: AppColors.textFaint),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: TextStyle(color: d == null ? AppColors.textFaint : AppColors.text, fontSize: 15)),
          const Spacer(),
          const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textFaint),
        ]),
      ),
    );
  }
}

/// Shows the "complete your profile" bottom sheet asking only for the missing
/// bits. Returns `{ 'gender': String?, 'dob': DateTime? }` on save, or null if
/// the user skipped. Only keys that were asked for are populated.
Future<Map<String, dynamic>?> showCompleteProfileSheet(
  BuildContext context, {
  required bool askGender,
  required bool askDob,
  String title = 'Complete your profile',
  String subtitle = 'Just a couple of details so we can serve you better.',
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceAlt,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (_) => _CompleteProfileSheet(
      askGender: askGender,
      askDob: askDob,
      title: title,
      subtitle: subtitle,
    ),
  );
}

class _CompleteProfileSheet extends StatefulWidget {
  final bool askGender, askDob;
  final String title, subtitle;
  const _CompleteProfileSheet({
    required this.askGender,
    required this.askDob,
    required this.title,
    required this.subtitle,
  });
  @override
  State<_CompleteProfileSheet> createState() => _CompleteProfileSheetState();
}

class _CompleteProfileSheetState extends State<_CompleteProfileSheet> {
  String? _gender;
  DateTime? _dob;

  bool get _valid =>
      (!widget.askGender || _gender != null) && (!widget.askDob || _dob != null);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.md,
        bottom: AppSpacing.lg + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(AppRadius.pill)),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(child: Text(widget.title, style: T.h2)),
          const SizedBox(height: 6),
          Center(child: Text(widget.subtitle, textAlign: TextAlign.center, style: T.caption)),
          const SizedBox(height: AppSpacing.lg),
          if (widget.askGender) ...[
            const Text('GENDER', style: T.label),
            const SizedBox(height: AppSpacing.sm),
            GenderSelector(value: _gender, onChanged: (v) => setState(() => _gender = v)),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (widget.askDob) ...[
            const Text('DATE OF BIRTH', style: T.label),
            const SizedBox(height: AppSpacing.sm),
            DobField(value: _dob, onTap: () async {
              final picked = await pickDob(context, _dob);
              if (picked != null) setState(() => _dob = picked);
            }),
            const SizedBox(height: AppSpacing.lg),
          ],
          AppButton(
            'Save',
            onPressed: _valid
                ? () => Navigator.pop(context, {
                      if (widget.askGender) 'gender': _gender,
                      if (widget.askDob) 'dob': _dob,
                    })
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Not now', style: T.caption),
            ),
          ),
        ],
      ),
    );
  }
}
