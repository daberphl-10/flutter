import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../models/program.dart'; // Imports your Farm model
import '../theme/app_theme.dart';

class RegisterTreeScreen extends StatefulWidget {
  @override
  _RegisterTreeScreenState createState() => _RegisterTreeScreenState();
}

class _RegisterTreeScreenState extends State<RegisterTreeScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text Controllers
  final _codeController = TextEditingController();
  final _blockController = TextEditingController();
  final _datePlantedController = TextEditingController();
  
  // Variety dropdown
  String? _selectedVariety;
  
  // Variety options
  final List<String> _varietyOptions = [
    'BR 25',
    'UF 18',
    'ICS 40',
    'K 1',
    'K 2',
    'PBC 123',
    'W 10',
    'Unknown / Native',
  ];

  // Function to show the Date Picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1990), // Trees can be old
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        // Format as YYYY-MM-DD for Laravel
        _datePlantedController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  // Data State
  List<Farm> _farms = [];
  Farm? _selectedFarm;

  // GPS State
  double? _latitude;
  double? _longitude;
  bool _gettingGPS = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchFarms();
  }

  // 1. LOAD FARMS
  void _fetchFarms() async {
    try {
      var farms = await ApiService.getFarms();
      setState(() {
        _farms = farms;
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error loading farms: $e")));
    }
  }

  // 2. GET GPS LOCATION
  Future<void> _captureLocation() async {
    setState(() => _gettingGPS = true);
    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw "Location permissions are denied";
        }
      }

      // Get position
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("GPS Error: $e")));
    } finally {
      setState(() => _gettingGPS = false);
    }
  }

  // 3. SAVE DATA
  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedFarm == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Please select a farm")));
      return;
    }

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please capture GPS location first")));
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ApiService.registerTree(
        farmId: _selectedFarm!.id!,
        treeCode: _codeController.text,
        latitude: _latitude!,
        longitude: _longitude!,
        variety: _selectedVariety,
        blockName: _blockController.text,
        datePlanted: _datePlantedController.text.isNotEmpty
            ? _datePlantedController.text
            : null,
      );

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.green,
        content: Text("Tree Registered Successfully!"),
      ));

      Navigator.pop(context); // Go back
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.red,
        content: Text(e.toString()),
      ));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text("Register New Tree"), backgroundColor: Colors.green[800]),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppTheme.spacingMD),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- FARM DROPDOWN ---
              DropdownButtonFormField<Farm>(
                decoration: InputDecoration(
                    labelText: "Select Farm", border: OutlineInputBorder()),
                value: _selectedFarm,
                items: _farms.map((farm) {
                  return DropdownMenuItem(
                    value: farm,
                    child: Text(farm.name ?? "Unnamed Farm"),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedFarm = val),
              ),
              SizedBox(height: AppTheme.spacingMD),

              // --- TREE INFO ---
              TextFormField(
                controller: _codeController,
                decoration: InputDecoration(
                    labelText: "Tree Code (e.g. T-01)",
                    border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              SizedBox(height: AppTheme.spacingMD),
              DropdownButtonFormField<String>(
                value: _selectedVariety,
                decoration: InputDecoration(
                  labelText: "Variety (Optional)",
                  border: OutlineInputBorder(),
                ),
                items: _varietyOptions.map((String variety) {
                  return DropdownMenuItem<String>(
                    value: variety,
                    child: Text(variety),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedVariety = newValue;
                  });
                },
              ),
              SizedBox(height: AppTheme.spacingMD),
              TextFormField(
                controller: _blockController,
                decoration: InputDecoration(
                    labelText: "Block Name (Optional)",
                    border: OutlineInputBorder()),
              ),

              SizedBox(height: AppTheme.spacingLG),
              Divider(),
              SizedBox(height: AppTheme.spacingMD),

              // DATE PICKER INPUT
              TextFormField(
                controller: _datePlantedController,
                decoration: InputDecoration(
                  labelText: "Date Planted",
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today), // Calendar icon
                ),
                readOnly: true, // User cannot type, must pick
                onTap: () => _selectDate(context), // Open calendar on tap
              ),

              // --- GPS SECTION ---
              Text("Geolocation",
                  style: AppTheme.h3),
              SizedBox(height: AppTheme.spacingSM),

              Container(
                padding: EdgeInsets.all(AppTheme.spacingMD),
                color: Colors.grey[100],
                child: Column(
                  children: [
                    if (_latitude != null)
                      Column(
                        children: [
                          Text("Latitude: $_latitude",
                              style: TextStyle(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold)),
                          Text("Longitude: $_longitude",
                              style: TextStyle(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold)),
                          SizedBox(height: 10),
                        ],
                      ),
                    ElevatedButton.icon(
                      onPressed: _gettingGPS ? null : _captureLocation,
                      icon: _gettingGPS
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(Icons.my_location),
                      label: Text(_latitude == null
                          ? "Capture GPS Coordinates"
                          : "Update Location"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 30),

              // --- SUBMIT ---
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text("SAVE TREE TO MAP",
                          style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[800]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
