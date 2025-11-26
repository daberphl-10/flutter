import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../providers/refresh_provider.dart';
import 'dashboard_screen.dart';
import '../user/LoginPage.dart';
import '../screens/harvest_entry_form.dart';

class FarmMapScreen extends StatefulWidget {
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

  // Default Camera Position (Change this to your Farm's location)
  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(16.6038, 121.1939),
    zoom: 16, // Zoomed in closer for web
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    
    // Listen to refresh provider for real-time updates
    Future.microtask(() {
      context.read<RefreshProvider>().addListener(_onRefreshNotification);
    });
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

          return Marker(
            markerId: MarkerId("farm_$id"),
            position: LatLng(lat, lng),
            onTap: () => _showFarmDetails(farm),
            // Farm markers use blue color
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: InfoWindow(
              title: farm.name ?? "Unknown Farm",
              snippet: farm.location ?? "Location unknown",
            ),
          );
        }).toSet();

        _isLoading = false;
      });
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
            // If log exists, use the specific disease name (e.g., "Frosty Pod Rot")
            status = log['disease_type'] ?? log['status'] ?? "Unknown";
          }

          // 3. Color Logic
          double hue = BitmapDescriptor.hueGreen; // Default Green

          if (status != "Healthy") {
            if (status.toLowerCase().contains('black')) {
              hue = BitmapDescriptor.hueViolet; // Darker for Black Pod
            } else {
              hue = BitmapDescriptor.hueRed; // Red for other diseases
            }
          }

          return Marker(
            markerId: MarkerId(id),
            position: LatLng(lat, lng),
            onTap: () => _showTreeDetails(tree), // Pass the full object
            icon: BitmapDescriptor.defaultMarkerWithHue(hue),
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
            status = log['disease_type'] ?? log['status'] ?? "Unknown";
          }

          // 3. Color Logic
          double hue = BitmapDescriptor.hueGreen; // Default Green

          if (status != "Healthy") {
            if (status.toLowerCase().contains('black')) {
              hue = BitmapDescriptor.hueViolet; // Darker for Black Pod
            } else {
              hue = BitmapDescriptor.hueRed; // Red for other diseases
            }
          }

          return Marker(
            markerId: MarkerId(id),
            position: LatLng(lat, lng),
            onTap: () => _showTreeDetails(tree),
            icon: BitmapDescriptor.defaultMarkerWithHue(hue),
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
        backgroundColor: Colors.green[800],
        actions: [
          // Toggle between Farm and Tree view
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: EdgeInsets.symmetric(horizontal: 4),
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
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              _showLogoutDialog(context);
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : GoogleMap(
              mapType: MapType.satellite, // Satellite looks great on web
              initialCameraPosition: _kGooglePlex,
              markers: _markers,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
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
          padding: EdgeInsets.all(20),
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                ],
              ),
              Divider(height: 20),

              // 2. FARM DETAILS GRID
              Row(
                children: [
                  _buildInfo("Area", "${farm.area_hectares ?? 0}ha", Icons.landscape),
                  _buildInfo("Soil Type", farm.soil_type ?? "N/A", Icons.public),
                  _buildInfo("Coordinates", 
                    "${farm.latitude?.toStringAsFixed(4) ?? 'N/A'},\n${farm.longitude?.toStringAsFixed(4) ?? 'N/A'}", 
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
              SizedBox(height: 10),

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
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Logout'),
          content: Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await AuthService.logout();
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                  (route) => false,
                );
              },
              child: Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
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
    String podCount = "0";
    String? imageUrl;
    String treatment = "No recommendation available."; // ✅ Add this

    if (log != null) {
      // Get specific disease or general status
      status = log['disease_type'] ?? log['status'] ?? "Issue Reported";
      lastInspection = log['inspection_date'] ?? "N/A";
      podCount = log['pod_count']?.toString() ?? "0";

      // Construct Image URL (Replace 127.0.0.1 with your Laravel IP)
      if (log['image_path'] != null) {
        imageUrl = "http://127.0.0.1:8000/storage/${log['image_path']}";
      }
      
      // ✅ Get treatment from detection history
      treatment = _getTreatmentForDisease(status);
    }

    // C. Colors
    Color statusColor = status == "Healthy" ? Colors.green : Colors.red;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          height: 500, // Taller to fit image
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Tree: $code",
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Chip(
                    label: Text(status,
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    backgroundColor: statusColor,
                  )
                ],
              ),
              Divider(),

              // 2. TREE DETAILS GRID
              Row(
                children: [
                  _buildInfo("Block", block, Icons.grid_view),
                  _buildInfo("Variety", variety, Icons.eco),
                  _buildInfo("Planted", planted, Icons.calendar_today),
                ],
              ),
              SizedBox(height: 15),

              // 3. LATEST SCAN SECTION
              Text("Latest Scan Details",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700])),
              SizedBox(height: 10),

              Row(
                children: [
                  _buildInfo("Inspected", lastInspection, Icons.history),
                  _buildInfo("Pods", podCount, Icons.circle_outlined),
                ],
              ),
              SizedBox(height: 15),

              // 4. TREATMENT RECOMMENDATION (If diseased)
              if (status != "Healthy")
                Card(
                  elevation: 3,
                  color: Colors.orange[50],
                  child: Padding(
                    padding: EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.local_hospital, color: Colors.orange[800], size: 24),
                            SizedBox(width: 10),
                            Text(
                              "Treatment Recommendation",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[800],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Text(
                          treatment,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Card(
                  elevation: 3,
                  color: Colors.green[50],
                  child: Padding(
                    padding: EdgeInsets.all(15),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[800], size: 24),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Tree is healthy. Continue monitoring and maintenance.",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              SizedBox(height: 15),

              // 5. IMAGE PREVIEW (If exists)
              if (imageUrl != null)
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                        image: DecorationImage(
                            image: NetworkImage(imageUrl), fit: BoxFit.cover)),
                  ),
                )
              else
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: Colors.grey[100],
                    child: Center(
                        child: Text("No scan image available",
                            style: TextStyle(color: Colors.grey))),
                  ),
                ),

              SizedBox(height: 20),

              // 6. ACTION BUTTONS
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.update),
                      label: Text("Update Pods"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue),
                      onPressed: () {
                        Navigator.pop(context);
                        // Show the Update Pods dialog, passing tree id and current pod count
                        _showUpdatePodsDialog(
                          context,
                          treeId,
                          currentPods,
                        );
                      },
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.camera_alt),
                      label: Text("Scan Now"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700]),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              // Pass the Tree ID to the scanner via route arguments
                              builder: (context) => DashboardScreen(),
                              settings: RouteSettings(arguments: tree['id'].toString()),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context); // Close tree details dialog
                        final treeId = tree['id'];
                        final treeIdInt = treeId is int ? treeId : int.tryParse(treeId.toString()) ?? 0;
                        // Wait a moment for the dialog to close, then show harvest form
                        await Future.delayed(Duration(milliseconds: 100));
                        if (mounted) {
                          _showHarvestForm(treeIdInt);
                        }
                      },
                      icon: const Icon(Icons.agriculture),
                      label: const Text('Harvest'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    ),
                  ),
                ],
              )
            ],
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
                        SnackBar(backgroundColor: Colors.green, content: Text("Yield Updated Successfully!"))
                      );

                      // 🔄 REFRESH MAP DATA using provider
                      context.read<RefreshProvider>().triggerFarmMapRefresh();
                      _loadData();

                    } catch (e) {
                      setState(() => _isUpdating = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(backgroundColor: Colors.red, content: Text("Error: $e"))
                      );
                    }
                  },
                  child: _isUpdating
                    ? SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text("SAVE"),
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
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: Colors.brown[300]),
          SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey)),
          Text(val,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ✅ Helper method to get treatment recommendation based on disease
  String _getTreatmentForDisease(String disease) {
    final d = disease.toLowerCase();

    if (d.contains('black')) {
      return "Immediate Action: Remove and bury all infected pods immediately to stop spores from spreading. "
             "Cultural: Improve air circulation by pruning the tree canopy (reduce shade). Improve drainage in the farm. "
             "Chemical: Apply Copper-based fungicides (e.g., Bordeaux mixture) every 2-4 weeks during the rainy season.";
    }

    if (d.contains('frosty') || d.contains('roreri')) {
      return "CRITICAL: Do NOT transport infected pods. Remove pods before the white dust (spores) appears. "
             "Disposal: Cover infected pods with plastic on the ground or bury them deep to prevent spore release. "
             "Maintenance: Perform weekly phytosanitary pruning. Fungicides are generally ineffective once infection starts; prevention is key.";
    }

    if (d.contains('witch') || d.contains('broom') || d.contains('perniciosa')) {
      return "Pruning: Prune and burn all 'broom-like' vegetative shoots (infected branches) and infected pods. "
             "Timing: Prune during dry periods to reduce reinfection risks. "
             "Long-term: Consider grafting with resistant clones if the tree is severely affected.";
    }

    if (d.contains('borer') || d.contains('carmenta') || d.contains('pod borer')) {
      return "Mechanical: Implement 'Sleeving' (bagging) of young pods (2-3 months old) using plastic bags to prevent moths from laying eggs. "
             "Sanitation: Harvest ripe pods regularly. Remove and bury infested pods to kill larvae inside. "
             "Biological: Encourage natural enemies (ants/wasps) or use pheromone traps.";
    }

    if (d.contains('healthy')) {
      return "Maintenance: Continue regular monitoring. Ensure proper fertilization (NPK) to maintain tree immunity. "
             "Prevention: Keep the area around the tree base clean (weeding) and maintain 3x3 meter spacing.";
    }

    return "Consult an expert or local agricultural technician for specific treatment recommendations.";
  }

  void _showHarvestForm(int treeId) {
    print('🌾 DEBUG: _showHarvestForm called with treeId: $treeId');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        print('🌾 DEBUG: Building HarvestEntryForm');
        return HarvestEntryForm(
          treeId: treeId,
          onSave: (podCount, date) {
            print('🌾 FARM_MAP: Harvest logged callback received: $podCount pods');
            print('🌾 FARM_MAP: About to trigger refresh...');
            context.read<RefreshProvider>().triggerFarmMapRefresh();
            print('🌾 FARM_MAP: Refresh triggered!');
          },
        );
      },
    );
  }
}
