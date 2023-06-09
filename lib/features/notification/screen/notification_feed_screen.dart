import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:routemaster/routemaster.dart';
import 'package:sensei/core/common/error_text.dart';
import 'package:sensei/core/common/loader.dart';
import 'package:sensei/features/notification/controller/notification_controller.dart';

class NotificationFeedScreen extends ConsumerWidget {
  const NotificationFeedScreen({super.key});

  void navigateFromNotification(
      BuildContext context, String payload, String payloadData) {
    switch (payload) {
      case 'follow':
        Routemaster.of(context).push('/u/$payloadData');
        break;
      case 'postId':
        Routemaster.of(context).push('/post/$payloadData/comments');
        break;
      case 'commentId':
        Routemaster.of(context).push('/post/$payloadData/comments');
        break;
      default:
        Routemaster.of(context).push('/');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(userNotificationsProvider).when(
          data: (data) {
            return ListView.builder(
              itemCount: data.length,
              itemBuilder: (context, index) {
                return ListTile(
                  onTap: () {
                    // get the notification to mark it as read
                    ref
                        .watch(getnotificationControllerProvider.notifier)
                        .setNotificationToRead(data[index].title);
                    // navigate to the the payload screen
                    final payload = data[index].payload.keys.first;
                    print('payload: $payload');
                    final payloadData = data[index].payload.values.first;
                    print('payloadData: $payloadData');
                    navigateFromNotification(context, payload, payloadData);
                  },
                  title: Text(
                    data[index].title,
                    style: TextStyle(
                      fontWeight: data[index].isRead
                          ? FontWeight.w100
                          : FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    data[index].body,
                    style: const TextStyle(fontWeight: FontWeight.w300),
                  ),
                  // horizontalTitleGap: 10,
                  minVerticalPadding: 12,
                  leading: CachedNetworkImage(
                    imageUrl: data[index].image,
                    fit: BoxFit.cover,
                    width: 60,
                    height: 60,
                    useOldImageOnUrlChange: true,
                    alignment: Alignment.topLeft,
                    filterQuality: FilterQuality.low,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error),
                    cacheManager: CacheManager(
                      Config('customCacheKey',
                          stalePeriod: const Duration(days: 30),
                          maxNrOfCacheObjects: 1000,
                          repo: JsonCacheInfoRepository(
                              databaseName: 'mypostscache')),
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Loader(),
          error: (error, stack) => ErrorText(error: error.toString()),
        );
  }
}
