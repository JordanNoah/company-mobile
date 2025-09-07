// lib/components/image.dart
import 'dart:io';
import 'package:company/models/image_typeof.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:company/core/di.dart'; // http.client (Dio) global
import 'package:company/models/image_context.dart'; // enum ImageContext + .value
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';

class ImageComponent extends StatefulWidget {
  final String? url; // URL actual (puede ser null)
  final double? width; // si null => ocupa 100% del ancho
  final double? height; // puedes dejarlo null para autoheight
  final BoxFit fit;
  final BorderRadius borderRadius;

  /// Si es true, muestra el botón para editar (pick + upload)
  final bool edit;

  /// Endpoint al que se sube el archivo (ej. '/files/upload')
  final String uploadPath;

  /// Campos extra del form (opcional), p. ej. {'entityId':'123'}
  final Map<String, dynamic>? extraFields;

  /// Nombre de campo para el archivo en el form-data (por defecto 'file')
  final String fileFieldName;

  /// Contexto de negocio (user/company/product/...)
  final ImageContext? contextType;

  /// Imagetypeof (p. ej. banner, avatar, logo, ...)
  final ImageTypeof? imageType;

  /// Identificador de la entidad (p. ej. userId, productId)
  final String? entityId;

  /// Identificador de la entidad asociada al contexto (ej. id de la compañía)
  final String? contextId;

  /// Callback con la nueva URL retornada por el servidor
  final void Function(String newUrl)? onUploaded;

  /// Construcción del placeholder cuando no hay imagen
  final Widget Function(BuildContext context)? placeholderBuilder;

  /// Construcción del widget de error
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  const ImageComponent({
    super.key,
    this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
    this.edit = false,
    this.uploadPath = '/files/upload',
    this.extraFields,
    this.fileFieldName = 'file',
    this.contextType,
    this.contextId,
    this.imageType,
    this.entityId,
    this.onUploaded,
    this.placeholderBuilder,
    this.errorBuilder,
  });

  @override
  State<ImageComponent> createState() => _ImageComponentState();
}

