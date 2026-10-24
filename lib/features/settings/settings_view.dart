import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../ibutton/ibutton_service.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _ibutton = IButtonService.instance;

  @override
  void initState() {
    super.initState();
    _ibutton.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _ibutton.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  void _showEditContactDialog(int contactSlot) {
    final contact = contactSlot == 1 ? _ibutton.contact1 : _ibutton.contact2;
    final nameCtrl = TextEditingController(text: contact.name);
    final phoneCtrl = TextEditingController(text: contact.phoneNumber);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Edit Speed Dial Contact $contactSlot',
          style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: AppColors.textLight),
              decoration: const InputDecoration(
                labelText: 'Contact Name',
                labelStyle: TextStyle(color: AppColors.textMuted),
                prefixIcon: Icon(Icons.person, color: AppColors.accent),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: AppColors.textLight),
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                labelStyle: TextStyle(color: AppColors.textMuted),
                prefixIcon: Icon(Icons.phone, color: AppColors.accent),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () {
              final newContact = SpeedDialContact(
                name: nameCtrl.text.trim().isEmpty ? 'Contact $contactSlot' : nameCtrl.text.trim(),
                phoneNumber: phoneCtrl.text.trim().isEmpty ? '+919876543210' : phoneCtrl.text.trim(),
              );
              if (contactSlot == 1) {
                _ibutton.setContact1(newContact);
              } else {
                _ibutton.setContact2(newContact);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: AppColors.background, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: AppColors.textLight,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up, color: AppColors.textLight),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section 1: Button Gestures & Feedback
              const Text(
                'Button Gestures & Feedback',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 16),

              _buildGestureRow(ButtonGestureType.singlePress),
              const SizedBox(height: 14),

              _buildGestureRow(ButtonGestureType.doublePress),
              const SizedBox(height: 14),

              _buildGestureRow(ButtonGestureType.triplePress),
              const SizedBox(height: 14),

              _buildGestureRow(ButtonGestureType.longPress),
              const SizedBox(height: 14),

              _buildGestureRow(
                ButtonGestureType.singleLongPress,
                contactSlot: 1,
              ),
              const SizedBox(height: 14),

              _buildGestureRow(
                ButtonGestureType.doubleLongPress,
                contactSlot: 2,
              ),
              const SizedBox(height: 14),

              _buildGestureRow(ButtonGestureType.tripleLongPress),
              const SizedBox(height: 28),

              // Section 2: Media Features
              const Text(
                'Media Features',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Force Play Music',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Automatically start your preferred app when ride starts',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _ibutton.forcePlayMusic,
                    activeColor: AppColors.accent,
                    activeTrackColor: AppColors.accent.withOpacity(0.3),
                    inactiveThumbColor: AppColors.textMuted,
                    inactiveTrackColor: AppColors.surfaceLight,
                    onChanged: (val) {
                      _ibutton.setForcePlayMusic(val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Quick Hardware Test Controls
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.tune, color: AppColors.accent, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'TEST HANDLEBAR GESTURE DISPATCH',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ButtonGestureType.values.map((gesture) {
                        return OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            backgroundColor: AppColors.surfaceLight,
                          ),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final success = await _ibutton.triggerGesture(gesture);
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Tested ${gesture.label}: ${_ibutton.getActionForGesture(gesture).label}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  backgroundColor: success ? AppColors.accent : Colors.orange,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          child: Text(
                            gesture.label,
                            style: const TextStyle(color: AppColors.textLight, fontSize: 11),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGestureRow(ButtonGestureType gesture, {int? contactSlot}) {
    final currentAction = _ibutton.getActionForGesture(gesture);
    final isSpeedDial = currentAction == ButtonGestureAction.speedDial;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                gesture.label,
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ButtonGestureAction>(
                  value: currentAction,
                  dropdownColor: AppColors.surface,
                  icon: const Icon(Icons.arrow_drop_down, color: AppColors.accent),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  items: ButtonGestureAction.values.map((action) {
                    return DropdownMenuItem(
                      value: action,
                      child: Text(
                        action.label,
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (newAction) {
                    if (newAction != null) {
                      _ibutton.setActionForGesture(gesture, newAction);
                    }
                  },
                ),
              ),
            ),
          ],
        ),

        // If Speed Dial selected, show Contact card matching user's screenshot
        if (isSpeedDial && contactSlot != null) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _showEditContactDialog(contactSlot),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: AppColors.accent, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Contact: ',
                    style: TextStyle(
                      color: AppColors.accent.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      contactSlot == 1
                          ? '${_ibutton.contact1.name} (${_ibutton.contact1.phoneNumber})'
                          : '${_ibutton.contact2.name} (${_ibutton.contact2.phoneNumber})',
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.edit, color: AppColors.textMuted, size: 14),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
