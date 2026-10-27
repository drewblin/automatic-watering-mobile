import 'mdns_controller_resolver.dart';

class ControllerAddressService {
  ControllerAddressService({
    required MdnsControllerResolver mdnsControllerResolver,
  }) : _mdnsControllerResolver = mdnsControllerResolver;

  final MdnsControllerResolver _mdnsControllerResolver;
  final _addresses = <String, String>{};

  Future<String?> resolve({
    required String hostname,
    bool refresh = false,
  }) async {
    final cached = _addresses[hostname];
    if (!refresh && cached != null) return cached;

    final address = await _mdnsControllerResolver.resolve(
      hostname: hostname,
      localHostname: hostname,
    );
    if (address == null || address.isEmpty) return null;
    _addresses[hostname] = address;
    return address;
  }
}
