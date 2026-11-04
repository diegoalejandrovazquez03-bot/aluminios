import 'package:flutter/material.dart';

import 'dart:convert';

import 'package:image_picker/image_picker.dart';

import '../../core/constants.dart';
import '../../core/app_routes.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/image_viewer.dart';
import '../../widgets/sheet_message.dart';
import '../../widgets/top_bar.dart';

class CatalogScreen extends StatefulWidget {
  final AppState state;
  final Function(int) onNavigate;

  const CatalogScreen({
    super.key,
    required this.state,
    required this.onNavigate,
  });

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  String _typeFilter = 'Todos';

  final List<String> _types = [
    'Todos',
    'Cancel',
    'Ventana',
    'Domo',
    'Fachada',
    'Barandal',
    'Residencial',
  ];

  void _openUploadModal() {
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final widthCtrl = TextEditingController();
    final heightCtrl = TextEditingController();
    final depthCtrl = TextEditingController();
    final photoData = <String>[];
    int? selectedClientId;
    String selectedType = 'Ventana';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Agregar foto al catálogo',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Título del trabajo *',
                    ),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    items: _types.where((t) => t != 'Todos').map((t) {
                      return DropdownMenuItem(value: t, child: Text(t));
                    }).toList(),
                    onChanged: (val) =>
                        setModalState(() => selectedType = val ?? 'Ventana'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    initialValue: selectedClientId,
                    decoration: const InputDecoration(
                      labelText: 'Cliente asociado (opcional)',
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Sin cliente'),
                      ),
                      ...widget.state.clients.map(
                        (client) => DropdownMenuItem<int?>(
                          value: client.id,
                          child: Text(client.name),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setModalState(() => selectedClientId = value),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: urlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'URL de la imagen (o dejar vacío para demo)',
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            final photo = await ImagePicker().pickImage(
                              source: ImageSource.camera,
                              imageQuality: 65,
                              maxWidth: 1200,
                              maxHeight: 1200,
                            );
                            if (photo != null) {
                              final bytes = await photo.readAsBytes();
                              setModalState(
                                () => photoData.add(
                                  'data:image/jpeg;base64,${base64Encode(bytes)}',
                                ),
                              );
                            }
                          } catch (_) {
                            if (!ctx.mounted) return;
                            showSheetMessage(
                              ctx,
                              'No se pudo abrir la cámara. Revisa los permisos del dispositivo.',
                            );
                          }
                        },
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Cámara'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            final photo = await ImagePicker().pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 65,
                              maxWidth: 1200,
                              maxHeight: 1200,
                            );
                            if (photo != null) {
                              final bytes = await photo.readAsBytes();
                              setModalState(
                                () => photoData.add(
                                  'data:image/jpeg;base64,${base64Encode(bytes)}',
                                ),
                              );
                            }
                          } catch (_) {
                            if (!ctx.mounted) return;
                            showSheetMessage(
                              ctx,
                              'No se pudo acceder a la galería. Revisa los permisos del dispositivo.',
                            );
                          }
                        },
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Galería'),
                      ),
                    ],
                  ),
                  if (photoData.isNotEmpty)
                    Text('${photoData.length} foto(s) seleccionada(s).'),
                  const SizedBox(height: 8),
                  const Text(
                    'Medidas manuales (cm)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: widthCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Ancho'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: heightCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Alto'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: depthCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Fondo'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () {
                      if (titleCtrl.text.trim().isEmpty) {
                        showSheetMessage(ctx, 'Escribe el título del trabajo');
                        return;
                      }
                      final imgUrl =
                          (photoData.isNotEmpty ? photoData.first : null) ??
                          (urlCtrl.text.trim().isNotEmpty
                              ? urlCtrl.text.trim()
                              : 'https://images.unsplash.com/photo-1587527901949-ab0341697c1e?w=420&h=320&fit=crop&auto=format');

                      final newWork = Work(
                        id: DateTime.now().millisecondsSinceEpoch,
                        title: titleCtrl.text.trim(),
                        type: selectedType,
                        img: imgUrl,
                        custom: true,
                        photos: photoData,
                        width: double.tryParse(widthCtrl.text),
                        height: double.tryParse(heightCtrl.text),
                        depth: double.tryParse(depthCtrl.text),
                        clientId: selectedClientId,
                      );
                      widget.state.addWork(newWork);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Trabajo agregado al catálogo'),
                        ),
                      );
                    },
                    child: const Text('Guardar en Catálogo'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openPhotoViewer(Work work) {
    final hasSize =
        work.width != null || work.height != null || work.depth != null;
    showImageViewer(
      context,
      images: work.photos.isEmpty ? [work.img] : work.photos,
      title: work.title,
      subtitle: work.type,
      details: hasSize
          ? 'Medidas: ${work.width ?? '—'} × ${work.height ?? '—'} × ${work.depth ?? '—'} cm'
          : null,
      action: work.custom
          ? IconButton(
              tooltip: 'Eliminar foto',
              icon: Icon(Icons.delete_outline, color: AppColors.cancelled),
              onPressed: () {
                widget.state.deleteWork(work.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Foto eliminada')));
              },
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final works = state.works.where((w) {
      return _typeFilter == 'Todos' || w.type == _typeFilter;
    }).toList();

    return Scaffold(
      appBar: TopBar(
        title: 'Catálogo Visual',
        showLogo: true,
        onAvatarTap: () => widget.onNavigate(AdminScreen.perfil),
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: _types.map((t) {
                final isSel = _typeFilter == t;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(t),
                    selected: isSel,
                    selectedColor: AppColors.navy,
                    labelStyle: TextStyle(
                      color: isSel
                          ? Colors.white
                          : (isDark ? Colors.white70 : AppColors.navy),
                      fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 12,
                    ),
                    backgroundColor: isDark
                        ? AppColors.surfaceDark
                        : Colors.white,
                    side: BorderSide(
                      color: isSel ? Colors.transparent : AppColors.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    onSelected: (val) => setState(() => _typeFilter = t),
                  ),
                );
              }).toList(),
            ),
          ),

          // Grid of Works
          Expanded(
            child: works.isEmpty
                ? Center(
                    child: Text(
                      'Sin fotos para esta categoría',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.95,
                        ),
                    itemCount: works.length,
                    itemBuilder: (context, i) {
                      final w = works[i];
                      return GestureDetector(
                        onTap: () => _openPhotoViewer(w),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.surfaceDark
                                : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.hairline),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(10),
                                  ),
                                  child: _workImage(w.img, fit: BoxFit.cover),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  w.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.navy,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.onInk,
        icon: const Icon(Icons.add_a_photo),
        label: const Text(
          'Subir foto',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        onPressed: _openUploadModal,
      ),
    );
  }

  Widget _workImage(String source, {required BoxFit fit}) {
    if (source.startsWith('data:image/')) {
      try {
        return Image.memory(base64Decode(source.split(',').last), fit: fit);
      } catch (_) {}
    }
    return Image.network(
      source,
      fit: fit,
      errorBuilder: (context, error, stackTrace) =>
          Container(color: Colors.black12, child: const Icon(Icons.image)),
    );
  }
}
