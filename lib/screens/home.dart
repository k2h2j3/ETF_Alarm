import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:alarm/model/alarm_settings.dart';
import 'package:eft_alarm/screens/edit_alarm.dart';
import 'package:eft_alarm/screens/ring.dart';
import 'package:eft_alarm/screens/shortcut_button.dart';
import 'package:eft_alarm/widgets/tile.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExampleAlarmHomeScreen extends StatefulWidget {
  const ExampleAlarmHomeScreen({Key? key}) : super(key: key);

  @override
  State<ExampleAlarmHomeScreen> createState() => _ExampleAlarmHomeScreenState();
}

class _ExampleAlarmHomeScreenState extends State<ExampleAlarmHomeScreen> {
  late List<AlarmSettings> alarms;
  late List<bool> enabledAlarms;

  static StreamSubscription<AlarmSettings>? subscription;

  @override
  void initState() {
    super.initState();
    if (Alarm.android) {
      checkAndroidNotificationPermission();
      checkAndroidScheduleExactAlarmPermission();
    }
    loadAlarms();
    subscription ??= Alarm.ringStream.stream.listen(
          (alarmSettings) => navigateToRingScreen(alarmSettings),
    );

    // 저장된 알람 상태 복원
    SharedPreferences.getInstance().then((prefs) {
      final savedEnabledAlarms = prefs.getStringList('enabledAlarms');
      if (savedEnabledAlarms != null) {
        setState(() {
          enabledAlarms = savedEnabledAlarms.map((e) => e == 'true').toList();
        });
      }
    });
  }

  // 알람 리스트를 가져와서 해당 알람들을 시간순으로 정렬
  Future<void> loadAlarms() async {
    final alarmList = await Alarm.getAlarms();
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();

    final updatedAlarms = await Future.wait(alarmList.map((alarm) async {
      if (alarm.dateTime.isBefore(now)) {
        final originalAlarmTimeMillis = prefs.getInt('originalAlarmTime_${alarm.id}');
        final originalAlarmTime = originalAlarmTimeMillis != null
            ? DateTime.fromMillisecondsSinceEpoch(originalAlarmTimeMillis)
            : alarm.dateTime;

        return AlarmSettings(
          id: alarm.id,
          dateTime: originalAlarmTime.add(const Duration(days: 1)),
          assetAudioPath: alarm.assetAudioPath,
          loopAudio: alarm.loopAudio,
          vibrate: alarm.vibrate,
          fadeDuration: alarm.fadeDuration,
          notificationTitle: alarm.notificationTitle,
          notificationBody: alarm.notificationBody,
          enableNotificationOnKill: alarm.enableNotificationOnKill,
        );
      }
      return alarm;
    }));

    updatedAlarms.sort((a, b) => a.dateTime.isBefore(b.dateTime) ? 0 : 1);

    final savedEnabledAlarms = prefs.getStringList('enabledAlarms');

    setState(() {
      alarms = updatedAlarms;
      enabledAlarms = List<bool>.filled(alarms.length, true);

      if (savedEnabledAlarms != null) {
        for (int i = 0; i < alarms.length; i++) {
          final alarmId = alarms[i].id.toString();
          final index = savedEnabledAlarms.indexOf(alarmId);
          if (index != -1) {
            enabledAlarms[i] = savedEnabledAlarms[index + 1] == 'true';
          }
        }
      }
    });
  }

