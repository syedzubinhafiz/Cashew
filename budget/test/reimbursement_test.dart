/// Pure-Dart unit tests for reimbursement calculation logic.
///
/// These tests cover all edge cases for net-cost computation, progress
/// percentage, summary totals, and multi-account scenarios — without
/// depending on Flutter widgets or the database.
///
/// Run with:  flutter test test/reimbursement_test.dart
library reimbursement_test;

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Pure logic extracted from the app (no Flutter/database dependencies)
// ---------------------------------------------------------------------------

/// Net out-of-pocket cost for an expense transaction.
/// Returns the gross amount minus however much has been reimbursed so far.
/// Clamps at 0 — you can never have a negative cost from being over-reimbursed.
double netCost({
  required double grossAmount,
  required double reimbursedAmount,
}) {
  return (grossAmount - reimbursedAmount).clamp(0.0, double.infinity);
}

/// Pending reimbursement still owed.
double pendingReimbursement({
  required double reimbursableAmount,
  required double reimbursedAmount,
}) {
  return (reimbursableAmount - reimbursedAmount).clamp(0.0, double.infinity);
}

/// Progress as a fraction [0, 1].
double reimbursementProgress({
  required double reimbursableAmount,
  required double reimbursedAmount,
}) {
  if (reimbursableAmount <= 0) return 0.0;
  return (reimbursedAmount / reimbursableAmount).clamp(0.0, 1.0);
}

/// Whether the transaction is fully reimbursed.
bool isFullyReimbursed({
  required double reimbursableAmount,
  required double reimbursedAmount,
}) {
  return reimbursedAmount >= reimbursableAmount;
}

