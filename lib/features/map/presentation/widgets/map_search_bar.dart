import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:mapbox_search/mapbox_search.dart';

class MapSearchBar extends ConsumerStatefulWidget {
  const MapSearchBar({
    super.key,
    required this.mapboxMap,
    this.onSearchCompleted,
  });

  final MapboxMap? mapboxMap;
  final Future<void> Function()? onSearchCompleted;

  @override
  ConsumerState<MapSearchBar> createState() => _MapSearchBarState();
}

class _MapSearchBarState extends ConsumerState<MapSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  SearchBoxAPI? _search;
  int _querySerial = 0;
  List<Suggestion> _suggestions = [];
  bool _isLoadingSuggestions = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);

    final apiKey = dotenv.env['MAPBOX_ACCESS_TOKEN'];
    if (apiKey != null && apiKey.isNotEmpty) {
      _search = SearchBoxAPI(
        apiKey: apiKey,
        limit: 5,
        language: 'ja',
        types: const [
          PlaceType.poi,
          PlaceType.address,
          PlaceType.country,
          PlaceType.district,
          PlaceType.locality,
          PlaceType.neighborhood,
          PlaceType.place,
          PlaceType.postcode,
          PlaceType.region,
        ],
      );
    }
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
    _fetchSuggestions(_controller.text.trim());
  }

  Future<void> _fetchSuggestions(String query) async {
    final search = _search;
    if (search == null || query.length < 2) {
      if (!mounted) return;
      setState(() {
        _suggestions = [];
        _isLoadingSuggestions = false;
      });
      return;
    }

    final serial = ++_querySerial;
    setState(() {
      _isLoadingSuggestions = true;
    });

    try {
      final response = await search.getSuggestions(query);
      if (!mounted || serial != _querySerial) return;

      final suggestions = response.fold(
        (success) => success.suggestions,
        (failure) => <Suggestion>[],
      );

      if (!mounted || serial != _querySerial) return;
      setState(() {
        _suggestions = suggestions;
      });
    } finally {
      if (mounted && serial == _querySerial) {
        setState(() {
          _isLoadingSuggestions = false;
        });
      }
    }
  }

  Future<void> _moveToSuggestion(Suggestion suggestion) async {
    final mapboxMap = widget.mapboxMap;
    final search = _search;
    if (mapboxMap == null || search == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('検索の準備ができていません')));
      return;
    }

    setState(() {
      _isSearching = true;
    });
    _focusNode.unfocus();

    try {
      final placeResponse = await search.getPlace(suggestion.mapboxId);
      final place = placeResponse.fold(
        (success) => success.features.firstOrNull,
        (failure) {
          throw StateError(failure.message ?? '施設詳細の取得に失敗しました');
        },
      );

      final coordinates = place?.geometry.coordinates;
      if (coordinates == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('施設の位置情報を取得できませんでした')));
        return;
      }

      await mapboxMap.setCamera(
        CameraOptions(
          center: Point(
            coordinates: Position(coordinates.long, coordinates.lat),
          ),
          zoom: 14,
        ),
      );
      await widget.onSearchCompleted?.call();

      if (!mounted) return;
      setState(() {
        _controller.text = suggestion.name;
        _controller.selection = TextSelection.collapsed(
          offset: _controller.text.length,
        );
        _suggestions = [];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('検索に失敗しました: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _searchLocation(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty || _isSearching) return;

    if (_suggestions.isNotEmpty) {
      await _moveToSuggestion(_suggestions.first);
      return;
    }

    final search = _search;
    if (search == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Mapbox token が設定されていません')));
      return;
    }

    setState(() {
      _isSearching = true;
    });
    _focusNode.unfocus();

    try {
      final response = await search.getSuggestions(trimmedQuery);
      final suggestions = response.fold((success) => success.suggestions, (
        failure,
      ) {
        throw StateError(failure.message ?? '施設検索に失敗しました');
      });

      if (suggestions.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('場所が見つかりませんでした')));
        return;
      }

      await _moveToSuggestion(suggestions.first);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('検索に失敗しました: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showSuggestions =
        _focusNode.hasFocus && _controller.text.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(28),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            textInputAction: TextInputAction.search,
            onSubmitted: _searchLocation,
            decoration: InputDecoration(
              hintText: '検索',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _isSearching || _isLoadingSuggestions
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _controller.clear();
                        setState(() {
                          _suggestions = [];
                        });
                        _focusNode.requestFocus();
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 0,
              ),
            ),
          ),
        ),
        if (showSuggestions && _suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _suggestions.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final suggestion = _suggestions[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined),
                    title: Text(
                      suggestion.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      suggestion.fullAddress ?? suggestion.placeFormatted,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _moveToSuggestion(suggestion),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}
