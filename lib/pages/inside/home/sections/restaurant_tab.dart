import 'package:auto_route/auto_route.dart';
import 'package:company/components/image.dart';
import 'package:company/core/authStorage.dart';
import 'package:company/core/di.dart';
import 'package:company/models/company.dart';
import 'package:company/models/image_context.dart';
import 'package:company/models/image_typeof.dart';
import 'package:company/service/external.dart';
import 'package:flutter/material.dart';

@RoutePage()
class RestaurantTabPage extends StatefulWidget {
  const RestaurantTabPage({super.key});

  @override
  State<RestaurantTabPage> createState() => _RestaurantTabPageState();
}

class _RestaurantTabPageState extends State<RestaurantTabPage>
    with TickerProviderStateMixin {

  Future<(Company company, String? imageUrl)> _load() async {
    
    final cid = await AuthStorage.getCompanyJson() ?? null;
    if (cid == null) {
      throw Exception("No company found in storage");
    }
    final url = await fetchImageUrlByPost(
      contextType: ImageContext.company,
      contextId: cid.id.toString(),
      type: ImageTypeof.banner,
    );
    return (cid, url);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(Company, String?)>(
      future: _load(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }

        final (company, imageUrl) = snap.data!;

        return Column(
          children: [
            Text(
              company.commercialName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ImageComponent(
              url: imageUrl ?? 'https://via.placeholder.com/800x400',
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              edit: true,
              uploadPath: '/upload',
              contextType: ImageContext.company,
              contextId: company.id.toString(),
              imageType: ImageTypeof.banner,
              extraFields: {
                'typeOf': ImageTypeof.banner.value,
              },
              onUploaded: (newUrl) async {
                setState(() {});
              },
            ),
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                title: Text('Razón Social: ${company.socialReason}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NIT: ${company.identificationNumber}'),
                    Text('Teléfono: ${company.mobilePhone}'),
                    Text('Email: ${company.email}'),
                  ],
                ),
                dense: true,
              ),
            ),
          ],
        );
      },
    );
  }
}
