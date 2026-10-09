# shopmate

app login
email: dessel731@outlook.com
passwork Makeit123


# ShopMate — Project Status & Continuation Guide

**Project:** ShopMate
**Location:** `~/Desktop/shopmate/shopmate`
**Stack:** Flutter + Dart + Supabase + Riverpod + GoRouter
**Current Version:** `1.0.0+1`
**Current Stage:** Pre-release / Client Release Preparation
**Last Verified:** 18 September 2026

---

# 1. PROJECT OBJECTIVE

ShopMate is a general-goods inventory and business management application being developed for a client.

The application is intended to help the client manage:

* Products
* Stock/inventory
* Sales
* Customers
* Purchases
* Dashboard/business overview
* Inventory movements/history
* Low-stock monitoring

The immediate objective is **not to keep adding features indefinitely**.

The current objective is:

> **Finish the existing application, verify the database/business logic, identify only genuine release blockers, polish the application, and prepare the client release package.**

The first distribution plan is:

* Android APK
* Windows desktop application
* Supabase cloud backend
* Client installation/user documentation

The application is **not currently being prepared for Google Play Store or Microsoft Store publication**.

---

# 2. DEVELOPMENT APPROACH

The project is already substantially built.

Do **NOT** restart the architecture or rebuild existing features without first verifying whether the feature already exists.

The current working philosophy is:

1. Inspect what already exists.
2. Verify functionality.
3. Fix actual problems.
4. Complete genuine gaps.
5. Verify Supabase/database integrity.
6. Polish the UI/UX.
7. Build release versions.
8. Package the client deliverables.

Avoid unnecessary architectural refactoring while the project is in release mode.

---

# 3. CURRENT ARCHITECTURE

The project follows a feature-based Clean Architecture approach.

Current feature structure:

```text
lib/
├── app/
│   ├── app.dart
│   ├── config/
│   │   └── supabase_config.dart
│   ├── router/
│   │   └── app_router.dart
│   └── theme/
│       ├── app_colors.dart
│       ├── app_radius.dart
│       ├── app_shadows.dart
│       ├── app_spacing.dart
│       ├── app_theme.dart
│       └── app_typography.dart
│
├── core/
│   ├── navigation/
│   └── services/
│       └── supabase_service.dart
│
├── features/
│   ├── auth/
│   ├── customers/
│   ├── dashboard/
│   ├── inventory/
│   ├── more/
│   ├── products/
│   ├── purchases/
│   └── sales/
│
└── main.dart
```

Most major features contain:

```text
data/
domain/
presentation/
```

with repositories, datasources, models/entities, use cases, providers and screens.

---

# 4. FEATURES ALREADY BUILT

The following major areas already exist in the codebase.

## Authentication

Exists:

* Login
* Signup
* Supabase authentication
* Authentication state handling
* Protected routes

Relevant files:

```text
lib/features/auth/
```

---

## Dashboard

Exists:

* Dashboard screen
* Dashboard summary
* Recent sales
* Inventory alerts
* Low-stock banner
* Quick actions
* Statistics cards

Relevant files:

```text
lib/features/dashboard/
```

---

## Products

Exists:

* Product list
* Product search
* Product filtering
* Add product
* Edit product
* Product details
* Delete product
* Low-stock handling
* Product image selection
* Product repository/use cases
* Supabase persistence

Relevant files:

```text
lib/features/products/
```

---

## Inventory

Exists:

* Inventory summary
* Product inventory list
* Low-stock view
* Stock adjustment
* Stock movement history
* Movement filtering
* Product search
* Inventory repository/use cases
* Supabase inventory operations

Relevant files:

```text
lib/features/inventory/
```

Database inventory transaction logic has previously been checked.

The `adjust_stock()` database operation uses transactional/row-locking logic to protect stock quantities.

---

## Sales

Exists:

* Sales list
* New sale
* Product search
* Cart
* Payment handling
* Sale summary
* Sale details
* Sales repository/use cases
* Supabase sale transaction

Relevant files:

```text
lib/features/sales/
```

The `create_sale` database function has previously been tested.

Example previously verified:

```text
Biscuit stock: 20 → 19
```

with a corresponding sale inventory movement.

---

## Customers

Exists:

* Customer list
* Add customer
* Customer details
* Customer editing/CRUD
* Customer repository/use cases
* Supabase persistence

Relevant files:

```text
lib/features/customers/
```

---

## Purchases

Exists:

* Purchase list
* New purchase
* Purchase cart/items
* Purchase details
* Purchase summary
* Purchase repository/use cases
* Supabase persistence

