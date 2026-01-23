import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:saveeye_flutter_sdk/saveeye_flutter_sdk.dart';
import 'onboarding_complete_screen.dart';

class EncryptionKeyScreen extends HookWidget {
  const EncryptionKeyScreen({super.key, required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context) {
    final client = useSaveEyeClient();
    final opticalKey = useState('');
    final mepKey = useState('');
    final gpk60Key = useState('');
    final gpk61Key = useState('');
    final loading = useState(false);
    final deviceProfile = useState<int?>(null);
    final showWaitWidget = useState(false);
    final error = useState<String?>(null);

    // Get device info to determine profile
    useEffect(() {
      // Use getMyDevices to find the device and get its profile
      client.getMyDevices().then((devices) {
        final device = devices.firstWhere(
          (d) => d.id == deviceId,
          orElse: () => throw Exception('Device not found'),
        );
        deviceProfile.value = device.plusDevice?.deviceType?.profile;
      }).catchError((e) {
        print('Error getting device: $e');
        error.value = 'Failed to get device information';
      });
      return null;
    }, [deviceId]);

    Future<void> handleContinue() async {
      if (loading.value) return;
      loading.value = true;
      error.value = null;

      try {
        await client.setEncryptionKeys(
          deviceId,
          mepKey: mepKey.value.isEmpty ? null : mepKey.value,
          gpk60Key: gpk60Key.value.isEmpty ? null : gpk60Key.value,
          gpk61Key: gpk61Key.value.isEmpty ? null : gpk61Key.value,
          opticalKey: opticalKey.value.isEmpty ? null : opticalKey.value,
        );
        showWaitWidget.value = true;
      } catch (e) {
        error.value = e.toString();
      } finally {
        loading.value = false;
      }
    }

    if (showWaitWidget.value) {
      return EncryptionWaiter(
        deviceId: deviceId,
        onTimeout: () => showWaitWidget.value = false,
        onDone: () {
          if (context.mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const OnboardingCompleteScreen(),
              ),
            );
          }
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Encryption Key')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Please enter the encryption key for your device.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            if (deviceProfile.value == 4)
              OpticalKeyWidget(
                opticalKey: opticalKey.value,
                setOpticalKey: (key) => opticalKey.value = key,
              ),
            if (deviceProfile.value == 5)
              MEPKeyWidget(
                mepKey: mepKey.value,
                setMEPKey: (key) => mepKey.value = key,
              ),
            if (deviceProfile.value == 6)
              GPKKeyWidget(
                gpk60Key: gpk60Key.value,
                gpk61Key: gpk61Key.value,
                setGpk60Key: (key) => gpk60Key.value = key,
                setGpk61Key: (key) => gpk61Key.value = key,
              ),
            if (deviceProfile.value == null)
              const Center(
                child: CircularProgressIndicator(),
              ),
            if (error.value != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(top: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Error: ${error.value}',
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            const Spacer(),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: loading.value ? null : handleContinue,
                child: Text(loading.value ? 'Loading...' : 'Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OpticalKeyWidget extends HookWidget {
  const OpticalKeyWidget({
    super.key,
    required this.opticalKey,
    required this.setOpticalKey,
  });

  final String opticalKey;
  final void Function(String) setOpticalKey;

  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController(text: opticalKey);
    useEffect(() {
      if (controller.text != opticalKey) {
        controller.text = opticalKey;
      }
      return null;
    }, [opticalKey]);

    return TextField(
      controller: controller,
      obscureText: true,
      decoration: const InputDecoration(
        labelText: 'Enter optical key',
        border: OutlineInputBorder(),
      ),
      onChanged: setOpticalKey,
    );
  }
}

class MEPKeyWidget extends HookWidget {
  const MEPKeyWidget({
    super.key,
    required this.mepKey,
    required this.setMEPKey,
  });

  final String mepKey;
  final void Function(String) setMEPKey;

  @override
  Widget build(BuildContext context) {
    final error = useState<String>('');
    final controller = useTextEditingController(text: mepKey);
    useEffect(() {
      if (controller.text != mepKey) {
        controller.text = mepKey;
      }
      return null;
    }, [mepKey]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Enter MEP key',
            border: const OutlineInputBorder(),
            errorText: error.value.isEmpty ? null : error.value,
          ),
          onChanged: (value) {
            setMEPKey(value);
            if (error.value.isNotEmpty) {
              error.value = '';
            }
          },
          onEditingComplete: () {
            if (mepKey.length != 20) {
              error.value = 'MEP key must be exactly 20 characters long';
            } else {
              error.value = '';
            }
          },
        ),
      ],
    );
  }
}

class GPKKeyWidget extends HookWidget {
  const GPKKeyWidget({
    super.key,
    required this.gpk60Key,
    required this.gpk61Key,
    required this.setGpk60Key,
    required this.setGpk61Key,
  });

  final String gpk60Key;
  final String gpk61Key;
  final void Function(String) setGpk60Key;
  final void Function(String) setGpk61Key;

  @override
  Widget build(BuildContext context) {
    final gpk60Error = useState<String>('');
    final gpk61Error = useState<String>('');
    final gpk60Controller = useTextEditingController(text: gpk60Key);
    final gpk61Controller = useTextEditingController(text: gpk61Key);

    useEffect(() {
      if (gpk60Controller.text != gpk60Key) {
        gpk60Controller.text = gpk60Key;
      }
      return null;
    }, [gpk60Key]);

    useEffect(() {
      if (gpk61Controller.text != gpk61Key) {
        gpk61Controller.text = gpk61Key;
      }
      return null;
    }, [gpk61Key]);

    return Column(
      children: [
        TextField(
          controller: gpk60Controller,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Enter GPK60 key',
            border: const OutlineInputBorder(),
            errorText: gpk60Error.value.isEmpty ? null : gpk60Error.value,
          ),
          onChanged: (value) {
            setGpk60Key(value);
            if (gpk60Error.value.isNotEmpty) {
              gpk60Error.value = '';
            }
          },
          onEditingComplete: () {
            if (gpk60Key.length != 32) {
              gpk60Error.value = 'GPK60 key must be exactly 32 characters long';
            } else {
              gpk60Error.value = '';
            }
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: gpk61Controller,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Enter GPK61 key',
            border: const OutlineInputBorder(),
            errorText: gpk61Error.value.isEmpty ? null : gpk61Error.value,
          ),
          onChanged: (value) {
            setGpk61Key(value);
            if (gpk61Error.value.isNotEmpty) {
              gpk61Error.value = '';
            }
          },
          onEditingComplete: () {
            if (gpk61Key.length != 32) {
              gpk61Error.value = 'GPK61 key must be exactly 32 characters long';
            } else {
              gpk61Error.value = '';
            }
          },
        ),
      ],
    );
  }
}

class EncryptionWaiter extends HookWidget {
  const EncryptionWaiter({
    super.key,
    required this.deviceId,
    required this.onTimeout,
    required this.onDone,
  });

