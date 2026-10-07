import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/ui/app_snackbar.dart';
import 'data/profile_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, this.profileService});

  final ProfileService? profileService;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final ProfileService _profileService;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _profileSubscription;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _profileLoaded = false;

  String _originalDisplayName = '';
  String _email = '';

  bool get _hasChanges {
    return _nameController.text.trim() != _originalDisplayName;
  }

  @override
  void initState() {
    super.initState();

    _profileService = widget.profileService ?? ProfileService();

    _nameController.addListener(_onNameChanged);

    _listenToProfile();
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();

    _nameController
      ..removeListener(_onNameChanged)
      ..dispose();

    super.dispose();
  }

  void _listenToProfile() {
    _profileSubscription = _profileService.watchCurrentUserProfile().listen(
      _onProfileSnapshot,
      onError: _onProfileError,
    );
  }

  void _onProfileSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    if (!mounted) {
      return;
    }

    final authUser = FirebaseAuth.instance.currentUser;

    final data = snapshot.data() ?? <String, dynamic>{};

    final firestoreDisplayName = data['displayName'];

    final firestoreEmail = data['email'];

    final displayName =
        firestoreDisplayName is String && firestoreDisplayName.trim().isNotEmpty
        ? firestoreDisplayName.trim()
        : authUser?.displayName?.trim() ?? '';

    final email = firestoreEmail is String && firestoreEmail.trim().isNotEmpty
        ? firestoreEmail.trim()
        : authUser?.email?.trim() ?? '';

    /*
     * On the first profile load, populate the form.
     *
     * After that, do not overwrite the user's current
     * input while they are editing.
     */
    if (!_profileLoaded) {
      _originalDisplayName = displayName;
      _email = email;

      _nameController.value = TextEditingValue(
        text: displayName,
        selection: TextSelection.collapsed(offset: displayName.length),
      );

      _profileLoaded = true;
    } else if (!_hasChanges) {
      /*
       * If the user has not modified the form, keep it
       * synchronized with Firestore.
       */
      _originalDisplayName = displayName;
      _email = email;

      _nameController.value = TextEditingValue(
        text: displayName,
        selection: TextSelection.collapsed(offset: displayName.length),
      );
    }

    if (_isLoading) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onProfileError(Object error, StackTrace stackTrace) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _onNameChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  Future<void> _saveProfile() async {
    if (_isSaving) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    final normalizedName = _nameController.text.trim();

    if (normalizedName == _originalDisplayName) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _profileService.updateProfile(displayName: normalizedName);

      if (!mounted) {
        return;
      }

      AppSnackBar.showMessage(context, 'Profile updated successfully.');

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      AppSnackBar.showMessage(context, _getErrorMessage(error));

      setState(() {
        _isSaving = false;
      });
    }
  }

  String _getErrorMessage(Object error) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' =>
          'You do not have permission to update your profile.',
        'unavailable' =>
          'The service is temporarily unavailable. Please try again.',
        _ => 'Unable to update your profile. Please try again.',
      };
    }

    if (error is ArgumentError) {
      return error.message?.toString() ?? 'Invalid profile information.';
    }

    if (error is StateError) {
      return error.message;
    }

    return 'Unable to update your profile. Please try again.';
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasChanges || _isSaving) {
      return true;
    }

    final shouldDiscard =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Discard changes?'),
              content: const Text('Your profile changes have not been saved.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false);
                  },
                  child: const Text('Keep Editing'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Discard'),
                ),
              ],
            );
          },
        ) ??
        false;

    return shouldDiscard;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: !_hasChanges || _isSaving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }

        final shouldDiscard = await _confirmDiscardChanges();

        if (!context.mounted || !shouldDiscard) {
          return;
        }

        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Edit Profile')),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personal information',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Update the name displayed across Yening Ecos.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _nameController,
                        enabled: !_isSaving,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: 'Display name',
                          hintText: 'Enter your display name',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final name = value?.trim() ?? '';

                          if (name.isEmpty) {
                            return 'Please enter your display name.';
                          }

                          if (name.length > 100) {
                            return 'Display name cannot exceed 100 characters.';
                          }

                          return null;
                        },
                        onFieldSubmitted: (_) {
                          if (_hasChanges) {
                            _saveProfile();
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: _email,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Only your display name can be changed here. Your email address is linked to your account.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _isSaving || !_hasChanges ? null : _saveProfile,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
