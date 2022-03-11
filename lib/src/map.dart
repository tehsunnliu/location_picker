import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:location_picker/src/providers/location_provider.dart';
import 'package:location_picker/src/utils/loading_builder.dart';
import 'package:location_picker/src/utils/log.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'model/location_result.dart';
import 'utils/location_utils.dart';

class MapPicker extends StatefulWidget {
  const MapPicker(
    this.apiKey, {
    Key? key,
    this.initialCenter,
    this.initialZoom,
    this.requiredGPS,
    this.myLocationButtonEnabled,
    this.layersButtonEnabled,
    this.automaticallyAnimateToCurrentLocation,
    this.mapStylePath,
    this.appBarColor,
    this.layersIconColor,
    this.layersButtonColor,
    this.myLocationIconColor,
    this.myLocationButtonColor,
    this.selectButtonText,
    this.selectButtonColor,
    this.selectButtonFontColor,
    this.searchBarBoxDecoration,
    this.hintText,
    this.resultCardConfirmIcon,
    this.resultCardAlignment,
    this.resultCardDecoration,
    this.resultCardPadding,
    this.language,
    this.desiredAccuracy,
    this.locationChangedCallback,
  }) : super(key: key);

  final Function? locationChangedCallback;

  final String apiKey;

  final LatLng? initialCenter;
  final double? initialZoom;

  final bool? requiredGPS;
  final bool? myLocationButtonEnabled;
  final bool? layersButtonEnabled;
  final bool? automaticallyAnimateToCurrentLocation;

  final String? mapStylePath;

  final Color? appBarColor;
  final Color? layersIconColor;
  final Color? layersButtonColor;
  final Color? myLocationIconColor;
  final Color? myLocationButtonColor;
  final Color? selectButtonColor;
  final Color? selectButtonFontColor;
  final BoxDecoration? searchBarBoxDecoration;
  final String? hintText;
  final String? selectButtonText;
  final Widget? resultCardConfirmIcon;
  final Alignment? resultCardAlignment;
  final Decoration? resultCardDecoration;
  final EdgeInsets? resultCardPadding;

  final String? language;

  final LocationAccuracy? desiredAccuracy;

  @override
  MapPickerState createState() => MapPickerState();
}

class MapPickerState extends State<MapPicker> {
  Completer<GoogleMapController> mapController = Completer();

  MapType _currentMapType = MapType.normal;

  String? _mapStyle;

  LatLng? _lastMapPosition;

  Position? _currentPosition;

  String? _address;

  String? _placeId;

  void _onToggleMapTypePressed() {
    final MapType nextType =
        MapType.values[(_currentMapType.index + 1) % MapType.values.length];

    setState(() => _currentMapType = nextType);
  }

  Future<bool> _determinePosition() async {
    bool serviceEnabled, permissionGranted = false;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      d('Location services are disabled.');
      return permissionGranted;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        d('Location permissions are denied');
        return permissionGranted;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      d('Location permissions are permanently denied, we cannot request permissions.');
      return permissionGranted;
    }

