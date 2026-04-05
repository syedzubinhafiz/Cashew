import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/editWalletsPage.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/button.dart';
import 'package:budget/widgets/framework/popupFramework.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:budget/widgets/selectAmount.dart';
import 'package:budget/widgets/tappable.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:budget/widgets/util/showDatePicker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RecordReimbursementSheet extends StatefulWidget {
  const RecordReimbursementSheet({required this.transaction, super.key});
  final Transaction transaction;

  @override
  State<RecordReimbursementSheet> createState() =>
      _RecordReimbursementSheetState();
}

class _RecordReimbursementSheetState extends State<RecordReimbursementSheet> {
  late double _amount;
  late String _walletPk;
  late DateTime _dateTime;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amount = (widget.transaction.reimbursableAmount -
            widget.transaction.reimbursedAmount)
        .clamp(0.0, double.infinity);
    _walletPk = appStateSettings["selectedWalletPk"];
    _dateTime = DateTime.now();
  }

  Future<void> _submit() async {
    AllWallets allWallets = Provider.of<AllWallets>(context, listen: false);
    TransactionWallet? destWallet = allWallets.indexedByPk[_walletPk];
    if (destWallet == null) return;
    setState(() {
      _isLoading = true;
    });
    try {
      await database.recordReimbursement(
        originalTransaction: widget.transaction,
        reimbursementAmount: _amount,
        destinationWallet: destWallet,
        dateTime: _dateTime,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        popRoute(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AllWallets allWallets = Provider.of<AllWallets>(context);
    TransactionWallet? currentWallet = allWallets.indexedByPk[_walletPk];

    return PopupFramework(
      title: "Record Reimbursement",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Amount row
          Tappable(
            color: getColor(context, "lightDarkAccentHeavyLight"),
            borderRadius: 12,
            onTap: () async {
              await openBottomSheet(
                context,
                PopupFramework(
                  title: "Amount",
                  child: SelectAmountValue(
                    amountPassed: _amount.toString(),
                    setSelectedAmount: (amount, _) {
                      setState(() {
                        _amount = amount;
                      });
                    },
                    next: () {
                      popRoute(context);
                    },
                    nextLabel: "set-amount".tr(),
                    allowZero: false,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 15, vertical: 13),
              child: Row(
                children: [
                  Icon(
                    appStateSettings["outlinedIcons"]
                        ? Icons.payments_outlined
                        : Icons.payments_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextFont(
                      text: "Amount",
                      fontSize: 15,
                      textColor:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  TextFont(
                    text: convertToMoney(allWallets, _amount),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 8),
          // Wallet row
          Tappable(
            color: getColor(context, "lightDarkAccentHeavyLight"),
            borderRadius: 12,
            onTap: () async {
              TransactionWallet? result = await selectWalletPopup(
                context,
                selectedWallet: currentWallet,
                allowEditWallet: false,
              );
              if (result != null) {
                setState(() {
                  _walletPk = result.walletPk;
                });
              }
            },
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 15, vertical: 13),
              child: Row(
                children: [
                  Icon(
                    appStateSettings["outlinedIcons"]
                        ? Icons.account_balance_wallet_outlined
                        : Icons.account_balance_wallet_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextFont(
                      text: "Destination Account",
                      fontSize: 15,
                      textColor:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  TextFont(
                    text: currentWallet?.name ?? "Select Account",
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 8),
          // Date row
          Tappable(
            color: getColor(context, "lightDarkAccentHeavyLight"),
            borderRadius: 12,
            onTap: () async {
              DateTime? picked = await showCustomDatePicker(context, _dateTime);
              if (picked != null) {
                setState(() {
                  _dateTime = _dateTime.copyWith(
                    year: picked.year,
                    month: picked.month,
                    day: picked.day,
                  );
                });
              }
            },
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 15, vertical: 13),
              child: Row(
                children: [
                  Icon(
                    appStateSettings["outlinedIcons"]
                        ? Icons.calendar_today_outlined
                        : Icons.calendar_today_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextFont(
                      text: "Date",
                      fontSize: 15,
                      textColor:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  TextFont(
                    text: getWordedDateShortMore(
                      _dateTime,
                      includeYear: _dateTime.year != DateTime.now().year,
                    ),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 18),
          // Submit button
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : Button(
                  label: "Record Reimbursement",
                  onTap: _submit,
                  disabled: _amount <= 0,
                  expandedLayout: true,
                ),
          SizedBox(height: 8),
        ],
      ),
    );
  }
}