  final String deviceId;
  final VoidCallback onTimeout;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final client = useSaveEyeClient();
    final decryptionErrorStart = useState<DateTime?>(null);
    final timerRef = useRef<Timer?>(null);

    Future<void> poll() async {
      try {
        final session = await client.getOnboardingSession(deviceId);
        if (session == null) {
          return;
        }

        if (session.status == Enum$PlusDeviceOnboardingSessionStatus.DONE) {
          timerRef.value?.cancel();
          onDone();
        } else if (session.status ==
            Enum$PlusDeviceOnboardingSessionStatus.ERROR_MESSAGES) {
          if (session.errorCode == 'DecryptionError') {
            final now = DateTime.now();
            if (decryptionErrorStart.value == null) {
              decryptionErrorStart.value = now;
            } else {
              final elapsed = now.difference(decryptionErrorStart.value!);
              if (elapsed.inMilliseconds > 180000) {
                // 3 minutes
                timerRef.value?.cancel();
                onTimeout();
                return;
              }
            }
            // Continue polling
          } else {
            decryptionErrorStart.value = null;
            // Continue polling for other errors
          }
        } else {
          decryptionErrorStart.value = null;
          // Continue polling for other statuses
        }
      } catch (e) {
        print('Error polling encryption session: $e');
      }
    }

    useEffect(() {
      poll();
      timerRef.value = Timer.periodic(
        const Duration(seconds: 2),
        (_) => poll(),
      );

      return () {
        timerRef.value?.cancel();
      };
    }, [deviceId]);

    return Scaffold(
      appBar: AppBar(title: const Text('Processing Encryption')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Processing Encryption',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Text(
              'Please wait while we process your encryption key.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
