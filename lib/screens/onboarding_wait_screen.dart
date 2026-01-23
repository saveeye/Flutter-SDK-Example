import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:saveeye_flutter_sdk/saveeye_flutter_sdk.dart';
import 'encryption_key_screen.dart';
import 'onboarding_complete_screen.dart';

class DeviceError {
  final String errorCode;
  final String errorMessage;
  final bool canContinue;
  final String? pushToScreen;

  DeviceError({
    required this.errorCode,
    required this.errorMessage,
    required this.canContinue,
    this.pushToScreen,
  });
}

class OnboardingWaitScreen extends HookWidget {
  const OnboardingWaitScreen({super.key, required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context) {
    final client = useSaveEyeClient();
    final status = useState<Enum$PlusDeviceOnboardingSessionStatus?>(null);
    final error = useState<DeviceError?>(null);
    final timerRef = useRef<Timer?>(null);
    final resolvedDeviceId = useState<String?>(null);
    final isLoadingDeviceId = useState(true);

    final possibleErrors = useMemoized(
      () => [
        DeviceError(
          errorCode: 'DecryptionError',
          errorMessage: '',
          canContinue: false,
          pushToScreen: 'EncryptionKeyScreen',
        ),
        DeviceError(
          errorCode: 'AuthenticationFailure',
          errorMessage: '',
          canContinue: false,
          pushToScreen: 'EncryptionKeyScreen',
        ),
        DeviceError(
          errorCode: 'ACKError',
          errorMessage:
              'Error connecting to the device. Try reconnecting the device to the meter.',
          canContinue: true,
        ),
        DeviceError(
          errorCode: 'Timeout',
          errorMessage:
              'No response from meter. The port might be closed or the device is not properly connected.',
          canContinue: true,
        ),
        DeviceError(
          errorCode: 'LengthMismatch',
          errorMessage:
              'Invalid message received from meter. If the error persists it could be a connection or hardware issue.',
          canContinue: true,
        ),
        DeviceError(
          errorCode: 'SequenceError',
          errorMessage:
              'Invalid message received from meter. If the error persists it could be a connection or hardware issue.',
          canContinue: true,
        ),
        DeviceError(
          errorCode: 'InvalidData',
          errorMessage:
              'Invalid message received from meter. If the error persists it could be a connection or hardware issue.',
          canContinue: true,
        ),
        DeviceError(
          errorCode: 'CRCError',
          errorMessage:
              "Invalid data received from meter. Try removing the splitter if you're using one.",
          canContinue: true,
        ),
        DeviceError(
          errorCode: 'IdentificationError',
          errorMessage:
              'Error communicating with the meter. If the error persists contact customer support.',
          canContinue: true,
        ),
        DeviceError(
          errorCode: 'NegotiateError',
          errorMessage:
              'The device had trouble negotiating with the meter. Try adjusting the placement of the device.',
          canContinue: false,
        ),
        DeviceError(
          errorCode: 'LogonError',
          errorMessage:
              'Error while communicating with the meter. If the error persists it could be a hardware issue.',
          canContinue: true,
        ),
        DeviceError(
          errorCode: 'SecurityError',
          errorMessage: '',
          canContinue: false,
          pushToScreen: 'EncryptionKeyScreen',
        ),
        DeviceError(
          errorCode: 'ReadError',
          errorMessage: 'Error reading data from the meter.',
          canContinue: true,
        ),
        DeviceError(
          errorCode: 'InvalidDeviceID',
          errorMessage:
              "Couldn't read data from meter. Contact customer support.",
          canContinue: false,
        ),
        DeviceError(
          errorCode: 'InitializationError',
          errorMessage:
              "Couldn't read data from meter. Contact customer support.",
          canContinue: false,
        ),
        DeviceError(
          errorCode: 'AssociationError',
          errorMessage:
              "Couldn't read data from meter. Contact customer support.",
          canContinue: false,
        ),
      ],
      [],
    );

    void handleError(String errorCode) {
      final foundError = possibleErrors.firstWhere(
        (e) => e.errorCode == errorCode,
        orElse: () => DeviceError(
          errorCode: 'GenericError',
          errorMessage: 'An error occurred. Please try again.',
          canContinue: false,
        ),
      );

      if (foundError.pushToScreen != null) {
        timerRef.value?.cancel();
        if (context.mounted && resolvedDeviceId.value != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  EncryptionKeyScreen(deviceId: resolvedDeviceId.value!),
            ),
          );
        }
        return;
      }

      error.value = foundError;
    }

    Future<String?> _getDeviceIdFromInput(String input) async {
      return await client.getDeviceIdFromQrOrBle(input);
    }

    Future<void> poll() async {
      if (resolvedDeviceId.value == null) {
        return;
      }

      try {
        final session = await client.getOnboardingSession(
          resolvedDeviceId.value!,
        );
        if (session == null) {
          return;
        }

        status.value = session.status;

        if (session.status == Enum$PlusDeviceOnboardingSessionStatus.DONE) {
          timerRef.value?.cancel();
          if (context.mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const OnboardingCompleteScreen(),
              ),
            );
          }
        } else if (session.status ==
                Enum$PlusDeviceOnboardingSessionStatus.ERROR_MESSAGES &&
            session.errorCode != null) {
          handleError(session.errorCode!);
        } else {
          // Continue polling for other statuses
        }
      } catch (e) {
        print('Error polling onboarding session: $e');
      }
    }

    useEffect(() {
      // First, convert BLE name/QR code to deviceId
      _getDeviceIdFromInput(deviceId).then((id) {
        resolvedDeviceId.value = id;
        isLoadingDeviceId.value = false;

        if (id == null) {
          error.value = DeviceError(
            errorCode: 'InvalidDeviceID',
            errorMessage:
                "Couldn't read data from meter. Contact customer support.",
            canContinue: false,
          );
          return;
        }

        // Start polling once we have the deviceId
        poll();

        // Set up periodic polling every 2 seconds
        timerRef.value = Timer.periodic(
          const Duration(seconds: 2),
          (_) => poll(),
        );
      });

      // Cleanup on dispose
      return () {
        timerRef.value?.cancel();
      };
    }, [deviceId]);

    if (isLoadingDeviceId.value) {
      return Scaffold(
        appBar: AppBar(title: const Text('Finishing setup')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Finishing setup')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (status.value ==
                Enum$PlusDeviceOnboardingSessionStatus
                    .FIRMWARE_UPDATE_IN_PROGRESS)
              const FirmwareUpdateWidget()
            else
              FinishingSetupWidget(error: error.value),
            if (error.value == null)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Please wait while we finish onboarding your device.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class FinishingSetupWidget extends StatelessWidget {
  const FinishingSetupWidget({super.key, required this.error});

  final DeviceError? error;

  @override
  Widget build(BuildContext context) {
    if (error == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          if (error!.errorMessage.isNotEmpty)
            Text(
              error!.errorMessage,
              style: TextStyle(fontSize: 16, color: Colors.red.shade700),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 10),
          Text(
            'Error Code: ${error!.errorCode}',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class FirmwareUpdateWidget extends StatelessWidget {
  const FirmwareUpdateWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Firmware updating',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'Please keep your device powered on and nearby. Do not close the app during the update.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
