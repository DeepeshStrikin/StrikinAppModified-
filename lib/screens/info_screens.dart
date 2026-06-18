import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_image.dart';
import '../theme.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';

const _cdn = 'https://cdn.sanity.io/images/y370h02s/production';
// Raw URL (no proxy here) — appImg() decides asset-vs-network downstream.
String _img(String file, {int w = 700}) => '$_cdn/$file?w=$w&q=75';

Future<void> _open(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Widget _pageScaffold(BuildContext context, String title, List<Widget> children) {
  return Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg), child: AppHeader(title: title)),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxxl),
                  children: children,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _netImage(String url, {double height = 170}) => ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Image(image: appImg(url),
          height: height, width: double.infinity, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(height: height, color: AppColors.surfaceElevated)),
    );

/* ---------------------------- ATTRACTIONS ---------------------------- */
class AttractionsScreen extends StatelessWidget {
  const AttractionsScreen({super.key});

  static const _items = [
    ('VVIP Bays', 'Immersive luxury. Themed golf bay escapes.', '71e81a78436e02aaf23d578651cef57bf3cc51d7-1920x1080.png'),
    ('Cricket Bays', 'Tech-powered cricket. Gully roots. New-age thrills.', '9c0cefc60358879dfff6ec15cb11e8158ab3cfee-2560x1703.png'),
    ('Golf Bays', 'Play your way and lounge easy with social golf.', 'b0a99393be83b97e331bc07e61a01263e849c96f-3840x2160.png'),
    ('Cafe', 'Step into a futuristic cafe experience, today.', '0d1948955fc338feeae6fb7b08a4b78484eb58b8-1500x938.png'),
    ('Mega Screen', 'A stadium-like experience in plush lounge comfort.', '8c8a8d2f6bdb2ac4e8d1edbcd84380eb5f2e57cd-1920x1080.png'),
    ('Rooftop Dining', 'Above it all. Panoramic rooftop dining.', 'b665e9badcb7e0f69c71fc556ac5b6b5ec8f5d91-1920x1080.png'),
  ];

  @override
  Widget build(BuildContext context) {
    return _pageScaffold(context, 'Attractions', [
      const SizedBox(height: AppSpacing.sm),
      const Text('Everything at STRIKIN', style: T.h1),
      const SizedBox(height: 4),
      const Text('Tech-powered sport, immersive entertainment & rooftop dining — all in one place.',
          style: T.caption),
      const SizedBox(height: AppSpacing.lg),
      for (final it in _items)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _netImage(_img(it.$3), height: 160),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it.$1, style: T.h3),
                      const SizedBox(height: 4),
                      Text(it.$2, style: T.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    ]);
  }
}

/* ---------------------------- ABOUT ---------------------------- */
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _pageScaffold(context, 'About us', [
      const SizedBox(height: AppSpacing.sm),
      _netImage(_img('b7c80970f0f00febbb7ace581500e589fe3d59e6-2560x1651.png', w: 1000), height: 200),
      const SizedBox(height: AppSpacing.lg),
      const Text('About STRIKIN', style: T.h1),
      const SizedBox(height: AppSpacing.sm),
      Text("India's home for next-level sport, entertainment, dining & social experiences.",
          style: T.h3.copyWith(color: AppColors.primary)),
      const SizedBox(height: AppSpacing.lg),
      const Text(
        "STRIKIN is India's premier destination for tech-powered sport, immersive entertainment, rooftop dining, and elevated social energy — all in one place.",
        style: T.body,
      ),
      const SizedBox(height: AppSpacing.md),
      const Text(
        'Where every moment is an expedition. Into sound. Into taste. Into tech. Into play.',
        style: T.body,
      ),
      const SizedBox(height: AppSpacing.md),
      const Text(
        'STRIKIN was imagined not as another venue, but as a vibrant collision of sport, dreamy design, and immersive indulgences.',
        style: T.body,
      ),
      const SizedBox(height: AppSpacing.md),
      const Text(
        'Setting a new standard — redefining how India connects and plays. Crafted for the next generation of social experiences, for those who want more than ordinary.',
        style: T.body,
      ),
      const SizedBox(height: AppSpacing.xl),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Get in touch', style: T.h3),
            const SizedBox(height: AppSpacing.md),
            _contactRow(Icons.mail_outline, 'hello@strikin.com', () => _open('mailto:hello@strikin.com')),
            const SizedBox(height: AppSpacing.sm),
            _contactRow(Icons.call_outlined, '+91 8121036380', () => _open('tel:+918121036380')),
            const SizedBox(height: AppSpacing.sm),
            _contactRow(Icons.location_on_outlined, '1st Floor, Manasu Building, Hyderabad', null),
          ],
        ),
      ),
    ]);
  }
}

