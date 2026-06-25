import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  List<HospitalModel> _hospitals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHospitals();
  }

  Future<void> _loadHospitals() async {
    final hospitalRepo = ref.read(hospitalRepositoryProvider);
    final hospitals = await hospitalRepo.getHospitals();
    setState(() {
      _hospitals = hospitals;
      _markers.clear();
      for (final hospital in hospitals) {
        if (hospital.latitude != null && hospital.longitude != null) {
          _markers.add(
            Marker(
              markerId: MarkerId(hospital.id.toString()),
              position: LatLng(hospital.latitude!, hospital.longitude!),
              infoWindow: InfoWindow(
                title: hospital.name,
                snippet: '${hospital.address} • ${hospital.phoneNumber}',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
            ),
          );
        }
      }
      setState(() => _isLoading = false);
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    final localization = ref.watch(localizationServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(localization.translate('hospital_locator')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(4.0511, 9.7679), // Cameroon center
                    zoom: 6,
                  ),
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                ),
                // Hospital List Bottom Sheet
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20.r),
                        topRight: Radius.circular(20.r),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          margin: EdgeInsets.only(top: 12.h),
                          width: 40.w,
                          height: 4.h,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(16.w),
                          child: Text(
                            '${_hospitals.length} ${localization.translate('hospitals_nearby')}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            itemCount: _hospitals.length,
                            itemBuilder: (context, index) {
                              final hospital = _hospitals[index];
                              return Card(
                                margin: EdgeInsets.only(bottom: 8.h),
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.local_hospital,
                                    color: AppTheme.primaryColor,
                                  ),
                                  title: Text(hospital.name),
                                  subtitle: Text(hospital.address ?? ''),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.directions),
                                    onPressed: () {
                                      // Open navigation
                                    },
                                  ),
                                  onTap: () {
                                    if (hospital.latitude != null && hospital.longitude != null) {
                                      _mapController?.animateCamera(
                                        CameraUpdate.newLatLngZoom(
                                          LatLng(hospital.latitude!, hospital.longitude!),
                                          15,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
