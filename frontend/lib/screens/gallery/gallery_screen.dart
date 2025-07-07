import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import 'image_detail_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({Key? key}) : super(key: key);

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _searchController = TextEditingController();
  
  List<ClinicalImage> _images = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  String _searchQuery = '';
  int _currentPage = 0;
  static const int _pageSize = 20;
  bool _hasMoreImages = true;
  
  late TabController _tabController;
  int _selectedTabIndex = 0;
  
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    _loadImages();
  }
  
  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _selectedTabIndex = _tabController.index;
        _images.clear();
        _currentPage = 0;
        _hasMoreImages = true;
        _isLoading = true;
      });
      _loadImages();
    }
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreImages) {
        _loadMoreImages();
      }
    }
  }
  
  Future<void> _loadImages({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _currentPage = 0;
        _hasMoreImages = true;
        _images.clear();
        _isLoading = true;
      });
    }
    
    try {
      ApiResponse response;
      
      if (_searchQuery.isNotEmpty) {
        response = await _apiService.searchClinicalImages(
          query: _searchQuery,
          skip: _currentPage * _pageSize,
          limit: _pageSize,
          myImagesOnly: _selectedTabIndex == 1,
        );
      } else {
        switch (_selectedTabIndex) {
          case 0: // Todas las imágenes
            response = await _apiService.getClinicalImages(
              skip: _currentPage * _pageSize,
              limit: _pageSize,
            );
            break;
          case 1: // Mis imágenes
            response = await _apiService.getMyClinicalImages(
              skip: _currentPage * _pageSize,
              limit: _pageSize,
            );
            break;
          case 2: // Públicas
            response = await _apiService.getPublicClinicalImages(
              skip: _currentPage * _pageSize,
              limit: _pageSize,
            );
            break;
          default:
            response = await _apiService.getClinicalImages(
              skip: _currentPage * _pageSize,
              limit: _pageSize,
            );
        }
      }
      
      if (response.isSuccess && mounted) {
        final List<dynamic> imageList = response.data?['images'] ?? response.data ?? [];
        final List<ClinicalImage> newImages = imageList
            .map((json) => ClinicalImage.fromJson(json))
            .toList();
        
        setState(() {
          if (isRefresh || _currentPage == 0) {
            _images = newImages;
          } else {
            _images.addAll(newImages);
          }
          _hasMoreImages = newImages.length == _pageSize;
          _isLoading = false;
          _errorMessage = null;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = response.error ?? 'Error cargando imágenes';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error inesperado: $e';
        });
      }
    }
  }
  
  Future<void> _loadMoreImages() async {
    if (_isLoadingMore || !_hasMoreImages) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    _currentPage++;
    await _loadImages();
    
    setState(() {
      _isLoadingMore = false;
    });
  }
  
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _currentPage = 0;
      _hasMoreImages = true;
      _isLoading = true;
    });
    
    // Debounce search
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_searchQuery == query && mounted) {
        _loadImages(isRefresh: true);
      }
    });
  }
  
  Future<void> _uploadImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      
      if (image == null) return;
      
      await _showUploadDialog(File(image.path));
    } catch (e) {
      _showErrorSnackBar('Error seleccionando imagen: $e');
    }
  }
  
  Future<void> _showUploadDialog(File imageFile) async {
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController tagsController = TextEditingController();
    bool isPublic = false;
    bool isUploading = false;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Subir Imagen Clínica'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Vista previa de la imagen
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          imageFile,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Campo de descripción
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        hintText: 'Describe la imagen clínica...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Campo de tags
                    TextField(
                      controller: tagsController,
                      decoration: const InputDecoration(
                        labelText: 'Tags (separados por comas)',
                        hintText: 'radiografía, tórax, neumonía',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Switch para imagen pública
                    Row(
                      children: [
                        Switch(
                          value: isPublic,
                          onChanged: isUploading ? null : (value) {
                            setState(() {
                              isPublic = value;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        const Text('Imagen pública'),
                      ],
                    ),
                    
                    if (isUploading) ...[
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(width: 16),
                          Text('Subiendo imagen...'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUploading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isUploading ? null : () async {
                    setState(() {
                      isUploading = true;
                    });
                    
                    try {
                      final response = await _apiService.uploadClinicalImage(
                        imageFile: imageFile,
                        description: descriptionController.text.isNotEmpty 
                            ? descriptionController.text 
                            : null,
                        tags: tagsController.text.isNotEmpty 
                            ? tagsController.text 
                            : null,
                        isPublic: isPublic,
                      );
                      
                      if (response.isSuccess) {
                        Navigator.of(context).pop();
                        _showSuccessSnackBar('Imagen subida exitosamente');
                        _loadImages(isRefresh: true);
                      } else {
                        setState(() {
                          isUploading = false;
                        });
                        _showErrorSnackBar(response.error ?? 'Error subiendo imagen');
                      }
                    } catch (e) {
                      setState(() {
                        isUploading = false;
                      });
                      _showErrorSnackBar('Error inesperado: $e');
                    }
                  },
                  child: const Text('Subir'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  void _openImageDetail(ClinicalImage image) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ImageDetailScreen(image: image),
      ),
    ).then((_) {
      // Recargar la lista si se hicieron cambios
      _loadImages(isRefresh: true);
    });
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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            title: const Text('Galería Clínica'),
            floating: true,
            pinned: true,
            snap: false,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.add_a_photo),
                onPressed: _uploadImage,
                tooltip: 'Subir imagen',
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(100),
              child: Column(
                children: [
                  // Barra de búsqueda
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Buscar imágenes...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  
                  // Tabs
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Todas'),
                      Tab(text: 'Mis Imágenes'),
                      Tab(text: 'Públicas'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        body: RefreshIndicator(
          onRefresh: () => _loadImages(isRefresh: true),
          child: _buildBody(),
        ),
      ),
    );
  }
  
  Widget _buildBody() {
    if (_isLoading && _images.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (_errorMessage != null && _images.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadImages(isRefresh: true),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    
    if (_images.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty 
                  ? 'No se encontraron imágenes'
                  : 'No hay imágenes clínicas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Intenta con otros términos de búsqueda'
                  : 'Sube tu primera imagen para comenzar',
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _uploadImage,
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Subir Imagen'),
              ),
            ],
          ],
        ),
      );
    }
    
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _images.length + (_isLoadingMore ? 2 : 0),
      itemBuilder: (context, index) {
        if (index >= _images.length) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        
        final image = _images[index];
        return _buildImageCard(image);
      },
    );
  }
  
  Widget _buildImageCard(ClinicalImage image) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openImageDetail(image),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                ),
                child: Stack(
                  children: [
                    // Imagen
                    Positioned.fill(
                      child: Image.network(
                        _apiService.getClinicalImageViewUrl(image.id),
                        fit: BoxFit.cover,
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
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[300],
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  color: Colors.grey[500],
                                  size: 32,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Error cargando imagen',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    
                    // Badges
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (image.isPublic)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
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
                    ),
                    
                    // Overlay con información
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              image.displayDescription,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.remove_red_eye,
                                  color: Colors.white70,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${image.viewCount}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  image.fileSizeHuman,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}