import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/sponsor_service.dart';
import '../../models/sponsor.dart';

class SponsorsPage extends StatefulWidget {
  const SponsorsPage({super.key});

  @override
  State<SponsorsPage> createState() => _SponsorsPageState();
}

class _SponsorsPageState extends State<SponsorsPage> {
  final SponsorService _sponsorService = SponsorService();
  late Future<List<Sponsor>> _sponsorsFuture;

  @override
  void initState() {
    super.initState();
    _sponsorsFuture = _sponsorService.getSponsors();
  }

  Future<void> _launchWebsite(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sponsors')),
      body: FutureBuilder<List<Sponsor>>(
        future: _sponsorsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Error loading sponsors'));
          }

          final sponsors = snapshot.data ?? [];
          if (sponsors.isEmpty) {
            return const Center(child: Text('No sponsors available'));
          }

          return ListView.builder(
            itemCount: sponsors.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final sponsor = sponsors[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  onTap: () => _launchWebsite(sponsor.websiteUrl),
                  leading: SizedBox(
                    width: 60,
                    height: 60,
                    child: Image.network(sponsor.logoUrl),
                  ),
                  title: Text(sponsor.name),
                  subtitle: Text(sponsor.area),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
