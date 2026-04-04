import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/fab.dart';
import 'package:budget/widgets/fadeIn.dart';
import 'package:budget/widgets/framework/pageFramework.dart';
import 'package:budget/widgets/incomeExpenseTabSelector.dart';
import 'package:budget/widgets/navigationSidebar.dart';
import 'package:budget/widgets/noResults.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:budget/widgets/selectedTransactionsAppBar.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:budget/widgets/transactionEntry/transactionEntry.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:implicitly_animated_reorderable_list/implicitly_animated_reorderable_list.dart';
import 'package:implicitly_animated_reorderable_list/transitions.dart';
import 'package:budget/colors.dart';

class ReimbursementsPage extends StatefulWidget {
  const ReimbursementsPage({Key? key}) : super(key: key);

  @override
  State<ReimbursementsPage> createState() => ReimbursementsPageState();
}

class ReimbursementsPageState extends State<ReimbursementsPage>
    with SingleTickerProviderStateMixin {
  String pageId = "Reimbursements";
  late TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );
  GlobalKey<PageFrameworkState> pageState = GlobalKey();

  void scrollToTop() {
    pageState.currentState?.scrollToTop();
  }

  @override
  void initState() {
    _tabController.addListener(() {
      setState(() {});
    });
    super.initState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if ((globalSelectedID.value[pageId] ?? []).length > 0) {
          globalSelectedID.value[pageId] = [];
          globalSelectedID.notifyListeners();
          return false;
        } else {
          return true;
        }
      },
      child: PageFramework(
        key: pageState,
        listID: pageId,
        floatingActionButton: AnimateFABDelayed(
          fab: AddFAB(
            tooltip: "Add Reimbursable Expense",
            openPage: AddTransactionPage(
              routesToPopAfterDelete: RoutesToPopAfterDelete.None,
            ),
          ),
        ),
        dragDownToDismiss: true,
        title: "Reimbursements",
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 8.0),
              child: StreamBuilder<double?>(
                stream: database.watchTotalPendingReimbursements(
                    Provider.of<AllWallets>(context)),
                builder: (context, snapshot) {
                  double totalPending = snapshot.data ?? 0;
                  return Column(
                    children: [
                      SizedBox(height: 10),
                      TextFont(
                        text: totalPending > 0
                            ? "Pending"
                            : "No Pending Reimbursements",
                        fontSize: 16,
                        textColor: getColor(context, "textLight"),
                      ),
                      if (totalPending > 0)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(top: 2),
                          child: TextFont(
                            text: convertToMoney(
                                Provider.of<AllWallets>(context), totalPending),
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            textColor: getColor(context, "unPaidUpcoming"),
                          ),
                        ),
                      SizedBox(height: 10),
                    ],
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsetsDirectional.symmetric(
                  horizontal: getHorizontalPaddingConstrained(context) + 13),
              child: IncomeExpenseTabSelector(
                hasBorderRadius: true,
                onTabChanged: (_) {},
                initialTabIsIncome: false,
                showIcons: false,
                tabController: _tabController,
                expenseLabel: "Pending",
                expenseCustomIcon: Icon(
                  appStateSettings["outlinedIcons"]
                      ? Icons.pending_actions_outlined
                      : Icons.pending_actions_rounded,
                ),
                incomeLabel: "Completed",
                incomeCustomIcon: Icon(
                  appStateSettings["outlinedIcons"]
                      ? Icons.check_circle_outlined
                      : Icons.check_circle_rounded,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: 15),
          ),
          StreamBuilder<List<Transaction>>(
            stream: database.watchAllReimbursableTransactions(
                isPending: _tabController.index == 0),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                if (snapshot.data!.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: NoResults(
                        message: _tabController.index == 0
                            ? "No pending reimbursements"
                            : "No completed reimbursements",
                      ),
                    ),
                  );
                }
                return SliverImplicitlyAnimatedList<Transaction>(
                  spawnIsolate: false,
                  items: snapshot.data!,
                  areItemsTheSame: (a, b) =>
                      a.transactionPk == b.transactionPk,
                  insertDuration: Duration(milliseconds: 500),
                  removeDuration: Duration(milliseconds: 500),
                  updateDuration: Duration(milliseconds: 500),
                  itemBuilder: (BuildContext context,
                      Animation<double> animation,
                      Transaction item,
                      int index) {
                    return SizeFadeTransition(
                      sizeFraction: 0.7,
                      key: ValueKey(item.transactionPk),
                      curve: Curves.easeInOut,
                      animation: animation,
                      child: Column(
                        children: [
                          TransactionEntry(
                            openPage: AddTransactionPage(
                              transaction: item,
                              routesToPopAfterDelete:
                                  RoutesToPopAfterDelete.One,
                            ),
                            transaction: item,
                            listID: pageId,
                            transactionAfter: nullIfIndexOutOfRange(
                                snapshot.data!, index + 1),
                            transactionBefore: nullIfIndexOutOfRange(
                                snapshot.data!, index - 1),
                          ),
                          ReimbursementProgressBar(transaction: item),
                        ],
                      ),
                    );
                  },
                );
              } else {
                return SliverToBoxAdapter();
              }
            },
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: 75),
          ),
        ],
      ),
    );
  }
}

class ReimbursementProgressBar extends StatelessWidget {
  const ReimbursementProgressBar({required this.transaction, super.key});
  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    double progress = transaction.reimbursableAmount > 0
        ? (transaction.reimbursedAmount / transaction.reimbursableAmount)
            .clamp(0.0, 1.0)
        : 0;
    bool isComplete =
        transaction.reimbursedAmount >= transaction.reimbursableAmount;
    return Padding(
      padding:
          const EdgeInsetsDirectional.only(start: 25, end: 25, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextFont(
                text: isComplete
                    ? "Fully Reimbursed"
                    : "Reimbursed: ${convertToMoney(Provider.of<AllWallets>(context), transaction.reimbursedAmount)} / ${convertToMoney(Provider.of<AllWallets>(context), transaction.reimbursableAmount)}",
                fontSize: 12,
                textColor: isComplete
                    ? getColor(context, "incomeAmount")
                    : getColor(context, "textLight"),
              ),
              if (!isComplete)
                TextFont(
                  text: "${(progress * 100).toStringAsFixed(0)}%",
                  fontSize: 12,
                  textColor: getColor(context, "textLight"),
                ),
            ],
          ),
          SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadiusDirectional.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .secondaryContainer
                  .withOpacity(0.5),
              color: isComplete
                  ? getColor(context, "incomeAmount")
                  : Theme.of(context).colorScheme.primary,
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}
