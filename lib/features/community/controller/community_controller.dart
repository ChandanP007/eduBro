import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sensei/core/constants/constants.dart';
import 'package:sensei/core/failure.dart';
import 'package:sensei/core/providers/storage_repository_provider.dart';
import 'package:sensei/core/utlis.dart';
import 'package:sensei/features/auth/controller/auth_controller.dart';
import 'package:sensei/features/community/repository/community_repository.dart';
import 'package:sensei/features/notification/repository/notification_repository.dart';
import 'package:sensei/models/community_model.dart';
import 'package:sensei/models/notification_model.dart';
import 'package:sensei/models/post_model.dart';
import 'package:routemaster/routemaster.dart';
import 'package:uuid/uuid.dart';

final userCommunitiesProvider = StreamProvider((ref) {
  final communityController = ref.watch(communityControllerProvider.notifier);
  return communityController.getUserCommunities();
});

final communityControllerProvider =
    StateNotifierProvider<CommunityController, bool>((ref) {
  final communityRepository = ref.watch(communityRepositoryProvider);
  final storageRepository = ref.watch(storageRepositoryProvider);
  final notificationRepository = ref.watch(notificationRepositoryProvider);
  return CommunityController(
    communityRepository: communityRepository,
    notificationRepository: notificationRepository,
    storageRepository: storageRepository,
    ref: ref,
  );
});

final getCommunityByNameProvider = StreamProvider.family((ref, String name) {
  return ref
      .watch(communityControllerProvider.notifier)
      .getCommunityByName(name);
});

final searchCommunityProvider = StreamProvider.family((ref, String query) {
  return ref.watch(communityControllerProvider.notifier).searchCommunity(query);
});

final getCommunityPostsProvider = StreamProvider.family((ref, String name) {
  return ref.read(communityControllerProvider.notifier).getCommunityPosts(name);
});

class CommunityController extends StateNotifier<bool> {
  final CommunityRepository _communityRepository;
  final NotificationRepository _notificationRepository;
  final Ref _ref;
  final StorageRepository _storageRepository;
  CommunityController({
    required CommunityRepository communityRepository,
    required NotificationRepository notificationRepository,
    required Ref ref,
    required StorageRepository storageRepository,
  })  : _communityRepository = communityRepository,
        _notificationRepository = notificationRepository,
        _ref = ref,
        _storageRepository = storageRepository,
        super(false);

  void createCommunity(
      String name,
      String bio,
      File? communityProfileFile,
      Uint8List? communityProfileWebFile,
      List<String> tags,
      BuildContext context) async {
    state = true;
    final uid = _ref.read(userProvider)?.uid ?? '';

    Community community = Community(
      id: name,
      name: name,
      banner: Constants.bannerDefault,
      avatar: Constants.avatarDefault,
      members: [uid],
      mods: [uid],
      bio: bio,
      tags: tags,
      ownerId: uid,
      ownerName: _ref.read(userProvider)?.name ?? '',
    );

    if (communityProfileFile != null || communityProfileWebFile != null) {
      // communities/profile/memes
      final res = await _storageRepository.storeFile(
        path: 'communities/profile',
        id: community.name,
        file: communityProfileFile,
        webFile: communityProfileWebFile,
      );
      res.fold(
        (l) => showSnackBar(context, l.message),
        (r) => community = community.copyWith(avatar: r),
      );
    }

    final res = await _communityRepository.createCommunity(community);
    // add the commmunity id to the user

    final user = _ref.read(userProvider)!;
    await _communityRepository.addCommunityToUser(
      community.id,
      user.uid,
    );

    state = false;
    res.fold((l) => showSnackBar(context, l.message), (r) {
      showSnackBar(context, 'Community created successfully!');
      Routemaster.of(context).pop();
    });
  }

  void joinCommunity(Community community, BuildContext context) async {
    final user = _ref.read(userProvider)!;

    Either<Failure, void> res;
    if (community.members.contains(user.uid)) {
      res = await _communityRepository.leaveCommunity(community.name, user.uid);
    } else {
      res = await _communityRepository.joinCommunity(community.name, user.uid);
      _notificationRepository.createNotification(NotificationModel(
        id: const Uuid().v1(),
        isRead: false,
        type: 'follow',
        title: "${user.name} Follows your community ${community.name}",
        body:
            "${user.name} started following your  community ${community.name}. Have a look at their profile",
        payload: {
          'follow': user.uid,
        },
        senderId: user.uid,
        receiverId: [community.ownerId],
        image: user.profilePic,
        createdAt: DateTime.now(),
      ));
    }

    res.fold((l) => showSnackBar(context, l.message), (r) {
      if (community.members.contains(user.uid)) {
        showSnackBar(context, 'Community left successfully!');
      } else {
        showSnackBar(context, 'Community joined successfully!');
      }
    });
  }

  Stream<List<Community>> getUserCommunities() {
    final uid = _ref.read(userProvider)!.uid;
    return _communityRepository.getUserCommunities(uid);
  }

  Stream<Community> getCommunityByName(String name) {
    return _communityRepository.getCommunityByName(name);
  }

  void editCommunity({
    required File? profileFile,
    required File? bannerFile,
    required Uint8List? profileWebFile,
    required Uint8List? bannerWebFile,
    required BuildContext context,
    required Community community,
    required String bio,
    // List<String>? tags,
  }) async {
    state = true;
    if (profileFile != null || profileWebFile != null) {
      // communities/profile/memes
      final res = await _storageRepository.storeFile(
        path: 'communities/profile',
        id: community.name,
        file: profileFile,
        webFile: profileWebFile,
      );
      res.fold(
        (l) => showSnackBar(context, l.message),
        (r) => community = community.copyWith(avatar: r, bio: bio),
      );
    }

    if (bannerFile != null || bannerWebFile != null) {
      // communities/banner/memes
      final res = await _storageRepository.storeFile(
        path: 'communities/banner',
        id: community.name,
        file: bannerFile,
        webFile: bannerWebFile,
      );
      res.fold(
        (l) => showSnackBar(context, l.message),
        (r) => community = community.copyWith(banner: r, bio: bio),
      );
    }

    community = community.copyWith(bio: bio);

    final res = await _communityRepository.editCommunity(community);
    state = false;
    res.fold(
      (l) => showSnackBar(context, l.message),
      (r) => Routemaster.of(context).pop(),
    );
  }

  Stream<List<Community>> searchCommunity(String query) {
    return _communityRepository.searchCommunity(query);
  }

  void addMods(
      String communityName, List<String> uids, BuildContext context) async {
    final res = await _communityRepository.addMods(communityName, uids);
    res.fold(
      (l) => showSnackBar(context, l.message),
      (r) => Routemaster.of(context).pop(),
    );
  }

  Stream<List<Post>> getCommunityPosts(String name) {
    return _communityRepository.getCommunityPosts(name);
  }
}
