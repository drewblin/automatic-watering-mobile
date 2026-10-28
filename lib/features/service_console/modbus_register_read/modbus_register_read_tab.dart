import 'package:flutter/material.dart';

import '../../local_controller/modbus_register_read_models.dart';
import '../modbus_register_fields.dart';
import 'modbus_register_read_controller.dart';

class ModbusRegisterReadTab extends StatefulWidget {
  const ModbusRegisterReadTab({required this.controller, required super.key});

  final ModbusRegisterReadController controller;

  @override
  State<ModbusRegisterReadTab> createState() => _ModbusRegisterReadTabState();
}

class _ModbusRegisterReadTabState extends State<ModbusRegisterReadTab> {
  final _slaveAddressController = TextEditingController();
  final _registerAddressController = TextEditingController(text: '0');
  final _quantityController = TextEditingController(text: '1');

  @override
  void dispose() {
    _slaveAddressController.dispose();
    _registerAddressController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await widget.controller.submit(
      slaveAddressText: _slaveAddressController.text,
      registerAddressText: _registerAddressController.text,
      quantityText: _quantityController.text,
    );
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
    final result = state.result;

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
          ),
          const SizedBox(height: 12),
          ModbusRegisterNumberField(
            controller: _quantityController,
            label: 'Кількість регістрів',
            helperText: 'Від 1 до 64',
            enabled: !state.isSubmitting,
          ),
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
                  : const Icon(Icons.search),
              label: const Text('Прочитати'),
            ),
          ),
          if (message != null &&
              state.status == ModbusRegisterReadStatus.failure) ...[
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.error),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(message),
              ),
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 16),
            _ReadResult(result: result),
          ],
        ],
      ),
    );
  }
}

class _ReadResult extends StatelessWidget {
  const _ReadResult({required this.result});

  final ModbusRegisterReadResult result;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.primary),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Результат', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Пристрій: ${result.slaveAddress}'),
            DataTable(
              horizontalMargin: 0,
              columnSpacing: 24,
              columns: const [
                DataColumn(label: Text('Регістр')),
                DataColumn(label: Text('Значення'), numeric: true),
              ],
              rows: [
                for (var index = 0; index < result.values.length; index++)
                  DataRow(cells: [
                    DataCell(Text('${result.registerAddress + index}')),
                    DataCell(Text('${result.values[index]}')),
                  ]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
