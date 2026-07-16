import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../core/providers/providers.dart';
import '../../../../data/repositories/hospital_repository.dart';
import '../../../../data/models/hospital_model.dart';

class HospitalLocatorScreen extends ConsumerStatefulWidget {
  const HospitalLocatorScreen({super.key});

  @override
  ConsumerState<HospitalLocatorScreen> createState() => _HospitalLocatorScreenState();
}

class _HospitalLocatorScreenState extends ConsumerState<HospitalLocatorScreen> {
  final Set<Marker> _markers = {};
  GoogleMapController? _mapController;
  List<HospitalModel> _allHospitals = [];
  List<HospitalModel> _filteredHospitals = [];
  bool _isLoading = true;
  bool _useGoogleMaps = !kIsWeb; // Default to Local/Stylized Map on Web to prevent runtime crashes
  String _searchQuery = '';
  HospitalModel? _selectedHospital;
  final TextEditingController _searchController = TextEditingController();
  final TransformationController _transformationController = TransformationController();

  // Bounding box coordinates for map projection (Cameroon Central Region)
  double minLat = 3.2;
  double maxLat = 4.6;
  double minLng = 9.2;
  double maxLng = 12.2;

  @override
  void initState() {
    super.initState();
    _loadHospitals();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _transformationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadHospitals() async {
    try {
      final hospitalRepo = ref.read(hospitalRepositoryProvider);
      final hospitals = await hospitalRepo.getHospitals();
      
      if (mounted) {
        setState(() {
          _allHospitals = hospitals;
          _filteredHospitals = hospitals;
          _updateMarkers(hospitals);
          _calculateBoundingBox(hospitals);
          _isLoading = false;
        });

        // Small delay to let UI build before centering the simulated map
        Future.delayed(const Duration(milliseconds: 300), () {
          if (hospitals.isNotEmpty && !_useGoogleMaps) {
            _centerOnFirstHospital();
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _calculateBoundingBox(List<HospitalModel> hospitals) {
    final validHospitals = hospitals
        .where((h) => h.latitude != null && h.longitude != null)
        .toList();
    if (validHospitals.isNotEmpty) {
      final lats = validHospitals.map((h) => h.latitude!).toList();
      final lngs = validHospitals.map((h) => h.longitude!).toList();
      
      minLat = lats.reduce((a, b) => a < b ? a : b) - 0.3;
      maxLat = lats.reduce((a, b) => a > b ? a : b) + 0.3;
      minLng = lngs.reduce((a, b) => a < b ? a : b) - 0.3;
      maxLng = lngs.reduce((a, b) => a > b ? a : b) + 0.3;
      
      // Ensure constraints are valid and non-zero
      if (minLat == maxLat) {
        minLat -= 0.5;
        maxLat += 0.5;
      }
      if (minLng == maxLng) {
        minLng -= 0.5;
        maxLng += 0.5;
      }
    }
  }

  void _updateMarkers(List<HospitalModel> hospitals) {
    _markers.clear();
    for (final hospital in hospitals) {
      if (hospital.latitude != null && hospital.longitude != null) {
        _markers.add(
          Marker(
            markerId: MarkerId(hospital.id.toString()),
            position: LatLng(hospital.latitude!, hospital.longitude!),
            infoWindow: InfoWindow(
              title: hospital.name,
              snippet: '${hospital.address ?? ''} • ${hospital.phoneNumber ?? ''}',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
            onTap: () {
              setState(() {
                _selectedHospital = hospital;
              });
            },
          ),
        );
      }
    }
  }

  void _filterHospitals(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredHospitals = _allHospitals;
      } else {
        final q = query.toLowerCase();
        _filteredHospitals = _allHospitals.where((hospital) {
          final name = hospital.name.toLowerCase();
          final address = (hospital.address ?? '').toLowerCase();
          final city = (hospital.city ?? '').toLowerCase();
          final region = (hospital.region ?? '').toLowerCase();
          return name.contains(q) ||
              address.contains(q) ||
              city.contains(q) ||
              region.contains(q);
        }).toList();
      }
      _updateMarkers(_filteredHospitals);
    });
  }

  void _centerOnFirstHospital() {
    final validHospitals = _filteredHospitals
        .where((h) => h.latitude != null && h.longitude != null)
        .toList();
    if (validHospitals.isNotEmpty) {
      _selectHospital(validHospitals.first);
    }
  }

  void _selectHospital(HospitalModel hospital) {
    setState(() {
      _selectedHospital = hospital;
    });

    if (hospital.latitude != null && hospital.longitude != null) {
      if (_useGoogleMaps) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(hospital.latitude!, hospital.longitude!),
            14,
          ),
        );
      } else {
        // Center the stylized map
        final double x = (hospital.longitude! - minLng) / (maxLng - minLng) * 600;
        final double y = (1.0 - (hospital.latitude! - minLat) / (maxLat - minLat)) * 400;
        _centerMockMapOn(x, y);
      }
    }
  }

  void _centerMockMapOn(double x, double y) {
    const double zoom = 1.6;
    final double viewportWidth = MediaQuery.of(context).size.width;
    final double viewportHeight = 240.h;
    
    final double tx = (viewportWidth / 2) - (x * zoom);
    final double ty = (viewportHeight / 2) - (y * zoom);
    
    _transformationController.value = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(zoom);
  }

  Future<void> _checkPermissionAndGetLocation() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition();
      if (_useGoogleMaps) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            13,
          ),
        );
      } else {
        final double x = (position.longitude - minLng) / (maxLng - minLng) * 600;
        final double y = (1.0 - (position.latitude - minLat) / (maxLat - minLat)) * 400;
        _centerMockMapOn(x, y);
      }
    } catch (_) {}
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _checkPermissionAndGetLocation();
    if (_selectedHospital != null && _selectedHospital!.latitude != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_selectedHospital!.latitude!, _selectedHospital!.longitude!),
          14,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = ref.watch(localizationServiceProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(localization.translate('hospital_locator')),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search Bar and Map Mode Switcher
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 48.h,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: TextField(
                                controller: _searchController,
                                onChanged: _filterHospitals,
                                decoration: InputDecoration(
                                  hintText: 'Search by hospital, city or region...',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            _searchController.clear();
                                            _filterHospitals('');
                                          },
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 14.h),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          // Toggle between Local/Stylized Map and Google Maps
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: IconButton(
                              icon: Icon(
                                _useGoogleMaps ? Icons.map_outlined : Icons.satellite_alt_outlined,
                                color: AppTheme.primaryColor,
                              ),
                              tooltip: _useGoogleMaps ? 'Switch to Stylized Map' : 'Switch to Google Maps',
                              onPressed: () {
                                setState(() {
                                  _useGoogleMaps = !_useGoogleMaps;
                                });
                                // Re-center map upon mode switch
                                Future.delayed(const Duration(milliseconds: 200), () {
                                  if (_selectedHospital != null) {
                                    _selectHospital(_selectedHospital!);
                                  } else {
                                    _centerOnFirstHospital();
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Map Container (height restricted to represent a "small map")
                Container(
                  height: 240.h,
                  margin: EdgeInsets.symmetric(horizontal: 16.w),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _useGoogleMaps
                      ? GoogleMap(
                          onMapCreated: _onMapCreated,
                          initialCameraPosition: CameraPosition(
                            target: _selectedHospital?.latitude != null && _selectedHospital?.longitude != null
                                ? LatLng(_selectedHospital!.latitude!, _selectedHospital!.longitude!)
                                : const LatLng(3.8480, 11.5021), // Yaounde default
                            zoom: 12,
                          ),
                          markers: _markers,
                          myLocationEnabled: true,
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: false,
                        )
                      : InteractiveViewer(
                          transformationController: _transformationController,
                          boundaryMargin: const EdgeInsets.all(120),
                          minScale: 0.5,
                          maxScale: 3.0,
                          child: Stack(
                            children: [
                              // Background Stylized Canvas
                              SizedBox(
                                width: 600,
                                height: 400,
                                child: CustomPaint(
                                  painter: MapBackgroundPainter(
                                    minLat: minLat,
                                    maxLat: maxLat,
                                    minLng: minLng,
                                    maxLng: maxLng,
                                    hospitals: _allHospitals,
                                  ),
                                ),
                              ),
                              // Dotted user pulsing marker (Simulated location Yaounde area)
                              Positioned(
                                left: (11.45 - minLng) / (maxLng - minLng) * 600 - 8,
                                top: (1.0 - (3.86 - minLat) / (maxLat - minLat)) * 400 - 8,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Live Hospital Markers on local canvas
                              ..._filteredHospitals.map((hospital) {
                                if (hospital.latitude == null || hospital.longitude == null) {
                                  return const SizedBox();
                                }
                                double x = (hospital.longitude! - minLng) / (maxLng - minLng) * 600;
                                double y = (1.0 - (hospital.latitude! - minLat) / (maxLat - minLat)) * 400;
                                bool isSelected = _selectedHospital?.id == hospital.id;
                                
                                return Positioned(
                                  left: x - 18,
                                  top: y - 36,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedHospital = hospital;
                                      });
                                    },
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          color: isSelected ? AppTheme.primaryColor : Colors.redAccent.withOpacity(0.75),
                                          size: isSelected ? 36.w : 28.w,
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                                          decoration: BoxDecoration(
                                            color: isSelected ? AppTheme.primaryColor : Colors.white.withOpacity(0.85),
                                            borderRadius: BorderRadius.circular(4.r),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Colors.black12,
                                                blurRadius: 2,
                                                offset: Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            hospital.name.split(' ').last,
                                            style: TextStyle(
                                              fontSize: 8.sp,
                                              color: isSelected ? Colors.white : Colors.black87,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                ),
                SizedBox(height: 12.h),

                // Title Section
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_filteredHospitals.length} ${localization.translate('hospitals_nearby')}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      TextButton.icon(
                        onPressed: _checkPermissionAndGetLocation,
                        icon: const Icon(Icons.my_location, size: 16),
                        label: const Text('My Location', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),

                // Hospital List Bottom Section
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    itemCount: _filteredHospitals.length,
                    itemBuilder: (context, index) {
                      final hospital = _filteredHospitals[index];
                      final isSelected = _selectedHospital?.id == hospital.id;
                      
                      return Card(
                        elevation: isSelected ? 4 : 1,
                        margin: EdgeInsets.only(bottom: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          side: BorderSide(
                            color: isSelected
                                ? AppTheme.primaryColor.withOpacity(0.5)
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12.r),
                            gradient: isSelected
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppTheme.primaryColor.withOpacity(0.04),
                                      Theme.of(context).cardColor,
                                    ],
                                  )
                                : null,
                          ),
                          child: InkWell(
                            onTap: () => _selectHospital(hospital),
                            borderRadius: BorderRadius.circular(12.r),
                            child: Padding(
                              padding: EdgeInsets.all(12.w),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8.w),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppTheme.primaryColor.withOpacity(0.1)
                                          : Colors.grey[100],
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.local_hospital,
                                      color: isSelected ? AppTheme.primaryColor : Colors.grey[600],
                                      size: 24.w,
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          hospital.name,
                                          style: TextStyle(
                                            fontSize: 15.sp,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? AppTheme.primaryColor : Colors.black87,
                                          ),
                                        ),
                                        SizedBox(height: 4.h),
                                        Text(
                                          '${hospital.address ?? ''}, ${hospital.city ?? ''} (${hospital.region ?? ''})',
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        if (hospital.phoneNumber != null && hospital.phoneNumber!.isNotEmpty) ...[
                                          SizedBox(height: 6.h),
                                          Row(
                                            children: [
                                              Icon(Icons.phone, size: 12.w, color: Colors.grey[500]),
                                              SizedBox(width: 4.w),
                                              Text(
                                                hospital.phoneNumber!,
                                                style: TextStyle(
                                                  fontSize: 12.sp,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        // Real Coordinates display
                                        if (hospital.latitude != null && hospital.longitude != null) ...[
                                          SizedBox(height: 4.h),
                                          Row(
                                            children: [
                                              Icon(Icons.pin_drop, size: 12.w, color: Colors.grey[500]),
                                              SizedBox(width: 4.w),
                                              Text(
                                                'Lat: ${hospital.latitude!.toStringAsFixed(4)}, Lng: ${hospital.longitude!.toStringAsFixed(4)}',
                                                style: TextStyle(
                                                  fontSize: 11.sp,
                                                  color: Colors.grey[500],
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  // Quick Action Buttons
                                  Column(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.directions_outlined),
                                        color: AppTheme.primaryColor,
                                        tooltip: 'Directions',
                                        onPressed: () async {
                                          if (hospital.latitude != null && hospital.longitude != null) {
                                            final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${hospital.latitude},${hospital.longitude}');
                                            try {
                                              if (await canLaunchUrl(url)) {
                                                await launchUrl(url, mode: LaunchMode.externalApplication);
                                              } else {
                                                throw 'Could not launch maps';
                                              }
                                            } catch (_) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Could not launch directions URL')),
                                                );
                                              }
                                            }
                                          }
                                        },
                                      ),
                                      if (hospital.phoneNumber != null && hospital.phoneNumber!.isNotEmpty)
                                        IconButton(
                                          icon: const Icon(Icons.phone_outlined),
                                          color: Colors.green,
                                          tooltip: 'Call Hospital',
                                          onPressed: () async {
                                            final telUrl = Uri.parse('tel:${hospital.phoneNumber}');
                                            if (await canLaunchUrl(telUrl)) {
                                              await launchUrl(telUrl);
                                            }
                                          },
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

// Custom Painter to draw stylized map features
class MapBackgroundPainter extends CustomPainter {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;
  final List<HospitalModel> hospitals;

  MapBackgroundPainter({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
    required this.hospitals,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Draw background color (light grey map color)
    paint.color = const Color(0xFFEFEFEF);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Draw map grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E2E2)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const double gridSize = 40.0;
    for (double i = 0; i < size.width; i += gridSize) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += gridSize) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    // Draw Atlantic coastline (Littoral region near Douala) on the left side
    // Douala longitude is ~9.76. Bounding box left is ~9.2.
    final oceanPaint = Paint()
      ..color = const Color(0xFFCBE3FB) // light blue ocean
      ..style = PaintingStyle.fill;
    
    final Path oceanPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.16, 0)
      ..quadraticBezierTo(
        size.width * 0.12,
        size.height * 0.35,
        size.width * 0.08,
        size.height * 0.65,
      )
      ..quadraticBezierTo(
        size.width * 0.04,
        size.height * 0.85,
        0,
        size.height * 0.95,
      )
      ..close();
    
    canvas.drawPath(oceanPath, oceanPaint);

    // Draw Coastline outline
    final coastPaint = Paint()
      ..color = const Color(0xFF90C2F9)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(oceanPath, coastPaint);

    // Coordinate positions for Yaounde & Douala
    // Douala coords: (4.0508, 9.7679)
    // Yaounde coords: (3.848, 11.5021)
    final double doualaX = (9.7679 - minLng) / (maxLng - minLng) * size.width;
    final double doualaY = (1.0 - (4.0508 - minLat) / (maxLat - minLat)) * size.height;
    final double yaoundeX = (11.5021 - minLng) / (maxLng - minLng) * size.width;
    final double yaoundeY = (1.0 - (3.848 - minLat) / (maxLat - minLat)) * size.height;

    // Draw Highway N3 (Connecting Douala to Yaounde)
    final roadShadow = Paint()
      ..color = Colors.black.withOpacity(0.04)
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final roadPaint = Paint()
      ..color = const Color(0xFFF8BA4E) // orange highway color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Path highway = Path()
      ..moveTo(doualaX, doualaY)
      ..quadraticBezierTo(
        (doualaX + yaoundeX) / 2,
        (doualaY + yaoundeY) / 2 - 25,
        yaoundeX,
        yaoundeY,
      );

    canvas.drawPath(highway, roadShadow);
    canvas.drawPath(highway, roadPaint);

    // Draw secondary roads branch
    final secondaryRoad = Paint()
      ..color = const Color(0xFFDDDDDD)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(Offset(doualaX, doualaY), Offset(doualaX + 30, doualaY + 60), secondaryRoad);
    canvas.drawLine(Offset(doualaX, doualaY), Offset(doualaX - 10, doualaY - 50), secondaryRoad);
    canvas.drawLine(Offset(yaoundeX, yaoundeY), Offset(yaoundeX + 50, yaoundeY - 40), secondaryRoad);
    canvas.drawLine(Offset(yaoundeX, yaoundeY), Offset(yaoundeX - 40, yaoundeY + 50), secondaryRoad);

    // Draw city anchors (small dots)
    final cityPaint = Paint()
      ..color = const Color(0xFF555555)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(doualaX, doualaY), 4, cityPaint);
    canvas.drawCircle(Offset(yaoundeX, yaoundeY), 4, cityPaint);

    // Draw major city name labels
    const textStyle = TextStyle(
      color: Color(0xFF555555),
      fontSize: 10,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.0,
      shadows: [
        Shadow(color: Colors.white, offset: Offset(1.5, 1.5), blurRadius: 1),
      ],
    );

    _drawText(canvas, "DOUALA", Offset(doualaX - 25, doualaY + 8), textStyle);
    _drawText(canvas, "YAOUNDÉ", Offset(yaoundeX - 25, yaoundeY + 8), textStyle);
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant MapBackgroundPainter oldDelegate) {
    return oldDelegate.minLat != minLat ||
        oldDelegate.maxLat != maxLat ||
        oldDelegate.minLng != minLng ||
        oldDelegate.maxLng != maxLng;
  }
}
