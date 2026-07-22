import 'dart:async';
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
  bool _isSearchingLive = false;
  Timer? _debounceTimer;
  bool _useGoogleMaps = !kIsWeb; // Default to Local/Stylized Map on Web
  String _searchQuery = '';
  String _activeFilter = 'NEAREST'; // ALL, NEAREST, BLOOD_BANK, EMERGENCY
  Position? _userPosition;
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
    _initDataAndLocation();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _transformationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initDataAndLocation() async {
    await _requestAndFetchUserLocation();
    await _loadHospitals();
  }

  Future<void> _requestAndFetchUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (serviceEnabled && (permission == LocationPermission.whileInUse || permission == LocationPermission.always)) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        if (mounted) {
          setState(() {
            _userPosition = position;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadHospitals() async {
    try {
      final hospitalRepo = ref.read(hospitalRepositoryProvider);
      final hospitals = await hospitalRepo.searchLiveHealthcareFacilities(
        '',
        userLat: _userPosition?.latitude,
        userLng: _userPosition?.longitude,
      );

      // Calculate real distances if user location is available
      _computeDistances(hospitals);

      if (mounted) {
        setState(() {
          _allHospitals = hospitals;
          _applySearchAndFilter();
          _calculateBoundingBox(hospitals);
          _isLoading = false;
        });

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

  void _computeDistances(List<HospitalModel> hospitals) {
    if (_userPosition == null) return;
    for (var h in hospitals) {
      if (h.latitude != null && h.longitude != null) {
        final meters = Geolocator.distanceBetween(
          _userPosition!.latitude,
          _userPosition!.longitude,
          h.latitude!,
          h.longitude!,
        );
        h.distanceKm = meters / 1000.0;
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
        final distText = hospital.distanceKm != null
            ? ' • ${hospital.distanceKm!.toStringAsFixed(1)} km'
            : '';
        _markers.add(
          Marker(
            markerId: MarkerId(hospital.id.toString()),
            position: LatLng(hospital.latitude!, hospital.longitude!),
            infoWindow: InfoWindow(
              title: hospital.name,
              snippet: '${hospital.address ?? ''}$distText',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              _selectedHospital?.id == hospital.id
                  ? BitmapDescriptor.hueViolet
                  : BitmapDescriptor.hueRed,
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

  void _applySearchAndFilter() {
    List<HospitalModel> list = List.from(_allHospitals);

    // 1. Filter by search query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((hospital) {
        final name = hospital.name.toLowerCase();
        final address = (hospital.address ?? '').toLowerCase();
        final city = (hospital.city ?? '').toLowerCase();
        final region = (hospital.region ?? '').toLowerCase();
        final services = (hospital.services ?? '').toLowerCase();
        final desc = (hospital.description ?? '').toLowerCase();
        return name.contains(q) ||
            address.contains(q) ||
            city.contains(q) ||
            region.contains(q) ||
            services.contains(q) ||
            desc.contains(q);
      }).toList();
    }

    // 2. Filter by chip category
    if (_activeFilter == 'BLOOD_BANK') {
      list = list.where((h) => h.hasBloodBank).toList();
    } else if (_activeFilter == 'EMERGENCY') {
      list = list.where((h) => h.hasEmergencyServices).toList();
    }

    // 3. Ascending order proximity sorting (nearest to farthest)
    if (_activeFilter == 'NEAREST' || _userPosition != null) {
      list.sort((a, b) {
        if (a.distanceKm == null && b.distanceKm == null) return 0;
        if (a.distanceKm == null) return 1;
        if (b.distanceKm == null) return -1;
        return a.distanceKm!.compareTo(b.distanceKm!);
      });
    }

    _filteredHospitals = list;
    _updateMarkers(_filteredHospitals);
  }

  void _onSearchChanged(String query) {
    _searchQuery = query;
    _applySearchAndFilter();

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _isSearchingLive = true);
      try {
        final hospitalRepo = ref.read(hospitalRepositoryProvider);
        final results = await hospitalRepo.searchLiveHealthcareFacilities(
          _searchQuery,
          userLat: _userPosition?.latitude,
          userLng: _userPosition?.longitude,
        );
        _computeDistances(results);
        if (mounted) {
          setState(() {
            _allHospitals = results;
            _applySearchAndFilter();
            _calculateBoundingBox(results);
            _isSearchingLive = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => _isSearchingLive = false);
        }
      }
    });
  }

  void _setFilter(String filter) {
    setState(() {
      _activeFilter = filter;
      _applySearchAndFilter();
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
    await _fetchUserLocationSilently();
    if (_userPosition != null) {
      _computeDistances(_allHospitals);
      setState(() {
        _applySearchAndFilter();
      });

      if (_useGoogleMaps) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(_userPosition!.latitude, _userPosition!.longitude),
            13,
          ),
        );
      } else {
        final double x = (_userPosition!.longitude - minLng) / (maxLng - minLng) * 600;
        final double y = (1.0 - (_userPosition!.latitude - minLat) / (maxLat - minLat)) * 400;
        _centerMockMapOn(x, y);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location updated. Showing distances from your GPS position.'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_selectedHospital != null && _selectedHospital!.latitude != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_selectedHospital!.latitude!, _selectedHospital!.longitude!),
          14,
        ),
      );
    }
  }

  Future<void> _openInRealGoogleMaps({double? lat, double? lng, String? title}) async {
    Uri url;
    if (lat != null && lng != null) {
      url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    } else if (_selectedHospital?.latitude != null && _selectedHospital?.longitude != null) {
      url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${_selectedHospital!.latitude},${_selectedHospital!.longitude}');
    } else if (_userPosition != null) {
      url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${_userPosition!.latitude},${_userPosition!.longitude}');
    } else {
      url = Uri.parse('https://www.google.com/maps/@3.8480,11.5021,13z');
    }

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch Google Maps';
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps GPS')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = ref.watch(localizationServiceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          localization.translate('hospital_locator'),
          style: const TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.bold),
        ),
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.onSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor, size: 24),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else if (Navigator.of(context, rootNavigator: true).canPop()) {
              Navigator.of(context, rootNavigator: true).pop();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_rounded, color: AppTheme.primaryColor),
            tooltip: 'Open in Google Maps App',
            onPressed: () => _openInRealGoogleMaps(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search Bar and Map Mode Switcher
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 48.h,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _searchController,
                                onChanged: _onSearchChanged,
                                decoration: InputDecoration(
                                  hintText: 'Search hospital, city, or services (ICU, Lab)...',
                                  hintStyle: TextStyle(fontSize: 12.sp, color: Colors.grey),
                                  prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
                                  suffixIcon: _isSearchingLive
                                      ? Container(
                                          padding: EdgeInsets.all(12.w),
                                          width: 20.w,
                                          height: 20.w,
                                          child: const CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                                        )
                                      : (_searchQuery.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear, size: 18),
                                              onPressed: () {
                                                _searchController.clear();
                                                _onSearchChanged('');
                                              },
                                            )
                                          : null),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 14.h),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
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
                      SizedBox(height: 10.h),

                      // Filter Chips Row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('All', 'ALL', Icons.local_hospital_rounded),
                            SizedBox(width: 8.w),
                            _buildFilterChip('Nearest', 'NEAREST', Icons.near_me_rounded),
                            SizedBox(width: 8.w),
                            _buildFilterChip('Blood Bank', 'BLOOD_BANK', Icons.bloodtype_rounded),
                            SizedBox(width: 8.w),
                            _buildFilterChip('24/7 Emergency', 'EMERGENCY', Icons.emergency_rounded),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Interactive Map Container
                Container(
                  height: 220.h,
                  margin: EdgeInsets.symmetric(horizontal: 16.w),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      _useGoogleMaps
                          ? GoogleMap(
                              onMapCreated: _onMapCreated,
                              initialCameraPosition: CameraPosition(
                                target: _selectedHospital?.latitude != null && _selectedHospital?.longitude != null
                                    ? LatLng(_selectedHospital!.latitude!, _selectedHospital!.longitude!)
                                    : LatLng(_userPosition?.latitude ?? 3.8480, _userPosition?.longitude ?? 11.5021),
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
                                  GestureDetector(
                                    onDoubleTap: () => _openInRealGoogleMaps(),
                                    child: SizedBox(
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
                                  ),
                                  if (_userPosition != null)
                                    Positioned(
                                      left: (_userPosition!.longitude - minLng) / (maxLng - minLng) * 600 - 8,
                                      top: (1.0 - (_userPosition!.latitude - minLat) / (maxLat - minLat)) * 400 - 8,
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
                                          _openInRealGoogleMaps(
                                            lat: hospital.latitude,
                                            lng: hospital.longitude,
                                            title: hospital.name,
                                          );
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

                      // Floating Badge Overlay on Top Right of Map
                      Positioned(
                        top: 12.h,
                        right: 12.w,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _openInRealGoogleMaps(),
                            borderRadius: BorderRadius.circular(20.r),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(20.r),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.directions_rounded, color: Colors.white, size: 14.w),
                                  SizedBox(width: 4.w),
                                  Text(
                                    'Open Real Map GPS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
                        '${_filteredHospitals.length} Healthcare Facilities Found',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.onSurface,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _checkPermissionAndGetLocation,
                        icon: const Icon(Icons.my_location_rounded, size: 16, color: AppTheme.primaryColor),
                        label: Text(
                          _userPosition != null ? 'GPS Active' : 'Locate Me',
                          style: TextStyle(fontSize: 12.sp, color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                // Hospital Cards List
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
                          borderRadius: BorderRadius.circular(16.r),
                          side: BorderSide(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: InkWell(
                            onTap: () => _selectHospital(hospital),
                            borderRadius: BorderRadius.circular(16.r),
                            child: Padding(
                              padding: EdgeInsets.all(14.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(10.w),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppTheme.primaryColor.withOpacity(0.12)
                                              : const Color(0xFFF0F4F8),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.local_hospital_rounded,
                                          color: isSelected ? AppTheme.primaryColor : Colors.grey.shade700,
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
                                                color: isSelected ? AppTheme.primaryColor : AppTheme.onSurface,
                                              ),
                                            ),
                                            SizedBox(height: 4.h),
                                            Text(
                                              '${hospital.address ?? ''}, ${hospital.city ?? ''} (${hospital.region ?? ''})',
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          if (hospital.distanceKm != null) ...[
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryColor.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12.r),
                                              ),
                                              child: Text(
                                                '📍 ${hospital.formattedDistance}',
                                                style: TextStyle(
                                                  fontSize: 11.sp,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.primaryColor,
                                                ),
                                              ),
                                            ),
                                            SizedBox(height: 4.h),
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(10.r),
                                              ),
                                              child: Text(
                                                '⏱️ ${hospital.estimatedTravelTime}',
                                                style: TextStyle(
                                                  fontSize: 10.sp,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.blue[800],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 10.h),

                                  // Opening Hours Badge
                                  Row(
                                    children: [
                                      Icon(Icons.access_time_rounded, size: 14.w, color: Colors.green.shade700),
                                      SizedBox(width: 6.w),
                                      Text(
                                        hospital.openingHours,
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8.h),

                                  // Services Tags
                                  Wrap(
                                    spacing: 6.w,
                                    runSpacing: 6.h,
                                    children: hospital.servicesList.map((service) {
                                      return Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFECEFF1),
                                          borderRadius: BorderRadius.circular(8.r),
                                        ),
                                        child: Text(
                                          service,
                                          style: TextStyle(fontSize: 10.sp, color: Colors.blueGrey.shade800),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  SizedBox(height: 10.h),

                                  const Divider(height: 16),

                                  // Action Buttons
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.phone_rounded, size: 14.w, color: Colors.grey.shade600),
                                          SizedBox(width: 4.w),
                                          Text(
                                            hospital.phoneNumber ?? 'No phone',
                                            style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade800),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          if (hospital.phoneNumber != null && hospital.phoneNumber!.isNotEmpty)
                                            IconButton(
                                              icon: const Icon(Icons.phone),
                                              color: Colors.green.shade700,
                                              tooltip: 'Call Hospital',
                                              onPressed: () async {
                                                final telUrl = Uri.parse('tel:${hospital.phoneNumber}');
                                                if (await canLaunchUrl(telUrl)) {
                                                  await launchUrl(telUrl);
                                                }
                                              },
                                            ),
                                          IconButton(
                                            icon: const Icon(Icons.directions_rounded),
                                            color: AppTheme.primaryColor,
                                            tooltip: 'Google Maps Directions',
                                            onPressed: () async {
                                              if (hospital.latitude != null && hospital.longitude != null) {
                                                final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${hospital.latitude},${hospital.longitude}');
                                                try {
                                                  if (await canLaunchUrl(url)) {
                                                    await launchUrl(url, mode: LaunchMode.externalApplication);
                                                  }
                                                } catch (_) {}
                                              }
                                            },
                                          ),
                                        ],
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

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final bool isSelected = _activeFilter == value;
    return ChoiceChip(
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 16.w,
        color: isSelected ? Colors.white : AppTheme.primaryColor,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.bold,
          color: isSelected ? Colors.white : AppTheme.onSurface,
        ),
      ),
      selected: isSelected,
      selectedColor: AppTheme.primaryColor,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      onSelected: (_) => _setFilter(value),
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
