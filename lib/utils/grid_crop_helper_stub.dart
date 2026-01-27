/// Stub for grid-aspect crop. Used when dart.library.io is not available (e.g. web).
/// On mobile, [grid_crop_helper.dart] is used via conditional import.
Future<String?> cropToGridAspect(String imagePath, bool isVertical) async =>
    null;
