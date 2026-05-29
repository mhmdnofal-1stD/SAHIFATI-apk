import 'package:flutter/foundation.dart';

import '../models/card_model.dart';
import '../services/cards_service.dart';

class CardsProvider with ChangeNotifier {
  final CardsService _service = CardsService();

  List<CardModel> cards = [];
  bool isLoading = false;
  bool hasError = false;
  String errorMessage = '';

  int currentPage = 1;
  int totalPages = 1;
  int totalCount = 0;

  String searchQuery = '';
  String statusFilter = '';

  CardModel? selectedCard;
  bool isDetailLoading = false;

  // ── List operations ─────────────────────────────────────────────────────────

  Future<void> loadCards({
    bool reset = false,
    String? status,
    String? search,
  }) async {
    if (reset) {
      currentPage = 1;
      cards = [];
    }

    if (isLoading) return;
    isLoading = true;
    hasError = false;
    notifyListeners();

    try {
      final result = await _service.getCards(
        page: currentPage,
        status: status ?? statusFilter,
        search: search ?? searchQuery,
      );
      if (reset) {
        cards = result.cards;
      } else {
        cards = [...cards, ...result.cards];
      }
      totalCount = result.total;
      totalPages = result.pages;
    } catch (e) {
      hasError = true;
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadNextPage() async {
    if (currentPage >= totalPages || isLoading) return;
    currentPage++;
    await loadCards();
  }

  void setSearch(String query) {
    searchQuery = query;
    loadCards(reset: true, search: query);
  }

  void setStatusFilter(String status) {
    statusFilter = status;
    loadCards(reset: true, status: status);
  }

  // ── Detail operations ────────────────────────────────────────────────────────

  Future<void> loadCard(int id) async {
    isDetailLoading = true;
    hasError = false;
    errorMessage = '';
    final cachedFromList = cards.cast<CardModel?>().firstWhere(
      (card) => card?.id == id,
      orElse: () => null,
    );
    if (cachedFromList != null) {
      selectedCard = cachedFromList;
    }
    notifyListeners();
    try {
      selectedCard = await _service.getCard(id);
    } catch (e) {
      hasError = selectedCard == null;
      errorMessage = e.toString();
    } finally {
      isDetailLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateStatus(
    int id, {
    required String status,
    String? comment,
    String? rejectReason,
  }) async {
    try {
      final updated = await _service.updateStatus(
        id,
        status: status,
        comment: comment,
        rejectReason: rejectReason,
      );
      selectedCard = updated;
      // Refresh in list if present
      cards = cards.map((c) => c.id == id ? updated : c).toList();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> addComment(int id, String comment) async {
    try {
      final updated = await _service.addComment(id, comment);
      selectedCard = updated;
      cards = cards.map((c) => c.id == id ? updated : c).toList();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}