class _ImageComponentState extends State<ImageComponent> {
  final _picker = ImagePicker();
  File? _localFile; // preview local antes/después de subir
  bool _uploading = false; // estado de subida
  double? _progress; // 0..1 durante la subida
  String? _currentUrl; // URL efectiva (inicia con widget.url)

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
  }

  @override
  void didUpdateWidget(covariant ImageComponent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si cambia la URL desde afuera, actualiza
    if (oldWidget.url != widget.url) {
      _currentUrl = widget.url;
      _localFile = null;
    }
  }

  Future<bool> _ensureGalleryPermission() async {
    // iOS usa Permission.photos
    if (Platform.isIOS) {
      var status = await Permission.photos.status;
      if (status.isDenied || status.isRestricted) {
        status = await Permission.photos.request();
      }
      if (status.isPermanentlyDenied) {
        _promptOpenSettings('Permiso de Fotos denegado permanentemente.');
        return false;
      }
      return status.isGranted;
    }

    // Android: el plugin mapea READ_MEDIA_IMAGES a Permission.photos en 13+
    if (Platform.isAndroid) {
      var status = await Permission.photos.status;
      if (status.isDenied || status.isRestricted) {
        status = await Permission.photos.request();
      }
      // Fallback para Android <= 12
      if (!status.isGranted) {
        var storage = await Permission.storage.status;
        if (storage.isDenied || storage.isRestricted) {
          storage = await Permission.storage.request();
        }
        if (storage.isPermanentlyDenied) {
          _promptOpenSettings(
            'Permiso de Almacenamiento denegado permanentemente.',
          );
          return false;
        }
        return storage.isGranted;
      }
      if (status.isPermanentlyDenied) {
        _promptOpenSettings('Permiso de Fotos denegado permanentemente.');
        return false;
      }
      return status.isGranted;
    }

    // Otras plataformas: no aplicamos permisos
    return true;
  }

  void _promptOpenSettings(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$message Abre configuración para habilitarlo.'),
        action: SnackBarAction(label: 'Abrir', onPressed: openAppSettings),
      ),
    );
  }

  Future<void> _pickAndUpload() async {
    final granted = await _ensureGalleryPermission();
    if (!granted) {
      _showSnack('Se necesitan permisos para acceder a tus fotos');
      return;
    }

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;

    final file = File(picked.path);
    setState(() {
      _localFile = file; // preview inmediata
    });

    await _upload(file);
  }

  Future<void> _upload(File file) async {
    setState(() {
      _uploading = true;
      _progress = 0.0;
    });

    // (Opcional) Validar que ciertos contextos lleven entityId
    if (widget.contextType != null &&
        {
          ImageContext.user,
          ImageContext.product,
          ImageContext.category,
          ImageContext.brand,
        }.contains(widget.contextType) &&
        (widget.entityId == null || widget.entityId!.isEmpty)) {
      _showSnack(
        'Falta entityId para el contexto ${widget.contextType!.value}',
      );
      setState(() {
        _uploading = false;
        _progress = null;
      });
      return;
    }

    try {
      // Campos base que siempre queremos enviar
      final baseFields = <String, dynamic>{
        if (widget.contextType != null) 'context': widget.contextType!.value,
        if (widget.contextId != null && widget.contextId!.isNotEmpty)
          'contextId': widget.contextId, // 👈 nuevo
        if (widget.entityId != null && widget.entityId!.isNotEmpty)
          'entityId': widget.entityId, // (si quieres mantenerlo aparte)
        if (widget.imageType != null && widget.imageType!.value.isNotEmpty)
          'typeOf': widget.imageType!.value, // 👈 nuevo
      };
      print(widget.contextId);

      // form-data
      final form = FormData.fromMap({
        ...baseFields, // contexto/entidad
        ...(widget.extraFields ?? {}), // el caller puede sobreescribir
        widget.fileFieldName: await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });

      final res = await http.client.post(
        widget.uploadPath,
        data: form,
        options: Options(contentType: 'multipart/form-data'),
        onSendProgress: (sent, total) {
          if (!mounted) return;
          if (total > 0) {
            setState(() => _progress = sent / total);
          }
        },
      );

      // Ajusta a cómo responde tu backend
      // asumiendo { data: { url: 'https://...' } } o { url: '...' } o { location: '...' }
      String? newUrl;
      final body = res.data;
      if (body is Map<String, dynamic>) {
        if (body['data'] is Map && (body['data'] as Map)['url'] != null) {
          newUrl = (body['data'] as Map)['url'] as String;
        } else if (body['url'] is String) {
          newUrl = body['url'] as String;
        } else if (body['location'] is String) {
          newUrl = body['location'] as String;
        }
      }

      if (newUrl == null || newUrl.isEmpty) {
        throw Exception('El servidor no retornó la URL de la imagen');
      }

      if (!mounted) return;
      setState(() {
        _currentUrl = newUrl;
        _uploading = false;
        _progress = null;
      });

      widget.onUploaded?.call(newUrl);
      _showSnack('Imagen actualizada');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _progress = null;
      });
      _showSnack('Error subiendo imagen');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildImageContent(context);

    return Stack(
      children: [
        ClipRRect(borderRadius: widget.borderRadius, child: content),

        // Overlay de progreso durante upload
        if (_uploading)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black45,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    if (_progress != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${((_progress ?? 0) * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

        // Botón de edición (solo si edit=true)
        if (widget.edit)
          Positioned(
            right: 8,
            bottom: 8,
            child: FloatingActionButton.small(
              heroTag: null,
              onPressed: _uploading ? null : _pickAndUpload,
              child: const Icon(Icons.edit),
            ),
          ),
      ],
    );
  }

  Widget _buildImageContent(BuildContext context) {
    final w = widget.width ?? double.infinity; // 100% si no se especifica
    final h = widget.height;

    if (_localFile != null) {
      // Preview local (tras elegir imagen)
      return Image.file(
        _localFile!,
        width: w,
        height: h,
        fit: widget.fit,
        errorBuilder: (c, e, s) => _errorWidget(context, e),
      );
    }

    if (_currentUrl != null && _currentUrl!.isNotEmpty) {
      // Imagen de red
      return Image.network(
        _currentUrl!,
        width: w,
        height: h,
        fit: widget.fit,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            width: w,
            height: h,
            child: const Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (c, e, s) => _errorWidget(context, e),
      );
    }

    // Placeholder si no hay imagen
    return SizedBox(
      width: w,
      height: h,
      child:
          widget.placeholderBuilder?.call(context) ??
          Container(
            color: Colors.grey[300],
            child: const Center(child: Icon(Icons.image, size: 48)),
          ),
    );
  }

  Widget _errorWidget(BuildContext context, Object error) {
    return widget.errorBuilder?.call(context, error) ??
        Container(
          width: widget.width ?? double.infinity,
          height: widget.height,
          color: Colors.grey[300],
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.red),
          ),
        );
  }
}
