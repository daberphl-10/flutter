class DiseaseInfo {
  final String name;
  final String scientificName;
  final String description;
  final List<String> visualSigns;

  DiseaseInfo({
    required this.name,
    required this.scientificName,
    required this.description,
    required this.visualSigns,
  });

  static DiseaseInfo? getDiseaseInfo(String diseaseName) {
    final normalizedName = diseaseName.toLowerCase().trim();
    
    if (normalizedName.contains('black pod')) {
      return DiseaseInfo(
        name: 'Black Pod Rot',
        scientificName: 'Phytophthora palmivora',
        description: 'This is the most common and destructive fungal disease.',
        visualSigns: [
          'Color: Dark brown to chocolate-black spots.',
          'Shape: Irregular blotches that usually start at the tip (bottom) or the stem (top) of the pod.',
          'Texture: The boundary between the black spot and the healthy yellow/green skin is rapidly expanding but distinct.',
          'Progression: In advanced stages, the entire pod turns black and may look shriveled.',
        ],
      );
    } else if (normalizedName.contains('frosty pod')) {
      return DiseaseInfo(
        name: 'Frosty Pod Rot',
        scientificName: 'Moniliophthora roreri',
        description: 'This is deceptive because the pod often looks heavy and solid before showing external signs.',
        visualSigns: [
          'Texture (The "Frost"): The definitive feature is a thick, white to cream-colored powdery mat (fungal spores) covering part or all of the pod.',
          'Deformity: If infected young, the pod looks swollen or has a "hump" (tumor-like growth).',
          'Discoloration: Before the white powder appears, the pod may show irregular yellowing or brown spots that look different from the sharp Black Pod spots.',
        ],
      );
    } else if (normalizedName.contains('pod borer') || normalizedName.contains('borer')) {
      return DiseaseInfo(
        name: 'Cacao Pod Borer',
        scientificName: 'Carmenta foraseminis',
        description: 'This is an insect pest, not a fungus, so the visual signs are mechanical damage.',
        visualSigns: [
          'Frass (Sawdust): The #1 indicator. The AI detects small piles of brown sawdust-like poop (frass) stuck to the outside of the pod.',
          'Holes: Small, dark entry or exit holes (pinholes) on the surface.',
          'Uneven Ripening: The pod turns yellow/orange prematurely (unevenly) while other parts are still green.',
        ],
      );
    } else if (normalizedName.contains('witches broom') || normalizedName.contains('witches\' broom')) {
      return DiseaseInfo(
        name: 'Witches Broom',
        scientificName: 'Moniliophthora perniciosa',
        description: 'While this disease is famous for creating "brooms" on branches, it also deforms the pods.',
        visualSigns: [
          'Shape Distortion: The pod looks carrot-shaped, round, or strawberries-shaped instead of the normal oval cacao shape.',
          'Hardness: The pod looks thick and hard (indurated).',
          'Green Patches: Even when ripe, "islands" of green remain on the pod surface.',
        ],
      );
    } else if (normalizedName == 'healthy') {
      return DiseaseInfo(
        name: 'Healthy Pod',
        scientificName: 'No Disease',
        description: 'The pod shows no signs of disease or pest damage.',
        visualSigns: [
          'Uniformity: Smooth skin texture (or normal roughness for the variety).',
          'Color: Consistent coloring (Green, Yellow, Red, or Purple depending on variety) without dark lesions, white powder, or holes.',
        ],
      );
    }
    
    return null;
  }
}

