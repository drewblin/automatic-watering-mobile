import 'package:flutter/material.dart';

import '../modbus_register_fields.dart';
import 'modbus_register_write_controller.dart';

class ModbusRegisterWriteTab extends StatefulWidget {
  const ModbusRegisterWriteTab({
    required this.controller,
    super.key,
  });

  final ModbusRegisterWriteController controller;

  @override
  State<ModbusRegisterWriteTab> createState() => _ModbusRegisterWriteTabState();
}

class _ModbusRegisterWriteTabState extends State<ModbusRegisterWriteTab> {
  final _slaveAddressController = TextEditingController();
  final _registerAddressController = TextEditingController(text: '0');
  final _valueController = TextEditingController();

  @override
  void dispose() {
    _slaveAddressController.dispose();
    _registerAddressController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final success = await widget.controller.submit(
      slaveAddressText: _slaveAddressController.text,
      registerAddressText: _registerAddressController.text,
      valueText: _valueController.text,
    );
    if (!mounted || !success) {
      return;
    }
    if (widget.controller.state.status == ModbusRegisterWriteStatus.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Значення записано в регістр.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: _buildForm,
    );
  }

  Widget _buildForm(BuildContext context, Widget? child) {
    final state = widget.controller.state;
    final message = state.message;
    final validationMessage =
        state.status == ModbusRegisterWriteStatus.invalid ? message : null;
    final resultMessage =
        state.status == ModbusRegisterWriteStatus.invalid ? null : message;

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 16),
          ModbusRegisterAddressFields(
            slaveAddressController: _slaveAddressController,
            registerAddressController: _registerAddressController,
            enabled: !state.isSubmitting,
            digitsOnly: true,
            onChanged: widget.controller.clearValidationMessage,
          ),
          const SizedBox(height: 12),
          ModbusRegisterNumberField(
            controller: _valueController,
            label: 'Значення',
            enabled: !state.isSubmitting,
            digitsOnly: true,
            onChanged: widget.controller.clearValidationMessage,
          ),
          if (validationMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              validationMessage,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: state.isSubmitting ? null : _submit,
              icon: state.isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.edit_outlined),
              label: const Text('Записати в регістр'),
            ),
          ),
          if (resultMessage != null) ...[
            const SizedBox(height: 16),
            _OperationResult(
              message: resultMessage,
              isSuccess: state.status == ModbusRegisterWriteStatus.success,
            ),
          ],
        ],
      ),
    );
  }
}

class _OperationResult extends StatelessWidget {
  const _OperationResult({
    required this.message,
    required this.isSuccess,
  });

  final String message;
  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: isSuccess ? colorScheme.primary : colorScheme.error,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message),
      ),
    );
  }
}
