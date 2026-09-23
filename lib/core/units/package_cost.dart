library;

/// Commercial-package ↔ base-unit cost conversion.
///
/// Unit-basis contract (the root cause of the historic COGS bug):
///  • the pharmacist always thinks and types in **commercial packages**
///    (the box / التعبئة التجارية);
///  • the database stores costs per **base unit** (`items.costMicros`,
///    `batches.unitCostMicros`) because COGS is computed per base unit
///    (`batch.unitCostMicros × quantityBase`).
///
/// Every cost entry point (item dialog, purchase invoice lines, manual batch
/// entry, Excel import) must convert package → base on the way in, and
/// base → package when displaying a stored value back. These helpers keep
/// that conversion in one place so the entry points cannot drift apart.
///
/// Division rounds half-up in integer micro-units; a non-positive
/// [unitsPerLarge] is treated as 1 (package == base unit).
import '../money/money.dart';

/// Converts a per-commercial-package amount to a per-base-unit amount.
int packageCostToBaseUnitCost(int packageCostMicros, int unitsPerLarge) =>
    Money.fromUnits(packageCostMicros)
        .divideBy(unitsPerLarge <= 0 ? 1 : unitsPerLarge)
        .units;

/// Converts a per-base-unit amount to a per-commercial-package amount.
int baseUnitCostToPackageCost(int baseUnitCostMicros, int unitsPerLarge) =>
    baseUnitCostMicros * (unitsPerLarge <= 0 ? 1 : unitsPerLarge);
