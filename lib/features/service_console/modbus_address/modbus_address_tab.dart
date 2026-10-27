import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'modbus_address_change_controller.dart';

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
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(ModbusRegisterWriteTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _slaveAddressController.dispose();
    _registerAddressController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
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
          TextField(
            controller: _slaveAddressController,
            decoration: const InputDecoration(
              labelText: 'Адреса пристрою',
              border: OutlineInputBorder(),
            ),
            enabled: !state.isSubmitting,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => widget.controller.clearValidationMessage(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _registerAddressController,
            decoration: const InputDecoration(
              labelText: 'Адреса регістра',
              border: OutlineInputBorder(),
            ),
            enabled: !state.isSubmitting,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => widget.controller.clearValidationMessage(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _valueController,
            decoration: const InputDecoration(
              labelText: 'Значення',
              border: OutlineInputBorder(),
            ),
            enabled: !state.isSubmitting,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => widget.controller.clearValidationMessage(),
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
