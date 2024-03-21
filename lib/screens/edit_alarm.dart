import 'package:alarm/alarm.dart';
import 'package:alarm/model/alarm_settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ExampleAlarmEditScreen extends StatefulWidget {
  final AlarmSettings? alarmSettings;

  const ExampleAlarmEditScreen({Key? key, this.alarmSettings})
      : super(key: key);

  @override
  State<ExampleAlarmEditScreen> createState() => _ExampleAlarmEditScreenState();
}

class _ExampleAlarmEditScreenState extends State<ExampleAlarmEditScreen> {
  bool loading = false;
  // 알람 이름을 저장할 변수 추가
  String alarmName = '';


  late bool creating;
  late DateTime selectedDateTime;
  late bool loopAudio;
  late bool vibrate;
  late double? volume;
  late String assetAudio;

  @override
  void initState() {
    super.initState();
    creating = widget.alarmSettings == null;

    if (creating) {
      selectedDateTime = DateTime.now().add(const Duration(minutes: 1));
      selectedDateTime = selectedDateTime.copyWith(second: 0, millisecond: 0);
      loopAudio = true;
      vibrate = true;
      volume = null;
      assetAudio = 'assets/marimba.mp3';
    } else {
      selectedDateTime = widget.alarmSettings!.dateTime;
      loopAudio = widget.alarmSettings!.loopAudio;
      vibrate = widget.alarmSettings!.vibrate;
      volume = widget.alarmSettings!.volume;
      assetAudio = widget.alarmSettings!.assetAudioPath;
    }
  }

  String getDay() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final difference = selectedDateTime.difference(today).inDays;

    switch (difference) {
      case 0:
        return 'Today';
      case 1:
        return 'Tomorrow';
      case 2:
        return 'After tomorrow';
      default:
        return 'In $difference days';
    }
  }

  Future<void> pickTime() async {
    final res = await showTimePicker(
      initialTime: TimeOfDay.fromDateTime(selectedDateTime),
      context: context,
    );

    if (res != null) {
      setState(() {
        final DateTime now = DateTime.now();
        selectedDateTime = now.copyWith(
          hour: res.hour,
          minute: res.minute,
          second: 0,
          millisecond: 0,
          microsecond: 0,
        );
        if (selectedDateTime.isBefore(now)) {
          selectedDateTime = selectedDateTime.add(const Duration(days: 1));
        }
      });
    }
  }

  AlarmSettings buildAlarmSettings() {
    final id = creating
        ? DateTime.now().millisecondsSinceEpoch % 10000
        : widget.alarmSettings!.id;

    final alarmSettings = AlarmSettings(
      id: id,
      dateTime: selectedDateTime,
      loopAudio: loopAudio,
      vibrate: vibrate,
      volume: volume,
      assetAudioPath: assetAudio,
      notificationTitle: 'Alarm example',
      notificationBody: 'Your alarm ($id) is ringing',
    );
    return alarmSettings;
  }

  void saveAlarm() {
    if (loading) return;
    setState(() => loading = true);
    Alarm.set(alarmSettings: buildAlarmSettings()).then((res) {
      if (res) Navigator.pop(context, true);
      setState(() => loading = false);
    });
  }

  void deleteAlarm() {
    Alarm.stop(widget.alarmSettings!.id).then((res) {
      if (res) Navigator.pop(context, true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hours = List<int>.generate(12, (index) => index);
    final minutes = List<int>.generate(60, (index) => index);
    final ampm = ['오전', '오후'];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: saveAlarm,
                    child: loading
                        ? const CircularProgressIndicator()
                        : const Text('Save'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                getDay(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 100,
                    child: CupertinoPicker(
                      itemExtent: 50,
                      onSelectedItemChanged: (index) {
                        setState(() {
                          selectedDateTime = selectedDateTime.copyWith(
                            hour: selectedDateTime.hour >= 12
                                ? selectedDateTime.hour - 12
                                : selectedDateTime.hour + 12,
                          );
                        });
                      },
                      children: ampm.map((ap) {
                        return Center(child:
                        Text(
                          style: TextStyle(fontSize: 30),
                          ap,
                        ));
                      }).toList(),
                      scrollController: FixedExtentScrollController(
                        initialItem: selectedDateTime.hour >= 12 ? 1 : 0,
                      ),
                      looping: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 100,
                    child: CupertinoPicker(
                      itemExtent: 50,
                      onSelectedItemChanged: (index) {
                        setState(() {
                          selectedDateTime = selectedDateTime.copyWith(
                            hour: hours[index] +
                                (selectedDateTime.hour >= 12 ? 12 : 0),
                          );
                        });
                      },
                      children: hours.map((hour) {
                        return Center(
                          child: Text(
                            hour.toString().padLeft(2, '0'),
                            style: const TextStyle(fontSize: 40),
                          ),
                        );
                      }).toList(),
                      scrollController: FixedExtentScrollController(
                        initialItem: selectedDateTime.hour % 12,
                      ),
                      looping: true,
                    ),
                  ),
                  const Text(
                    ':',
                    style: TextStyle(fontSize: 40),
                  ),
                  SizedBox(
                    width: 100,
                    child: CupertinoPicker(
                      itemExtent: 50,
                      onSelectedItemChanged: (index) {
                        setState(() {
                          selectedDateTime =
                              selectedDateTime.copyWith(minute: minutes[index]);
                        });
                      },
                      children: minutes.map((minute) {
                        return Center(
                          child: Text(
                            minute.toString().padLeft(2, '0'),
                            style: const TextStyle(fontSize: 40),
                          ),
                        );
                      }).toList(),
                      scrollController: FixedExtentScrollController(
                        initialItem: selectedDateTime.minute,
                      ),
                      looping: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.label, color: Colors.grey[400]),
                  const SizedBox(width: 10),
                  const Text('알림 설정'),
                ],
              ),
              const SizedBox(height: 20),
              // 알람 이름 입력 필드 추가
              TextFormField(
                initialValue: alarmName,
                decoration: const InputDecoration(
                  labelText: '',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    alarmName = value;
                  });
                },
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '진동',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Switch(
                    value: vibrate,
                    onChanged: (value) => setState(() => vibrate = value),
                  ),
                ],
              ),
              const Spacer(),
              if (!creating)
                TextButton(
                  onPressed: deleteAlarm,
                  child: Text(
                    'Delete Alarm',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium!
                        .copyWith(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}