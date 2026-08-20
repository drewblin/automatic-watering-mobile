import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'modbus_address_change_controller.dart';

class ModbusAddressTab extends StatefulWidget {
  const ModbusAddressTab({
    required this.controller,
    super.key,
  });

  final ModbusAddressChangeController controller;

  @override
  State<ModbusAddressTab> createState() => _ModbusAddressTabState();
}

class _ModbusAddressTabState extends State<ModbusAddressTab> {
  final _currentAddressController = TextEditingController();
  final _newAddressController = TextEditingController();
  final _registerAddressController = TextEditingController(text: '256');
  final _saveRegisterAddressController = TextEditingController();
  final _saveValueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(ModbusAddressTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _currentAddressController.dispose();
    _newAddressController.dispose();
    _registerAddressController.dispose();
    _saveRegisterAddressController.dispose();
    _saveValueController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _submit() async {
    final success = await widget.controller.submit(
      currentAddressText: _currentAddressController.text,
      newAddressText: _newAddressController.text,
      registerAddressText: _registerAddressController.text,
      saveRegisterAddressText: _saveRegisterAddressController.text,
      saveValueText: _saveValueController.text,
    );
    if (!mounted || !success) {
      return;
    }
    if (widget.controller.state.status == ModbusAddressChangeStatus.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modbus адресу змінено.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final message = state.message;
    final validationMessage =
        state.status == ModbusAddressChangeStatus.invalid ? message : null;
    final resultMessage =
        state.status == ModbusAddressChangeStatus.invalid ? null : message;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 16),
        TextField(
          controller: _currentAddressController,
          decoration: const InputDecoration(
            labelText: 'Поточна адреса девайса',
            border: OutlineInputBorder(),
          ),
          enabled: !state.isSubmitting,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => widget.controller.clearValidationMessage(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _newAddressController,
          decoration: const InputDecoration(
            labelText: 'Нова адреса',
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
            labelText: 'Адреса register',
            border: OutlineInputBorder(),
          ),
          enabled: !state.isSubmitting,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => widget.controller.clearValidationMessage(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _saveRegisterAddressController,
          decoration: const InputDecoration(
            labelText: 'Save register address',
            border: OutlineInputBorder(),
          ),
          enabled: !state.isSubmitting,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => widget.controller.clearValidationMessage(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _saveValueController,
          decoration: const InputDecoration(
            labelText: 'Save value',
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
                : const Icon(Icons.swap_horiz),
            label: const Text('Змінити адресу'),
          ),
        ),
        if (resultMessage != null) ...[
          const SizedBox(height: 16),
          _OperationResult(
            message: resultMessage,
            isSuccess: state.status == ModbusAddressChangeStatus.success,
          ),
        ],
      ],
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
