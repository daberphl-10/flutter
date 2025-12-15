import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../providers/refresh_provider.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import '../screens/harvest_entry_form.dart';

class FarmMapScreen extends StatefulWidget {
  final int? farmId; // Optional farm ID to navigate to
  final double? initialLatitude; // Optional initial latitude
  final double? initialLongitude; // Optional initial longitude
  final bool showTrees; // Whether to show trees view instead of farms
  final int? treeId; // Optional tree ID to highlight when navigating from tree list
  
  const FarmMapScreen({
    super.key,
    this.farmId,
    this.initialLatitude,
    this.initialLongitude,
    this.showTrees = false, // Default to farms view
    this.treeId,
  });

  @override
  State<FarmMapScreen> createState() => FarmMapScreenState();
}

class FarmMapScreenState extends State<FarmMapScreen>
    with WidgetsBindingObserver, RouteAware {
  final Completer<GoogleMapController> _controller = Completer();
  final RouteObserver<PageRoute> _routeObserver = RouteObserver<PageRoute>();

  Set<Marker> _markers = {};
  bool _isLoading = true;
  bool _showFarms = true; // Toggle between farm and tree view
  List<dynamic> _farms = [];
  List<dynamic> _trees = [];
  dynamic _selectedFarm; // Track which farm is selected for tree viewing
  bool _isSelectingTreeLocation = false; // Track if user is selecting a tree location on map
  LatLng? _selectedTreeLocation; // Store selected location for new tree

  // Variety options
  static const List<String> _varietyOptions = [
    'BR 25',
    'UF 18',
    'ICS 40',
    'K 1',
    'K 2',
    'PBC 123',
    'W 10',
    'Unknown / Native',
  ];

  // Default Camera Position (Change this to your Farm's location)
  CameraPosition get _initialCameraPosition {
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      return CameraPosition(
        target: LatLng(widget.initialLatitude!, widget.initialLongitude!),
        zoom: 16.0,
      );
    }
    return const CameraPosition(
      target: LatLng(16.6038, 121.1939),
      zoom: 16, // Zoomed in closer for web
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // If showTrees is true, start with trees view
    if (widget.showTrees) {
      _showFarms = false;
    }
    
    _loadData();
    
    // Listen to refresh provider for real-time updates
    Future.microtask(() {
      context.read<RefreshProvider>().addListener(_onRefreshNotification);
    });
    
    // If initial coordinates are provided, navigate to that location after map loads
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToLocation(
          widget.initialLatitude!,
          widget.initialLongitude!,
        );
      });
    }
  }
  
  // Navigate map camera to specific location
  Future<void> _navigateToLocation(double latitude, double longitude) async {
    final GoogleMapController controller = await _controller.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(latitude, longitude),
          zoom: 16.0,
        ),
      ),
    );
  }

  void _onRefreshNotification() {
    print('🔄 FARM_MAP: _onRefreshNotification called - reloading map data...');
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _routeObserver.unsubscribe(this);
    context.read<RefreshProvider>().removeListener(_onRefreshNotification);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reload data when app comes back to foreground
      _loadData();
    }
  }

  @override
  void didPopNext() {
    // Called when the screen comes back into view from a pushed route
    _loadData();
  }

  @override
  void didPushNext() {
    // Called when another route is pushed on top
  }

  Future<void> _loadData() async {
    if (_showFarms) {
      await _loadFarms();
    } else {
      // If a farm is selected, load only trees for that farm
      if (_selectedFarm != null) {
        await _loadTreesForFarm(_selectedFarm.id);
      } else {
        await _loadTrees();
      }
    }
  }

  Future<void> _loadFarms() async {
    try {
      final farms = await ApiService.getFarms();

      setState(() {
        _farms = farms;
        _markers = farms.map<Marker>((farm) {
          // 1. Extract farm data
          String id = farm.id.toString();
          double lat = farm.latitude ?? 0.0;
          double lng = farm.longitude ?? 0.0;

          // If this is the farm we're navigating to, highlight it
          bool isTargetFarm = widget.farmId != null && farm.id == widget.farmId;

          return Marker(
            markerId: MarkerId("farm_$id"),
            position: LatLng(lat, lng),
            // Disable marker taps when selecting tree location
            onTap: _isSelectingTreeLocation ? null : () => _showFarmDetails(farm),
            // Farm markers use blue color, or red if it's the target farm
            icon: BitmapDescriptor.defaultMarkerWithHue(
              isTargetFarm 
                ? BitmapDescriptor.hueRed 
                : BitmapDescriptor.hueBlue
            ),
            infoWindow: InfoWindow(
              title: farm.name ?? "Unknown Farm",
              snippet: farm.location ?? "Location unknown",
            ),
          );
        }).toSet();

        _isLoading = false;
      });
      
      // If a farm ID is provided, find and navigate to that farm
      if (widget.farmId != null) {
        try {
          final targetFarm = farms.firstWhere(
            (farm) => farm.id == widget.farmId,
          );
          
          if (targetFarm.latitude != null && 
              targetFarm.longitude != null &&
              targetFarm.latitude != 0.0 &&
              targetFarm.longitude != 0.0) {
            // Wait a bit for the map to be ready, then navigate
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                _navigateToLocation(targetFarm.latitude!, targetFarm.longitude!);
              }
            });
          }
        } catch (e) {
          print("Farm with ID ${widget.farmId} not found: $e");
        }
      }
    } catch (e) {
      print("Error loading farms: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTrees() async {
    try {
      final trees = await ApiService.getAllMapTrees();

      setState(() {
        _trees = trees;
        _markers = trees.map<Marker>((tree) {
          // 1. Extract ID & Location
          String id = tree['id'].toString();
          double lat = double.tryParse(tree['latitude'].toString()) ?? 0.0;
          double lng = double.tryParse(tree['longitude'].toString()) ?? 0.0;

          // 2. LOGIC: Get Status from 'latest_log'
          // If latest_log is null, the tree has no history, so we assume 'Healthy'
          var log = tree['latest_log'];
          String status = "Healthy";

          if (log != null) {
            String? diseaseType = log['disease_type']?.toString();
            String? logStatus = log['status']?.toString();
            
            // If disease_type exists and is not empty/null/healthy, use it
            if (diseaseType != null && 
                diseaseType.trim().isNotEmpty && 
                diseaseType.toLowerCase() != 'healthy' &&
                diseaseType.toLowerCase() != 'null') {
              status = diseaseType;
            } 
            // If disease_type is null/empty/healthy, check status field
            else if (logStatus != null && 
                     logStatus.trim().isNotEmpty &&
                     logStatus.toLowerCase() != 'healthy' &&
                     logStatus.toLowerCase() != 'null') {
              status = logStatus;
            } 
            // Otherwise, tree is healthy
            else {
              status = "Healthy";
            }
          }

          // 3. Color Logic - Match Vue.js color scheme
          double hue = BitmapDescriptor.hueGreen; // Green for Healthy

          // Check if status is actually healthy (case-insensitive)
          final statusLower = status.toLowerCase().trim();
          if (statusLower != "healthy" && statusLower.isNotEmpty) {
            if (statusLower.contains('black pod')) {
              hue = BitmapDescriptor.hueViolet; // Violet/Dark Purple for Black Pod Rot
            } else if (statusLower.contains('frosty') || statusLower.contains('frosty pod')) {
              hue = BitmapDescriptor.hueCyan; // Azure/Light Blue for Frosty Pod Rot
            } else if (statusLower.contains('pod borer') || statusLower.contains('borer') || statusLower.contains('cacao pod borer')) {
              hue = BitmapDescriptor.hueOrange; // Orange for Cacao Pod Borer
            } else if (statusLower.contains('witches') || statusLower.contains('broom')) {
              hue = BitmapDescriptor.hueRed; // Red for Witches' Broom
            } else {
              hue = BitmapDescriptor.hueRed; // Red for other diseases (Canker, etc.)
            }
          }

          // Highlight target tree if navigating from tree list
          bool isTargetTree = widget.treeId != null && tree['id'] == widget.treeId;

          return Marker(
            markerId: MarkerId(id),
            position: LatLng(lat, lng),
            // Disable marker taps when selecting tree location
            onTap: _isSelectingTreeLocation ? null : () => _showTreeDetails(tree),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              isTargetTree ? BitmapDescriptor.hueRed : hue
            ),
          );
        }).toSet();

        _isLoading = false;
      });
    } catch (e) {
      print("Error: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTreesForFarm(int farmId) async {
    try {
      final trees = await ApiService.getTreesByFarm(farmId);

      setState(() {
        _trees = trees;
        _markers = trees.map<Marker>((tree) {
          // 1. Extract ID & Location
          String id = tree['id'].toString();
          double lat = double.tryParse(tree['latitude'].toString()) ?? 0.0;
          double lng = double.tryParse(tree['longitude'].toString()) ?? 0.0;

          // 2. Get Status from 'latest_log'
          var log = tree['latest_log'];
          String status = "Healthy";

          if (log != null) {
            String? diseaseType = log['disease_type']?.toString();
            String? logStatus = log['status']?.toString();
            
            // If disease_type exists and is not empty/null/healthy, use it
            if (diseaseType != null && 
                diseaseType.trim().isNotEmpty && 
                diseaseType.toLowerCase() != 'healthy' &&
                diseaseType.toLowerCase() != 'null') {
              status = diseaseType;
            } 
            // If disease_type is null/empty/healthy, check status field
            else if (logStatus != null && 
                     logStatus.trim().isNotEmpty &&
                     logStatus.toLowerCase() != 'healthy' &&
                     logStatus.toLowerCase() != 'null') {
              status = logStatus;
            } 
            // Otherwise, tree is healthy
            else {
              status = "Healthy";
            }
          }

          // 3. Color Logic - Match Vue.js color scheme
          double hue = BitmapDescriptor.hueGreen; // Green for Healthy

          // Check if status is actually healthy (case-insensitive)
          final statusLower = status.toLowerCase().trim();
          if (statusLower != "healthy" && statusLower.isNotEmpty) {
            if (statusLower.contains('black pod')) {
              hue = BitmapDescriptor.hueViolet; // Violet/Dark Purple for Black Pod Rot
            } else if (statusLower.contains('frosty') || statusLower.contains('frosty pod')) {
              hue = BitmapDescriptor.hueCyan; // Azure/Light Blue for Frosty Pod Rot
            } else if (statusLower.contains('pod borer') || statusLower.contains('borer') || statusLower.contains('cacao pod borer')) {
              hue = BitmapDescriptor.hueOrange; // Orange for Cacao Pod Borer
            } else if (statusLower.contains('witches') || statusLower.contains('broom')) {
              hue = BitmapDescriptor.hueRed; // Red for Witches' Broom
            } else {
              hue = BitmapDescriptor.hueRed; // Red for other diseases (Canker, etc.)
            }
          }

          // Highlight target tree if navigating from tree list
          bool isTargetTree = widget.treeId != null && tree['id'] == widget.treeId;

          return Marker(
            markerId: MarkerId(id),
            position: LatLng(lat, lng),
            onTap: () => _showTreeDetails(tree),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              isTargetTree ? BitmapDescriptor.hueRed : hue
            ),
          );
        }).toSet();

        _isLoading = false;
      });
    } catch (e) {
      print("Error loading trees for farm: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _showFarms 
            ? "Farms Map" 
            : (_selectedFarm != null 
              ? "Trees - ${_selectedFarm.name ?? 'Farm'}" 
              : "Trees Map"
            ),
        ),
        actions: [
          // Toggle between Farm and Tree view
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingSM),
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingXS),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: _showFarms ? null : () {
                        setState(() {
                          _showFarms = true;
                          _selectedFarm = null; // Reset selected farm
                          _loadData();
                        });
                      },
                      child: Text(
                        "Farms",
                        style: TextStyle(
                          color: _showFarms ? Colors.white : Colors.white70,
                          fontWeight: _showFarms ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    Text("|", style: TextStyle(color: Colors.white70)),
                    TextButton(
                      onPressed: !_showFarms ? null : () {
                        setState(() {
                          _showFarms = false;
                          _loadData();
                        });
                      },
                      child: Text(
                        "Trees",
                        style: TextStyle(
                          color: !_showFarms ? Colors.white : Colors.white70,
                          fontWeight: !_showFarms ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : GoogleMap(
                  mapType: MapType.satellite,
                  initialCameraPosition: _initialCameraPosition,
                  markers: _markers,
                  onMapCreated: (GoogleMapController controller) {
                    _controller.complete(controller);
                  },
                  onTap: _isSelectingTreeLocation && !_showFarms
                      ? (LatLng location) {
                          print('Tree location selected: ${location.latitude}, ${location.longitude}');
                          setState(() {
                            _selectedTreeLocation = location;
                            _isSelectingTreeLocation = false; // Exit selection mode
                          });
                          // Show tree registration dialog with selected location
                          _showRegisterTreeDialog(location);
                        }
                      : null, // Disable tap handler when not in selection mode
                ),
          // Visual indicator when selecting tree location
          if (_isSelectingTreeLocation && !_showFarms)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                color: Colors.green.withOpacity(0.9),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.touch_app, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tap on the map to select tree location',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _isSelectingTreeLocation = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Location selection cancelled'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      tooltip: 'Cancel selection',
                ),
        ],
      ),
              ),
            ),
        ],
      ),
      // Floating Action Button - Show when viewing trees (with or without selected farm)
      floatingActionButton: !_showFarms
          ? FloatingActionButton(
              onPressed: _showRegisterTreeOptions,
              backgroundColor: Colors.green,
              child: const Icon(Icons.add, color: Colors.white),
              tooltip: 'Register New Tree',
            )
          : null,
    );
  }

  /// Show options to register a tree: Manual form or Map selection
  void _showRegisterTreeOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(AppTheme.spacingMD),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Register New Tree',
                style: AppTheme.h3,
              ),
              SizedBox(height: AppTheme.spacingMD),
              ListTile(
                leading: Icon(Icons.edit, color: Colors.blue),
                title: Text('Manual Registration'),
                subtitle: Text('Fill in tree details manually'),
                onTap: () {
                  Navigator.pop(context);
                  _showRegisterTreeForm();
                },
              ),
              SizedBox(height: AppTheme.spacingSM),
              ListTile(
                leading: Icon(Icons.location_on_outlined, color: Colors.red),
                title: Text('Pick Location on Map'),
                subtitle: Text('Tap on the map to select tree location'),
                onTap: () {
                  Navigator.pop(context);
                  _showSelectLocationOnMap();
                },
              ),
              SizedBox(height: AppTheme.spacingSM),
            ],
          ),
        );
      },
    );
  }

  /// Show instructions and enable map location selection
  void _showSelectLocationOnMap() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Select Tree Location'),
          content: Text('Tap anywhere on the map to mark where you want to plant the tree.\n\nYou can see all existing trees on the map while selecting.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _isSelectingTreeLocation = true;
                  _selectedTreeLocation = null;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('📍 Tap anywhere on the map to select tree location'),
                    duration: Duration(seconds: 4),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text('Start Selection'),
            ),
          ],
        );
      },
    );
  }

  /// Show tree registration form with pre-filled location
  void _showRegisterTreeDialog(LatLng location) {
    // Cancel selection mode
    setState(() {
      _isSelectingTreeLocation = false;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final TextEditingController treeCodeController = TextEditingController();
        final TextEditingController blockNameController = TextEditingController();
        final TextEditingController varietyController = TextEditingController();
        DateTime selectedDatePlanted = DateTime.now();
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ✅ Show which farm this tree will be registered to
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        border: Border.all(color: Colors.blue, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.apartment, color: Colors.blue),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Farm:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  _selectedFarm?.name ?? 'Unknown Farm',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppTheme.spacingMD),
                    Text(
                      'Register New Tree',
                      style: AppTheme.h3,
                    ),
                    SizedBox(height: AppTheme.spacingMD),
                    Text(
                      'Location: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
                      style: AppTheme.bodySmall.copyWith(color: Colors.grey),
                    ),
                    SizedBox(height: AppTheme.spacingMD),
                    TextField(
                      controller: treeCodeController,
                      decoration: InputDecoration(
                        labelText: 'Tree Code',
                        hintText: 'e.g., A_01, B_05',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.label),
                      ),
                    ),
                    SizedBox(height: AppTheme.spacingMD),
                    TextField(
                      controller: blockNameController,
                      decoration: InputDecoration(
                        labelText: 'Block Name',
                        hintText: 'e.g., Block A, North Section',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                    ),
                    SizedBox(height: AppTheme.spacingMD),
                    TextFormField(
                      controller: varietyController,
                      decoration: InputDecoration(
                        labelText: 'Variety',
                        hintText: 'e.g., BR 25, UF 18, ICS 40',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.nature),
                      ),
                    ),
                    SizedBox(height: AppTheme.spacingMD),
                    GestureDetector(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDatePlanted,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                          helpText: 'Select Date Planted',
                        );
                        if (picked != null && picked != selectedDatePlanted) {
                          setState(() {
                            selectedDatePlanted = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: Colors.green),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Date Planted',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    '${selectedDatePlanted.toLocal().toString().split(' ')[0]}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                            ),
                            child: Text('Cancel'),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    if (treeCodeController.text.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                        content: Text('Please enter tree code'),
                                      ));
                                      return;
                                    }

                                    setState(() => isSubmitting = true);

                                    try {
                                      // Register the tree via API
                                      await ApiService.registerTree(
                                        farmId: _selectedFarm?.id ?? 1,
                                        treeCode: treeCodeController.text,
                                        blockName: blockNameController.text,
                                        variety: varietyController.text.trim(),
                                        latitude: location.latitude,
                                        longitude: location.longitude,
                                        datePlanted: selectedDatePlanted.toIso8601String().split('T')[0],
                                      );

                                      Navigator.pop(context);

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          backgroundColor: Colors.green,
                                          content: Text(
                                              '✅ Tree registered successfully!'),
                                        ),
                                      );

                                      // Reload trees
                                      _loadData();
                                    } catch (e) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          backgroundColor: Colors.red,
                                          content: Text('Error: $e'),
                                        ),
                                      );
                                    }

                                    setState(() => isSubmitting = false);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: isSubmitting
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : Text('Register'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Show manual tree registration form
  void _showRegisterTreeForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _RegisterTreeForm(
        selectedFarm: _selectedFarm,
        onTreeRegistered: () {
                                      _loadData();
        },
      ),
    );
  }

  void _showFarmDetails(dynamic farm) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. HEADER
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            farm.name ?? "Unknown Farm",
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 16, color: Colors.grey),
                              SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  farm.location ?? "Location unknown",
                                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Divider(height: 20),

                // 2. FARM DETAILS GRID
                Row(
                  children: [
                    _buildInfo("Area", "${farm.area_hectares ?? 0}ha", Icons.landscape),
                    SizedBox(width: 8),
                    _buildInfo("Soil Type", farm.soil_type ?? "N/A", Icons.public),
                    SizedBox(width: 8),
                    _buildInfo("Coordinates", 
                      "${farm.latitude?.toStringAsFixed(4) ?? 'N/A'}, ${farm.longitude?.toStringAsFixed(4) ?? 'N/A'}", 
                      Icons.map),
                  ],
                ),
                SizedBox(height: 20),

                // 3. ACTION BUTTON - View Trees
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.forest),
                    label: Text("View Trees in This Farm"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      padding: EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      // Set the selected farm and switch to trees view
                      setState(() {
                        _selectedFarm = farm;
                        _showFarms = false;
                        _loadData();
                      });
                    },
                  ),
                ),
                SizedBox(height: AppTheme.spacingSM),

                // 4. CLOSE BUTTON
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Close"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTreeDetails(dynamic tree) {
    // A. Extract Basic Tree Info
    String code = tree['tree_code'] ?? "Unknown";
    String block = tree['block_name'] ?? "N/A";
    String variety = tree['variety'] ?? "N/A";
    String planted = tree['date_planted'] ?? "Unknown Date";

    // Get pod count from tree data
    int treeId = int.tryParse(tree['id'].toString()) ?? 0;
    String currentPods = tree['pod_count']?.toString() ?? "0";

    // B. Extract Latest Log Info (Disease, Image, Pods)
    var log = tree['latest_log'];

    String status = "Healthy";
    String lastInspection = "Never Scanned";
    String podCount = "0"; // ✅ Will be set from latest_log
    String? imageUrl;
    String treatment = "No recommendation available."; // ✅ Add this
    
    if (log != null) {
      status = log['status'] ?? log['disease_type'] ?? "Healthy";
      lastInspection = log['created_at'] ?? "Unknown";
      podCount = log['pod_count']?.toString() ?? "0";
      imageUrl = log['image_url'];
      treatment = log['treatment_recommendation'] ?? "No recommendation available.";
    }

    // C. Show Bottom Sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // HEADER
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Tree: $code",
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 5),
                          Text(
                            "Block: $block | Variety: $variety",
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Divider(height: 20),

                // STATUS CARD
                Container(
                  padding: EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: status.toLowerCase().contains('healthy') 
                        ? Colors.green[50] 
                        : Colors.orange[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: status.toLowerCase().contains('healthy') 
                          ? Colors.green 
                          : Colors.orange,
                      width: 2,
                    ),
                  ),
                  child: Row(
                  children: [
                      Icon(
                        status.toLowerCase().contains('healthy') 
                            ? Icons.check_circle 
                            : Icons.warning,
                        color: status.toLowerCase().contains('healthy') 
                            ? Colors.green 
                            : Colors.orange,
                        size: 30,
                      ),
                      SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Status: $status",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: status.toLowerCase().contains('healthy') 
                                    ? Colors.green[700] 
                                    : Colors.orange[700],
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              "Last Inspection: $lastInspection",
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // IMAGE (if available)
                if (imageUrl != null && imageUrl!.isNotEmpty) ...[
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                ],

                // DETAILS GRID
                Row(
                  children: [
                    _buildInfo("Pods", podCount, Icons.eco),
                    _buildInfo("Planted", planted.split(' ')[0], Icons.calendar_today),
                  ],
                ),
                SizedBox(height: 20),

                // TREATMENT RECOMMENDATION
                if (treatment.isNotEmpty && treatment != "No recommendation available.") ...[
                  Container(
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue, width: 1),
                    ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                            Icon(Icons.medical_services, color: Colors.blue),
                            SizedBox(width: 10),
                            Text(
                                  "Treatment Recommendation",
                              style: TextStyle(
                                fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                        SizedBox(height: 10),
                          Text(
                            treatment,
                          style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 20),
                ],

                // ACTION BUTTONS
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.camera_alt),
                        label: Text("Scan Now"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          padding: EdgeInsets.symmetric(vertical: 15),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DashboardScreen(),
                              settings: RouteSettings(arguments: treeId.toString()),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                      child: ElevatedButton.icon(
                            icon: Icon(Icons.edit),
                            label: Text("Update Pods"),
                        style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: EdgeInsets.symmetric(vertical: 15),
                            ),
                        onPressed: () {
                          Navigator.pop(context);
                              _showUpdatePodsDialog(context, treeId, currentPods);
                            },
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.agriculture),
                            label: Text("Harvest"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              padding: EdgeInsets.symmetric(vertical: 15),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _showHarvestForm(treeId);
                        },
                      ),
                    ),
                      ],
                    ),
                    SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("Close"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUpdatePodsDialog(BuildContext context, int treeId, String currentCount) {
    final _podController = TextEditingController(text: currentCount);
    bool _isUpdating = false;

    showDialog(
      context: context,
      barrierDismissible: false, // User must click Cancel or Save
      builder: (context) {
        return StatefulBuilder( // Needed to update state inside a Dialog
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.edit_note, color: Colors.blue),
                  SizedBox(width: 10),
                  Text("Update Yield"),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Enter total pods currently on Tree #$treeId"),
                  SizedBox(height: 15),
                  TextField(
                    controller: _podController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: "Pod Count",
                      border: OutlineInputBorder(),
                      suffixText: "pods"
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  onPressed: _isUpdating ? null : () async {
                    if (_podController.text.isEmpty) return;

                    setState(() => _isUpdating = true); // Show loading

                    try {
                      await ApiService.updatePodCount(treeId, int.parse(_podController.text));

                      Navigator.pop(context); // Close Dialog

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.green,
                          content: Text("Pod count updated successfully!"),
                        ),
                      );

                      // Reload trees to reflect the update
                      _loadData();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.red,
                          content: Text("Error: $e"),
                        ),
                      );
                    } finally {
                      if (mounted) {
                        setState(() => _isUpdating = false);
                      }
                    }
                  },
                  child: _isUpdating
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Helper widget
  Widget _buildInfo(String label, String val, IconData icon) {
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.brown[300]),
          SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey)),
          SizedBox(height: 2),
          Text(
            val,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showHarvestForm(int treeId) {
    print('DEBUG: _showHarvestForm called with treeId: $treeId');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HarvestEntryForm(
          treeId: treeId,
        ),
      ),
    );
  }
}

