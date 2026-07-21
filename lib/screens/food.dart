import 'package:flutter/material.dart';
import '../api.dart';
import '../app_image.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';
import 'checkout.dart';

class FoodScreen extends StatefulWidget {
  const FoodScreen({super.key});
  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  final store = BookingStore.instance;
  List<FoodItem> _food = [];
  String _cat = 'Burgers';

  @override
  void initState() {
    super.initState();
    Api.getFood().then((f) => setState(() {
          _food = f;
          if (f.isNotEmpty) _cat = f.first.category;
        }));
  }

  @override
  Widget build(BuildContext context) {
    final cats = <String>{for (final f in _food) f.category}.toList();
    final visible = _food.where((f) => f.category == _cat).toList();

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    const Padding(padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg), child: AppHeader(title: 'Grab a Bite')),
                    // Category tabs
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        children: cats
                            .map((c) => GestureDetector(
                                  onTap: () => setState(() => _cat = c),
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: AppSpacing.lg),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(c, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c == _cat ? AppColors.text : AppColors.textFaint)),
                                        const SizedBox(height: 4),
                                        if (c == _cat) Container(height: 2, width: 24, color: AppColors.primary),
                                      ],
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        children: visible.map((f) {
                          final q = store.qtyOf(f.id);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: AppCard(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(f.name, style: T.bodyStrong),
                                        const SizedBox(height: 2),
                                        Text(f.description, style: T.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: AppSpacing.sm),
                                        Text('₹${f.price.toStringAsFixed(2)}', style: T.bodyStrong),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Column(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(AppRadius.md),
                                        child: Image(image: appImg(f.image), width: 92, height: 72, fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(width: 92, height: 72, color: AppColors.surfaceElevated)),
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      q == 0
                                          ? GestureDetector(
                                              onTap: () => store.addFood(f),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: AppColors.surfaceElevated,
                                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                                  border: Border.all(color: AppColors.border),
                                                ),
                                                child: const Text('+ Add', style: T.label),
                                              ),
                                            )
                                          : Container(
                                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                                              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppRadius.sm)),
                                              child: Row(children: [
                                                GestureDetector(onTap: () => store.removeFood(f.id), child: const Icon(Icons.remove, size: 16, color: AppColors.textOnAccent)),
                                                Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm), child: Text('$q', style: const TextStyle(color: AppColors.textOnAccent, fontWeight: FontWeight.w700))),
                                                GestureDetector(onTap: () => store.addFood(f), child: const Icon(Icons.add, size: 16, color: AppColors.textOnAccent)),
                                              ]),
                                            ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg,
                          bottomSafePad(context, extra: AppSpacing.lg)),
                      decoration: const BoxDecoration(color: AppColors.surfaceAlt, border: Border(top: BorderSide(color: AppColors.border))),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Bay ${rupees(store.bayTotal)}${store.foodTotal > 0 ? '  +  Food ${rupees(store.foodTotal)}' : ''}',
                                  style: T.caption,
                                ),
                              ),
                              Text(rupees(store.grandTotal), style: T.h3.copyWith(color: AppColors.primary)),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AppButton(store.food.isEmpty ? 'Skip and proceed' : 'Continue to checkout',
                              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CheckoutScreen()))),
                        ],
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
