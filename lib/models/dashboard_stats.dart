class DashboardStats {
  final int totalTontines;
  final int activeTontines;
  final double totalContributions;
  final double walletBalance;
  final DateTime? nextPayment;
  final List<dynamic> recentActivity;

  DashboardStats({
    required this.totalTontines,
    required this.activeTontines,
    required this.totalContributions,
    required this.walletBalance,
    this.nextPayment,
    required this.recentActivity,
  });
}