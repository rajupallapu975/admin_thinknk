import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../services/auth_service.dart';
import '../auth_wrapper.dart';

import 'package:flutter/foundation.dart'; // Added for kIsWeb

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  TimeOfDay? _openingTime;
  TimeOfDay? _closingTime;
  bool _isLoadingLocation = false;
  bool _isSubmitting = false;

  Future<void> _selectTime(BuildContext context, bool isOpening) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isOpening) {
          _openingTime = picked;
        } else {
          _closingTime = picked;
        }
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied, we cannot request permissions.';
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      // Geocoding package is NOT compatible with Web
      if (!kIsWeb) {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          setState(() {
            _locationController.text = "${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}";
            _pincodeController.text = place.postalCode ?? "";
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location detected! Please enter your shop address manually.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Location Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      if (_openingTime == null || _closingTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select both opening and closing times")),
        );
        return;
      }

      setState(() => _isSubmitting = true);
      try {
        final details = {
          'shopName': _shopNameController.text,
          'openingTime': _openingTime!.format(context),
          'closingTime': _closingTime!.format(context),
          'mobile': _mobileController.text,
          'pincode': _pincodeController.text,
          'address': _locationController.text,
          'email': AuthService().currentUser?.email,
        };

        await AuthService().saveShopDetails(details);
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthWrapper()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Submit Error: $e"), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade900, Colors.blue.shade600],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Card(
                elevation: 12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.store_mall_directory_rounded, size: 50, color: Colors.blue.shade800),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "Shop Registration",
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                        ),
                        const SizedBox(height: 8),
                        Text("Fill in your details to get started", style: TextStyle(color: Colors.grey.shade600)),
                        const SizedBox(height: 32),
                        
                        _buildTextField(_shopNameController, "Xerox Shop Name", Icons.storefront),
                        
                        Row(
                          children: [
                            Expanded(
                              child: _buildTimePickerField(
                                _openingTime?.format(context) ?? "Opening Time",
                                Icons.login,
                                () => _selectTime(context, true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTimePickerField(
                                _closingTime?.format(context) ?? "Closing Time",
                                Icons.logout,
                                () => _selectTime(context, false),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        _buildTextField(_mobileController, "Mobile Number", Icons.phone_android_rounded, keyboardType: TextInputType.phone),
                        _buildTextField(_pincodeController, "Pincode", Icons.pin_drop_rounded, keyboardType: TextInputType.number),
                        
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(_locationController, "Shop Full Address", Icons.location_on_rounded, maxLines: 2),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: _isLoadingLocation ? null : _getCurrentLocation,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade800,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: _isLoadingLocation 
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.my_location, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade800,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                          ),
                          child: _isSubmitting 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("Create Captain Profile", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimePickerField(String text, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text, 
                style: TextStyle(color: text.contains("Time") ? Colors.grey.shade600 : Colors.black87),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, 
    String label, 
    IconData icon, 
    {TextInputType keyboardType = TextInputType.text, int maxLines = 1}
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blue.shade700),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey.shade50,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
        ),
        validator: (value) => value == null || value.isEmpty ? "$label is required" : null,
      ),
    );
  }
}
