/// Payment methods accepted by the `record_expense` RPC.
///
/// Expenses are never paid on credit, so there is deliberately no credit
/// option. [code] must match the database check constraint on
/// `expenses.payment_method`.
enum ExpensePaymentMethod {
  cash('cash', 'Cash'),
  mobileMoney('mobile_money', 'Mobile Money'),
  card('card', 'Card'),
  bankTransfer('bank_transfer', 'Bank Transfer');

  const ExpensePaymentMethod(this.code, this.label);

  final String code;
  final String label;
}
