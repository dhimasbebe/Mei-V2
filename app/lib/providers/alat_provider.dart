import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/alat_repository.dart';
import '../domain/models/alat.dart';
import '../domain/models/lokasi.dart';

final alatRepositoryProvider = Provider<AlatRepository>((ref) => const AlatRepository());

/// Alat yang discan / dicari saat ini (untuk detail & form).
final alatDetailProvider = StateProvider<Alat?>((ref) => null);

final alatByBarcodeProvider = FutureProvider.family<Alat, String>((ref, barcode) async {
  final repo = ref.watch(alatRepositoryProvider);
  return repo.getByBarcode(barcode);
});

final alatSearchProvider = FutureProvider.family<List<Alat>, AlatSearchParams>((ref, params) async {
  final repo = ref.watch(alatRepositoryProvider);
  return repo.search(query: params.query, idKategori: params.idKategori, idLokasi: params.idLokasi);
});

final lokasiListProvider = FutureProvider<List<Lokasi>>((ref) async {
  final repo = ref.watch(alatRepositoryProvider);
  return repo.getLokasiList();
});

@immutable
class AlatSearchParams {
  const AlatSearchParams({this.query, this.idKategori, this.idLokasi});
  final String? query;
  final int? idKategori;
  final int? idLokasi;

  @override
  bool operator ==(Object other) =>
      other is AlatSearchParams &&
      other.query == query &&
      other.idKategori == idKategori &&
      other.idLokasi == idLokasi;

  @override
  int get hashCode => Object.hash(query, idKategori, idLokasi);
}
