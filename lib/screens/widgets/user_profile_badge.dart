import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/providers/users_provider.dart';
import 'custom_text.dart';

class UserProfileBadge extends StatelessWidget {
  const UserProfileBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UsersProvider>(context).selectedUser;

    if (user == null) {
      return const SizedBox();
    }

    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        const CircleAvatar(
          radius: 18,
          backgroundColor: Colors.grey,
          child: Icon(
            Icons.person,
            color: Colors.grey,
            size: 20,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: CustomText(
            text: user.username.isNotEmpty ? user.username : user.email,
            fontSize: 14,
            color: Colors.black,
            withBackground: false,
            textAlign: TextAlign.start,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
