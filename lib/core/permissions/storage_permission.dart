import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../l10n/app_localizations.dart';

/// Ensures the app may read/write user-visible files (backup destination
/// folders, restore archives, data exports) on Android.
///
/// Android 11+ (API 30) enforces scoped storage: raw file I/O in shared
/// folders (Download, …) throws "permission denied" unless the app holds
/// "All files access" (`MANAGE_EXTERNAL_STORAGE`), which can only be granted
/// in system Settings. On API 29 and below the classic storage permission
/// is requested normally. Other platforms need nothing.
///
/// Returns true when file access is available; false when the user declines
/// (a clear message is shown — never a silent failure).
Future<bool> ensureStoragePermission(BuildContext context) async {
  if (!Platform.isAndroid) return true;

  Future<bool> granted(int sdk) async {
    if (sdk >= 30) {
      return Permission.manageExternalStorage.status.isGranted;
    }
    return Permission.storage.status.isGranted;
  }

  final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
  if (await granted(sdk)) return true;
  if (!context.mounted) return false;

  final l10n = AppLocalizations.of(context);
  final proceed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.storagePermissionTitle),
      content: Text(l10n.storagePermissionRationale),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.storagePermissionOpenSettings),
        ),
      ],
    ),
  );
  if (proceed != true || !context.mounted) return false;

  if (sdk >= 30) {
    // "All files access" has no runtime dialog. request() opens the exact
    // system page for it ("Special app access > All files access"), unlike
    // openAppSettings() which lands on the generic app-info page where the
    // toggle does not exist (2026-10-05: Ali's screenshots proved the user
    // could not find the permission there).
    await Permission.manageExternalStorage.request();
  } else {
    await Permission.storage.request();
  }
  if (await granted(sdk)) return true;

  if (context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.storagePermissionDenied)));
  }
  return false;
}
