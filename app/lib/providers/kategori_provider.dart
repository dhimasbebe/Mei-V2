import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/kategori_repository.dart';
import '../domain/models/kategori.dart';
import '../domain/models/spesifikasi.dart';

final kategoriRepositoryProvider = Provider<KategoriRepository>((ref) => const KategoriRepository());

final kategoriListProvider = FutureProvider<List<Kategori>>((ref) async {
  final repo = ref.watch(kategoriRepositoryProvider);
  return repo.getKategoriList();
});

final spesifikasiProvider = FutureProvider.family<List<Spesifikasi>, int>((ref, idKategori) async {
  final repo = ref.watch(kategoriRepositoryProvider);
  return repo.getSpesifikasi(idKategori);
});
