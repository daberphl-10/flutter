import 'package:flutter/material.dart';
import '../models/notification.dart' as models;
import '../services/api_service.dart';

class NotificationProvider with ChangeNotifier {
  List<models.AppNotification> _notifications = [];
  bool _isLoading = false;
  int _unreadCount = 0;

  List<models.AppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _unreadCount;

  /// Load notifications from API
  Future<void> loadNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await ApiService.getNotifications();
      _notifications = data
          .map((json) => models.AppNotification.fromJson(json))
          .toList();
      
      _unreadCount = _notifications.where((n) => !n.read).length;
    } catch (e) {
      print('Error loading notifications: $e');
      _notifications = [];
      _unreadCount = 0;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mark a notification as read
  Future<void> markAsRead(int notificationId) async {
    try {
      await ApiService.markNotificationAsRead(notificationId);
      
      // Update local state
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(read: true);
        _unreadCount = _notifications.where((n) => !n.read).length;
        notifyListeners();
      }
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    final unreadNotifications = _notifications.where((n) => !n.read).toList();
    
    for (var notification in unreadNotifications) {
      await markAsRead(notification.id);
    }
  }

  /// Refresh notifications
  Future<void> refresh() async {
    await loadNotifications();
  }
}

