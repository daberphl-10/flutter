import 'package:flutter/material.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final data = await ApiService.getDashboardStats();
      setState(() {
        _stats = data;
        _isLoading = false;
      });
    } catch (e) {
      print(e);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Farm Overview"), 
        backgroundColor: Colors.brown[800],
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _loadStats)
        ],
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator())
        : _stats == null 
          ? Center(child: Text("No data available"))
          : SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Inventory Summary", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 15),
                  
                  // 1. THE THREE BIG CARDS
                  Row(
                    children: [
                      _buildStatCard("Trees", _stats!['summary']['total_trees'].toString(), Icons.park, Colors.green),
                      _buildStatCard("Pods", _stats!['summary']['total_pods'].toString(), Icons.eco, Colors.orange),
                    ],
                  ),
                  SizedBox(height: 10),
                  _buildStatCard("Est. Yield (kg)", _stats!['summary']['estimated_yield_kg'].toString(), Icons.scale, Colors.blue, fullWidth: true),

                  SizedBox(height: 30),
                  
                  // 2. HEALTH STATUS BREAKDOWN
                  Text("Health Status", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white, 
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 5)]
                    ),
                    child: Column(
                      children: (_stats!['health_breakdown'] as List).map<Widget>((item) {
                        String status = item['status'];
                        int count = item['total'];
                        Color color = status == 'Healthy' ? Colors.green : Colors.red;
                        
                        return ListTile(
                          leading: CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Icon(Icons.circle, color: color, size: 15)),
                          title: Text(status, style: TextStyle(fontWeight: FontWeight.bold)),
                          trailing: Text("$count trees", style: TextStyle(fontSize: 16)),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, {bool fullWidth = false}) {
    return Expanded(
      flex: fullWidth ? 0 : 1,
      child: Container(
        width: fullWidth ? double.infinity : null,
        margin: EdgeInsets.all(5),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3))
        ),
        child: Column(
          children: [
            Icon(icon, size: 30, color: color),
            SizedBox(height: 10),
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }
}