/// Adjust an amount for summary totals: for reimbursable expenses subtract
/// what has already been received (mirrors transactionEntries.dart logic).
double adjustedAmountForSummary({
  required double transactionAmount, // negative for expenses
  required bool isReimbursable,
  required bool isIncome,
  required double reimbursedAmount,
}) {
  if (isReimbursable && !isIncome && reimbursedAmount > 0) {
    return transactionAmount + reimbursedAmount;
  }
  return transactionAmount;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('netCost', () {
    test('no reimbursement — full gross amount', () {
      expect(netCost(grossAmount: 100, reimbursedAmount: 0), equals(100.0));
    });

    test('partial reimbursement — gross minus received', () {
      expect(netCost(grossAmount: 100, reimbursedAmount: 25), equals(75.0));
    });

    test('full reimbursement — zero out-of-pocket', () {
      expect(netCost(grossAmount: 100, reimbursedAmount: 100), equals(0.0));
    });

    test('over-reimbursement clamps to zero (not negative)', () {
      // Edge case: someone accidentally paid back more than owed.
      expect(netCost(grossAmount: 100, reimbursedAmount: 120), equals(0.0));
    });

    test('partial reimbursement expectation — paid 50% of what was expected', () {
      // RM100 dinner, expected to get back RM50, received RM25 so far.
      expect(netCost(grossAmount: 100, reimbursedAmount: 25), equals(75.0));
    });

    test('different-account reimbursement does not affect net cost formula', () {
      // The destination wallet is irrelevant to the net cost calculation —
      // only the amounts matter. RM100 paid via Card, RM40 received in Cash.
      expect(netCost(grossAmount: 100, reimbursedAmount: 40), equals(60.0));
    });
  });

  group('pendingReimbursement', () {
    test('nothing received yet — full amount pending', () {
      expect(
        pendingReimbursement(reimbursableAmount: 50, reimbursedAmount: 0),
        equals(50.0),
      );
    });

    test('half received — half pending', () {
      expect(
        pendingReimbursement(reimbursableAmount: 50, reimbursedAmount: 25),
        equals(25.0),
      );
    });

    test('fully received — zero pending', () {
      expect(
        pendingReimbursement(reimbursableAmount: 50, reimbursedAmount: 50),
        equals(0.0),
      );
    });

    test('over-received clamps pending to zero', () {
      expect(
        pendingReimbursement(reimbursableAmount: 50, reimbursedAmount: 60),
        equals(0.0),
      );
    });
  });

  group('reimbursementProgress', () {
    test('zero reimbursable amount returns 0% (avoids divide-by-zero)', () {
      expect(
        reimbursementProgress(reimbursableAmount: 0, reimbursedAmount: 0),
        equals(0.0),
      );
    });

    test('25/50 = 50%', () {
      expect(
        reimbursementProgress(reimbursableAmount: 50, reimbursedAmount: 25),
        equals(0.5),
      );
    });

    test('50/50 = 100%', () {
      expect(
        reimbursementProgress(reimbursableAmount: 50, reimbursedAmount: 50),
        equals(1.0),
      );
    });

    test('over-reimbursement clamps to 100%', () {
      expect(
        reimbursementProgress(reimbursableAmount: 50, reimbursedAmount: 70),
        equals(1.0),
      );
    });

    test('RM100 gross, RM100 reimbursable, RM25 received = 25%', () {
      expect(
        reimbursementProgress(reimbursableAmount: 100, reimbursedAmount: 25),
        equals(0.25),
      );
    });
  });

  group('isFullyReimbursed', () {
    test('equal amounts → fully reimbursed', () {
      expect(
        isFullyReimbursed(reimbursableAmount: 100, reimbursedAmount: 100),
        isTrue,
      );
    });

    test('received more than expected → fully reimbursed', () {
      expect(
        isFullyReimbursed(reimbursableAmount: 50, reimbursedAmount: 60),
        isTrue,
      );
    });

    test('partial → not fully reimbursed', () {
      expect(
        isFullyReimbursed(reimbursableAmount: 100, reimbursedAmount: 75),
        isFalse,
      );
    });

    test('nothing received → not fully reimbursed', () {
      expect(
        isFullyReimbursed(reimbursableAmount: 100, reimbursedAmount: 0),
        isFalse,
      );
    });
  });

  group('adjustedAmountForSummary', () {
    // transactionAmount is negative for expenses in the app
    test('non-reimbursable expense — unchanged', () {
      expect(
        adjustedAmountForSummary(
          transactionAmount: -100,
          isReimbursable: false,
          isIncome: false,
          reimbursedAmount: 0,
        ),
        equals(-100.0),
      );
    });

    test('reimbursable expense, nothing received — unchanged (still -100)', () {
      expect(
        adjustedAmountForSummary(
          transactionAmount: -100,
          isReimbursable: true,
          isIncome: false,
          reimbursedAmount: 0,
        ),
        equals(-100.0),
      );
    });

    test('reimbursable expense, RM25 received — summary shows -75', () {
      expect(
        adjustedAmountForSummary(
          transactionAmount: -100,
          isReimbursable: true,
          isIncome: false,
          reimbursedAmount: 25,
        ),
        equals(-75.0),
      );
    });

    test('fully reimbursed expense — summary shows 0', () {
      expect(
        adjustedAmountForSummary(
          transactionAmount: -100,
          isReimbursable: true,
          isIncome: false,
          reimbursedAmount: 100,
        ),
        equals(0.0),
      );
    });

    test('income transactions are never adjusted (reimbursement receipts)', () {
      // The paired income transaction created when recording a reimbursement
      // should pass through unadjusted.
      expect(
        adjustedAmountForSummary(
          transactionAmount: 25,
          isReimbursable: false,
          isIncome: true,
          reimbursedAmount: 0,
        ),
        equals(25.0),
      );
    });
  });

  group('end-to-end scenarios', () {
    test('Scenario A: RM100 dinner, expect RM100 back, received RM0', () {
      // Gross: RM100, reimbursable: RM100, received: RM0
      // Net cost shown on entry:        RM100 (nothing back yet)
      // Pending:                         RM100
      // Progress:                        0%
      // Summary expense contribution:   -RM100
      expect(netCost(grossAmount: 100, reimbursedAmount: 0), equals(100.0));
      expect(pendingReimbursement(reimbursableAmount: 100, reimbursedAmount: 0), equals(100.0));
      expect(reimbursementProgress(reimbursableAmount: 100, reimbursedAmount: 0), equals(0.0));
      expect(adjustedAmountForSummary(transactionAmount: -100, isReimbursable: true, isIncome: false, reimbursedAmount: 0), equals(-100.0));
    });

    test('Scenario B: RM100 dinner, expect RM50 back, received RM25 (50% of expected)', () {
      // This matches the screenshot: RM25 / RM50 at 50%
      // Net cost shown on entry:        RM75 (paid RM100, got RM25 back)
      // Pending:                         RM25
      // Progress:                        50%
      // Summary expense contribution:   -RM75
      expect(netCost(grossAmount: 100, reimbursedAmount: 25), equals(75.0));
      expect(pendingReimbursement(reimbursableAmount: 50, reimbursedAmount: 25), equals(25.0));
      expect(reimbursementProgress(reimbursableAmount: 50, reimbursedAmount: 25), equals(0.5));
      expect(adjustedAmountForSummary(transactionAmount: -100, isReimbursable: true, isIncome: false, reimbursedAmount: 25), equals(-75.0));
    });

    test('Scenario C: RM100 dinner, expect RM50 back, received RM50 (fully reimbursed)', () {
      // Net cost:   RM50 (only half was reimbursable)
      // Pending:     RM0
      // Progress:   100%
      // Summary:    -RM50
      expect(netCost(grossAmount: 100, reimbursedAmount: 50), equals(50.0));
      expect(pendingReimbursement(reimbursableAmount: 50, reimbursedAmount: 50), equals(0.0));
      expect(isFullyReimbursed(reimbursableAmount: 50, reimbursedAmount: 50), isTrue);
      expect(adjustedAmountForSummary(transactionAmount: -100, isReimbursable: true, isIncome: false, reimbursedAmount: 50), equals(-50.0));
    });

    test('Scenario D: Reimbursement to different account (Bank → Cash)', () {
      // User paid RM100 from Bank card. Friend paid back RM100 in Cash.
      // The income transaction lands in Cash wallet (walletFk = cashWallet).
      // The expense on Bank is tracked with reimbursedAmount = 100.
      // Net cost on expense entry: RM0
      // Bank balance impact: -RM100 (unchanged — this is actual cash out)
      // Cash balance impact: +RM100 (income tx in Cash wallet)
      // No double-counting because netAmount() returns tbl.amount only.
      expect(netCost(grossAmount: 100, reimbursedAmount: 100), equals(0.0));
      expect(isFullyReimbursed(reimbursableAmount: 100, reimbursedAmount: 100), isTrue);
      // The income transaction itself is untouched by adjustedAmountForSummary
      expect(adjustedAmountForSummary(transactionAmount: 100, isReimbursable: false, isIncome: true, reimbursedAmount: 0), equals(100.0));
    });

    test('Scenario E: Multiple partial payments (RM25 + RM25 = RM50 of RM100)', () {
      // After first payment: reimbursedAmount = 25
      double afterFirst = netCost(grossAmount: 100, reimbursedAmount: 25);
      expect(afterFirst, equals(75.0));
      // After second payment: reimbursedAmount = 50
      double afterSecond = netCost(grossAmount: 100, reimbursedAmount: 50);
      expect(afterSecond, equals(50.0));
      expect(reimbursementProgress(reimbursableAmount: 100, reimbursedAmount: 50), equals(0.5));
    });

    test('Scenario F: Over-reimbursement (friend pays back RM120 for RM100 expense)', () {
      // Net cost clamps to 0, progress clamps to 100%
      expect(netCost(grossAmount: 100, reimbursedAmount: 120), equals(0.0));
      expect(reimbursementProgress(reimbursableAmount: 100, reimbursedAmount: 120), equals(1.0));
      expect(isFullyReimbursed(reimbursableAmount: 100, reimbursedAmount: 120), isTrue);
    });

    test('Scenario G: Partial reimbursable amount (split bill — RM30 of RM100 expected back)', () {
      // User paid RM100 but only their share beyond their half (RM30) will come back.
      // reimbursableAmount = 30, reimbursedAmount = 0
      expect(netCost(grossAmount: 100, reimbursedAmount: 0), equals(100.0));
      expect(pendingReimbursement(reimbursableAmount: 30, reimbursedAmount: 0), equals(30.0));
      // After receiving RM30:
      expect(netCost(grossAmount: 100, reimbursedAmount: 30), equals(70.0));
      expect(isFullyReimbursed(reimbursableAmount: 30, reimbursedAmount: 30), isTrue);
    });
  });
}
