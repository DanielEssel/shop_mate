/// Expense categories accepted by the `record_expense` RPC.
///
/// [code] must match the database check constraint on `expenses.category`.
enum ExpenseCategory {
  rent('rent', 'Rent'),
  utilities('utilities', 'Utilities'),
  transport('transport', 'Transport'),
  salaries('salaries', 'Salaries'),
  supplies('supplies', 'Supplies'),
  maintenance('maintenance', 'Maintenance'),
  marketing('marketing', 'Marketing'),
  communication('communication', 'Communication'),
  other('other', 'Other');

  const ExpenseCategory(this.code, this.label);

  final String code;
  final String label;
}
