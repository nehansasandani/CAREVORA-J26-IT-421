// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

void launchTelUrl(String phoneNumber) {
  try {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final anchor = html.AnchorElement(href: 'tel:$cleanPhone')
      ..target = '_self';
    anchor.click();
  } catch (e) {
    // Graceful fallback
  }
}

void launchWhatsAppUrl(String phoneNumber, [String? message]) {
  try {
    var cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanPhone.startsWith('0') && cleanPhone.length == 10) {
      cleanPhone = '94${cleanPhone.substring(1)}';
    }
    final textParam = message != null && message.isNotEmpty ? '?text=${Uri.encodeComponent(message)}' : '';
    final anchor = html.AnchorElement(href: 'https://wa.me/$cleanPhone$textParam')
      ..target = '_blank';
    anchor.click();
  } catch (e) {
    // Graceful fallback
  }
}
