import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';

class ImageDetailScreen extends StatefulWidget {
  final ClinicalImage image;

  const ImageDetailScreen({
    Key? key,
    required this.image,
  }) : super(key: key);

  @override
  State<ImageDetailScreen> createState() => _ImageDetailScreenState();
}

class _ImageDetailScreenState extends State<ImageDetailScreen> {
  final ApiService _apiService = ApiService();
  late ClinicalImage _image;
  bool _isLoading = false;
  String? _imageUrl;
  
  @override
  void initState() {
    super.initState();
    _image = widget.image;
    _loadImageUrl();
  }
  
  Future<void> _loadImageUrl() async {
    try {
      final response = await _apiService.getClinicalImageUrl(_image.id);
      if (response.isSuccess && mounted) {
        setState(() {
          _imageUrl = response.data?['image_url'];
        });
      }
    } catch (e) {
      // Fallback to direct URL
      setState(() {
        _imageUrl = _apiService.getClinicalImageViewUrl(_image.id);
      });
    }
  }
  
  Future<void> _editImage() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _EditImageDialog(image: _image),
    );
    
    if (result != null) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        final response = await _apiService.updateClinicalImage(
          _image.id,
          description: result['description'],
          tags: result['tags'],
          isPublic: result['isPublic'],
        );
        
        if (response.isSuccess) {
          setState(() {
            _image = ClinicalImage.fromJson(response.data!);
            _isLoading = false;
          });
          _showSuccessSnackBar('Imagen actualizada exitosamente');
        } else {
          setState(() {
            _isLoading = false;
          });
          _showErrorSnackBar(response.error ?? 'Error actualizando imagen');
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Error inesperado: $e');
      }
    }
  }
  
  Future<void> _deleteImage() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Imagen'),
        content: const Text('¿Estás seguro de que quieres eliminar esta imagen? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        final response = await _apiService.deleteClinicalImage(_image.id);
        
        if (response.isSuccess) {
          Navigator.of(context).pop(true); // Indica que se eliminó la imagen
          _showSuccessSnackBar('Imagen eliminada exitosamente');
        } else {
          setState(() {
            _isLoading = false;
          });
          _showErrorSnackBar(response.error ?? 'Error eliminando imagen');
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Error inesperado: $e');
      }
    }
  }
  
  Future<void> _downloadImage() async {
    try {
      final url = _apiService.getClinicalImageDownloadUrl(_image.id);
      // En una aplicación real, aquí se implementaría la descarga
      // Por ahora solo copiamos la URL al portapapeles
      await Clipboard.setData(ClipboardData(text: url));
      _showSuccessSnackBar('URL de descarga copiada al portapapeles');
    } catch (e) {
      _showErrorSnackBar('Error obteniendo enlace de descarga: $e');
    }
  }
  
  void _shareImage() {
    // En una aplicación real, aquí se implementaría compartir la imagen
    _showSuccessSnackBar('Función de compartir próximamente disponible');
  }
  
  void _showImageInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Información de la Imagen'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('Nombre del archivo', _image.originalFilename),
              _buildInfoRow('Tamaño', _image.fileSizeHuman),
              _buildInfoRow('Tipo', _image.fileType),
              _buildInfoRow('Dimensiones', _image.imageDimensions),
              if (_image.aspectRatio != null)
                _buildInfoRow('Relación de aspecto', _image.aspectRatio!.toStringAsFixed(2)),
              _buildInfoRow('Visualizaciones', _image.viewCount.toString()),
              _buildInfoRow('Estado', _image.isPublic ? 'Público' : 'Privado'),
              _buildInfoRow('Subido', _formatDate(_image.createdAt)),
              if (_image.updatedAt != _image.createdAt)
                _buildInfoRow('Actualizado', _formatDate(_image.updatedAt)),
              if (_image.owner != null)
                _buildInfoRow('Propietario', _image.owner!.fullName),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    final months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    
    return '${date.day} de ${months[date.month - 1]} de ${date.year} a las ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  bool _canEdit() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.user;
    return currentUser != null && 
           (currentUser.id == _image.ownerId || currentUser.isSuperuser);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Imagen principal
          Center(
            child: _imageUrl != null
                ? InteractiveViewer(
                    panEnabled: true,
                    boundaryMargin: const EdgeInsets.all(20),
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: Image.network(
                      _imageUrl!,
                      fit: BoxFit.contain,
                      headers: {
                        'Authorization': 'Bearer ${_apiService._token}',
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            color: Colors.white,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image,
                                color: Colors.white70,
                                size: 64,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Error cargando imagen',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  )
                : const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  ),
          ),
          
          // AppBar transparente
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppBar(
              backgroundColor: Colors.black54,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.white),
                  onPressed: _showImageInfo,
                ),
                if (_canEdit()) ...[
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    onPressed: _isLoading ? null : _editImage,
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (value) {
                      switch (value) {
                        case 'download':
                          _downloadImage();
                          break;
                        case 'share':
                          _shareImage();
                          break;
                        case 'delete':
                          _deleteImage();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'download',
                        child: Row(
                          children: [
                            Icon(Icons.download),
                            SizedBox(width: 8),
                            Text('Descargar'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share),
                            SizedBox(width: 8),
                            Text('Compartir'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Eliminar', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  IconButton(
                    icon: const Icon(Icons.download, color: Colors.white),
                    onPressed: _downloadImage,
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white),
                    onPressed: _shareImage,
                  ),
                ],
              ],
            ),
          ),
          
          // Información inferior
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_image.description != null && _image.description!.isNotEmpty)
                      Text(
                        _image.description!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    
                    const SizedBox(height: 8),
                    
                    // Tags
                    if (_image.tags != null && _image.tags!.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _image.tags!.split(',').map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '#${tag.trim()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    
                    const SizedBox(height: 12),
                    
                    // Información adicional
                    Row(
                      children: [
                        Icon(
                          Icons.remove_red_eye,
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_image.viewCount} visualizaciones',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.storage,
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _image.fileSizeHuman,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        if (_image.isPublic)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Público',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EditImageDialog extends StatefulWidget {
  final ClinicalImage image;

  const _EditImageDialog({
    required this.image,
  });

  @override
  State<_EditImageDialog> createState() => _EditImageDialogState();
}

class _EditImageDialogState extends State<_EditImageDialog> {
  late TextEditingController _descriptionController;
  late TextEditingController _tagsController;
  late bool _isPublic;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.image.description ?? '');
    _tagsController = TextEditingController(text: widget.image.tags ?? '');
    _isPublic = widget.image.isPublic;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar Imagen'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                hintText: 'Describe la imagen clínica...',
                border: OutlineInputBorder(),
              ),
            ),
            
            const SizedBox(height: 16),
            
            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags (separados por comas)',
                hintText: 'radiografía, tórax, neumonía',
                border: OutlineInputBorder(),
              ),
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Switch(
                  value: _isPublic,
                  onChanged: (value) {
                    setState(() {
                      _isPublic = value;
                    });
                  },
                ),
                const SizedBox(width: 8),
                const Text('Imagen pública'),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop({
              'description': _descriptionController.text.isNotEmpty 
                  ? _descriptionController.text 
                  : null,
              'tags': _tagsController.text.isNotEmpty 
                  ? _tagsController.text 
                  : null,
              'isPublic': _isPublic,
            });
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}