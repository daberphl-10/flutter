class DetectionResponse {
  final String message;
  final String detectedDisease;
  final double confidence;
  final String? imagePath;
  final String treatment; // ✅ Add this

  DetectionResponse({
    required this.message,
    required this.detectedDisease,
    required this.confidence,
    this.imagePath,
    required this.treatment, // ✅ Add this
  });

  factory DetectionResponse.fromJson(Map<String, dynamic> json) {
    // 1. SETUP DEFAULT VARIABLES
    String disease = "Unknown";
    double confidence = 0.0;
    String? imgPath;
    String treatment = "No recommendation available."; // ✅ Add this

    // 2. EXTRACT DATA (Safely)
    // Check if we have the 'data' object (from Tree Log response)
    if (json['data'] != null) {
      var data = json['data'];
      
      // Get Image Path
      imgPath = data['image_path'];

      // Get Confidence (Sent from Laravel as 'ai_confidence')
      if (json['ai_confidence'] != null) {
        confidence = (json['ai_confidence'] as num).toDouble();
      } 
      // Fallback: If backend didn't send confidence, assume high if we have a result
      else {
        // If detected_disease is stored in 'data' and not null, assume 1.0
        // If it is null, we handle it below
        confidence = data['disease_type'] != null ? 1.0 : 0.0;
      }

      // ---------------------------------------------------------
      // 🚀 LOGIC GATES (USER RULES)
      // ---------------------------------------------------------

      // RULE 1: Low Confidence = "Not a Cacao"
      if (confidence < 0.60) {
        disease = "Not a Cacao Pod / Unclear";
      } 
      // RULE 2: Null Disease Type = "Healthy"
      else if (data['disease_type'] == null) {
        disease = "Healthy";
      } 
      // RULE 3: Normal Disease Detection
      else {
        disease = data['disease_type'].toString();
      }

    } 
    // 3. FALLBACK (For old AI response format, just in case)
    else if (json['result'] != null) {
       // ... (Keep your old fallback logic here if you want, or remove it)
    }

    // ✅ Extract treatment recommendation from backend
    if (json['treatment'] != null) {
      treatment = json['treatment'].toString();
    }

    return DetectionResponse(
      message: json['message']?.toString() ?? "Processed",
      detectedDisease: disease,
      confidence: confidence,
      imagePath: imgPath,
      treatment: treatment, // ✅ Add this
    );
  }
}