import 'package:flutter/material.dart';
import '../api.dart';
import '../app_image.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';
import 'food.dart';

String _tierLabel(String t) =>
    const {'standard': 'Standard', 'vip': 'VIP', 'vvip': 'VVIP', 'gold': 'Gold'}[t] ?? t.toUpperCase();

/// Party-size word by activity (see models.partyNoun): games → "players",
/// cafe / rooftop dining → "guests", mega screen / movies → "people".
String _partyNoun(ActivityType? a, {bool plural = true}) => partyNoun(a, plural: plural);
String _partyTitle(ActivityType? a) => partyTitle(a);
// Bookable-unit word per activity: golf/cricket → "bay", cafe/rooftop → "table".
String _spaceNoun(ActivityType? a, {bool plural = false}) => spaceNoun(a, plural: plural);
String _spaceTitle(ActivityType? a) => spaceTitle(a);

const _wd = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const _mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

class ActivityBookingScreen extends StatefulWidget {
  const ActivityBookingScreen({super.key});
  @override
  State<ActivityBookingScreen> createState() => _ActivityBookingScreenState();
}

class _ActivityBookingScreenState extends State<ActivityBookingScreen> {
  final store = BookingStore.instance;
  List<Bay> _bays = [];
  List<Slot> _slots = [];
  bool _showAllSlots = false;
  String? _selectedTier; // chosen bay tier (Standard / VIP / VVIP)
  final _days = List.generate(10, (i) => DateTime.now().add(Duration(days: i)));

  static const _tierOrder = ['standard', 'vip', 'vvip', 'gold'];

  /// Distinct tiers available for this activity, in a sensible order.
  List<String> get _tiers {
    final present = _bays.map((b) => b.bayTier).toSet();
    final ordered = _tierOrder.where(present.contains).toList();
    ordered.addAll(present.where((t) => !_tierOrder.contains(t)));
    return ordered;
  }

  List<Bay> _baysOfTier(String tier) => _bays.where((b) => b.bayTier == tier).toList();

  double _tierFrom(String tier) =>
      _baysOfTier(tier).map((b) => b.pricePerSession).fold<double>(double.infinity, (a, b) => b < a ? b : a);

  void _pickTier(String tier) {
    setState(() {
      _selectedTier = tier;
      _showAllSlots = false;
      _slots = []; // clear stale slots
    });
    store.clearBay(); // start the new tier's selection fresh
    final inTier = _baysOfTier(tier);
    if (inTier.isEmpty) return;

    // For generic identical bays (allow_select = false, e.g. Standard/VIP with
    // many identical bays), auto-select the first bay so time slots load immediately.
    // The customer can tap extra bays if their group needs more capacity.
    // For themed/named bays (allow_select = true, e.g. VVIP rooms), only
    // auto-select when there's exactly one — the customer must pick which room.
    final autoSelect = inTier.length == 1 || !inTier.first.allowSelect;
    if (autoSelect) {
      store.toggleBay(inTier.first);
      _loadSlots();
    }
  }

