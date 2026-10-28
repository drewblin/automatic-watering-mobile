import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ModbusRegisterAddressFields extends StatelessWidget {
  const ModbusRegisterAddressFields({
    required this.slaveAddressController,
    required this.registerAddressController,
    required this.enabled,
    this.digitsOnly = false,
    this.onChanged,
    super.key,
  });

  final TextEditingController slaveAddressController;
  final TextEditingController registerAddressController;
  final bool enabled;
  final bool digitsOnly;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ModbusRegisterNumberField(
          controller: slaveAddressController,
          label: 'Адреса пристрою',
          enabled: enabled,
          digitsOnly: digitsOnly,
          onChanged: onChanged,
        ),
        const SizedBox(height: 12),
        ModbusRegisterNumberField(
          controller: registerAddressController,
          label: 'Адреса регістра',
          enabled: enabled,
          digitsOnly: digitsOnly,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class ModbusRegisterNumberField extends StatelessWidget {
  const ModbusRegisterNumberField({
    required this.controller,
    required this.label,
    required this.enabled,
    this.helperText,
    this.digitsOnly = false,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final String? helperText;
  final bool digitsOnly;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        border: const OutlineInputBorder(),
      ),
      enabled: enabled,
      keyboardType: digitsOnly
          ? TextInputType.number
          : const TextInputType.numberWithOptions(signed: true),
      inputFormatters:
          digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
      onChanged: onChanged == null ? null : (_) => onChanged!(),
    );
  }
}
