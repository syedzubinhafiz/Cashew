/// Data model representing an allocation of a transfer amount toward a goal.
class GoalAllocation {
  String objectivePk;
  double amount;
  GoalAllocation({required this.objectivePk, required this.amount});
}
