import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/partner.dart';
import '../theme/app_theme.dart';

class PartnerCard extends StatelessWidget {
  final Partner partner;
  final String? distanceLabel;
  const PartnerCard({super.key, required this.partner, this.distanceLabel});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/partner/${partner.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildLogo(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partner.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      partner.kategorie,
                      style: const TextStyle(
                          color: AppColors.orange,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${partner.adresse}, ${partner.plz} ${partner.ort}',
                            style: const TextStyle(color: AppColors.grey, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (distanceLabel != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            distanceLabel!,
                            style: const TextStyle(
                                color: AppColors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ],
                    ),
                    if (partner.berater.isNotEmpty &&
                        (partner.kategorie == 'Versicherungsmakler' ||
                            partner.kategorie == 'KFZ Sachverständiger')) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.person_outline,
                            size: 13, color: AppColors.grey),
                        const SizedBox(width: 4),
                        Text(partner.berater,
                            style: const TextStyle(
                                color: AppColors.grey, fontSize: 12)),
                      ]),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    if (partner.logo.isNotEmpty) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            partner.logo,
            width: 60,
            height: 60,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _initial(),
          ),
        ),
      );
    }
    return _initial();
  }

  Widget _initial() {
    final letter = partner.name.isNotEmpty ? partner.name[0].toUpperCase() : '?';
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
