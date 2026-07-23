import 'dart:typed_data' show Uint8List;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart' show PhotoManager;

import '../../data/photos/nearby_photos_finder.dart';
import '../../data/photos/photo_library_service.dart';
import '../../data/photos/photo_manager_library_service.dart';
import '../../domain/models/track_photo.dart';
import '../../ui/glass.dart';
import '../../ui/ios_menu.dart';
import '../../ui/ios_progress.dart';
import '../../ui/ios_toast.dart';
import '../../ui/tokens.dart';
import 'route_editor_provider.dart';

/// Accesso alla libreria foto del dispositivo (sola lettura) dietro
/// l'interfaccia comune — vedi `lib/data/photos/photo_library_service.dart`.
final photoLibraryServiceProvider =
    Provider<PhotoLibraryService>((ref) => const PhotoManagerLibraryService());

/// Orchestratore "foto vicine al percorso" (§"Sync album fotografico",
/// `docs/eval-photo-sync.md`).
final nearbyPhotosFinderProvider = Provider<NearbyPhotosFinder>(
    (ref) => NearbyPhotosFinder(ref.watch(photoLibraryServiceProvider)));

/// Azione "Trova foto" della card traccia: richiede il permesso alla libreria
/// foto, cerca le candidate vicine al percorso e — se ce ne sono — apre una
/// griglia per scegliere quali collegare. Azione **manuale**, mai automatica
/// (vedi decisione nel doc): l'utente la avvia esplicitamente dal bottone.
Future<void> findNearbyPhotos(
  BuildContext context,
  WidgetRef ref,
  DrawnTrack track,
) async {
  if (track.routedPath.length < 2) {
    showIosToast(context, 'Traccia senza percorso');
    return;
  }

  final phase = ValueNotifier<String>('Ricerca foto vicine al percorso…');
  final closeProgress = showIosProgress(context, message: phase);

  NearbyPhotosResult result;
  try {
    result = await ref
        .read(nearbyPhotosFinderProvider)
        .findNearby(routedPath: track.routedPath);
  } catch (_) {
    closeProgress();
    phase.dispose();
    if (context.mounted) showIosToast(context, 'Ricerca foto non riuscita');
    return;
  }
  closeProgress();
  phase.dispose();
  if (!context.mounted) return;

  if (result.permission == PhotoLibraryPermission.denied) {
    await _showPermissionDenied(context);
    return;
  }

  // Non ripropone foto già collegate a questa traccia.
  final alreadyLinked = track.photos.map((p) => p.id).toSet();
  final fresh =
      result.photos.where((p) => !alreadyLinked.contains(p.id)).toList();

  if (fresh.isEmpty) {
    showIosToast(context, 'Nessuna foto trovata vicino a questo percorso');
    return;
  }

  final chosen = await showCupertinoModalPopup<List<TrackPhoto>>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _NearbyPhotosSheet(
      photos: fresh,
      limited: result.permission == PhotoLibraryPermission.limited,
    ),
  );
  if (chosen == null || chosen.isEmpty || !context.mounted) return;

  await ref.read(tracksProvider.notifier).addPhotos(track.id, chosen);
  if (context.mounted) {
    showIosToast(
      context,
      chosen.length == 1
          ? 'Foto aggiunta alla traccia'
          : '${chosen.length} foto aggiunte alla traccia',
    );
  }
}

Future<void> _showPermissionDenied(BuildContext context) {
  return showIosConfirm(
    context: context,
    title: 'Accesso alla libreria foto negato',
    message: 'Per cercare le foto vicine al percorso, Sentèi ha bisogno del '
        'permesso di leggere la tua libreria foto. Puoi concederlo dalle '
        'Impostazioni.',
    confirmLabel: 'Apri Impostazioni',
    destructive: false,
    onConfirm: PhotoManager.openSetting,
  );
}

/// Griglia delle foto trovate: tutte selezionate di default, tap per
/// escludere/includere. "Aggiungi" ritorna le selezionate al chiamante.
class _NearbyPhotosSheet extends StatefulWidget {
  const _NearbyPhotosSheet({required this.photos, required this.limited});

  final List<TrackPhoto> photos;
  final bool limited;

  @override
  State<_NearbyPhotosSheet> createState() => _NearbyPhotosSheetState();
}

class _NearbyPhotosSheetState extends State<_NearbyPhotosSheet> {
  late final Set<String> _selected = {for (final p in widget.photos) p.id};

  void _toggle(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final media = MediaQuery.of(context);
    final count = widget.photos.length;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.7),
          child: GlassSurface(
            opacity: 0.94,
            blur: 30,
            borderRadius: AppRadii.rCard,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count == 1
                        ? 'Trovata 1 foto vicino al percorso'
                        : 'Trovate $count foto vicino al percorso',
                    style: AppText.value.copyWith(color: palette.label),
                  ),
                  if (widget.limited) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Accesso limitato ad alcune foto: potrebbero essercene '
                      'altre nella libreria.',
                      style: AppText.captionSmall
                          .copyWith(color: palette.secondaryLabel),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Flexible(
                    child: GridView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: widget.photos.length,
                      itemBuilder: (_, i) {
                        final p = widget.photos[i];
                        return _PhotoTile(
                          thumbnail: p.thumbnail,
                          selected: _selected.contains(p.id),
                          onTap: () => _toggle(p.id),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          color: palette.glassFill.withValues(alpha: 0.5),
                          borderRadius: AppRadii.rPill,
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('Annulla',
                              style: AppText.pillLabel
                                  .copyWith(color: palette.label)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          color: AppColors.primary
                              .withValues(alpha: _selected.isEmpty ? 0.4 : 1),
                          borderRadius: AppRadii.rPill,
                          onPressed: _selected.isEmpty
                              ? null
                              : () => Navigator.of(context).pop([
                                    for (final p in widget.photos)
                                      if (_selected.contains(p.id)) p,
                                  ]),
                          child: Text(
                            'Aggiungi (${_selected.length})',
                            style: AppText.pillLabel
                                .copyWith(color: const Color(0xFFFFFFFF)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.thumbnail,
    required this.selected,
    required this.onTap,
  });

  final Uint8List? thumbnail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: AppRadii.rMd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: context.palette.hairline.withValues(alpha: 0.08),
              child: thumbnail != null
                  ? Image.memory(thumbnail!, fit: BoxFit.cover)
                  : Icon(CupertinoIcons.photo,
                      color: context.palette.tertiaryIcon),
            ),
            if (!selected)
              ColoredBox(color: const Color(0x99000000)),
            Positioned(
              right: 4,
              top: 4,
              child: Icon(
                selected
                    ? CupertinoIcons.checkmark_circle_fill
                    : CupertinoIcons.circle,
                size: 20,
                color: selected
                    ? AppColors.primary
                    : const Color(0xFFFFFFFF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