Relevant files:

```text
lib/features/purchases/
```

The `create_purchase` database operation has previously been implemented/verified for:

* Purchase date
* Purchase number
* Stock update
* Cost update
* Purchase records
* Inventory movement

---

# 5. SUPABASE

Current Supabase project:

```text
https://ocurrzhjxrgdcumckwam.supabase.co
```

Configuration:

```text
lib/app/config/supabase_config.dart
```

Current startup:

```dart
await Supabase.initialize(
  url: SupabaseConfig.url,
  publishableKey: SupabaseConfig.publishableKey,
);
```

Production initialization is performed in:

```text
lib/main.dart
```

The application uses Supabase for authentication and backend data.

---

# 6. IMPORTANT DATABASE BUSINESS LOGIC

Previously implemented/verified database operations include:

## Sales

```text
create_sale(...)
```

Handles sale creation and stock reduction.

---

## Purchases

```text
create_purchase(...)
```

Handles purchase creation and stock/cost updates.

---

## Stock adjustment

```text
adjust_stock(...)
```

Handles stock adjustments transactionally.

---

## Inventory movement types

The database supports movement types including:

```text
sale
purchase
adjustment
return
opening
```

However, not every movement type currently has a complete UI workflow.

---

# 7. KNOWN INVENTORY GAPS

These were identified during the earlier inventory audit.

## Opening stock

Opening stock is currently capable of being placed directly into product stock, but a proper opening-stock movement workflow may still be required.

---

## Returns

The database supports a `return` movement type, but a complete user-facing sales/purchase return workflow has not yet been established.

---

## Stock reconciliation

No dedicated stock reconciliation/counting workflow has been confirmed.

---

## Inventory valuation

A complete inventory valuation system has not been confirmed.

For example:

```text
Total stock value
Cost value
Potential selling value
Profit/stock margin
```

---

## Cost history

A dedicated historical cost tracking system has not been confirmed.

These should **not automatically be treated as release blockers**.

They need to be assessed against the client's actual day-one requirements before implementation.

---

# 8. MORE SECTION

The current More screen exists but contains several placeholders.

Current items include:

* Suppliers
* Expenses
* Reports
* Analytics
* Settings
* Users & Permissions
* Notifications
* Help & Support

At the moment, these currently use a "Coming Soon" type interaction rather than complete feature workflows.

Relevant file:

```text
lib/features/more/presentation/screens/more_screen.dart
```

This is one of the most important areas to review before release.

However:

> Do not automatically build all of these features.

First determine which ones are genuinely required by the client for V1.

---

# 9. ROUTING

Current main application shell uses:

```text
/dashboard
/products
/inventory
/sales
/more
```

The router uses:

```text
StatefulShellRoute.indexedStack
```

Customers and Purchases are currently top-level routes:

```text
/customers
/purchases
```

The main router is:

```text
lib/app/router/app_router.dart
```

Authentication state is connected to GoRouter using Supabase auth state changes.

---

# 10. APP STARTUP

Production entry point:

```text
lib/main.dart
```

Current flow:

```text
WidgetsFlutterBinding.ensureInitialized()
        ↓
Supabase.initialize()
        ↓
ProviderScope
        ↓
ShopInventoryApp
```

The application widget is:

```text
lib/app/app.dart
```

The application currently uses:

```dart
MaterialApp.router(...)
```

with GoRouter.

---

# 11. TESTING STATUS

This has just been fixed and verified.

## Flutter analyzer

Command:

```bash
flutter analyze
```

Current result:

```text
No issues found!
```

## Flutter tests

Command:

```bash
flutter test
```

Current result:

```text
00:04 +1: All tests passed!
```

Therefore the current baseline is:

```text
Analyzer: CLEAN
Tests: CLEAN
```

This is an important milestone.

---

# 12. TEST FILE

Current test:

```text
test/widget_test.dart
```

The test initializes Supabase and mocks SharedPreferences for the Flutter test environment.

This was necessary because Supabase initialization uses SharedPreferences, while ordinary Flutter widget tests do not automatically provide the native SharedPreferences plugin implementation.

The test now verifies that:

```text
ShopInventoryApp
```

can start successfully.

Do not unnecessarily redesign the application architecture just to change this test.

---

# 13. RECENT PROBLEM THAT WAS FIXED

The original test was:

```dart
await tester.pumpWidget(
  const ShopInventoryApp(),
);

expect(find.text('ShopMate'), findsOneWidget);
```

It failed because:

