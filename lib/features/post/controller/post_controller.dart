import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensei/core/enums/enums.dart';
import 'package:sensei/core/providers/storage_repository_provider.dart';
import 'package:sensei/core/utlis.dart';
import 'package:sensei/features/auth/controller/auth_controller.dart';
import 'package:sensei/features/notification/repository/notification_repository.dart';
import 'package:sensei/features/post/repository/post_repository.dart';
import 'package:sensei/features/user_profile/controller/user_profile_controller.dart';
import 'package:sensei/models/comment_model.dart';
import 'package:sensei/models/community_model.dart';
import 'package:sensei/models/notification_model.dart';
import 'package:sensei/models/post_model.dart';
import 'package:routemaster/routemaster.dart';
import 'package:uuid/uuid.dart';

final postControllerProvider =
    StateNotifierProvider<PostController, bool>((ref) {
  final postRepository = ref.watch(postRepositoryProvider);
  final storageRepository = ref.watch(storageRepositoryProvider);
  final notificationRepository = ref.watch(notificationRepositoryProvider);
  return PostController(
    postRepository: postRepository,
    notificationRepository: notificationRepository,
    storageRepository: storageRepository,
    ref: ref,
  );
});

final userPostsProvider =
    StreamProvider.family((ref, List<Community> communities) {
  final postController = ref.watch(postControllerProvider.notifier);
  return postController.fetchUserPosts(communities);
});

final explorePostsProvider = StreamProvider((ref) {
  final postController = ref.watch(postControllerProvider.notifier);
  return postController.fetchExplorePosts();
});

final getPostByIdProvider = StreamProvider.family((ref, String postId) {
  final postController = ref.watch(postControllerProvider.notifier);
  return postController.getPostById(postId);
});

final getPostCommentsProvider = StreamProvider.family((ref, String postId) {
  final postController = ref.watch(postControllerProvider.notifier);
  return postController.fetchPostComments(postId);
});

class PostController extends StateNotifier<bool> {
  final PostRepository _postRepository;
  final NotificationRepository _notificationRepository;
  final Ref _ref;
  final StorageRepository _storageRepository;
  PostController({
    required PostRepository postRepository,
    required NotificationRepository notificationRepository,
    required Ref ref,
    required StorageRepository storageRepository,
  })  : _postRepository = postRepository,
        _notificationRepository = notificationRepository,
        _ref = ref,
        _storageRepository = storageRepository,
        super(false);

  void shareTextPost({
    required BuildContext context,
    required String title,
    required Community selectedCommunity,
    required String description,
  }) async {
    state = true;
    String postId = const Uuid().v1();
    final user = _ref.read(userProvider)!;

    final Post post = Post(
      id: postId,
      title: title,
      communityName: selectedCommunity.name,
      communityProfilePic: selectedCommunity.avatar,
      upvotes: [],
      downvotes: [],
      commentCount: 0,
      username: user.name,
      uid: user.uid,
      type: 'text',
      link: '',
      createdAt: DateTime.now(),
      awards: [],
      description: description,
    );

    final res = await _postRepository.addPost(post);
    await _postRepository.addPostToUser(post, user.uid);
    _ref
        .read(userProfileControllerProvider.notifier)
        .updateUserKarma(UserKarma.textPost);
    state = false;
    res.fold((l) => showSnackBar(context, l.message), (r) {
      showSnackBar(context, 'Posted successfully!');
      Routemaster.of(context).pop();
    });
  }

  void shareLinkPost({
    required BuildContext context,
    required String title,
    required Community selectedCommunity,
    required String link,
  }) async {
    state = true;
    String postId = const Uuid().v1();
    final user = _ref.read(userProvider)!;

    final Post post = Post(
      id: postId,
      title: title,
      communityName: selectedCommunity.name,
      communityProfilePic: selectedCommunity.avatar,
      upvotes: [],
      downvotes: [],
      commentCount: 0,
      username: user.name,
      uid: user.uid,
      type: 'link',
      createdAt: DateTime.now(),
      awards: [],
      link: link,
    );

    final res = await _postRepository.addPost(post);
    await _postRepository.addPostToUser(post, user.uid);
    _ref
        .read(userProfileControllerProvider.notifier)
        .updateUserKarma(UserKarma.linkPost);
    state = false;
    res.fold((l) => showSnackBar(context, l.message), (r) {
      showSnackBar(context, 'Posted successfully!');
      Routemaster.of(context).pop();
    });
  }

  void shareImagePost({
    required BuildContext context,
    required String title,
    required Community selectedCommunity,
    required File? file,
    required Uint8List? webFile,
  }) async {
    state = true;
    String postId = const Uuid().v1();
    final user = _ref.read(userProvider)!;
    final imageRes = await _storageRepository.storeFile(
      path: 'posts/${selectedCommunity.name}',
      id: postId,
      file: file,
      webFile: webFile,
    );

    imageRes.fold((l) => showSnackBar(context, l.message), (r) async {
      final Post post = Post(
        id: postId,
        title: title,
        communityName: selectedCommunity.name,
        communityProfilePic: selectedCommunity.avatar,
        upvotes: [],
        downvotes: [],
        commentCount: 0,
        username: user.name,
        uid: user.uid,
        type: 'image',
        createdAt: DateTime.now(),
        awards: [],
        link: r,
      );

      final res = await _postRepository.addPost(post);
      // add the post id to user posts list
      await _postRepository.addPostToUser(post, user.uid);
      _ref
          .read(userProfileControllerProvider.notifier)
          .updateUserKarma(UserKarma.imagePost);
      state = false;
      res.fold((l) => showSnackBar(context, l.message), (r) {
        showSnackBar(context, 'Posted successfully!');
        Routemaster.of(context).pop();
      });
    });
  }

