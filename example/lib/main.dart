import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:location_picker/location_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  LocationResult? _pickedLocation;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location Picker',
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('location picker'),
        ),
        body: Builder(builder: (context) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ElevatedButton(
                  onPressed: () async {
                    LocationResult? result = await showLocationPicker(
                      context,
                      'AIzaSyBNXOQrlQfnXQgL7yoQQoRUDnUsU0z4frc',
                      initialCenter: const LatLng(31.1975844, 29.9598339),
                      myLocationButtonEnabled: true,
                      layersButtonEnabled: true,
                      desiredAccuracy: LocationAccuracy.best,
                      // automaticallyAnimateToCurrentLocation: true,
                      // mapStylePath: 'assets/mapStyle.json',
                      // requiredGPS: true,
                      // countries: ['AE', 'NG']
                      // resultCardAlignment: Alignment.bottomCenter,
                    );
                    debugPrint("result = $result");
                    setState(() => _pickedLocation = result);
                  },
                  child: const Text('Pick location'),
                ),
                Text(_pickedLocation.toString()),
              ],
            ),
          );
        }),
      ),
    );
  }
}
