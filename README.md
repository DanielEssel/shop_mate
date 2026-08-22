# shopmate

app login
email: dessel731@outlook.com
passwork Makeit123


A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.






database  scheme

| column_name         | data_type                | is_nullable | column_default    |
| ------------------- | ------------------------ | ----------- | ----------------- |
| id                  | uuid                     | NO          | gen_random_uuid() |
| name                | text                     | NO          | null              |
| category            | text                     | NO          | null              |
| sku                 | text                     | YES         | null              |
| barcode             | text                     | YES         | null              |
| description         | text                     | YES         | null              |
| cost_price          | numeric                  | NO          | 0                 |
| selling_price       | numeric                  | NO          | 0                 |
| stock_quantity      | integer                  | NO          | 0                 |
| low_stock_threshold | integer                  | NO          | 10                |
| is_active           | boolean                  | NO          | true              |
| created_at          | timestamp with time zone | NO          | now()             |
| updated_at          | timestamp with time zone | NO          | now()             |
| image_url           | text                     | YES         | null              |

| column_name       | data_type                | is_nullable | column_default    |
| ----------------- | ------------------------ | ----------- | ----------------- |
| id                | uuid                     | NO          | gen_random_uuid() |
| product_id        | uuid                     | NO          | null              |
| movement_type     | text                     | NO          | null              |
| quantity          | integer                  | NO          | null              |
| previous_quantity | integer                  | NO          | null              |
| new_quantity      | integer                  | NO          | null              |
| reference_id      | uuid                     | YES         | null              |
| note              | text                     | YES         | null              |
| created_by        | uuid                     | YES         | null              |
| created_at        | timestamp with time zone | NO          | now()             |

| constraint_name                    | constraint_type | column_name |
| ---------------------------------- | --------------- | ----------- |
| 2200_17484_10_not_null             | CHECK           | null        |
| 2200_17484_11_not_null             | CHECK           | null        |
| 2200_17484_12_not_null             | CHECK           | null        |
| 2200_17484_13_not_null             | CHECK           | null        |
| 2200_17484_1_not_null              | CHECK           | null        |
| 2200_17484_2_not_null              | CHECK           | null        |
| 2200_17484_3_not_null              | CHECK           | null        |
| 2200_17484_7_not_null              | CHECK           | null        |
| 2200_17484_8_not_null              | CHECK           | null        |
| 2200_17484_9_not_null              | CHECK           | null        |
| products_cost_price_check          | CHECK           | null        |
| products_low_stock_threshold_check | CHECK           | null        |
| products_pkey                      | PRIMARY KEY     | id          |
| products_selling_price_check       | CHECK           | null        |
| products_stock_quantity_check      | CHECK           | null        |
| 2200_17581_10_not_null             | CHECK           | null        |
| 2200_17581_1_not_null              | CHECK           | null        |
| 2200_17581_2_not_null              | CHECK           | null        |
| 2200_17581_3_not_null              | CHECK           | null        |
| 2200_17581_4_not_null              | CHECK           | null        |
| 2200_17581_5_not_null              | CHECK           | null        |
| 2200_17581_6_not_null              | CHECK           | null        |
| stock_movement_type_check          | CHECK           | null        |
| stock_movements_created_by_fkey    | FOREIGN KEY     | created_by  |
| stock_movements_pkey               | PRIMARY KEY     | id          |
| stock_movements_product_id_fkey    | FOREIGN KEY     | product_id  |

| movement_type | movement_count |
| ------------- | -------------- |
| sale          | 10             |


| id                                   | product_id                           | movement_type | quantity | previous_quantity | new_quantity | reference_id                         | note                                             | created_at                    |
| ------------------------------------ | ------------------------------------ | ------------- | -------- | ----------------- | ------------ | ------------------------------------ | ------------------------------------------------ | ----------------------------- |
| ca85441e-46cf-460c-9d11-d79dcae961ac | 0866dbc6-250e-4f79-963e-364b2c753c1b | sale          | 1        | 19                | 18           | a5f7e148-9605-48b4-aca3-a35304a1218d | Stock reduced from sale SL-20260821082600-BDBF26 | 2026-08-21 08:26:00.772738+00 |
| 66e86528-e76e-4c42-ac75-478e6027a9d4 | 7478827d-7ade-4601-9bd8-ffe332e3b0b1 | sale          | 1        | 19                | 18           | f9395096-404a-40e3-abde-30b6cc40af62 | Stock reduced from sale SL-20260821072310-0F9E8E | 2026-08-21 07:23:10.606823+00 |
| 9ce10692-be6c-4fff-ac53-2709399521db | 3cd7f1b9-72cd-451e-9e8c-f7c47e8db7a7 | sale          | 2        | 120               | 118          | e7a83711-a073-4050-ac1b-bc7cebdd639a | Stock reduced from sale SL-20260821071456-6DFE91 | 2026-08-21 07:14:56.577443+00 |
| 27f88088-9db2-44d1-a396-dd322139e716 | 556297d4-5538-447e-96cd-8d48dbd90856 | sale          | 1        | 99                | 98           | c9ac0e38-f713-4ae2-8cd0-bf57e55b40a8 | Stock reduced from sale SL-20260821071253-B48582 | 2026-08-21 07:12:53.025334+00 |
| c96580d1-51d7-4b18-8814-19161be730e0 | 0c469384-7258-47b2-8e8b-46349c08d412 | sale          | 1        | 48                | 47           | c9ac0e38-f713-4ae2-8cd0-bf57e55b40a8 | Stock reduced from sale SL-20260821071253-B48582 | 2026-08-21 07:12:53.025334+00 |
| a470d4c3-a9c3-4add-bf26-919174ad3e11 | 0866dbc6-250e-4f79-963e-364b2c753c1b | sale          | 1        | 20                | 19           | 5432047d-411e-4608-807d-7a60b891b1ac | Stock reduced from sale SL-20260820193705-62EAC6 | 2026-08-20 19:37:05.645521+00 |
| 0e9bda5e-550c-4882-bc3c-aa81010d4b2a | 556297d4-5538-447e-96cd-8d48dbd90856 | sale          | 1        | 100               | 99           | 5432047d-411e-4608-807d-7a60b891b1ac | Stock reduced from sale SL-20260820193705-62EAC6 | 2026-08-20 19:37:05.645521+00 |
| 5255c7e4-f27d-4c9b-9e10-089e3cdae88f | 0c469384-7258-47b2-8e8b-46349c08d412 | sale          | 1        | 49                | 48           | 5432047d-411e-4608-807d-7a60b891b1ac | Stock reduced from sale SL-20260820193705-62EAC6 | 2026-08-20 19:37:05.645521+00 |
| 53e6ea02-419c-44e4-aba6-29e41275a533 | 7478827d-7ade-4601-9bd8-ffe332e3b0b1 | sale          | 1        | 20                | 19           | 5432047d-411e-4608-807d-7a60b891b1ac | Stock reduced from sale SL-20260820193705-62EAC6 | 2026-08-20 19:37:05.645521+00 |
| 80108d47-0ab8-4496-b811-6d66e202dff0 | 0c469384-7258-47b2-8e8b-46349c08d412 | sale          | 1        | 50                | 49           | c1bc58d6-39eb-4e7b-92ce-68b582aab8e3 | Stock reduced from sale SL-20260820183621-585780 | 2026-08-20 18:36:21.235639+00 |