I have uploaded the existing ShopMate Flutter project.

Act as a **senior Flutter engineer, senior product engineer, UI/UX designer, database architect and QA engineer**.

This is an existing working application. Your job is to inspect it thoroughly and then **complete the unfinished product functionality**, not simply redesign the screens.

The application is intended to be a real-world shop inventory, sales and business-management application.

---

# 1. FIRST: UNDERSTAND THE EXISTING SYSTEM

Before changing code, inspect:

* complete project structure
* `pubspec.yaml`
* routing
* authentication
* state management
* repositories
* services
* models/entities
* Supabase integration
* database tables
* database functions/RPCs
* products
* inventory
* sales
* customers
* purchases
* stock movements
* dashboard
* existing navigation
* existing permissions/security

Trace the complete flow:

Product → Inventory → Sale → Customer → Payment → Balance → Stock movement → Reports

Understand the existing implementation before replacing anything.

Do NOT blindly rewrite existing working functionality.

---

# 2. COMPLETE THE PRODUCT

The application currently has core functionality, but several product areas need to be completed properly.

The following should become fully functional production features:

## A. EXPENSES

Build a complete Expenses module.

It should support:

* create expense
* edit expense
* delete expense
* expense categories
* amount
* date
* description/notes
* payment method
* user who recorded it
* optional reference
* search
* filtering
* date filtering
* category filtering
* totals

Examples:

* Rent
* Electricity
* Water
* Transport
* Salaries
* Supplies
* Maintenance
* Internet
* Other

Expenses must be persisted properly in Supabase.

Include:

* database table
* RLS/security where appropriate
* repository/data layer
* domain/model layer
* UI
* validation
* loading states
* empty states
* error handling

---

# 3. REPORTS

Build a useful Reports module.

Reports should not just be static UI.

They must use real application data.

Include reports such as:

### Sales

* total sales
* number of sales
* paid sales
* credit sales
* outstanding customer balances
* sales by date
* sales by product
* sales by customer
* sales by payment method

### Inventory

* current stock
* low-stock products
* stock value
* stock movements
* products sold
* products purchased

### Expenses

* total expenses
* expenses by category
* expenses over time

### Profit / business overview

Where the available data supports it:

Revenue
− Cost of Goods Sold
− Expenses
= Estimated Profit

Clearly distinguish between revenue, gross profit and net/estimated profit.

Do not invent financial values.

Reports should support:

* date ranges
* today
* yesterday
* this week
* this month
* custom range

Use real Supabase queries and aggregations.

---

# 4. ANALYTICS / DASHBOARD

Improve the existing dashboard into a useful business dashboard.

Include meaningful metrics such as:

* today's sales
* today's expenses
* outstanding credit
* low-stock products
* total customers
* sales trend
* expense trend
* top-selling products
* recent sales
* recent expenses

Charts should be clean and useful.

Do not overcrowd the dashboard.

The dashboard should work properly on:

* mobile
* tablet
* desktop

---

# 5. CUSTOMER + CREDIT SYSTEM

This is VERY IMPORTANT.

Inspect the existing customer and sales implementation carefully.

I need a proper relationship between:

Customer
→ Sale
→ Payment
→ Outstanding balance

A customer may buy something and:

### Example

Customer buys:

Product A = GHS 100
Product B = GHS 50

Total = GHS 150

Customer pays:

GHS 50

Outstanding:

GHS 100

The sale must remain associated with that customer.

The customer profile should show:

* total purchases
* total amount paid
* outstanding balance
* sales history
* payment history
* credit transactions

Do not simply store a random balance number on the customer and manually modify it.

The system should derive the balance from actual transactions/payment records where appropriate.

---

# 6. PARTIAL PAYMENTS

A sale should support:

* fully paid
* partially paid
* unpaid/credit

Example:

Sale total = GHS 500

Customer pays = GHS 200

Remaining balance = GHS 300

The system must correctly record:

Sale total: GHS 500
Paid: GHS 200
Balance: GHS 300

Later the customer can pay:

GHS 100

Then:

Paid: GHS 300
Balance: GHS 200

Later:

GHS 200

Then:

Paid: GHS 500
Balance: GHS 0

The payment history must remain intact.

Do NOT overwrite the original payment.

---

# 7. CUSTOMER PAYMENTS

Build a proper customer payment flow.

For example:

Customer → Outstanding Sale → Make Payment

Allow:

* full payment
* partial payment
* payment method
* payment date
* reference
* notes

Every payment should create a transaction/history record.

The UI should clearly show:

Paid
Outstanding
Payment history

Prevent:

* payment greater than outstanding balance
* negative payments
* invalid amounts
* inconsistent balances

Use database transactions/RPCs where necessary to maintain consistency.

---

# 8. SALES FLOW

Review the current sales creation flow.

It should support:

* walk-in/customer sale
* selecting an existing customer
* creating a customer
* cash
* mobile money
* other payment methods already supported by the system
* full payment
* partial payment
* credit sale

The sale must correctly update:

1. sale
2. sale items
3. payment
4. customer balance
5. inventory
6. stock movement

These operations should be atomic where appropriate.

If something fails, the system should not leave half-completed transactions.

---

# 9. SALES RECEIPTS / PRINTING

Implement proper sales receipt generation.

After completing a sale, the user should be able to:

* view receipt
* print receipt
* share/export where practical

Receipt should contain:

* shop/business name
* address/contact if configured
* receipt number
* date/time
* cashier/user
* customer
* products
* quantities
* unit prices
* line totals
* subtotal
* discount if supported
* total
* amount paid
* outstanding balance
* payment method
* thank-you message

Support a receipt layout suitable for:

* normal printer
* thermal receipt printer where practical
* PDF/export if appropriate

The receipt should clearly indicate:

PAID
or
PARTIALLY PAID
or
CREDIT

Do not fake printing functionality.

Use an appropriate Flutter printing/PDF approach that actually works.

---

# 10. USERS AND PERMISSIONS

Build a proper Users & Permissions area.

Inspect the current authentication implementation first.

Support appropriate roles such as:

* Owner/Admin
* Manager
* Cashier
* Staff

Permissions should control actual access.

Examples:

Owner/Admin can:

* manage users
* manage permissions
* view reports
* manage settings
* manage products
* manage customers
* manage sales
* manage expenses

Cashier may:

* create sales
* view products
* manage customers
* receive customer payments

but should not automatically have access to:

* user management
* sensitive settings
* financial reports

Do not rely only on hiding UI buttons.

Where appropriate, enforce permissions through backend/database security as well.

---

# 11. NOTIFICATIONS

Build a useful Notifications area.

It should support application notifications such as:

* low stock
* payment received
* outstanding customer balance
* important system events

Notifications should have:

* read/unread status
* timestamp
* notification type
* relevant reference where appropriate

The notification UI should be clean and useful.

Do not build fake notifications that don't connect to real events.

---

# 12. SETTINGS

Build a complete Settings area.

Include appropriate settings such as:

### Business

* business/shop name
* phone
* address
* currency
* receipt information

### Appearance

* theme settings if supported

### Sales

* receipt settings
* default payment method
* customer requirements

### Inventory

* low-stock threshold/settings

### Account

* profile
* password/authentication options supported by the current auth architecture

### Users

* user management where permitted

Do not create settings that have no actual effect.

Every setting should either work or be clearly identified as future functionality.

---

# 13. HELP & SUPPORT

Create a useful Help & Support section.

Include:

* frequently asked questions
* basic usage guidance
* contact/support information
* application information/version
* common troubleshooting information

Keep it simple and professional.

---

# 14. SEARCH / FILTERING

Review existing lists and improve them where necessary.

Important screens should support appropriate:

* search
* filtering
* sorting
* date ranges

Especially:

* sales
* customers
* products
* expenses
* reports
* notifications

---

# 15. UI/UX

Bring the entire application to a consistent professional standard.

Do not redesign randomly.

Improve:

* spacing
* typography
* hierarchy
* cards
* forms
* tables/lists
* dialogs
* buttons
* navigation
* empty states
* loading states
* error states
* confirmation flows
* responsive layouts

Maintain the existing ShopMate visual identity unless there is a strong reason to improve it.

The application should feel like a coherent professional business product.

---

# 16. DATABASE ARCHITECTURE

This is critical.

Before adding tables, inspect the existing Supabase schema.

Do not duplicate existing concepts.

Design proper relationships for:

users
roles
permissions
customers
sales
sale_items
payments
expenses
expense_categories
notifications
products
inventory
stock_movements

Use appropriate:

* primary keys
* foreign keys
* constraints
* indexes
* timestamps
* RLS policies

Where a financial/inventory operation requires multiple database changes, prefer a database transaction/RPC rather than several independent client operations.

---

# 17. DATA INTEGRITY

Pay particular attention to:

* duplicate sales
* duplicate payments
* stock going negative
* payment greater than balance
* deleting sales that already have payments
* deleting customers with transaction history
* concurrent operations
* stale balances
* failed transactions
* inconsistent totals

The system should remain consistent even when something goes wrong.

---

# 18. DO NOT BREAK EXISTING FEATURES

Existing working functionality must continue working.

Before modifying an existing feature:

1. Understand it.
2. Identify dependencies.
3. Make the smallest appropriate change.
4. Test the affected flow.

Do not replace working architecture simply because you prefer another architecture.

---

# 19. IMPLEMENTATION PROCESS

Work in this order:

### Phase 1

Full project audit.

### Phase 2

Database/schema assessment.

### Phase 3

Identify dependencies between features.

### Phase 4

Implement foundational data/logic changes.

### Phase 5

Implement customer/payment/credit improvements.

### Phase 6

Implement expenses.

### Phase 7

Implement reports and analytics.

### Phase 8

Implement users/roles/permissions.

### Phase 9

Implement notifications.

### Phase 10

Implement settings and help/support.

### Phase 11

Implement receipt generation/printing.

### Phase 12

Polish the entire UI/UX.

### Phase 13

Run tests, analyze errors and fix regressions.

---

# 20. IMPORTANT DEVELOPMENT RULE

Do not make hundreds of unrelated changes at once.

For each major feature:

1. Inspect existing implementation.
2. Explain the intended architecture.
3. Implement.
4. Check for errors.
5. Test the feature.
6. Check its effect on existing features.
7. Continue to the next feature.

If you discover a major architectural issue that requires a decision from me, stop and explain the issue rather than making a destructive assumption.

---

# FINAL REQUIREMENT

I don't want a collection of attractive screens.

I want a **fully working shop management product** where the UI, business logic, database and user flows actually work together.

The most important flows to verify end-to-end are:

### Sale

Product → Cart → Customer → Payment → Sale → Inventory → Receipt

### Credit

Customer → Sale → Partial Payment → Outstanding Balance → Later Payment → Balance Updated

### Inventory

Purchase/Adjustment → Stock → Sale → Stock Movement → Current Stock

### Finance

Sales → Payments → Expenses → Reports → Business Overview

### Security

User → Role → Permission → Allowed/Blocked Feature

After implementation, perform an end-to-end review of these flows.

Start by inspecting the uploaded project. **Do not start by rewriting the UI.**
