import 'package:flutter/material.dart';

class RemoteScreen extends StatelessWidget {
  const RemoteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme   = Theme.of(context).textTheme;

    // Şimdilik mock bir cihaz adı. Gerçek cihaz verini buraya bağlayabilirsin.
    final String connectedDeviceName = 'LG Bedroom';

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 160.0,
            collapsedHeight: 66.0,
            backgroundColor: colorScheme.surface,
            foregroundColor: colorScheme.onSurface,
            surfaceTintColor: colorScheme.surfaceTint,
            shadowColor: Colors.transparent,
            flexibleSpace: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final top = constraints.biggest.height;
                final safeAreaTop = MediaQuery.of(context).padding.top;
                final minHeight = 66.0 + safeAreaTop;
                final maxHeight = 160.0 + safeAreaTop;
                final expandRatio = ((top - minHeight) / (maxHeight - minHeight)).clamp(0.0, 1.0);

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // AÇIK DURUM
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: expandRatio > 0.4 ? 1.0 : 0.0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'TITANCAST',
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.0,
                                fontSize: 25.0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Remote',
                              style: textTheme.headlineSmall?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w400, // Devices ile eşitlendi
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // HİZA KORUYUCU: Devices ekranındaki Wifi widget'ının yüksekliği kadar hayali boşluk
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),

                    // KAPALI DURUM (Kaydırıldığında cihaz ismi sağa geçer)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 18,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: expandRatio < 0.4 ? 1.0 : 0.0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Remote',
                              style: textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              connectedDeviceName, // Cihaz adı sağda!
                              style: textTheme.labelMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Geri kalan Body kısmı (Eski haliyle aynı)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.settings_remote_rounded,
                        size: 48,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Remote Control',
                      style: textTheme.titleLarge?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Connect to a device from the Devices tab\nto use the remote.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}