  Stream<List<Post>> fetchUserPosts(List<Community> communities) {
    if (communities.isNotEmpty) {
      return _postRepository.fetchUserPosts(communities);
    }
    return Stream.value([]);
  }

  Stream<List<Post>> fetchExplorePosts() {
    return _postRepository.fetchExplorePosts();
  }

  void deletePost(Post post, BuildContext context) async {
    final res = await _postRepository.deletePost(post);
    _ref
        .read(userProfileControllerProvider.notifier)
        .updateUserKarma(UserKarma.deletePost);

    res.fold((l) => null,
        (r) => showSnackBar(context, 'Post Deleted successfully!'));
  }

  void deleteComment(Comment comment, BuildContext context) async {
    final res = await _postRepository.deleteComment(comment);
    _ref
        .read(userProfileControllerProvider.notifier)
        .updateUserKarma(UserKarma.deleteComment);
    res.fold((l) => null,
        (r) => showSnackBar(context, 'Comment Deleted successfully!'));
  }

  void upvote(Post post) async {
    final sender = _ref.read(userProvider);
    _postRepository.upvote(post, sender!.uid);
    // only send notification if the post is not by the user
    if (post.uid != sender.uid) {
      // also check if the user has already upvoted the post or not to avoid sending multiple notifications
      if (!post.upvotes.contains(sender.uid)) {
        _notificationRepository.createNotification(NotificationModel(
          id: const Uuid().v1(),
          isRead: false,
          type: 'upvote_post',
          title: "${sender.name} Liked your post",
          body:
              "${sender.name} liked your post ${post.title} with  ${post.upvotes.length + 1} likes",
          payload: {
            'postId': post.id,
          },
          senderId: sender.uid,
          receiverId: [post.uid],
          image: post.link,
          createdAt: DateTime.now(),
        ));
      }
    }
  }

  void downvote(Post post) async {
    final uid = _ref.read(userProvider)!.uid;
    _postRepository.downvote(post, uid);
  }

  void upvoteComment(Comment comment) async {
    final sender = _ref.read(userProvider);
    _postRepository.upvoteComment(comment, _ref.read(userProvider)!.uid);
    if (comment.postId != sender!.uid) {
      // also check if the user has already upvoted the post or not to avoid sending multiple notifications
      if (!comment.upVotes.contains(sender.uid)) {
        _notificationRepository.createNotification(NotificationModel(
          id: const Uuid().v1(),
          isRead: false,
          type: 'like_comment',
          title: "${sender.name} liked  your comment",
          body:
              "${sender.name} liked your comment ${comment.text} with  ${comment.upVotes.length + 1} likes",
          payload: {
            'commentId': comment.postId,
          },
          senderId: sender.uid,
          receiverId: [comment.authorId],
          image: comment.profilePic,
          createdAt: DateTime.now(),
        ));
      }
    }
  }

  void downvoteComment(Comment comment) async {
    _postRepository.downvoteComment(comment, _ref.read(userProvider)!.uid);
  }

  Stream<Post> getPostById(String postId) {
    return _postRepository.getPostById(postId);
  }

  void addComment({
    required BuildContext context,
    required String text,
    required Post post,
  }) async {
    final user = _ref.read(userProvider)!;
    String commentId = const Uuid().v1();
    Comment comment = Comment(
      id: commentId,
      text: text,
      createdAt: DateTime.now(),
      postId: post.id,
      username: user.name,
      profilePic: user.profilePic,
      authorId: user.uid,
      downVotes: [],
      upVotes: [],
    );
    if (!(post.uid == user.uid)) {
      _notificationRepository.createNotification(NotificationModel(
        id: const Uuid().v1(),
        isRead: false,
        type: 'upvote_post',
        title: "${user.name} commented on your post",
        body:
            "${user.name} commented on your post ${post.title} with  ${comment.text} ",
        payload: {
          'postId': post.id,
        },
        senderId: user.uid,
        receiverId: [post.uid],
        image: post.link,
        createdAt: DateTime.now(),
      ));
    }

    final res = await _postRepository.addComment(comment);

    _ref
        .read(userProfileControllerProvider.notifier)
        .updateUserKarma(UserKarma.comment);
    res.fold((l) => showSnackBar(context, l.message), (r) => null);
  }

  void awardPost({
    required Post post,
    required String award,
    required BuildContext context,
  }) async {
    final user = _ref.read(userProvider)!;

    final res = await _postRepository.awardPost(post, award, user.uid);

    res.fold((l) => showSnackBar(context, l.message), (r) {
      _ref
          .read(userProfileControllerProvider.notifier)
          .updateUserKarma(UserKarma.awardPost);
      _ref.read(userProvider.notifier).update((state) {
        state?.awards.remove(award);
        return state;
      });
      Routemaster.of(context).pop();
    });
  }

  Stream<List<Comment>> fetchPostComments(String postId) {
    return _postRepository.getCommentsOfPost(postId);
  }
}
