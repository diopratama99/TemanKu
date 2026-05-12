#!/bin/bash
# Test notification sender for TemanKu NotificationListener
# Run on emulator/device via: adb shell < test_notif.sh
#
# Since we can't easily fake package names via adb, we'll use
# a small Android test app approach instead.
# 
# RECOMMENDED: Use the companion test commands below with adb.

# === METHOD: Use `am broadcast` to trigger a test notification ===
# This won't work directly for NotificationListenerService because
# the service reads the actual package name from StatusBarNotification.
#
# BEST APPROACH: Use the Flutter debug button (see below)
