import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/image_model.dart';
import 'connection_status_provider.dart';

class ImagesState {
  final List<ImageModel> images;
  final bool isLoading;
  final String? error;

  ImagesState({
    required this.images,
    this.isLoading = false,
    this.error,
  });

  ImagesState copyWith({
    List<ImageModel>? images,
    bool? isLoading,
    String? error,
  }) {
    return ImagesState(
      images: images ?? this.images,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final imageSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredImagesProvider = Provider<List<ImageModel>>((ref) {
  final state = ref.watch(imagesNotifierProvider);
  final search = ref.watch(imageSearchQueryProvider).toLowerCase().trim();

  if (search.isEmpty) return state.images;

  return state.images.where((img) {
    return img.primaryTag.toLowerCase().contains(search) ||
        img.id.toLowerCase().contains(search);
  }).toList();
});

class ImagesNotifier extends StateNotifier<ImagesState> {
  final dynamic _client;
  final bool _isConnected;

  ImagesNotifier(this._client, this._isConnected)
      : super(ImagesState(images: [], isLoading: true)) {
    if (_isConnected) {
      refreshImages();
    } else {
      state = ImagesState(images: [], isLoading: false, error: 'Docker daemon disconnected');
    }
  }

  Future<void> refreshImages({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final list = await _client.getImages(showAll: true);
      if (!mounted) return;
      state = ImagesState(images: list, isLoading: false, error: null);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> removeImage(String id, {bool force = false}) async {
    try {
      await _client.removeImage(id, force: force);
      if (mounted) {
        await refreshImages(silent: true);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(error: e.toString());
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> pruneImages() async {
    try {
      final res = await _client.pruneImages();
      if (mounted) {
        await refreshImages(silent: true);
      }
      return res;
    } catch (e) {
      return {'Error': e.toString()};
    }
  }
}

final imagesNotifierProvider =
    StateNotifierProvider<ImagesNotifier, ImagesState>((ref) {
  final client = ref.watch(dockerApiClientProvider);
  final connState = ref.watch(connectionStatusProvider);
  return ImagesNotifier(client, connState.isConnected);
});
