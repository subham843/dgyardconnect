/// Shared address utilities — masking for technician until payment.
/// Returns area/road/mohalla only (no landmark, no building) when masking.
String maskAddressToArea(String? addr) {
  if (addr == null || addr.trim().isEmpty) return '—';
  final parts = addr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return addr;
  // Remove building, landmark, shop/flat/house — dealer-added details
  final filtered = parts.where((p) {
    final lower = p.toLowerCase();
    return !lower.startsWith('building:') &&
        !lower.startsWith('landmark:') &&
        !lower.startsWith('shop/flat/house no:');
  }).toList();
  if (filtered.isEmpty) return '—';
  // Return last 2–3 parts (area, road, mohalla) — locality from Google Maps
  final n = filtered.length <= 3 ? filtered.length : 3;
  return filtered.sublist(filtered.length - n).join(', ');
}
