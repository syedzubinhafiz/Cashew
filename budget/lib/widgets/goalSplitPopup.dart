import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/goalAllocation.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/button.dart';
import 'package:budget/widgets/framework/popupFramework.dart';
import 'package:budget/widgets/noResults.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:budget/widgets/radioItems.dart';
import 'package:budget/widgets/selectAmount.dart';
import 'package:budget/widgets/tappable.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class GoalSplitPopup extends StatefulWidget {
  const GoalSplitPopup({
    required this.totalAmount,
    required this.walletPk,
    required this.initialAllocations,
    super.key,
  });

  final double totalAmount;
  final String walletPk;
  final List<GoalAllocation> initialAllocations;

  @override
  State<GoalSplitPopup> createState() => _GoalSplitPopupState();
}

class _GoalSplitPopupState extends State<GoalSplitPopup> {
  late List<GoalAllocation> allocations;

  @override
  void initState() {
    super.initState();
    allocations = List.from(widget.initialAllocations);
  }

  double get totalAllocated =>
      allocations.fold(0.0, (sum, a) => sum + a.amount);

  double get remaining => widget.totalAmount - totalAllocated;

  bool get isOverAllocated => remaining < -0.001;

  Future<void> _addGoal() async {
    await openBottomSheet(
      context,
      PopupFramework(
        title: "Add Savings Goal",
        child: StreamBuilder<List<Objective>>(
          stream: database.watchAllObjectives(
            objectiveType: ObjectiveType.goal,
          ),
          builder: (context, snap) {
            List<Objective> goals =
                (snap.data ?? []).where((o) => o.income).toList();
            // Filter out already-allocated goals
            final Set<String> usedPks =
                allocations.map((a) => a.objectivePk).toSet();
            goals = goals
                .where((g) => !usedPks.contains(g.objectivePk))
                .toList();
            if (goals.isEmpty)
              return Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 15),
                child: NoResults(message: "No additional savings goals found"),
              );
            return RadioItems<Objective>(
              initial: goals.first,
              getSelected: (_) => false,
              items: goals,
              displayFilter: (Objective obj) => obj.name,
              onChanged: (Objective obj) {
                setState(() {
                  // Default amount: remaining amount, or zero if already over
                  final double defaultAmount =
                      remaining > 0 ? remaining : 0;
                  allocations.add(GoalAllocation(
                    objectivePk: obj.objectivePk,
                    amount: defaultAmount,
                  ));
                });
                popRoute(context);
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _editAmount(int index) async {
    await openBottomSheet(
      context,
      fullSnap: true,
      PopupFramework(
        title: "Set Amount",
        hasPadding: false,
        underTitleSpace: false,
        child: SelectAmount(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 18),
          allowZero: true,
          allDecimals: true,
          convertToMoney: true,
          setSelectedAmount: (amount, __) {
            setState(() {
              allocations[index] = GoalAllocation(
                objectivePk: allocations[index].objectivePk,
                amount: amount,
              );
            });
          },
          amountPassed: allocations[index].amount.toString(),
          next: () {
            popRoute(context);
          },
          nextLabel: "set-amount".tr(),
          enableWalletPicker: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AllWallets allWallets = Provider.of<AllWallets>(context);

    Color remainingColor;
    if (remaining.abs() < 0.001) {
      remainingColor = Colors.green;
    } else if (remaining < 0) {
      remainingColor = Theme.of(context).colorScheme.error;
    } else {
      remainingColor = getColor(context, "textLight");
    }

    return PopupFramework(
      title: "Split Across Goals",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Allocations list
          ...List.generate(allocations.length, (i) {
            final alloc = allocations[i];
            return Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 8),
              child: Tappable(
                color: getColor(context, "lightDarkAccentHeavyLight"),
                borderRadius: 12,
                onTap: () => _editAmount(i),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 15, vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        appStateSettings["outlinedIcons"]
                            ? Icons.savings_outlined
                            : Icons.savings_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: StreamBuilder<Objective>(
                          stream: database.getObjective(alloc.objectivePk),
                          builder: (context, snap) {
                            return TextFont(
                              text: snap.data?.name ?? "...",
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            );
                          },
                        ),
                      ),
                      Tappable(
                        color: Colors.transparent,
                        borderRadius: 8,
                        onTap: () => _editAmount(i),
                        child: Padding(
                          padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: 6, vertical: 2),
                          child: TextFont(
                            text: convertToMoney(allWallets, alloc.amount),
                            fontSize: 15,
                            textColor: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            allocations.removeAt(i);
                          });
                        },
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: getColor(context, "textLight"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // Add goal button
          Tappable(
            color: getColor(context, "lightDarkAccentHeavyLight"),
            borderRadius: 12,
            onTap: _addGoal,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 15, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    appStateSettings["outlinedIcons"]
                        ? Icons.add_circle_outline_outlined
                        : Icons.add_circle_outline_rounded,
                    size: 18,
                    color: getColor(context, "textLight"),
                  ),
                  SizedBox(width: 10),
                  TextFont(
                    text: "Add Goal",
                    fontSize: 15,
                    textColor: getColor(context, "textLight"),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 12),

          // Remaining summary
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextFont(
                text: "Total: " +
                    convertToMoney(allWallets, widget.totalAmount) +
                    "   Remaining: " +
                    convertToMoney(allWallets, remaining.abs()) +
                    (remaining < -0.001 ? " over" : ""),
                fontSize: 13,
                textColor: remainingColor,
              ),
            ],
          ),

          SizedBox(height: 12),

          Opacity(
            opacity: isOverAllocated ? 0.5 : 1.0,
            child: Button(
              expandedLayout: true,
              label: "Confirm Split",
              onTap: () {
                if (!isOverAllocated) {
                  popRoute(context, allocations);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