/// Separate StatefulWidget for tree registration form to properly manage state
class _RegisterTreeForm extends StatefulWidget {
  final dynamic selectedFarm;
  final VoidCallback onTreeRegistered;

  const _RegisterTreeForm({
    required this.selectedFarm,
    required this.onTreeRegistered,
  });

  @override
  State<_RegisterTreeForm> createState() => _RegisterTreeFormState();
}

class _RegisterTreeFormState extends State<_RegisterTreeForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController treeCodeController = TextEditingController();
  final TextEditingController blockNameController = TextEditingController();
  final TextEditingController varietyController = TextEditingController();
  final TextEditingController latitudeController = TextEditingController();
  final TextEditingController longitudeController = TextEditingController();
  
  DateTime selectedDatePlanted = DateTime.now();
  bool isSubmitting = false;
  bool isGettingLocation = false;
  dynamic selectedFarmForForm;
  List<dynamic> farmsList = [];
  bool isLoadingFarms = false;

  @override
  void initState() {
    super.initState();
    selectedFarmForForm = widget.selectedFarm;
    _loadFarms();
  }

  @override
  void dispose() {
    treeCodeController.dispose();
    blockNameController.dispose();
    varietyController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
    super.dispose();
  }

  Future<void> _loadFarms() async {
    if (farmsList.isEmpty && !isLoadingFarms) {
      setState(() {
        isLoadingFarms = true;
      });
      try {
        final farms = await ApiService.getFarms();
        setState(() {
          farmsList = farms;
          // If no farm selected, use first farm as default
          if (selectedFarmForForm == null && farms.isNotEmpty) {
            selectedFarmForForm = farms.first;
          }
          isLoadingFarms = false;
        });
      } catch (e) {
        setState(() {
          isLoadingFarms = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Farm Selection
              if (widget.selectedFarm == null) ...[
                // Show dropdown if no farm is pre-selected
                isLoadingFarms
                    ? Padding(
                        padding: EdgeInsets.all(AppTheme.spacingMD),
                        child: CircularProgressIndicator(),
                      )
                    : DropdownButtonFormField<dynamic>(
                        value: selectedFarmForForm,
                        decoration: InputDecoration(
                          labelText: 'Select Farm *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.agriculture),
                        ),
                        items: farmsList.map<DropdownMenuItem<dynamic>>((farm) {
                          return DropdownMenuItem<dynamic>(
                            value: farm,
                            child: Text(farm.name ?? 'Unknown Farm'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedFarmForForm = value;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select a farm';
                          }
                          return null;
                        },
                      ),
                SizedBox(height: AppTheme.spacingMD),
              ] else ...[
                // Show selected farm info if already selected
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    border: Border.all(color: Colors.blue, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.apartment, color: Colors.blue),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Farm:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              widget.selectedFarm?.name ?? 'Unknown Farm',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppTheme.spacingMD),
              ],
              Text(
                'Register New Tree - Manual',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: treeCodeController,
                decoration: InputDecoration(
                  labelText: 'Tree Code *',
                  hintText: 'e.g., A_01',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter tree code';
                  }
                  return null;
                },
              ),
              SizedBox(height: AppTheme.spacingMD),
              TextFormField(
                controller: blockNameController,
                decoration: InputDecoration(
                  labelText: 'Block Name',
                  hintText: 'e.g., Block A',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
              ),
              SizedBox(height: AppTheme.spacingMD),
              TextFormField(
                controller: varietyController,
                decoration: InputDecoration(
                  labelText: 'Variety',
                  hintText: 'e.g., BR 25, UF 18, ICS 40',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.nature),
                ),
              ),
              SizedBox(height: AppTheme.spacingMD),
              // GPS Location Section
              Container(
                padding: EdgeInsets.all(AppTheme.spacingMD),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.gps_fixed, color: Colors.blue),
                        SizedBox(width: AppTheme.spacingSM),
                        Text(
                          'Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppTheme.spacingSM),
                    ElevatedButton.icon(
                      onPressed: isGettingLocation ? null : () async {
                        setState(() {
                          isGettingLocation = true;
                        });
                        
                        try {
                          // Check permission
                          LocationPermission permission = await Geolocator.checkPermission();
                          if (permission == LocationPermission.denied) {
                            permission = await Geolocator.requestPermission();
                            if (permission == LocationPermission.denied) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Location permissions are denied'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              setState(() {
                                isGettingLocation = false;
                              });
                              return;
                            }
                          }
                          
                          if (permission == LocationPermission.deniedForever) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Location permissions are permanently denied. Please enable them in settings.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            setState(() {
                              isGettingLocation = false;
                            });
                            return;
                          }
                          
                          // Get current position
                          Position position = await Geolocator.getCurrentPosition(
                            desiredAccuracy: LocationAccuracy.high,
                          );
                          
                          // Update text fields
                          setState(() {
                            latitudeController.text = position.latitude.toStringAsFixed(6);
                            longitudeController.text = position.longitude.toStringAsFixed(6);
                            isGettingLocation = false;
                          });
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Location captured successfully!'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        } catch (e) {
                          setState(() {
                            isGettingLocation = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('GPS Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      icon: isGettingLocation
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(Icons.my_location, size: 20),
                      label: Text(isGettingLocation ? 'Getting Location...' : 'Get Current Location'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    SizedBox(height: AppTheme.spacingMD),
                    TextFormField(
                      controller: latitudeController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Latitude *',
                        hintText: '16.6038',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Latitude is required';
                        }
                        final lat = double.tryParse(value);
                        if (lat == null) {
                          return 'Invalid latitude';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: AppTheme.spacingMD),
                    TextFormField(
                      controller: longitudeController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Longitude *',
                        hintText: '121.1939',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Longitude is required';
                        }
                        final lng = double.tryParse(value);
                        if (lng == null) {
                          return 'Invalid longitude';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppTheme.spacingMD),
              GestureDetector(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
      context: context,
                    initialDate: selectedDatePlanted,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => selectedDatePlanted = picked);
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.green),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Date Planted',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          Text(
                            '${selectedDatePlanted.toLocal().toString().split(' ')[0]}',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                      ),
                      child: Text('Cancel'),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              // Validate form
                              if (!_formKey.currentState!.validate()) {
                                return;
                              }

                              // Validate coordinates are not 0,0
                              final lat = double.tryParse(latitudeController.text.trim());
                              final lng = double.tryParse(longitudeController.text.trim());
                              
                              if (lat == 0.0 && lng == 0.0) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text('Coordinates cannot be 0,0. Please provide a valid location.'),
                                  backgroundColor: Colors.orange,
                                ));
                                return;
                              }

                              // Use selectedFarmForForm which can be from dropdown or widget.selectedFarm
                              final farmToUse = selectedFarmForForm ?? widget.selectedFarm;
                              
                              if (farmToUse == null) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text('Please select a farm first'),
                                  backgroundColor: Colors.orange,
                                ));
                                return;
                              }

                              setState(() => isSubmitting = true);

                              try {
                                final farmId = farmToUse.id is int 
                                    ? farmToUse.id 
                                    : int.tryParse(farmToUse.id.toString());
                                
                                if (farmId == null) {
                                  throw Exception('Invalid farm ID');
                                }

                                await ApiService.registerTree(
                                  farmId: farmId,
                                  treeCode: treeCodeController.text.trim(),
                                  blockName: blockNameController.text.trim(),
                                  variety: varietyController.text.trim(),
                                  latitude: lat!,
                                  longitude: lng!,
                                  datePlanted: selectedDatePlanted.toIso8601String().split('T')[0],
                                );

                                Navigator.pop(context);

                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.green,
                                    content: Text(
                                        'Tree registered successfully!'),
                                  ),
                                );

                                // Callback to reload trees
                                widget.onTreeRegistered();
                              } catch (e) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.red,
                                    content: Text('Error: $e'),
                                  ),
                                );
                              }

                              setState(() => isSubmitting = false);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: isSubmitting
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text('Register Tree'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