1. Supabase had not been initialized.
2. The application no longer starts with a widget containing exactly `"ShopMate"` text.

The test was updated to initialize Supabase and verify application startup.

Then SharedPreferences mocking was added.

Current result:

```text
flutter test
→ All tests passed
```

---

# 14. CURRENT PROJECT HEALTH

At this point:

```text
Flutter analyzer       ✅ CLEAN
Flutter tests          ✅ PASSING
Authentication         ✅ IMPLEMENTED
Products               ✅ IMPLEMENTED
Inventory              ✅ IMPLEMENTED
Sales                  ✅ IMPLEMENTED
Customers              ✅ IMPLEMENTED
Purchases              ✅ IMPLEMENTED
Dashboard              ✅ IMPLEMENTED
Routing                ✅ IMPLEMENTED
Supabase integration   ✅ IMPLEMENTED
```

The project is therefore beyond the basic development stage.

The next stage is **release verification**, not rebuilding the application.

---

# 15. IMMEDIATE NEXT PHASE

The next phase should be:

# RELEASE-GAP AUDIT

The purpose is to determine:

```text
What is already working?
What is incomplete?
What is genuinely required for the client?
What can safely wait until V1.1?
```

Do not implement anything simply because it exists as a placeholder.

---

# 16. RELEASE PRIORITY CLASSIFICATION

Every remaining item should be classified as one of:

## RELEASE BLOCKER

Something that prevents the client from safely using the application.

Examples:

* Broken sales
* Incorrect stock calculations
* Database transaction failure
* Authentication failure
* Data loss
* Critical navigation failure
* App crash
* Incorrect customer/purchase records
* Serious RLS/security problem

These must be fixed before release.

---

## V1 CLIENT REQUIREMENT

A feature the client explicitly needs for normal day-one operation.

Examples might include:

* Supplier management
* Basic expenses
* Basic reports
* Business settings

Only implement these if required.

---

## V1.1 / FUTURE

Useful functionality that is not necessary for the client's initial operation.

Possible examples:

* Advanced analytics
* Advanced reports
* Stock valuation
* Returns workflow
* Stock reconciliation
* Notifications
* Multi-user permissions
* Advanced supplier management
* Flexible selling units, such as crates, packs and loose items (see section 29)

These should not delay the initial release unless the client specifically requires them.

---

# 17. NEXT AUDIT ORDER

Continue in this order.

## Step 1 — Inspect More

Determine whether:

```text
Suppliers
Expenses
Reports
Analytics
Settings
Users & Permissions
Notifications
Help & Support
```

are required for V1.

Do not build them yet.

---

## Step 2 — Verify AppShell/navigation

Inspect:

```text
lib/core/navigation/
```

Confirm that:

* Mobile navigation works.
* Desktop navigation works.
* Dashboard is accessible.
* Products is accessible.
* Inventory is accessible.
* Sales is accessible.
* More is accessible.
* Customers can be reached.
* Purchases can be reached.
* Back navigation behaves correctly.

---

## Step 3 — Verify the main business flows

Test manually using the actual Supabase backend.

### Product

```text
Create product
→ View product
→ Edit product
→ Delete product
```

### Inventory

```text
Adjust stock
→ Confirm stock quantity
→ Confirm movement history
```

### Purchase

```text
Create purchase
→ Confirm purchase
→ Confirm stock increases
→ Confirm inventory movement
```

### Sale

```text
Create sale
→ Confirm stock decreases
→ Confirm sale record
→ Confirm inventory movement
```

### Customer

```text
Create customer
→ View customer
→ Use customer in sale if supported
```

---

# 18. DATABASE / SUPABASE RELEASE AUDIT

After UI/business-flow verification, perform a final Supabase audit.

Check:

```text
Tables
Columns
Foreign keys
Indexes
RLS policies
RPC/functions
Triggers
Stock calculations
Sale transaction
Purchase transaction
Stock adjustment
Inventory movements
Authentication
```

Particular attention should be given to RLS.

The client release must not accidentally expose another customer's/business's data.

---

# 19. BRANDING CLEANUP

Current `pubspec.yaml` still contains:

```yaml
description: "A new Flutter project."
```

This should eventually be replaced with a proper ShopMate description.

Current application title in `app.dart` is:

```dart
title: 'ShopMate',
```

This should probably become:

```dart
title: 'ShopMate',
```

Do this during the release branding pass rather than making random changes throughout the project now.

Also review:

```text
Application name
App icon
Package/application ID
Version number
Splash screen
Windows application name
Android application name
```

---

# 20. CURRENT PUBSPEC

