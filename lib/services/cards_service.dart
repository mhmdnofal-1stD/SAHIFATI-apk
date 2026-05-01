import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/card_model.dart';
import 'sahifaty_api.dart';

class CardsService {
  final SahifatyApi _api = SahifatyApi();

  /// Fetches a paginated list of cards.
  ///
  /// Role-based filtering is applied server-side:
  /// - Role 0 (student): only approved cards
  /// - Role 3 (researcher): own cards
  /// - Role 4 (reviewer): pending + partial-approval queue
  /// - Role 5 (admitter): initial-approval queue
  Future<({List<CardModel> cards, int total, int page, int pages})> getCards({
    int page = 1,
    int limit = 20,
    String? status,
    String? search,
    String orderBy = 'createdAt',
    String orderDirection = 'desc',
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      'orderBy': orderBy,
      'orderDirection': orderDirection,
    };
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final query = Uri(queryParameters: params).query;
    final response = await _api.get('cards?$query');

    if (response.statusCode == 200) {
      final body = json.decode(response.body) as Map<String, dynamic>;
      final data = body['data'] as List? ?? [];
      return (
        cards: data
            .whereType<Map>()
            .map((e) => CardModel.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        total: (body['total'] as int?) ?? data.length,
        page: (body['page'] as int?) ?? page,
        pages: (body['pages'] as int?) ?? 1,
      );
    }
    throw Exception('cards_load_failed');
  }

  Future<CardModel> getCard(int id) async {
    final response = await _api.get('cards/$id');
    if (response.statusCode == 200) {
      return CardModel.fromJson(
        Map<String, dynamic>.from(json.decode(response.body) as Map),
      );
    }
    throw Exception('card_not_found');
  }

  /// Changes the workflow status of a card (reviewer / admitter / researcher).
  Future<CardModel> updateStatus(
    int id, {
    required String status,
    String? comment,
    String? rejectReason,
  }) async {
    final body = <String, dynamic>{'status': status};
    if (comment != null && comment.trim().isNotEmpty) body['comment'] = comment;
    if (rejectReason != null && rejectReason.trim().isNotEmpty) {
      body['rejectReason'] = rejectReason;
    }

    final response = await _api.put(url: 'cards/$id/status', body: body);
    if (response.statusCode == 200) {
      return CardModel.fromJson(
        Map<String, dynamic>.from(json.decode(response.body) as Map),
      );
    }
    final msg = _extractMessage(response);
    throw Exception(msg);
  }

  /// Adds a review comment without changing status.
  Future<CardModel> addComment(int id, String comment) async {
    final response = await _api.put(
      url: 'cards/$id',
      body: {'comment': comment},
    );
    if (response.statusCode == 200) {
      return CardModel.fromJson(
        Map<String, dynamic>.from(json.decode(response.body) as Map),
      );
    }
    throw Exception(_extractMessage(response));
  }

  String _extractMessage(http.Response response) {
    try {
      final body = json.decode(response.body);
      if (body is Map && body['message'] != null) {
        return body['message'].toString();
      }
    } catch (_) {}
    return 'request_failed';
  }
}
