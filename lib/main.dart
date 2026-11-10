import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'ui/app.dart';

void main() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'aiowebostv registration data',
    ], await rootBundle.loadString('licenses/aiowebostv.txt'));
  });
  runApp(const OpenRemoteApp());
}