  Future<void> navigateToRingScreen(AlarmSettings alarmSettings) async {
    final index = alarms.indexWhere((alarm) => alarm.id == alarmSettings.id);
    if (index != -1 && enabledAlarms[index]) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ExampleAlarmRingScreen(alarmSettings: alarmSettings),
        ),
      );
    }
  }

  Future<void> navigateToAlarmScreen(AlarmSettings? settings) async {
    final res = await showModalBottomSheet<AlarmSettings?>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 1,
          child: ExampleAlarmEditScreen(alarmSettings: settings),
        );
      },
    );

    await loadAlarms();
  }

  Future<void> checkAndroidNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isDenied) {
      alarmPrint('Requesting notification permission...');
      final res = await Permission.notification.request();
      alarmPrint(
        'Notification permission ${res.isGranted ? '' : 'not '}granted.',
      );
    }
  }

  Future<void> checkAndroidExternalStoragePermission() async {
    final status = await Permission.storage.status;
    if (status.isDenied) {
      alarmPrint('Requesting external storage permission...');
      final res = await Permission.storage.request();
      alarmPrint(
        'External storage permission ${res.isGranted ? '' : 'not'} granted.',
      );
    }
  }

  Future<void> checkAndroidScheduleExactAlarmPermission() async {
    final status = await Permission.scheduleExactAlarm.status;
    alarmPrint('Schedule exact alarm permission: $status.');
    if (status.isDenied) {
      alarmPrint('Requesting schedule exact alarm permission...');
      final res = await Permission.scheduleExactAlarm.request();
      alarmPrint(
        'Schedule exact alarm permission ${res.isGranted ? '' : 'not'} granted.',
      );
    }
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('alarm')),
      body: SafeArea(
        child: alarms.isNotEmpty
            ? ListView.separated(
          itemCount: alarms.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            return Row(
              children: [
                ExampleAlarmTile(
                  key: Key(alarms[index].id.toString()),
                  title: TimeOfDay(
                    hour: alarms[index].dateTime.hour,
                    minute: alarms[index].dateTime.minute,
                  ).format(context),
                  onPressed: () => navigateToAlarmScreen(alarms[index]),
                  onDismissed: () {
                    Alarm.stop(alarms[index].id).then((_) => loadAlarms());
                  },
                ),
                Text(alarms[index].notificationBody),
                Switch(
                  value: enabledAlarms[index],
                  onChanged: (value) async {
                    setState(() {
                      enabledAlarms[index] = value;
                    });

                    final prefs = await SharedPreferences.getInstance();
                    final alarmId = alarms[index].id.toString();
                    final alarmState = value.toString();

                    final savedEnabledAlarms = prefs.getStringList('enabledAlarms') ?? [];
                    final savedIndex = savedEnabledAlarms.indexOf(alarmId);
                    if (savedIndex != -1) {
                      savedEnabledAlarms[savedIndex + 1] = alarmState;
                    } else {
                      savedEnabledAlarms.addAll([alarmId, alarmState]);
                    }
                    await prefs.setStringList('enabledAlarms', savedEnabledAlarms);

                    if (value) {
                      final originalAlarmTimeMillis = prefs.getInt('originalAlarmTime_${alarms[index].id}');
                      if (originalAlarmTimeMillis != null) {
                        final originalAlarmTime = DateTime.fromMillisecondsSinceEpoch(originalAlarmTimeMillis);
                        final enabledAlarm = alarms[index].copyWith(dateTime: originalAlarmTime);
                        await Alarm.set(alarmSettings: enabledAlarm);
                        setState(() {
                          alarms[index] = enabledAlarm;
                        });
                      } else {
                        await Alarm.set(alarmSettings: alarms[index]);
                      }
                    } else {
                      await prefs.setInt('originalAlarmTime_${alarms[index].id}', alarms[index].dateTime.millisecondsSinceEpoch);
                      final disabledAlarmTime = alarms[index].dateTime.add(const Duration(days: 365));
                      final disabledAlarm = alarms[index].copyWith(dateTime: disabledAlarmTime);
                      await Alarm.set(alarmSettings: disabledAlarm);
                      setState(() {
                        alarms[index] = disabledAlarm;
                      });
                    }
                  },
                ),
              ],
            );
          },
        )
            : Center(
          child: Text(
            "No alarms set",
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ExampleAlarmHomeShortcutButton(refreshAlarms: loadAlarms),
            FloatingActionButton(
              onPressed: () => navigateToAlarmScreen(null),
              child: const Icon(Icons.alarm_add_rounded, size: 33),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}