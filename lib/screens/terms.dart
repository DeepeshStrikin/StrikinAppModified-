import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import '../widgets/scaffold.dart';

/// Displays the admin-managed Terms & Conditions fetched from the backend.
/// Lines starting with "# " render as bold headings; blank lines add spacing.
class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});
  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _loading = true;
  String _terms = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.getTerms();
      if (!mounted) return;
      setState(() {
        _terms = (d['terms'] ?? '').toString();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load Terms & Conditions. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      scroll: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppHeader(title: 'Terms of Service'),
          const SizedBox(height: AppSpacing.lg),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Center(child: Text(_error!, style: T.caption, textAlign: TextAlign.center)),
            )
          else if (_terms.trim().isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: Text('Terms & Conditions will be available soon.', style: T.caption, textAlign: TextAlign.center)),
            )
          else
            ..._render(_terms),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  List<Widget> _render(String text) {
    final widgets = <Widget>[];
    for (final rawLine in text.split('\n')) {
      final line = rawLine.trimRight();
      final trimmed = line.trimLeft();
      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: AppSpacing.md));
      } else if (trimmed.startsWith('# ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
          child: Text(trimmed.substring(2).trim(),
              style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w700)),
        ));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(line, style: const TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.5)),
        ));
      }
    }
    return widgets;
  }
}
