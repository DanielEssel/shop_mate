import '../models/product_model.dart';

class ProductLocalDataSource {
  Future<List<ProductModel>> getProducts() async {
    await Future<void>.delayed(
      const Duration(milliseconds: 300),
    );

    return const [
      ProductModel(
        id: '1',
        name: 'Peak Milk',
        category: 'Dairy',
        sellingPrice: 12.50,
        costPrice: 9.80,
        stockQuantity: 24,
        lowStockThreshold: 10,
        sku: 'DAI-001',
      ),
      ProductModel(
        id: '2',
        name: 'Milo 500g',
        category: 'Beverages',
        sellingPrice: 38.00,
        costPrice: 31.00,
        stockQuantity: 8,
        lowStockThreshold: 10,
        sku: 'BEV-001',
      ),
      ProductModel(
        id: '3',
        name: 'Rice 5kg',
        category: 'Grains',
        sellingPrice: 85.00,
        costPrice: 70.00,
        stockQuantity: 42,
        lowStockThreshold: 10,
        sku: 'GRA-001',
      ),
      ProductModel(
        id: '4',
        name: 'Cooking Oil 1L',
        category: 'Cooking',
        sellingPrice: 32.00,
        costPrice: 27.50,
        stockQuantity: 5,
        lowStockThreshold: 10,
        sku: 'COO-001',
      ),
      ProductModel(
        id: '5',
        name: 'Sugar 1kg',
        category: 'Groceries',
        sellingPrice: 18.00,
        costPrice: 15.00,
        stockQuantity: 31,
        lowStockThreshold: 10,
        sku: 'GRO-001',
      ),
    ];
  }
}