Important current configuration:

```yaml
name: shopmate
version: 1.0.0+1
publish_to: none
```

Main dependencies include:

```text
supabase_flutter
flutter_riverpod
go_router
shared_preferences
google_fonts
image_picker
```

There are currently no custom Flutter assets/fonts configured in `pubspec.yaml`.

---

# 21. RELEASE VERSIONING

Current version:

```text
1.0.0+1
```

Before final release, decide whether to use something such as:

```text
1.0.0+1
```

for the initial client release.

Do not increase versions unnecessarily during development.

---

# 22. RELEASE TARGETS

Initial client distribution:

## Android

Build:

```bash
flutter build apk --release
```

Expected deliverable:

```text
ShopMate-v1.0.0.apk
```

---

## Windows

Build:

```bash
flutter build windows --release
```

Expected deliverable:

```text
ShopMate-v1.0.0/
```

The Windows release should be tested on a Windows machine before handing it to the client.

---

# 23. FINAL CLIENT PACKAGE

Target structure:

```text
ShopMate_Client_Release/
│
├── Android/
│   └── ShopMate-v1.0.0.apk
│
├── Windows/
│   └── ShopMate-v1.0.0/
│
├── Database/
│   └── shopmate_v1.sql
│
├── Documentation/
│   ├── Installation Guide.pdf
│   └── User Guide.pdf
│
└── README.txt
```

The actual contents may change after the release audit.

---

# 24. IMPORTANT: DO NOT BUILD THE FINAL PACKAGE YET

Before building the final APK/Windows package, confirm:

```text
[ ] All V1-required features complete
[ ] No critical UI bugs
[ ] No analyzer issues
[ ] Tests passing
[ ] Product flow verified
[ ] Inventory flow verified
[ ] Sales verified
[ ] Purchases verified
[ ] Customers verified
[ ] Dashboard verified
[ ] Supabase/RLS verified
[ ] Branding complete
[ ] App icon complete
[ ] Version finalized
[ ] Android release tested
[ ] Windows release tested
[ ] Documentation prepared
```

---

# 25. COMMANDS FOR THE NEXT CHAT

Start by entering:

```bash
cd ~/Desktop/shopmate/shopmate
```

Then verify the clean baseline:

```bash
flutter analyze
flutter test
```

Expected:

```text
No issues found!
```

and:

```text
All tests passed!
```

Then inspect the navigation:

```bash
find lib/core/navigation -type f | sort
```

Inspect the complete More screen:

```bash
cat lib/features/more/presentation/screens/more_screen.dart
```

Inspect the main app shell/navigation implementation before making routing changes.

---

# 26. CURRENT STOPPING POINT

The project has reached this exact point:

```text
                    SHOPMATE
                       │
                       ▼
              Core development
                  substantially
                    complete
                       │
                       ▼
              Analyzer cleaned
                       │
                       ▼
               Tests repaired
                       │
                       ▼
             flutter test PASS
                       │
                       ▼
          ┌───────────────────────┐
          │   CURRENT POSITION    │
          │                       │
          │ RELEASE-GAP AUDIT     │
          └───────────────────────┘
                       │
                       ▼
          Verify existing features
                       │
                       ▼
        Identify genuine V1 blockers
                       │
                       ▼
             Supabase final audit
                       │
                       ▼
               UI/UX polish
                       │
                       ▼
             Branding/versioning
                       │
                       ▼
          Android + Windows builds
                       │
                       ▼
            Client release package
```

---

# 27. INSTRUCTION FOR A NEW CHAT

If this project is continued in another ChatGPT conversation, provide this document first and say:

> **Continue the ShopMate project from this status. Do not rebuild existing features. We are in the release-gap audit stage. First inspect the current code/tree and determine what is already implemented versus what is genuinely missing. The current baseline is `flutter analyze` clean and `flutter test` passing.**

The new chat should then continue from:

```text
RELEASE-GAP AUDIT
```

and not restart the project analysis from the beginning.

---

# 28. GOLDEN RULE FOR THIS PROJECT

> **Verify before building.**

ShopMate already contains substantial functionality.

The remaining work should be driven by:

```text
Client requirement
        +
Actual code verification
        +
Actual Supabase verification
        =
Release decision
```

Not by the presence of a placeholder, a theoretical feature, or a generic inventory-app checklist.

---

# 29. Planned Feature: Flexible Selling Units for Retailers and Wholesalers

> **Status: planned, not implemented.**
> The current application sells every product in a single unit. Nothing in this section describes existing behaviour.

