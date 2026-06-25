import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../data/repositories/hospital_repository.dart';
import '../../../../data/models/hospital_model.dart';

class HospitalMapScreen extends ConsumerStatefulWidget {
  const HospitalMapScreen({super.key});

  @override
  ConsumerState<HospitalMapScreen> createState() => _HospitalMapScreenState();
}

class _HospitalMapScreenState extends ConsumerState<HospitalMapScreen> {
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
        title: Text(localization.translate('hospital_map')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
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
    );
  }
}
