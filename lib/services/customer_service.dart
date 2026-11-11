import 'package:restaurante_movil/constants/api_constants.dart';
import 'package:restaurante_movil/models/address_model.dart';
import 'package:restaurante_movil/services/http_client.dart';

class CustomerService {
  static Future<List<AddressModel>> getAddresses() async {
    final json = await HttpClient.get(ApiConstants.addresses, auth: true);
    final list = json['data'] as List? ?? [];
    return list
        .map((e) => AddressModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<AddressModel> createAddress(AddressModel address) async {
    final json = await HttpClient.post(
      ApiConstants.addresses,
      body: address.toJson(),
      auth: true,
    );
    return AddressModel.fromJson(json['data'] as Map<String, dynamic>);
  }

  static Future<AddressModel> updateAddress(
    int id,
    AddressModel address,
  ) async {
    final json = await HttpClient.put(
      ApiConstants.addressById(id),
      body: address.toJson(),
      auth: true,
    );
    return AddressModel.fromJson(json['data'] as Map<String, dynamic>);
  }

  static Future<void> deleteAddress(int id) async {
    await HttpClient.delete(ApiConstants.addressById(id), auth: true);
  }
}