> **Guiding principle:** ShopMate should adapt to how each product is sold, rather than forcing every business to use the same selling-unit workflow. Standard products must remain simple, while products that need multiple selling units receive the additional controls they require.

## Objective

Support different selling patterns, such as single items, full crates, half crates and loose bottles, with one inventory and sales system.

The same system should serve retailers, wholesalers and businesses selling different kinds of goods. Businesses that sell standard individual products must keep a sales workflow that is no more complicated than it is today.

---

## A. Product selling configurations

Each product uses one of two configurations.

### 1. Single selling unit (default)

For products normally sold by the piece or item, such as car batteries, furniture, electronics and individual packaged goods.

* The owner selects a base unit, such as piece or item.
* The owner sets the purchase cost, selling price and stock, as today.
* New Sale keeps its simple quantity-entry workflow.
* No crate, pack, half-pack or other unit selector appears.

### 2. Multiple selling units (optional)

For products sold in different quantities or packaging sizes, such as drinks, bottled water and boxed goods.

* The owner sets a base stock unit, such as bottle, can or piece.
* The owner defines the purchase pack's contents, such as 24 bottles per crate.
* The owner enables the selling units that apply, such as full crate, half crate, quarter crate or single bottle.
* The owner sets a selling price for each enabled unit.
* Pack sizes and available units are set per product.

Do not assume every product or business uses the same packaging or selling units.

---

## B. Supplier purchases and opening stock

The initial target scenario is suppliers selling drinks in full crates or boxes.

* Purchase entry supports full purchase packs and their cost.
* Received quantities are converted into the product's base stock unit.
* Opening stock supports the configured purchase pack plus any remaining loose items.
* The design must account for businesses that already hold stock when they start using ShopMate (see **Opening stock** in section 7).

---

## C. New Sale experience

The sales screen adapts to each product's configuration.

* Standard products keep the current fast quantity entry.
* Products with multiple selling units offer only their enabled units.
* Staff choose a unit and a quantity, with no manual conversion.
* The line total uses the configured price for the selected unit.
* Stock validation uses the converted base quantity, and a sale can never exceed available stock.
* Products of either configuration can be added to the same sale through the existing cart.
* The experience stays responsive on phones, tablets and desktop.

---

## D. Inventory, receipts and reporting

The implementation must cover:

* **Stock balance:** one authoritative balance per product, in its base unit.
* **Stock movements:** correct deductions for sales and correct receipts for purchases.
* **Stock history:** actual quantity movements, with enough transaction context for traceability.
* **Low-stock alerts:** a consistent threshold in the base unit.
* **Receipts:** what the customer bought, including the selling unit and quantity.
* **Cost and profit:** calculated under the existing costing rules.
* **Partial packs:** correct behaviour when less than one full crate or box remains.
* **Compatibility:** existing products and historical transactions keep working.

---

## E. Permissions

* Owners, or users with the appropriate permission, configure packaging, conversions and selling prices.
* Shop attendants sell the enabled units within their existing permissions.
* Current role restrictions stay in place. Attendants must not be able to bypass protected pricing or stock controls.

---

## F. Technical planning requirements

Before implementation, inspect the existing product, purchase, sale-item, inventory, stock-movement and reporting models, together with the database schema and the relevant RPCs.

The implementation plan must decide:

* How base units, purchase units and selling units are represented in the database.
* How unit conversions and per-unit prices are validated.
* How existing data and historical transactions remain compatible.
* Whether database migrations or RPC changes are needed.
* How stock integrity and transaction consistency are enforced.
* How the feature fits the existing feature-first Clean Architecture and Riverpod structure.

Do not settle on a schema or implementation details until that review is done.

---

# CURRENT STATUS SUMMARY

**Where we came from:**

Initial project audit → identified existing modules → inspected architecture → repaired stale widget test → fixed test environment → cleaned analyzer warnings.

**Where we are:**

```text
Flutter analyze: CLEAN
Flutter test: PASSING
Core features: SUBSTANTIALLY BUILT
Database transactions: IMPLEMENTED
Current stage: RELEASE-GAP AUDIT
```

**Where we are going:**

```text
Release-gap audit
→ Verify existing workflows
→ Identify V1 requirements
→ Final Supabase/RLS audit
→ Fix only genuine blockers
→ Branding/polish
→ Android APK
→ Windows build
→ Client documentation/package
→ Client delivery
```

**Do not restart the architecture.**
**Do not rebuild completed features.**
**Do not build every "Coming Soon" item automatically.**
**Do not package the final release until the V1 audit is complete.**
