import 'package:oruma_app/models/medicine_supply.dart';

enum MedicineSupplyActivityType { supplied, returned, cancelled }

class MedicineSupplyActivity {
  final MedicineSupply supply;
  final MedicineSupplyItem item;
  final MedicineSupplyReturn? returnEntry;
  final MedicineSupplyActivityType type;
  final DateTime date;
  final int quantity;

  const MedicineSupplyActivity({
    required this.supply,
    required this.item,
    this.returnEntry,
    required this.type,
    required this.date,
    required this.quantity,
  });

  static List<MedicineSupplyActivity> fromSupplies(
    List<MedicineSupply> supplies,
  ) {
    final activities = <MedicineSupplyActivity>[];

    for (final supply in supplies) {
      for (final item in _itemsForSupply(supply)) {
        if (item.qtyGiven <= 0) continue;

        final suppliedDate = item.givenAt ?? supply.givenAt;
        activities.add(
          MedicineSupplyActivity(
            supply: supply,
            item: item,
            type: MedicineSupplyActivityType.supplied,
            date: suppliedDate,
            quantity: item.qtyGiven,
          ),
        );

        activities.addAll(_returnActivitiesForItem(supply, item));

        if (item.status == 'cancelled' || item.cancelledAt != null) {
          final cancelledQty = item.remainingQty > 0
              ? item.remainingQty
              : item.qtyGiven;
          activities.add(
            MedicineSupplyActivity(
              supply: supply,
              item: item,
              type: MedicineSupplyActivityType.cancelled,
              date:
                  item.cancelledAt ??
                  supply.updatedAt ??
                  supply.returnedAt ??
                  supply.givenAt,
              quantity: cancelledQty,
            ),
          );
        }
      }
    }

    activities.sort((a, b) {
      final dateOrder = b.date.compareTo(a.date);
      if (dateOrder != 0) return dateOrder;
      return _typeSortWeight(a.type).compareTo(_typeSortWeight(b.type));
    });

    return activities;
  }

  static List<MedicineSupplyItem> _itemsForSupply(MedicineSupply supply) {
    if (supply.items.isNotEmpty) {
      return supply.items
          .map(
            (item) => item.supplyId == null
                ? item.copyWith(supplyId: supply.id)
                : item,
          )
          .toList();
    }

    return [
      MedicineSupplyItem(
        id: supply.id,
        supplyId: supply.id,
        medicineId: supply.medicineId,
        qtyGiven: supply.qtyGiven,
        givenAt: supply.givenAt,
        status: supply.status ?? 'given',
        qtyReturned: supply.qtyReturned,
        returnedAt: supply.returnedAt,
        staffNote: supply.staffNote,
      ),
    ];
  }

  static int _returnedQuantity(MedicineSupply supply, MedicineSupplyItem item) {
    if (item.returnedQty > 0) return item.returnedQty;
    if (supply.items.isEmpty && (supply.qtyReturned ?? 0) > 0) {
      return supply.qtyReturned!.clamp(0, item.qtyGiven).toInt();
    }
    return 0;
  }

  static List<MedicineSupplyActivity> _returnActivitiesForItem(
    MedicineSupply supply,
    MedicineSupplyItem item,
  ) {
    if (item.returns.isNotEmpty) {
      final activities = item.returns
          .where((entry) => entry.qtyReturned > 0)
          .map(
            (entry) => MedicineSupplyActivity(
              supply: supply,
              item: item,
              returnEntry: entry,
              type: MedicineSupplyActivityType.returned,
              date: entry.returnedAt ?? item.returnedAt ?? supply.givenAt,
              quantity: entry.qtyReturned,
            ),
          )
          .toList();
      final historyTotal = item.returns.fold<int>(
        0,
        (sum, entry) => sum + entry.qtyReturned,
      );
      final missingLegacyQty = item.returnedQty - historyTotal;
      if (missingLegacyQty > 0) {
        activities.add(
          MedicineSupplyActivity(
            supply: supply,
            item: item,
            type: MedicineSupplyActivityType.returned,
            date: item.returnedAt ?? supply.returnedAt ?? supply.givenAt,
            quantity: missingLegacyQty,
          ),
        );
      }
      return activities;
    }

    final returnedQty = _returnedQuantity(supply, item);
    final hasReturn =
        returnedQty > 0 ||
        item.returnedAt != null ||
        item.status == 'returned' ||
        item.status == 'partially_given';
    if (!hasReturn) return const [];

    return [
      MedicineSupplyActivity(
        supply: supply,
        item: item,
        type: MedicineSupplyActivityType.returned,
        date: item.returnedAt ?? supply.returnedAt ?? supply.givenAt,
        quantity: returnedQty > 0 ? returnedQty : item.qtyGiven,
      ),
    ];
  }

  static int _typeSortWeight(MedicineSupplyActivityType type) {
    return switch (type) {
      MedicineSupplyActivityType.returned => 0,
      MedicineSupplyActivityType.cancelled => 1,
      MedicineSupplyActivityType.supplied => 2,
    };
  }

  DateTime get supplyDate => item.givenAt ?? supply.givenAt;

  DateTime? get expiryDate => returnEntry?.expiryDate ?? item.expiryDate;

  String get medicineName {
    final itemName = item.medicineName.trim();
    if (itemName.isNotEmpty && itemName != 'Unknown') return itemName;
    return supply.medicineName;
  }

  String get medicineCode {
    final itemCode = item.medicineCode.trim();
    if (itemCode.isNotEmpty) return itemCode;
    if (supply.medicineId is Map) {
      return supply.medicineId['code']?.toString() ?? '';
    }
    return '';
  }

  String get batchNumber => item.batchNumber;

  String get stockLabel {
    final source = item.sourceLabel.trim();
    return source.isEmpty ? 'Main Stock' : source;
  }

  String get quantityLabel {
    final unit = item.qtyUnit.trim();
    return unit.isEmpty ? '$quantity' : '$quantity $unit';
  }

  String get eventLabel {
    return switch (type) {
      MedicineSupplyActivityType.supplied => 'Supplied',
      MedicineSupplyActivityType.returned => 'Returned',
      MedicineSupplyActivityType.cancelled => 'Cancelled',
    };
  }

  String get statusValue {
    return switch (type) {
      MedicineSupplyActivityType.supplied => 'given',
      MedicineSupplyActivityType.returned => 'returned',
      MedicineSupplyActivityType.cancelled => 'cancelled',
    };
  }

  String? get note {
    final returnNote = returnEntry?.staffNote?.trim();
    if (returnNote?.isNotEmpty == true) return returnNote;
    final itemNote = item.staffNote?.trim();
    if (itemNote?.isNotEmpty == true) return itemNote;
    final supplyNote = supply.staffNote?.trim();
    return supplyNote?.isNotEmpty == true ? supplyNote : null;
  }
}