Widget _contactRow(IconData icon, String text, VoidCallback? onTap) => GestureDetector(
      onTap: onTap,
      child: Row(children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(text, style: T.body)),
        if (onTap != null) const Icon(Icons.chevron_right, size: 18, color: AppColors.textFaint),
      ]),
    );

/* ---------------------------- BLOGS ---------------------------- */
class BlogsScreen extends StatelessWidget {
  const BlogsScreen({super.key});

  static const _posts = [
    ('The Big Game, Bigger: Inside STRIKIN\'s Mega-Screening Lounge', 'ENTERTAIN', '24 May 2025', '8c8a8d2f6bdb2ac4e8d1edbcd84380eb5f2e57cd-1920x1080.png'),
    ('Where the Game Never Ends: Cricket at STRIKIN', 'PLAY', '23 May 2025', '45fe6f27dbdd2467075d2b94e2b57d4ccacccae3-2560x1600.jpg'),
    ('Not Your Average Café — Meet STRIKIN\'s Robotic Baristas', 'INDULGE', '12 May 2025', '0d1948955fc338feeae6fb7b08a4b78484eb58b8-1500x938.png'),
    ('Beyond the Screen: The STRIKIN Experience', 'PLAY', '2025', '38964763ff59712bd28c368bede4fb1cea5b1335-3840x2160.png'),
  ];

  @override
  Widget build(BuildContext context) {
    return _pageScaffold(context, 'Blogs', [
      const SizedBox(height: AppSpacing.sm),
      const Text('The STRIKIN Edit', style: T.h1),
      const SizedBox(height: 4),
      const Text('Latest moments, behind-the-scenes stories & insider updates.', style: T.caption),
      const SizedBox(height: AppSpacing.lg),
      for (final p in _posts)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: GestureDetector(
            onTap: () => _open('https://strikin.com/blogs'),
            child: AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _netImage(_img(p.$4), height: 160),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Tag(p.$2, tone: 'accent'),
                          const SizedBox(width: AppSpacing.sm),
                          Text(p.$3, style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
                        ]),
                        const SizedBox(height: AppSpacing.sm),
                        Text(p.$1, style: T.h3),
                        const SizedBox(height: 4),
                        const Text('By The STRIKIN Edit', style: T.caption),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      const SizedBox(height: AppSpacing.sm),
      AppButton('Read all on strikin.com', variant: 'secondary', onPressed: () => _open('https://strikin.com/blogs')),
    ]);
  }
}

/* ---------------------------- SUPPORT ---------------------------- */
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _pageScaffold(context, 'Support', [
      const SizedBox(height: AppSpacing.sm),
      const Text("We'd love to hear from you", style: T.h1),
      const SizedBox(height: AppSpacing.sm),
      const Text('Have questions or want to plan your visit? Reach out to the STRIKIN team for bookings, events, or anything else.',
          style: T.body),
      const SizedBox(height: AppSpacing.xl),
      _supportTile(Icons.mail_outline, 'Email us', 'hello@strikin.com', () => _open('mailto:hello@strikin.com')),
      const SizedBox(height: AppSpacing.md),
      _supportTile(Icons.call_outlined, 'Call us', '+91 8121036380', () => _open('tel:+918121036380')),
      const SizedBox(height: AppSpacing.md),
      _supportTile(Icons.chat_bubble_outline, 'WhatsApp', 'Chat with us', () => _open('https://wa.me/918121036380')),
      const SizedBox(height: AppSpacing.md),
      _supportTile(Icons.public, 'Visit website', 'strikin.com', () => _open('https://strikin.com')),
      const SizedBox(height: AppSpacing.xl),
      const Center(child: Text('1st Floor, Manasu Building, Hyderabad', style: T.caption)),
    ]);
  }

  Widget _supportTile(IconData icon, String title, String sub, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: AppCard(
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: const Color(0x1AD6FD31), borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: T.bodyStrong),
                  Text(sub, style: T.caption),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textFaint),
          ]),
        ),
      );
}