    return true;
  }

  // this also checks for location permission.
  Future<void> _initCurrentLocation() async {
    Position? currentPosition;
    bool permissionGranted = await _determinePosition();

    try {
      if (permissionGranted) {
        currentPosition = await Geolocator.getCurrentPosition(
            desiredAccuracy: widget.desiredAccuracy!);
        d("position = $currentPosition");
        if (mounted) {
          setState(() => _currentPosition = currentPosition);
        }
      } else {
        currentPosition = null;
        d("User denied to grant permission to access location");
      }
    } catch (e) {
      currentPosition = null;
      d("_initCurrentLocation#e = $e");
    }

    if (!mounted) return;

    setState(() => _currentPosition = currentPosition);

    if (currentPosition != null) {
      widget.locationChangedCallback!(
          LatLng(currentPosition.latitude, currentPosition.longitude));
      moveToCurrentLocation(
          LatLng(currentPosition.latitude, currentPosition.longitude));
    }
  }

  Future moveToCurrentLocation(LatLng currentLocation) async {
    d('MapPickerState.moveToCurrentLocation "currentLocation = [$currentLocation]"');
    final controller = await mapController.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: currentLocation, zoom: widget.initialZoom!),
    ));
  }

  @override
  void initState() {
    super.initState();
    if (widget.automaticallyAnimateToCurrentLocation! && !widget.requiredGPS!) {
      _initCurrentLocation();
    }

    if (widget.mapStylePath != null) {
      rootBundle.loadString(widget.mapStylePath!).then((string) {
        _mapStyle = string;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.requiredGPS!) {
      _checkGeolocationPermission();
      if (_currentPosition == null) _initCurrentLocation();
    }

    if (_currentPosition != null && dialogOpen != null) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    return Scaffold(
      body: Builder(
        builder: (context) {
          if (_currentPosition == null &&
              widget.automaticallyAnimateToCurrentLocation! &&
              widget.requiredGPS!) {
            return const Center(child: CircularProgressIndicator());
          }

          return buildMap();
        },
      ),
    );
  }

  Widget buildMap() {
    return Center(
      child: Stack(
        children: <Widget>[
          GoogleMap(
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            initialCameraPosition: CameraPosition(
              target: widget.initialCenter!,
              zoom: widget.initialZoom!,
            ),
            onMapCreated: (GoogleMapController controller) {
              mapController.complete(controller);
              //Implementation of mapStyle
              if (widget.mapStylePath != null) {
                controller.setMapStyle(_mapStyle);
              }

              _lastMapPosition = widget.initialCenter;
              LocationProvider.of(context, listen: false)
                  .setLastIdleLocation(_lastMapPosition);
            },
            onCameraMove: (CameraPosition position) {
              _lastMapPosition = position.target;
            },
            onCameraIdle: () async {
              debugPrint("onCameraIdle#_lastMapPosition = $_lastMapPosition");
              LocationProvider.of(context, listen: false)
                  .setLastIdleLocation(_lastMapPosition);
            },
            onCameraMoveStarted: () {
              debugPrint(
                  "onCameraMoveStarted#_lastMapPosition = $_lastMapPosition");
            },
//            onTap: (latLng) {
//              clearOverlay();
//            },
            mapType: _currentMapType,
            myLocationEnabled: true,
          ),
          _MapFabs(
            myLocationButtonEnabled: widget.myLocationButtonEnabled,
            layersButtonEnabled: widget.layersButtonEnabled,
            onToggleMapTypePressed: _onToggleMapTypePressed,
            onMyLocationPressed: _initCurrentLocation,
            layersIconColor: widget.layersIconColor,
            layersButtonColor: widget.layersButtonColor,
            myLocationIconColor: widget.myLocationIconColor,
            myLocationButtonColor: widget.myLocationButtonColor,
          ),
          pin(),
          locationCard(),
        ],
      ),
    );
  }

  Widget locationCard() {
    return Align(
      alignment: widget.resultCardAlignment ?? Alignment.bottomCenter,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).canvasColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              blurRadius: 2.0,
              spreadRadius: 0.0,
              offset: Offset(2.0, 2.0), // shadow direction: bottom right
            )
          ],
        ),
        // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child:
            Consumer<LocationProvider>(builder: (context, locationProvider, _) {
          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Wrap(
              children: [
                Column(
                  children: [
                    FutureLoadingBuilder<dynamic>(
                      future: getAddress(locationProvider.lastIdleLocation),
                      mutable: true,
                      loadingIndicator: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const <Widget>[
                          CircularProgressIndicator(),
                        ],
                      ),
                      builder: (context, data) {
                        if (data == null) {
                          return Text(
                            AppLocalizations.of(context).findingPlace,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: const TextStyle(
                                overflow: TextOverflow.ellipsis),
                          );
                        }
                        String message;
                        bool _hasError = false;
                        if (data['results'].isEmpty) {
                          message = data['error_message'];
                          _hasError = true;
                        } else {
                          _address = data['results'][0]["formatted_address"];
                          _placeId = data['results'][0]["place_id"];
                          message = _address ??
                              AppLocalizations.of(context).noResultFound;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Text(
                            message,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: TextStyle(
                                overflow: TextOverflow.ellipsis,
                                color: _hasError ? Colors.red : null),
                          ),
                        );
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            elevation: 1,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                            primary: widget.selectButtonColor ??
                                Theme.of(context)
                                    .buttonTheme
                                    .colorScheme!
                                    .primary,
                          ),
                          child: Text(
                            widget.selectButtonText ?? "USE THIS LOCATION",
                            style: TextStyle(
                              fontSize: 16,
                              color: widget.selectButtonFontColor ??
                                  Theme.of(context)
                                      .textTheme
                                      .button
                                      ?.foreground
                                      ?.color,
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop({
                              'location': LocationResult(
                                latLng: locationProvider.lastIdleLocation,
                                address: _address,
                                placeId: _placeId,
                              )
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                )
              ],
            ),
          );
        }),
      ),
    );
  }

  /// Returns place_id and formatted_address or throws an error
  Future<dynamic> getAddress(LatLng? location) async {
    if (location == null) {
      return null;
    }

    final endPoint =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${location.latitude},${location.longitude}'
        '&key=${widget.apiKey}&language=${widget.language}';

    final response = await http.get(Uri.parse(endPoint),
        headers: await LocationUtils.getAppHeaders());

    return jsonDecode(response.body);
  }

  Widget pin() {
    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.place, size: 56),
            Container(
              decoration: const ShapeDecoration(
                shadows: [
                  BoxShadow(
                    blurRadius: 4,
                    color: Colors.black38,
                  ),
                ],
                shape: CircleBorder(
                  side: BorderSide(
                    width: 4,
                    color: Colors.transparent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 56),
          ],
        ),
      ),
    );
  }

  Future<bool?>? dialogOpen;

  Future _checkGeolocationPermission() async {
    final geolocationStatus = await Geolocator.checkPermission();
    d("geolocationStatus = $geolocationStatus");

    if (geolocationStatus == LocationPermission.denied && dialogOpen == null) {
      dialogOpen = _showDeniedDialog();
    } else if (geolocationStatus == LocationPermission.deniedForever &&
        dialogOpen == null) {
      dialogOpen = _showDeniedForeverDialog();
    } else if (geolocationStatus == LocationPermission.whileInUse ||
        geolocationStatus == LocationPermission.always) {
      d('GeolocationStatus.granted');

      if (dialogOpen != null) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = null;
      }
    }
  }

  Future<bool?> _showDeniedDialog() {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return WillPopScope(
          onWillPop: () async {
            Navigator.of(context, rootNavigator: true).pop();
            Navigator.of(context, rootNavigator: true).pop();
            return true;
          },
          child: AlertDialog(
            title: Text(AppLocalizations.of(context).accessToLocationDenied),
            content: Text(
                AppLocalizations.of(context).allowAccessToTheLocationServices),
            actions: <Widget>[
              TextButton(
                child: Text(AppLocalizations.of(context).ok),
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  _initCurrentLocation();
                  dialogOpen = null;
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool?> _showDeniedForeverDialog() {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return WillPopScope(
          onWillPop: () async {
            Navigator.of(context, rootNavigator: true).pop();
            Navigator.of(context, rootNavigator: true).pop();
            return true;
          },
          child: AlertDialog(
            title: Text(
                AppLocalizations.of(context).accessToLocationPermanentlyDeined),
            content: Text(AppLocalizations.of(context)
                .allowAccessToTheLocationServicesFromSettings),
            actions: <Widget>[
              TextButton(
                child: Text(AppLocalizations.of(context).ok),
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  Geolocator.openAppSettings();
                  dialogOpen = null;
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MapFabs extends StatelessWidget {
  const _MapFabs({
    Key? key,
    required this.myLocationButtonEnabled,
    required this.layersButtonEnabled,
    required this.onToggleMapTypePressed,
    required this.onMyLocationPressed,
    this.layersIconColor,
    this.layersButtonColor,
    this.myLocationIconColor,
    this.myLocationButtonColor,
  }) : super(key: key);

  final bool? myLocationButtonEnabled;
  final bool? layersButtonEnabled;

  final VoidCallback onToggleMapTypePressed;
  final VoidCallback onMyLocationPressed;

  final Color? layersIconColor;
  final Color? layersButtonColor;

  final Color? myLocationIconColor;
  final Color? myLocationButtonColor;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        alignment: Alignment.topRight,
        margin: const EdgeInsets.only(right: 8),
        child: Column(
          children: <Widget>[
            if (layersButtonEnabled!)
              FloatingActionButton(
                elevation: 4,
                onPressed: onToggleMapTypePressed,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                mini: true,
                child: Icon(
                  Icons.layers,
                  color: layersIconColor,
                ),
                heroTag: "layers",
                backgroundColor: layersButtonColor,
              ),
            if (myLocationButtonEnabled!)
              FloatingActionButton(
                elevation: 4,
                onPressed: onMyLocationPressed,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                mini: true,
                child: Icon(
                  Icons.my_location,
                  color: myLocationIconColor,
                ),
                heroTag: "myLocation",
                backgroundColor: myLocationButtonColor,
              ),
          ],
        ),
      ),
    );
  }
}
