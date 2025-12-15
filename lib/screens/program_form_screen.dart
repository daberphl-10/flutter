import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/program.dart';
import '../services/api_service.dart';
import '../services/psgc_service.dart';
import '../theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FarmFormScreen extends StatefulWidget {
  final Farm? farm; // null for create, Farm for edit

  const FarmFormScreen({super.key, this.farm});

  @override
  State<FarmFormScreen> createState() => _FarmFormScreenState();
}

class _FarmFormScreenState extends State<FarmFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _areaHectaresController = TextEditingController();
  final _elevationController = TextEditingController();
  String? _selectedSoilType;
  bool _isLoading = false;
  
  // GPS Location State
  double? _latitude;
  double? _longitude;
  bool _gettingLocation = false;
  
  final List<String> _soilTypes = [
    'Clay Loam',
    'Sandy Loam',
    'Loam',
    'Silty Clay',
    'Clay',
    'Sandy',
  ];

  // PSGC Location data
  List<PSGCRegion> _regions = [];
  List<PSGCProvince> _provinces = [];
  List<PSGCCity> _cities = [];
  List<PSGCBarangay> _barangays = [];
  PSGCRegion? _selectedRegion;
  PSGCProvince? _selectedProvince;
  PSGCCity? _selectedCity;
  PSGCBarangay? _selectedBarangay;
  bool _loadingRegions = false;
  bool _loadingProvinces = false;
  bool _loadingCities = false;
  bool _loadingBarangays = false;

  @override
  void initState() {
    super.initState();
    if (widget.farm != null) {
      _nameController.text = widget.farm!.name ?? '';
      _addressController.text = widget.farm!.location ?? '';
      _latitude = widget.farm!.latitude;
      _longitude = widget.farm!.longitude;
      _selectedSoilType = widget.farm!.soil_type;
      _areaHectaresController.text =
          widget.farm!.area_hectares?.toString() ?? '';
    }
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    setState(() => _loadingRegions = true);
    final regions = await PSGCService.getRegions();
    setState(() {
      _regions = regions;
      _loadingRegions = false;
    });
  }

  Future<void> _loadProvinces(String regionCode) async {
    setState(() {
      _loadingProvinces = true;
      _provinces = [];
      _selectedProvince = null;
      _cities = [];
      _selectedCity = null;
      _barangays = [];
      _selectedBarangay = null;
    });
    final provinces = await PSGCService.getProvinces(regionCode);
    setState(() {
      _provinces = provinces;
      _loadingProvinces = false;
    });
  }

  Future<void> _loadCities(String provinceCode) async {
    setState(() {
      _loadingCities = true;
      _cities = [];
      _selectedCity = null;
      _barangays = [];
      _selectedBarangay = null;
    });
    final cities = await PSGCService.getCities(provinceCode);
    setState(() {
      _cities = cities;
      _loadingCities = false;
    });
  }

  Future<void> _loadBarangays(String cityCode) async {
    setState(() {
      _loadingBarangays = true;
      _barangays = [];
      _selectedBarangay = null;
    });
    final barangays = await PSGCService.getBarangays(cityCode);
    setState(() {
      _barangays = barangays;
      _loadingBarangays = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _areaHectaresController.dispose();
    _elevationController.dispose();
    super.dispose();
  }

  // Get GPS Location automatically
  Future<void> _getCurrentLocation() async {
    setState(() => _gettingLocation = true);
    
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location services are disabled. Please enable GPS.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permissions are denied. Please enable in settings.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied. Please enable in app settings.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '📍 Location captured: ${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _gettingLocation = false);
      }
    }
  }

  Future<void> _saveFarm() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate PSGC location fields
    if (_selectedRegion == null || _selectedProvince == null || 
        _selectedCity == null || _selectedBarangay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Region, Province, City/Municipality, and Barangay'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Build location string from PSGC selections
      final location = PSGCService.formatLocation(
        barangay: _selectedBarangay?.name,
        city: _selectedCity?.name,
        province: _selectedProvince?.name,
        address: _addressController.text.trim(),
      );

      final farm = Farm(
        id: widget.farm?.id,
        name: _nameController.text.trim(),
        location: location,
        latitude: _latitude,
        longitude: _longitude,
        soil_type: _selectedSoilType,
        area_hectares: _areaHectaresController.text.trim().isEmpty
            ? null
            : double.parse(_areaHectaresController.text.trim()),
      );

      if (widget.farm == null) {
        // Create new farm
        final created = await ApiService.createFarm(farm);
        // Set the newly created farm as the active farm for cacao operations
        final prefs = await SharedPreferences.getInstance();
        if (created.id != null) {
          await prefs.setInt('activeFarmId', created.id!);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Farm created and set as active')),
          );
        }
      } else {
        // Update existing farm
        await ApiService.updateFarm(farm);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Farm updated successfully')),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.farm == null ? 'Add Farm' : 'Edit Farm'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(AppTheme.spacingMD),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                    hintText: 'Enter farm name',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a farm name';
                    }
                    return null;
                  },
                  enabled: !_isLoading,
                ),
                SizedBox(height: AppTheme.spacingMD),
                // Region Dropdown
                DropdownButtonFormField<PSGCRegion>(
                  value: _selectedRegion,
                  decoration: const InputDecoration(
                    labelText: 'Region *',
                    border: OutlineInputBorder(),
                    hintText: 'Select region',
                  ),
                  items: _regions.map((region) {
                    return DropdownMenuItem<PSGCRegion>(
                      value: region,
                      child: Text(region.name),
                    );
                  }).toList(),
                  onChanged: _isLoading || _loadingRegions
                      ? null
                      : (PSGCRegion? newValue) {
                          setState(() {
                            _selectedRegion = newValue;
                            _selectedProvince = null;
                            _selectedCity = null;
                            _selectedBarangay = null;
                          });
                          if (newValue != null) {
                            _loadProvinces(newValue.code);
                          }
                        },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a region';
                    }
                    return null;
                  },
                ),
                SizedBox(height: AppTheme.spacingMD),
                // Province Dropdown
                DropdownButtonFormField<PSGCProvince>(
                  value: _selectedProvince,
                  decoration: InputDecoration(
                    labelText: 'Province *',
                    border: const OutlineInputBorder(),
                    hintText: _loadingProvinces ? 'Loading...' : 'Select province',
                  ),
                  items: _provinces.map((province) {
                    return DropdownMenuItem<PSGCProvince>(
                      value: province,
                      child: Text(province.name),
                    );
                  }).toList(),
                  onChanged: (_isLoading || _loadingProvinces || _selectedRegion == null)
                      ? null
                      : (PSGCProvince? newValue) {
                          setState(() {
                            _selectedProvince = newValue;
                            _selectedCity = null;
                            _selectedBarangay = null;
                          });
                          if (newValue != null) {
                            _loadCities(newValue.code);
                          }
                        },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a province';
                    }
                    return null;
                  },
                ),
                SizedBox(height: AppTheme.spacingMD),
                // City/Municipality Dropdown
                DropdownButtonFormField<PSGCCity>(
                  value: _selectedCity,
                  decoration: InputDecoration(
                    labelText: 'City/Municipality *',
                    border: const OutlineInputBorder(),
                    hintText: _loadingCities ? 'Loading...' : 'Select city/municipality',
                  ),
                  items: _cities.map((city) {
                    return DropdownMenuItem<PSGCCity>(
                      value: city,
                      child: Text('${city.name}${city.isCity ? ' (City)' : ' (Municipality)'}'),
                    );
                  }).toList(),
                  onChanged: (_isLoading || _loadingCities || _selectedProvince == null)
                      ? null
                      : (PSGCCity? newValue) {
                          setState(() {
                            _selectedCity = newValue;
                            _selectedBarangay = null;
                          });
                          if (newValue != null) {
                            _loadBarangays(newValue.code);
                          }
                        },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a city/municipality';
                    }
                    return null;
                  },
                ),
                SizedBox(height: AppTheme.spacingMD),
                // Barangay Dropdown
                DropdownButtonFormField<PSGCBarangay>(
                  value: _selectedBarangay,
                  decoration: InputDecoration(
                    labelText: 'Barangay *',
                    border: const OutlineInputBorder(),
                    hintText: _loadingBarangays ? 'Loading...' : 'Select barangay',
                  ),
                  items: _barangays.map((barangay) {
                    return DropdownMenuItem<PSGCBarangay>(
                      value: barangay,
                      child: Text(barangay.name),
                    );
                  }).toList(),
                  onChanged: (_isLoading || _loadingBarangays || _selectedCity == null)
                      ? null
                      : (PSGCBarangay? newValue) {
                          setState(() {
                            _selectedBarangay = newValue;
                          });
                        },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a barangay';
                    }
                    return null;
                  },
                ),
                SizedBox(height: AppTheme.spacingMD),
                // Additional Address Field
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Additional Address (Optional)',
                    border: OutlineInputBorder(),
                    hintText: 'Street, building, etc.',
                  ),
                  enabled: !_isLoading,
                ),
                SizedBox(height: AppTheme.spacingMD),
                // GPS Location Section
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on, color: Colors.blue),
                            const SizedBox(width: 8),
                            const Text(
                              'Farm Coordinates',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: AppTheme.spacingSM),
                        ElevatedButton.icon(
                          onPressed: _isLoading || _gettingLocation
                              ? null
                              : _getCurrentLocation,
                          icon: _gettingLocation
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.my_location),
                          label: Text(_gettingLocation
                              ? 'Getting Location...'
                              : 'Get Current Location'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                        if (_latitude != null && _longitude != null) ...[
                          SizedBox(height: AppTheme.spacingSM),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Location Captured',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: AppTheme.spacingXS),
                                Text(
                                  'Latitude: ${_latitude!.toStringAsFixed(6)}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                Text(
                                  'Longitude: ${_longitude!.toStringAsFixed(6)}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          SizedBox(height: AppTheme.spacingXS),
                          Text(
                            'Tap the button above to automatically get your current location',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SizedBox(height: AppTheme.spacingMD),
                DropdownButtonFormField<String>(
                  value: _selectedSoilType,
                  decoration: const InputDecoration(
                    labelText: 'Soil Type',
                    border: OutlineInputBorder(),
                    hintText: 'Select soil type',
                  ),
                  items: _soilTypes.map((String soilType) {
                    return DropdownMenuItem<String>(
                      value: soilType,
                      child: Text(soilType),
                    );
                  }).toList(),
                  onChanged: _isLoading
                      ? null
                      : (String? newValue) {
                          setState(() {
                            _selectedSoilType = newValue;
                          });
                        },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select soil type';
                    }
                    return null;
                  },
                ),
                SizedBox(height: AppTheme.spacingMD),
                TextFormField(
                  controller: _areaHectaresController,
                  decoration: const InputDecoration(
                    labelText: 'Area Size',
                    border: OutlineInputBorder(),
                    hintText: 'Enter area size',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter area size';
                    }
                    if (double.tryParse(value.trim()) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                  enabled: !_isLoading,
                ),
                SizedBox(height: AppTheme.spacingLG),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveFarm,
                  child: Text(_isLoading ? 'Saving...' : 'Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
