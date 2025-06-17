import 'package:flutter/material.dart';
import '../../services/sponsor_service.dart';

class SponsorSplash extends StatefulWidget {
  const SponsorSplash({super.key});

  @override
  State<SponsorSplash> createState() => _SponsorSplashState();
}

class _SponsorSplashState extends State<SponsorSplash> {
  final SponsorService _sponsorService = SponsorService();
  List<String> _logos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSponsors();
  }

  Future<void> _loadSponsors() async {
    try {
      final sponsors = await _sponsorService.getAllSponsors();
      _logos =
          sponsors
              .map((sponsor) => sponsor.logoUrl)
              .where((url) => url.isNotEmpty)
              .toList();
    } catch (e) {
      // ignore errors, just show empty screen
      debugPrint('Error loading sponsors: $e');
    }

    setState(() {
      _loading = false;
    });

    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _logos.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount =
              _logos.isEmpty ? 1 : (_logos.length <= 3 ? _logos.length : 3);
          final double tileSize = constraints.maxWidth / crossAxisCount;

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 1,
            ),
            itemCount: _logos.length,
            itemBuilder: (context, index) {
              final logoUrl = _logos[index];
              return Center(
                child: SizedBox(
                  width: tileSize * 0.8,
                  height: tileSize * 0.8,
                  child: Image.network(logoUrl, fit: BoxFit.contain),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
