import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sentei/domain/models/track_photo.dart';
import 'package:sentei/domain/services/photo_session_grouper.dart';

TrackPhoto _photo(String id, {DateTime? takenAt}) => TrackPhoto(
      id: id,
      position: const LatLng(45.0, 7.0),
      distanceMeters: 0,
      takenAt: takenAt,
    );

void main() {
  const grouper = PhotoSessionGrouper();

  test('nessuna foto → nessun gruppo', () {
    expect(grouper.group(const []), isEmpty);
  });

  test('foto vicine nel tempo finiscono nello stesso gruppo', () {
    final photos = [
      _photo('a', takenAt: DateTime(2025, 8, 18, 9, 0)),
      _photo('b', takenAt: DateTime(2025, 8, 18, 11, 30)),
      _photo('c', takenAt: DateTime(2025, 8, 18, 15, 0)),
    ];
    final sessions = grouper.group(photos);
    expect(sessions, hasLength(1));
    expect(sessions.single.photos.map((p) => p.id), ['a', 'b', 'c']);
    expect(sessions.single.date, DateTime(2025, 8, 18, 9, 0));
  });

  test('gap oltre la soglia crea un gruppo separato, più recente prima', () {
    final photos = [
      _photo('old', takenAt: DateTime(2022, 8, 27, 10, 0)),
      _photo('new', takenAt: DateTime(2025, 8, 18, 9, 0)),
    ];
    final sessions = grouper.group(photos);
    expect(sessions, hasLength(2));
    expect(sessions[0].photos.single.id, 'new');
    expect(sessions[1].photos.single.id, 'old');
  });

  test('pernottamento (gap < 30h attraverso la mezzanotte) resta un gruppo solo', () {
    final photos = [
      _photo('sera', takenAt: DateTime(2025, 8, 18, 20, 0)),
      _photo('mattina', takenAt: DateTime(2025, 8, 19, 6, 0)),
    ];
    expect(grouper.group(photos), hasLength(1));
  });

  test('foto senza data finiscono in un unico gruppo finale con date null', () {
    final photos = [
      _photo('dated', takenAt: DateTime(2025, 8, 18, 9, 0)),
      _photo('undated1'),
      _photo('undated2'),
    ];
    final sessions = grouper.group(photos);
    expect(sessions, hasLength(2));
    expect(sessions[0].date, isNotNull);
    expect(sessions[1].date, isNull);
    expect(sessions[1].photos.map((p) => p.id), ['undated1', 'undated2']);
  });

  test('soglia personalizzata', () {
    const tightGrouper = PhotoSessionGrouper(maxGap: Duration(hours: 1));
    final photos = [
      _photo('a', takenAt: DateTime(2025, 8, 18, 9, 0)),
      _photo('b', takenAt: DateTime(2025, 8, 18, 11, 0)),
    ];
    expect(tightGrouper.group(photos), hasLength(2));
  });
}