  /// Generic bay grid for non-themed tiers (Standard/VIP): a header image + a
  /// "Bay 1, Bay 2 …" grid (4 per row), selected tiles outlined in lime.
  Widget _bayGrid(List<Bay> bays) {
    final img = bays.isNotEmpty && bays.first.image.isNotEmpty
        ? bays.first.image
        : (store.activity?.image ?? '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (img.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Image(image: appImg(img), height: 160, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(height: 160, color: AppColors.surfaceElevated)),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.5),
          itemCount: bays.length,
          itemBuilder: (c, i) {
            final sel = store.isBaySelected(bays[i].id);
            return GestureDetector(
              onTap: () { store.toggleBay(bays[i]); setState(() { _showAllSlots = false; _slots = []; }); _loadSlots(); },
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: sel ? AppColors.primary : AppColors.border, width: sel ? 2 : 1),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${_spaceTitle(store.activity)} ${i + 1}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: sel ? AppColors.primary : AppColors.text)),
                    const SizedBox(height: 2),
                    Text(rupees(bays[i].pricePerSession),
                        style: TextStyle(
                            fontSize: 11,
                            color: sel ? AppColors.primary : AppColors.textMuted)),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _pickPlayers() async {
    // Allow large groups — if they exceed one bay's capacity, the bay step prompts
    // them to select multiple bays.
    const max = 30;
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surfaceAlt,
      isScrollControlled: true, // allow a taller, scrollable sheet
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.72),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.md),
              Container(width: 44, height: 4, decoration: BoxDecoration(
                  color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: AppSpacing.lg),
              Text('Select number of ${_partyNoun(store.activity)}', style: T.h2),
              const SizedBox(height: 6),
              const Text('Choose one of the options below',
                  style: TextStyle(color: AppColors.textFaint, fontSize: 14)),
              const SizedBox(height: AppSpacing.lg),
              Flexible(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2.1),
                  itemCount: max,
                  itemBuilder: (c, i) {
                    final n = i + 1;
                    final sel = store.players == n;
                    return GestureDetector(
                      onTap: () => Navigator.pop(ctx, n),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: sel ? AppColors.primary : AppColors.border, width: sel ? 2 : 1),
                        ),
                        child: Text('$n',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: sel ? AppColors.primary : AppColors.text)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) store.setPlayers(picked);
  }

  @override
  void initState() {
    super.initState();
    if (store.activity != null) {
      Api.getBays(store.activity!.id).then((b) => setState(() => _bays = b));
    }
  }

  void _loadSlots() {
    if (store.bay != null) {
      setState(() => _slots = []); // clear stale slots immediately while loading
      Api.getSlots(store.bay!.id, store.date).then((s) {
        if (mounted) setState(() => _slots = s);
      });
    }
  }

  String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

  Widget _gridCell({required Widget child, required VoidCallback? onTap, bool selected = false, bool disabled = false}) {
    return Opacity(
      opacity: disabled ? 0.35 : 1,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _timeGrid(BookingStore store) {
    const previewCount = 9;
    final hasMore = _slots.length > previewCount;
    final shown = (_showAllSlots || !hasMore) ? _slots.length : previewCount;

    final cells = <Widget>[
      for (int i = 0; i < shown; i++)
        _gridCell(
          selected: store.time == _slots[i].time,
          disabled: !_slots[i].isAvailable,
          onTap: () => store.setTime(_slots[i].time),
          child: Text(_slots[i].time,
              style: TextStyle(fontSize: 13, color: store.time == _slots[i].time ? AppColors.textOnAccent : AppColors.text)),
        ),
      if (hasMore && !_showAllSlots)
        _gridCell(
          onTap: () => setState(() => _showAllSlots = true),
          child: Text('View all', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
        ),
    ];

    return Column(
      children: [
        for (int row = 0; row < (cells.length / 3).ceil(); row++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                for (int col = 0; col < 3; col++) ...[
                  Expanded(child: (row * 3 + col) < cells.length ? cells[row * 3 + col] : const SizedBox()),
                  if (col < 2) const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final enoughCapacity = store.totalCapacity >= store.players;
        final canContinue = store.bays.isNotEmpty && store.time != null && enoughCapacity;
        final act = store.activity;
        final tierBays = _selectedTier == null ? <Bay>[] : _baysOfTier(_selectedTier!);
        // Themed tiers (e.g. VVIP rooms) let the customer pick the specific bay;
        // generic tiers (Standard/VIP) show a simple "Bay 1, Bay 2…" grid.
        final pickSpecific = tierBays.isEmpty || tierBays.first.allowSelect;
        final isScreening = act?.slug == 'screening';
        final noun = _spaceNoun(act); // bay / table / seat
        final isTable = noun == 'table';
        final title = isScreening
            ? 'Pick your seats'
            : (isTable ? 'Reserve a table' : 'Book a $noun');
        final selectLabel = isScreening
            ? 'Choose your seats'
            : (isTable ? 'Choose your table & vibe' : '${_spaceTitle(act)} type');
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    const Padding(padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg), child: AppHeader()),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: T.h1),

                            // Date strip
                            const SizedBox(height: AppSpacing.lg),
                            SizedBox(
                              height: 78,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _days.length,
                                separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                                itemBuilder: (_, i) {
                                  final d = _days[i];
                                  final active = _iso(d) == store.date;
                                  return GestureDetector(
                                    onTap: () {
                                      store.setDate(_iso(d));
                                      setState(() { _slots = []; _showAllSlots = false; });
                                      _loadSlots();
                                    },
                                    child: Container(
                                      width: 60,
                                      decoration: BoxDecoration(
                                        color: active ? AppColors.primary : AppColors.surface,
                                        borderRadius: BorderRadius.circular(AppRadius.md),
                                        border: Border.all(color: active ? AppColors.primary : AppColors.border),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(_wd[d.weekday % 7], style: TextStyle(fontSize: 12, color: active ? AppColors.textOnAccent : AppColors.textMuted)),
                                          Text('${d.day}', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: active ? AppColors.textOnAccent : AppColors.text)),
                                          Text(_mo[d.month - 1], style: TextStyle(fontSize: 12, color: active ? AppColors.textOnAccent : AppColors.textMuted)),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                            // Players (dropdown)
                            const SizedBox(height: AppSpacing.xl),
                            Text(_partyTitle(act), style: T.h3),
                            const SizedBox(height: AppSpacing.sm),
                            GestureDetector(
                              onTap: _pickPlayers,
                              child: Container(
                                height: 54,
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${store.players} ${_partyNoun(act, plural: store.players != 1)}', style: T.body),
                                    const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
                                  ],
                                ),
                              ),
                            ),

                            // STEP 1 — pick a tier (Standard / VIP / VVIP)
                            const SizedBox(height: AppSpacing.xl),
                            Text(selectLabel, style: T.h3),
                            const SizedBox(height: AppSpacing.sm),
                            ..._tiers.map((tier) {
                              final active = _selectedTier == tier;
                              final count = _baysOfTier(tier).length;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                child: GestureDetector(
                                  onTap: () => _pickTier(tier),
                                  child: AppCard(
                                    padding: const EdgeInsets.all(AppSpacing.md),
                                    borderColor: active ? AppColors.primary : AppColors.borderSubtle,
                                    child: Row(
                                      children: [
                                        Icon(active ? Icons.radio_button_checked : Icons.radio_button_off,
                                            color: active ? AppColors.primary : AppColors.textFaint, size: 22),
                                        const SizedBox(width: AppSpacing.md),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('${_tierLabel(tier)} $noun', style: T.bodyStrong),
                                              const SizedBox(height: 4),
                                              Text('$count ${count == 1 ? noun : _spaceNoun(act, plural: true)} available',
                                                  style: T.caption),
                                            ],
                                          ),
                                        ),
                                        Text('from ${rupees(_tierFrom(tier))}',
                                            style: T.bodyStrong.copyWith(color: AppColors.primary)),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),

                            // STEP 2 — pick one OR MORE named bays within the chosen tier
                            if (_selectedTier != null && _baysOfTier(_selectedTier!).length > 1) ...[
                              const SizedBox(height: AppSpacing.lg),
                              Text(pickSpecific ? 'Select ${_tierLabel(_selectedTier!)} $noun(s)' : 'Select number of ${_spaceNoun(act, plural: true)}', style: T.h3),
                              const SizedBox(height: 4),
                              Text(
                                'You can select multiple ${_spaceNoun(act, plural: true)} (max ${tierBays.first.maxPlayers} ${_partyNoun(act)} per $noun)',
                                style: const TextStyle(color: AppColors.textFaint, fontSize: 13),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              if (pickSpecific)
                                ...tierBays.map((b) {
                                  final active = store.isBaySelected(b.id);
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                    child: GestureDetector(
                                      onTap: () { store.toggleBay(b); setState(() { _showAllSlots = false; _slots = []; }); _loadSlots(); },
                                      child: AppCard(
                                        padding: const EdgeInsets.all(AppSpacing.md),
                                        borderColor: active ? AppColors.primary : AppColors.borderSubtle,
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Icon(active ? Icons.check_box : Icons.check_box_outline_blank,
                                                  color: active ? AppColors.primary : AppColors.textFaint, size: 22),
                                            ),
                                            const SizedBox(width: AppSpacing.md),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(children: [
                                                    Flexible(child: Text(b.name, style: T.bodyStrong, overflow: TextOverflow.ellipsis)),
                                                    const Spacer(),
                                                    Text(rupees(b.pricePerSession), style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w700)),
                                                  ]),
                                                  const SizedBox(height: 2),
                                                  Text('Max ${b.maxPlayers} · per session', style: T.caption),
                                                  const SizedBox(height: 2),
                                                  Text(b.description, style: T.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
                                                ],
                                              ),
                                            ),
                                            if (b.image.isNotEmpty) ...[
                                              const SizedBox(width: AppSpacing.md),
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(AppRadius.md),
                                                child: Image(image: appImg(b.image), width: 56, height: 56, fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => Container(width: 56, height: 56, color: AppColors.surfaceElevated)),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                })
                              else
                                _bayGrid(tierBays),
                              // Capacity feedback — clear red error when the selected
                              // bays can't fit everyone.
                              if (store.bays.isNotEmpty && !enoughCapacity)
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    color: const Color(0x1AE5484D),
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    border: Border.all(color: const Color(0x55E5484D)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.error_outline, color: Color(0xFFE5484D), size: 18),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Text(
                                          store.bays.length < _baysOfTier(_selectedTier!).length
                                              ? 'These ${store.bays.length == 1 ? '$noun holds' : '${_spaceNoun(act, plural: true)} hold'} only ${store.totalCapacity} ${_partyNoun(act)} — add another $noun to fit all ${store.players}.'
                                              : 'These ${_spaceNoun(act, plural: true)} hold only ${store.totalCapacity} ${_partyNoun(act)}. Reduce ${_partyNoun(act)} or choose a bigger tier.',
                                          style: const TextStyle(color: Color(0xFFE5484D), fontSize: 13, height: 1.35),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],

                            // Time
                            if (store.bay != null) ...[
                              const SizedBox(height: AppSpacing.lg),
                              const Text('Select time', style: T.h3),
                              const SizedBox(height: 4),
                              const Text('Live availability — taken slots are greyed out',
                                  style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
                              const SizedBox(height: AppSpacing.md),
                              if (_slots.isEmpty)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24),
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              else
                                _timeGrid(store),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Sticky CTA
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceAlt,
                          border: Border(top: BorderSide(color: AppColors.border)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(store.bays.isNotEmpty ? '${store.bays.length} ${store.bays.length == 1 ? noun : _spaceNoun(act, plural: true)} · ${store.players} ${_partyNoun(act, plural: store.players != 1)}' : 'Select a $noun', style: T.caption),
                                Text(rupees(store.bayTotal), style: T.h3.copyWith(color: AppColors.primary)),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            AppButton('Continue',
                                onPressed: canContinue
                                    ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FoodScreen()))
                                    : null),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
