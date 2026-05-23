part of '../cases_screen.dart';

class _ImagingHero extends StatelessWidget {
  const _ImagingHero({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: PratiCaseGradients.hero,
        borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
        boxShadow: [
          BoxShadow(
            color: PratiCaseColors.navy.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: PratiCaseColors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(PratiCaseRadius.md),
            ),
            child: const Icon(
              Icons.image_search_rounded,
              color: PratiCaseColors.tealBright,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PratiCaseColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'İstenen görüntüleme sonucu',
                  style: TextStyle(
                    color: PratiCaseColors.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagingPreviewCard extends StatelessWidget {
  const _ImagingPreviewCard({required this.imageUrl, required this.title});

  final String imageUrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.trim().isEmpty) {
      return _ImagingPlaceholderCard(title: title);
    }
    return Container(
      height: 230,
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _ImagingPlaceholderCard(
            title: title,
            message: 'Görüntü yüklenemedi. Rapor metni aşağıda.',
          );
        },
      ),
    );
  }
}

class _ImagingPlaceholderCard extends StatelessWidget {
  const _ImagingPlaceholderCard({this.title, this.message});

  final String? title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 178,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: PratiCaseColors.teal.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
            ),
            child: const Icon(
              Icons.image_not_supported_outlined,
              color: PratiCaseColors.teal,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title?.trim().isNotEmpty == true
                ? title!.trim()
                : 'Görüntüleme Önizlemesi',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: PratiCaseColors.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message ?? 'Görüntü dosyası yok. Klinik rapor ve sonuçla devam et.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: PratiCaseColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
