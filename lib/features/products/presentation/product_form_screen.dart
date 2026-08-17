import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/security/permission_guard.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/mb_confirm_dialog.dart';
import '../../../shared/widgets/mb_snackbar.dart';
import '../../../shared/widgets/mb_text_field.dart';
import '../../auth/presentation/session_controller.dart';
import '../../catalog/domain/entities/catalog.dart';
import '../../catalog/presentation/catalog_providers.dart';
import '../domain/entities/product.dart';
import 'products_providers.dart';
import 'widgets/conversions_editor.dart';
import 'widgets/photo_field.dart';
import 'widgets/price_recommender.dart';
import 'widgets/product_image.dart';
import 'widgets/product_form_step_indicator.dart';
import 'widgets/product_form_nav_bar.dart';
import 'widgets/product_form_summary.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final int? productId;

  const ProductFormScreen({super.key, this.productId});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _barcode = TextEditingController();
  final _description = TextEditingController();
  final _purchase = TextEditingController(text: '0.00');
  final _sale = TextEditingController(text: '0.00');
  final _stockMin = TextEditingController(text: '0');
  final _stockMax = TextEditingController();
  final _unitsPerPkg = TextEditingController(text: '1');
  final _purchasedQty = TextEditingController(text: '0');

  int? _categoryId;
  int? _brandId;
  int? _unitId;
  int? _purchaseUnitId;
  String? _photoPath;
  String? _originalPhotoPath;
  List<ConversionDraft> _conversions = [];
  bool _loaded = false;
  bool _saving = false;
  bool _dirty = false;
  int _currentStep = 0;

  static const _totalSteps = 5;

  bool get _isEditing => widget.productId != null;

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void initState() {
    super.initState();
    _name.addListener(_markDirty);
    _sku.addListener(_markDirty);
    _barcode.addListener(_markDirty);
    _description.addListener(_markDirty);
    _purchase.addListener(_markDirty);
    _sale.addListener(_markDirty);
    _stockMin.addListener(_markDirty);
    _stockMax.addListener(_markDirty);
    _unitsPerPkg.addListener(_markDirty);
    _purchasedQty.addListener(_markDirty);
    if (_isEditing) {
      _load();
    } else {
      _loaded = true;
    }
  }

  Future<void> _load() async {
    final id = widget.productId!;
    final stock = await ref.read(productByIdProvider(id).future);
    final product = stock?.product;
    final conversions = (await ref.read(productConversionsProvider(id).future));
    if (product != null) {
      _name.text = product.name;
      _sku.text = product.sku ?? '';
      _barcode.text = product.barcode ?? '';
      _description.text = product.description ?? '';
      _purchase.text = (product.purchasePrice.cents / 100).toStringAsFixed(2);
      _sale.text = (product.salePrice.cents / 100).toStringAsFixed(2);
      _stockMin.text = fmtQty(product.stockMin);
      _stockMax.text = product.stockMax == null ? '' : fmtQty(product.stockMax!);
      _categoryId = product.categoryId;
      _brandId = product.brandId;
      _unitId = product.baseUnitId;
      _purchaseUnitId = product.purchaseUnitId;
      _unitsPerPkg.text = fmtQty(product.saleUnitsPerPurchaseUnit);
      _photoPath = product.photoPath;
      _originalPhotoPath = product.photoPath;
      _conversions = [
        for (final c in conversions)
          ConversionDraft(
            id: c.id,
            unitId: c.unitId,
            factor: c.factor,
            purchasePrice: c.purchasePrice,
            salePrice: c.salePrice,
          ),
      ];
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    for (final c in [
      _name, _sku, _barcode, _description, _purchase, _sale, _stockMin, _stockMax,
      _unitsPerPkg, _purchasedQty,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Money _money(String text) => Money.fromSoles(double.tryParse(text.trim()) ?? 0);

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_name.text.trim().isEmpty) {
          showMbSnack(context, 'El nombre es obligatorio.');
          return false;
        }
        return true;
      case 1:
        if (_unitId == null) {
          showMbSnack(context, 'La unidad base de venta es obligatoria.');
          return false;
        }
        return true;
      case 2:
      case 3:
        return true;
      default:
        return true;
    }
  }

  void _nextStep() {
    if (_validateCurrentStep() && _currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  final _pageController = PageController();

  Future<void> _pickPhoto(ImageSource source) async {
    final guard =
        ensureAllowed(ref.read(sessionPermissionsProvider), 'products.edit');
    if (guard.isErr) {
      if (mounted) {
        showMbSnack(context, guard.failure!.message);
      }
      return;
    }
    final photo = ref.read(photoServiceProvider);
    final path = await photo.pickAndSave(source);
    if (path != null) {
      final old = _photoPath;
      setState(() => _photoPath = path);
      if (old != null) await photo.deletePhoto(old);
    }
  }

  Future<void> _removePhoto() async {
    final photo = ref.read(photoServiceProvider);
    final old = _photoPath;
    setState(() => _photoPath = null);
    if (old != null) await photo.deletePhoto(old);
  }

  Future<void> _save() async {
    final guard = ensureAllowed(
      ref.read(sessionPermissionsProvider),
      _isEditing ? 'products.edit' : 'products.create',
    );
    if (guard.isErr) {
      if (mounted) {
        showMbSnack(context, guard.failure!.message);
      }
      return;
    }
    if (_name.text.trim().isEmpty || _unitId == null) {
      showMbSnack(context, 'Nombre y unidad son obligatorios.');
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(productRepositoryProvider);
    final storeId = ref.read(sessionControllerProvider).valueOrNull?.store?.id;
    if (storeId == null) {
      if (mounted) {
        setState(() => _saving = false);
        showMbSnack(context, 'Sesión no disponible.');
      }
      return;
    }

    final draft = ProductDraft(
      storeId: storeId,
      categoryId: _categoryId,
      brandId: _brandId,
      baseUnitId: _unitId!,
      purchaseUnitId: _purchaseUnitId,
      saleUnitsPerPurchaseUnit: double.tryParse(_unitsPerPkg.text) ?? 1,
      sku: _sku.text.trim().isEmpty ? null : _sku.text.trim(),
      barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
      name: _name.text.trim(),
      description: _description.text.trim().isEmpty ? null : _description.text.trim(),
      purchasePrice: _money(_purchase.text),
      salePrice: _money(_sale.text),
      stockMin: double.tryParse(_stockMin.text) ?? 0,
      stockMax: _stockMax.text.trim().isEmpty
          ? null
          : double.tryParse(_stockMax.text),
      photoPath: _photoPath,
      purchasedQty: _isEditing ? 0 : (double.tryParse(_purchasedQty.text) ?? 0),
    );
    final conversions = [
      for (final c in _conversions)
        ProductUnitConversion(
            productId: widget.productId ?? 0,
            unitId: c.unitId,
            factor: c.factor,
            purchasePrice: c.purchasePrice,
            salePrice: c.salePrice,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
    ];

    final result = _isEditing
        ? await repo.updateProduct(widget.productId!, draft, conversions: conversions)
        : await repo.createProduct(draft, conversions: conversions);

    if (!mounted) return;
    if (result.isErr) {
      setState(() => _saving = false);
      showMbSnack(context, result.failure!.message);
      return;
    }
    if (_originalPhotoPath != null && _originalPhotoPath != _photoPath) {
      await ref.read(photoServiceProvider).deletePhoto(_originalPhotoPath!);
    }
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final guard =
        ensureAllowed(ref.read(sessionPermissionsProvider), 'products.disable');
    if (guard.isErr) {
      if (mounted) {
        showMbSnack(context, guard.failure!.message);
      }
      return;
    }
    final repo = ref.read(productRepositoryProvider);
    final canHard = (await repo.canHardDelete(widget.productId!)).orNull ?? false;
    if (!mounted) return;
    final message = canHard
        ? 'Este producto no tiene historial y se eliminará definitivamente.'
        : 'Este producto tiene historial; se desactivará (soft delete).';
    final confirmed = await showMbConfirm(
      context,
      title: 'Eliminar producto',
      message: message,
      confirmLabel: 'Eliminar',
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;
    final result = await repo.deleteProduct(widget.productId!);
    if (!mounted) return;
    if (result.isOk) {
      if (result.orNull == DeleteProductResult.hardDeleted && _photoPath != null) {
        await ref.read(photoServiceProvider).deletePhoto(_photoPath!);
      }
      if (mounted) context.pop();
    } else {
      showMbSnack(context, result.failure!.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final canEdit = session?.can('products.edit') ?? false;
    final canDisable = session?.can('products.disable') ?? false;

    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final brands = ref.watch(brandsProvider).valueOrNull ?? const [];
    final units = ref.watch(unitsProvider).valueOrNull ?? const [];

    if (!_loaded) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }

    final salePrice = _money(_sale.text);
    final purchasePrice = _money(_purchase.text);
    final unitsPerPkg = double.tryParse(_unitsPerPkg.text) ?? 1;
    final costPerBase = unitsPerPkg > 0
        ? Money((purchasePrice.cents / unitsPerPkg).round())
        : purchasePrice;

    final purchaseUnitName = _purchaseUnitId != null
        ? units.where((u) => u.id == _purchaseUnitId).map((u) => u.name).firstOrNull ?? 'compra'
        : null;

    final baseUnitName = _unitId != null
        ? units.where((u) => u.id == _unitId).map((u) => u.name).firstOrNull ?? 'unidad'
        : null;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !_dirty) return;
        final confirmed = await showMbConfirm(
          context,
          title: 'Cambios sin guardar',
          message: 'Tienes cambios sin guardar. ¿Deseas salir?',
          confirmLabel: 'Salir',
          cancelLabel: 'Quedarme',
        );
        if (confirmed == true && context.mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Editar producto' : 'Nuevo producto'),
          actions: [
            if (_isEditing && canDisable)
              IconButton(
                tooltip: 'Eliminar / desactivar',
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete,
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
            ProductFormStepIndicator(
              currentStep: _currentStep,
              totalSteps: _totalSteps,
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentStep = page),
                children: [
                  _StepBasicInfo(
                    photoPath: _photoPath,
                    name: _name,
                    sku: _sku,
                    barcode: _barcode,
                    description: _description,
                    canEdit: canEdit,
                    onPickPhoto: _pickPhoto,
                    onRemovePhoto: _removePhoto,
                  ),
                  _StepClassification(
                    photoPath: _photoPath,
                    productName: _name.text,
                    categoryId: _categoryId,
                    brandId: _brandId,
                    unitId: _unitId,
                    purchaseUnitId: _purchaseUnitId,
                    unitsPerPkg: _unitsPerPkg,
                    categories: categories,
                    brands: brands,
                    units: units,
                    baseUnitName: baseUnitName,
                    purchaseUnitName: purchaseUnitName,
                    onCategoryChanged: (v) => setState(() => _categoryId = v),
                    onBrandChanged: (v) => setState(() => _brandId = v),
                    onUnitChanged: (v) {
                      setState(() {
                        _unitId = v;
                        _purchaseUnitId ??= v;
                      });
                    },
                    onPurchaseUnitChanged: (v) => setState(() => _purchaseUnitId = v),
                    onUnitsPerPkgChanged: (_) => setState(() {}),
                  ),
                  _StepPrices(
                    photoPath: _photoPath,
                    productName: _name.text,
                    purchase: _purchase,
                    costPerBase: costPerBase,
                    unitsPerPkg: unitsPerPkg,
                    purchaseUnitName: purchaseUnitName,
                    salePrice: salePrice,
                    onPriceChanged: (price) {
                      final newText = (price.cents / 100).toStringAsFixed(2);
                      if (_sale.text != newText) {
                        _sale.text = newText;
                      }
                    },
                    onCostChanged: (_) => setState(() {}),
                  ),
                  _StepStock(
                    photoPath: _photoPath,
                    productName: _name.text,
                    stockMin: _stockMin,
                    stockMax: _stockMax,
                    purchasedQty: _purchasedQty,
                    isEditing: _isEditing,
                    units: units,
                    conversions: _conversions,
                    salePrice: salePrice,
                    unitSalePrice: salePrice,
                    purchaseUnitName: purchaseUnitName,
                    unitsPerPkg: unitsPerPkg,
                    onConversionsChanged: (drafts) => _conversions = drafts,
                    onPurchasedQtyChanged: (_) => setState(() {}),
                  ),
                  ProductFormSummary(
                    photoPath: _photoPath,
                    name: _name.text,
                    sku: _sku.text.isEmpty ? null : _sku.text,
                    barcode: _barcode.text.isEmpty ? null : _barcode.text,
                    description: _description.text.isEmpty ? null : _description.text,
                    categoryId: _categoryId,
                    brandId: _brandId,
                    unitId: _unitId,
                    purchaseUnitId: _purchaseUnitId,
                    unitsPerPkg: unitsPerPkg,
                    purchasePrice: purchasePrice,
                    salePrice: salePrice,
                    stockMin: double.tryParse(_stockMin.text) ?? 0,
                    stockMax: _stockMax.text.trim().isEmpty
                        ? null
                        : double.tryParse(_stockMax.text),
                    purchasedQty: double.tryParse(_purchasedQty.text) ?? 0,
                    isEditing: _isEditing,
                    categories: categories,
                    brands: brands,
                    units: units,
                    conversions: _conversions,
                  ),
                ],
              ),
            ),
            ProductFormNavBar(
              currentStep: _currentStep,
              totalSteps: _totalSteps,
              isEditing: _isEditing,
              saving: _saving,
              onPrevious: _previousStep,
              onNext: _nextStep,
              onSave: _saving ? null : _save,
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _StepBasicInfo extends StatelessWidget {
  final String? photoPath;
  final TextEditingController name;
  final TextEditingController sku;
  final TextEditingController barcode;
  final TextEditingController description;
  final bool canEdit;
  final Future<void> Function(ImageSource) onPickPhoto;
  final Future<void> Function() onRemovePhoto;

  const _StepBasicInfo({
    required this.photoPath,
    required this.name,
    required this.sku,
    required this.barcode,
    required this.description,
    required this.canEdit,
    required this.onPickPhoto,
    required this.onRemovePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PhotoField(
            photoPath: photoPath,
            onPick: onPickPhoto,
            onRemove: onRemovePhoto,
          ),
          const SizedBox(height: 16),
          MbTextField(
            controller: name,
            label: 'Nombre *',
            enabled: canEdit,
            autofocus: true,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: MbTextField(controller: sku, label: 'Código (SKU)'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MbTextField(controller: barcode, label: 'Código de barras'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MbTextField(
            controller: description,
            label: 'Descripción',
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _StepClassification extends StatelessWidget {
  final String? photoPath;
  final String productName;
  final int? categoryId;
  final int? brandId;
  final int? unitId;
  final int? purchaseUnitId;
  final TextEditingController unitsPerPkg;
  final List categories;
  final List brands;
  final List units;
  final String? baseUnitName;
  final String? purchaseUnitName;
  final ValueChanged<int?> onCategoryChanged;
  final ValueChanged<int?> onBrandChanged;
  final ValueChanged<int?> onUnitChanged;
  final ValueChanged<int?> onPurchaseUnitChanged;
  final ValueChanged<String?> onUnitsPerPkgChanged;

  const _StepClassification({
    required this.photoPath,
    required this.productName,
    required this.categoryId,
    required this.brandId,
    required this.unitId,
    required this.purchaseUnitId,
    required this.unitsPerPkg,
    required this.categories,
    required this.brands,
    required this.units,
    required this.baseUnitName,
    required this.purchaseUnitName,
    required this.onCategoryChanged,
    required this.onBrandChanged,
    required this.onUnitChanged,
    required this.onPurchaseUnitChanged,
    required this.onUnitsPerPkgChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProductBriefHeader(photoPath: photoPath, name: productName),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: categoryId,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Sin categoría')),
                    for (final c in categories)
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: onCategoryChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: brandId,
                  decoration: const InputDecoration(labelText: 'Marca'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Sin marca')),
                    for (final b in brands)
                      DropdownMenuItem(value: b.id, child: Text(b.name)),
                  ],
                  onChanged: onBrandChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            initialValue: unitId,
            decoration: const InputDecoration(labelText: 'Unidad base de venta *'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Seleccionar unidad')),
              for (final u in units)
                DropdownMenuItem(value: u.id, child: Text('${u.name} (${u.symbol})')),
            ],
            onChanged: onUnitChanged,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            initialValue: purchaseUnitId,
            decoration: const InputDecoration(labelText: 'Unidad de compra'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Igual que unidad base')),
              for (final u in units)
                DropdownMenuItem(value: u.id, child: Text('${u.name} (${u.symbol})')),
            ],
            onChanged: onPurchaseUnitChanged,
          ),
          const SizedBox(height: 12),
          MbTextField(
            controller: unitsPerPkg,
            label: 'Unidades de venta por unidad de compra',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: onUnitsPerPkgChanged,
            clearOnFocus: true,
          ),
          if (purchaseUnitId != null && unitId != null && purchaseUnitId != unitId) ...[
            const SizedBox(height: 4),
            Text(
              '${unitsPerPkg.text.isEmpty ? '0' : unitsPerPkg.text} '
              '${baseUnitName ?? 'unidad(es)'} por ${purchaseUnitName ?? 'compra'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepPrices extends StatelessWidget {
  final String? photoPath;
  final String productName;
  final TextEditingController purchase;
  final Money costPerBase;
  final double unitsPerPkg;
  final String? purchaseUnitName;
  final Money salePrice;
  final ValueChanged<Money> onPriceChanged;
  final ValueChanged<String> onCostChanged;

  const _StepPrices({
    required this.photoPath,
    required this.productName,
    required this.purchase,
    required this.costPerBase,
    required this.unitsPerPkg,
    required this.purchaseUnitName,
    required this.salePrice,
    required this.onPriceChanged,
    required this.onCostChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProductBriefHeader(photoPath: photoPath, name: productName),
          MbTextField(
            controller: purchase,
            label: purchaseUnitName != null
                ? 'Costo por $purchaseUnitName (S/)'
                : 'Costo unitario (S/)',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: onCostChanged,
            clearOnFocus: true,
          ),
          const SizedBox(height: 12),
          PriceRecommender(
            cost: costPerBase,
            unitsPerPkg: unitsPerPkg,
            purchaseUnitName: purchaseUnitName,
            initialSalePrice: salePrice,
            onPriceChanged: onPriceChanged,
          ),
        ],
      ),
    );
  }
}

class _StepStock extends StatelessWidget {
  final String? photoPath;
  final String productName;
  final TextEditingController stockMin;
  final TextEditingController stockMax;
  final TextEditingController purchasedQty;
  final bool isEditing;
  final List<Unit> units;
  final List<ConversionDraft> conversions;
  final Money salePrice;
  final Money unitSalePrice;
  final String? purchaseUnitName;
  final double unitsPerPkg;
  final ValueChanged<List<ConversionDraft>> onConversionsChanged;
  final ValueChanged<String?> onPurchasedQtyChanged;

  const _StepStock({
    required this.photoPath,
    required this.productName,
    required this.stockMin,
    required this.stockMax,
    required this.purchasedQty,
    required this.isEditing,
    required this.units,
    required this.conversions,
    required this.salePrice,
    required this.unitSalePrice,
    required this.purchaseUnitName,
    required this.unitsPerPkg,
    required this.onConversionsChanged,
    required this.onPurchasedQtyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProductBriefHeader(photoPath: photoPath, name: productName),
          MbTextField(
            controller: stockMin,
            label: 'Stock mínimo (unidades de venta)',
            keyboardType: TextInputType.number,
            clearOnFocus: true,
          ),
          const SizedBox(height: 12),
          MbTextField(
            controller: stockMax,
            label: 'Stock máximo (unidades de venta)',
            keyboardType: TextInputType.number,
            clearOnFocus: true,
          ),
          if (!isEditing) ...[
            const SizedBox(height: 20),
            MbTextField(
              controller: purchasedQty,
              label: purchaseUnitName != null
                  ? 'Unidades de compra compradas'
                  : 'Stock inicial',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              clearOnFocus: true,
              onChanged: onPurchasedQtyChanged,
            ),
            if (purchaseUnitName != null && unitsPerPkg > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Stock inicial = ${purchasedQty.text.isEmpty ? '0' : purchasedQty.text} '
                '$purchaseUnitName × $unitsPerPkg ud = '
                '${((double.tryParse(purchasedQty.text) ?? 0) * unitsPerPkg).toInt()} unidades',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ],
          const SizedBox(height: 20),
          ConversionsEditor(
            units: units,
            initial: conversions,
            unitSalePrice: salePrice,
            onChanged: onConversionsChanged,
          ),
        ],
      ),
    );
  }
}

class _ProductBriefHeader extends StatelessWidget {
  final String? photoPath;
  final String name;

  const _ProductBriefHeader({required this.photoPath, required this.name});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          ProductImage(photoPath: photoPath, width: 40, height: 40, borderRadius: 6),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name.isEmpty ? 'Sin nombre' : name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
