import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants.dart';
import '../../core/input_rules.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/profile_photo_options.dart';
import '../../widgets/sheet_message.dart';
import '../../widgets/top_bar.dart';
import '../../widgets/ui.dart';

/// Perfil del dueño: su cuenta, los datos del negocio (salen en el PDF, el
/// recibo, los mensajes de WhatsApp y el portal del cliente), las reglas de
/// las cotizaciones, la cuenta para transferencias y las preferencias.
class ProfileScreen extends StatelessWidget {
  final AppState state;
  final Function(int) onNavigate;

  const ProfileScreen({
    super.key,
    required this.state,
    required this.onNavigate,
  });

  Settings get _s => state.settings;

  String get _ownerName =>
      _s.ownerName.trim().isEmpty ? 'Administrador' : _s.ownerName.trim();

  static String _orDash(String value) =>
      value.trim().isEmpty ? 'Sin capturar' : value.trim();

  // ------------------------------------------------------------ Validación

  static String? _required(String v, String what) =>
      v.trim().isEmpty ? 'Escribe $what' : null;

  static String? _phone(String v) {
    final digits = PhoneInput.digits(v);
    if (digits.isEmpty) return 'Escribe el teléfono';
    return digits.length == PhoneInput.length
        ? null
        : 'El teléfono debe tener 10 dígitos';
  }

  static String? _optionalEmail(String v) =>
      v.trim().isEmpty ? null : AccountInput.validateEmail(v.trim());

  static String? _clabe(String v) {
    if (v.isEmpty) return null;
    return RegExp(r'^\d{18}$').hasMatch(v) ? null : 'La CLABE tiene 18 dígitos';
  }

  // ---------------------------------------------------------------- Hojas

  /// Hoja de edición genérica: un campo por [_Field]; [onSave] recibe los
  /// valores (por clave) cuando todos son válidos.
  void _editSheet(
    BuildContext context, {
    required String title,
    String? intro,
    required List<_Field> fields,
    required void Function(Map<String, String> values) onSave,
    String savedMessage = 'Cambios guardados',
  }) {
    final controllers = {
      for (final f in fields) f.key: TextEditingController(text: f.initial),
    };
    var submitted = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          String? errorOf(_Field f) =>
              f.validator?.call(controllers[f.key]!.text);
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SheetHeader(title),
                  if (intro != null) ...[
                    Text(
                      intro,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ] else
                    const SizedBox(height: 6),
                  for (final f in fields) ...[
                    TextField(
                      controller: controllers[f.key],
                      keyboardType: f.keyboard,
                      inputFormatters: f.formatters,
                      textCapitalization: f.capitalization,
                      minLines: 1,
                      maxLines: f.maxLines,
                      decoration: InputDecoration(
                        labelText: f.label,
                        hintText: f.hint,
                        helperText: f.helper,
                        helperMaxLines: 2,
                        prefixText: f.prefix,
                        suffixText: f.suffix,
                        errorMaxLines: 2,
                        errorText: submitted ? errorOf(f) : null,
                      ),
                      onChanged: (_) {
                        if (submitted) setSheetState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      final firstError = fields
                          .map(errorOf)
                          .whereType<String>()
                          .firstOrNull;
                      if (firstError != null) {
                        setSheetState(() => submitted = true);
                        showSheetMessage(ctx, firstError);
                        return;
                      }
                      onSave({
                        for (final f in fields)
                          f.key: controllers[f.key]!.text.trim(),
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(savedMessage)));
                    },
                    child: const Text('Guardar'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _editOwner(BuildContext context) => _editSheet(
    context,
    title: 'Mi nombre',
    intro: 'Aparece en tu perfil.',
    fields: [
      _Field(
        'ownerName',
        'Nombre completo *',
        initial: _s.ownerName,
        capitalization: TextCapitalization.words,
        validator: (v) => _required(v, 'tu nombre'),
      ),
    ],
    onSave: (v) => state.updateSettings(_s.copyWith(ownerName: v['ownerName'])),
  );

  void _editBusiness(BuildContext context) => _editSheet(
    context,
    title: 'Datos del negocio',
    intro:
        'Salen en el PDF de cotización, en los recibos, en los mensajes de '
        'WhatsApp y en el portal de tus clientes.',
    fields: [
      _Field(
        'bizName',
        'Nombre comercial *',
        initial: _s.bizName,
        capitalization: TextCapitalization.words,
        validator: (v) => _required(v, 'el nombre del negocio'),
      ),
      _Field(
        'bizPhone',
        'Teléfono / WhatsApp *',
        initial: _s.bizPhone,
        keyboard: TextInputType.phone,
        helper: 'Tus clientes te llaman y escriben a este número.',
        validator: _phone,
      ),
      _Field(
        'bizEmail',
        'Correo de contacto',
        initial: _s.bizEmail,
        keyboard: TextInputType.emailAddress,
        validator: _optionalEmail,
      ),
      _Field(
        'bizAddress',
        'Dirección del taller',
        initial: _s.bizAddress,
        capitalization: TextCapitalization.sentences,
        maxLines: 2,
      ),
      _Field(
        'bizHours',
        'Horario de atención',
        initial: _s.bizHours,
        hint: 'Lun a Vie 9:00–18:00 · Sáb 9:00–14:00',
        capitalization: TextCapitalization.sentences,
      ),
      _Field(
        'profileDescription',
        'Descripción',
        initial: _s.profileDescription,
        hint: 'Qué hace tu taller, en una o dos líneas',
        capitalization: TextCapitalization.sentences,
        maxLines: 3,
      ),
    ],
    onSave: (v) => state.updateSettings(
      _s.copyWith(
        bizName: v['bizName'],
        bizPhone: v['bizPhone'],
        bizEmail: v['bizEmail']!.toLowerCase(),
        bizAddress: v['bizAddress'],
        bizHours: v['bizHours'],
        profileDescription: v['profileDescription'],
      ),
    ),
  );

  void _editQuoteRules(BuildContext context) => _editSheet(
    context,
    title: 'Cotizaciones',
    fields: [
      _Field(
        'price',
        'Precio por m² sugerido *',
        initial: MoneyInput.format(_s.defaultPricePerM2),
        keyboard: MoneyInput.keyboard,
        formatters: MoneyInput.formatters,
        prefix: '\$ ',
        suffix: '/ m²',
        helper: 'Se propone al dar de alta un producto nuevo.',
        validator: (v) => (MoneyInput.parse(v) ?? 0) > 0
            ? null
            : 'Escribe un precio mayor a 0',
      ),
      _Field(
        'days',
        'Vigencia de la cotización *',
        initial: '${_s.quoteValidityDays}',
        keyboard: TextInputType.number,
        formatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(3),
        ],
        suffix: 'días',
        validator: (v) {
          final days = int.tryParse(v) ?? 0;
          return days >= 1 && days <= 365 ? null : 'Escribe de 1 a 365 días';
        },
      ),
      _Field(
        'terms',
        'Condiciones al pie del PDF',
        initial: _s.quoteTerms,
        hint: 'Ej. Anticipo del 50 % para iniciar. Instalación incluida.',
        capitalization: TextCapitalization.sentences,
        maxLines: 4,
      ),
    ],
    onSave: (v) => state.updateSettings(
      _s.copyWith(
        defaultPricePerM2: MoneyInput.parse(v['price']!),
        quoteValidityDays: int.parse(v['days']!),
        quoteTerms: v['terms'],
      ),
    ),
  );

  void _editBank(BuildContext context) => _editSheet(
    context,
    title: 'Pago por transferencia',
    intro:
        'Se incluyen en el PDF, en el recordatorio de saldo por WhatsApp y '
        'en el perfil de tus clientes. Déjalos vacíos si no aceptas '
        'transferencias.',
    fields: [
      _Field(
        'bankName',
        'Banco',
        initial: _s.bankName,
        capitalization: TextCapitalization.words,
      ),
      _Field(
        'bankHolder',
        'Titular de la cuenta',
        initial: _s.bankHolder,
        capitalization: TextCapitalization.words,
      ),
      _Field(
        'bankClabe',
        'CLABE interbancaria',
        initial: _s.bankClabe,
        keyboard: TextInputType.number,
        formatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(18),
        ],
        validator: _clabe,
      ),
    ],
    onSave: (v) => state.updateSettings(
      _s.copyWith(
        bankName: v['bankName'],
        bankHolder: v['bankHolder'],
        bankClabe: v['bankClabe'],
      ),
    ),
  );

  void _changePassword(BuildContext context) {
    final current = TextEditingController();
    final fresh = TextEditingController();
    final confirm = TextEditingController();
    var saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHeader('Cambiar contraseña'),
              const SizedBox(height: 6),
              TextField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña actual',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: fresh,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Nueva contraseña',
                  helperText: 'Al menos ${AccountInput.minPassword} caracteres',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirm,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Repite la nueva contraseña',
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (fresh.text != confirm.text) {
                          showSheetMessage(
                            ctx,
                            'Las contraseñas nuevas no coinciden',
                          );
                          return;
                        }
                        setSheetState(() => saving = true);
                        final error = await state.changeMyPassword(
                          current.text,
                          fresh.text,
                        );
                        if (!ctx.mounted) return;
                        setSheetState(() => saving = false);
                        if (error != null) {
                          showSheetMessage(ctx, error);
                          return;
                        }
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Contraseña actualizada'),
                          ),
                        );
                      },
                child: Text(saving ? 'Guardando…' : 'Cambiar contraseña'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Se cerrará la sesión actual en este dispositivo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cancelled,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              state.logout();
            },
            child: const Text('Salir'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Vista

  @override
  Widget build(BuildContext context) {
    final email = state.session?.email ?? '';

    return Scaffold(
      appBar: const TopBar(title: 'Mi perfil', showAvatar: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _header(context),
          const SizedBox(height: 24),

          const SectionHeader('Mi cuenta'),
          ListBox(
            children: [
              _row(
                Icons.person_outline,
                'Nombre',
                // Arriba se muestra "Administrador" mientras no haya nombre;
                // aquí se invita a capturarlo.
                _s.ownerName.trim().isEmpty
                    ? 'Toca para agregar tu nombre'
                    : _s.ownerName.trim(),
                () => _editOwner(context),
              ),
              BoxRow(
                leading: const IconBadge(Icons.alternate_email),
                title: 'Correo de acceso',
                subtitle: email.isEmpty ? 'Sin sesión' : email,
              ),
              _row(
                Icons.lock_outline,
                'Contraseña',
                'Cambiar la contraseña de acceso',
                () => _changePassword(context),
              ),
            ],
          ),
          const SizedBox(height: 24),

          const SectionHeader('Negocio'),
          ListBox(
            children: [
              _row(
                Icons.storefront_outlined,
                _s.bizName,
                [
                  _s.bizPhone,
                  if (_s.bizEmail.isNotEmpty) _s.bizEmail,
                ].join(' · '),
                () => _editBusiness(context),
              ),
              _row(
                Icons.place_outlined,
                'Dirección y horario',
                [
                  _orDash(_s.bizAddress),
                  if (_s.bizHours.isNotEmpty) _s.bizHours,
                ].join('\n'),
                () => _editBusiness(context),
              ),
            ],
          ),
          const SizedBox(height: 24),

          const SectionHeader('Cotizaciones y pagos'),
          ListBox(
            children: [
              _row(
                Icons.straighten,
                'Precio por m² sugerido',
                '${AppState.formatMXN(_s.defaultPricePerM2)} / m²',
                () => _editQuoteRules(context),
              ),
              _row(
                Icons.event_outlined,
                'Vigencia y condiciones',
                '${_s.quoteValidityDays} días'
                    '${_s.quoteTerms.isEmpty ? '' : ' · ${_s.quoteTerms}'}',
                () => _editQuoteRules(context),
              ),
              _row(
                Icons.account_balance_outlined,
                'Pago por transferencia',
                _s.hasBankInfo
                    ? _s.bankLines.join(' · ')
                    : 'Agrega banco y CLABE',
                () => _editBank(context),
              ),
            ],
          ),
          const SizedBox(height: 24),

          const SectionHeader('Preferencias'),
          ListBox(
            children: [
              BoxRow(
                leading: const IconBadge(Icons.dark_mode_outlined),
                title: 'Modo oscuro',
                trailing: Switch.adaptive(
                  value: _s.dark,
                  activeTrackColor: AppColors.navy,
                  onChanged: state.toggleDarkMode,
                ),
                onTap: () => state.toggleDarkMode(!_s.dark),
              ),
              BoxRow(
                leading: const IconBadge(Icons.tips_and_updates_outlined),
                title: 'Asesor de cotización',
                subtitle: 'Sugerencias por pieza y chat técnico',
                trailing: Switch.adaptive(
                  value: _s.ai,
                  activeTrackColor: AppColors.navy,
                  onChanged: (v) => state.updateSettings(_s.copyWith(ai: v)),
                ),
                onTap: () => state.updateSettings(_s.copyWith(ai: !_s.ai)),
              ),
            ],
          ),
          const SizedBox(height: 24),

          ListBox(
            children: [
              BoxRow(
                leading: IconBadge(
                  Icons.logout,
                  color: AppColors.cancelled,
                  background: AppColors.cancelledBg,
                ),
                title: 'Cerrar sesión',
                trailing: _chevron,
                onTap: () => _confirmLogout(context),
              ),
            ],
          ),

          // Solo en pruebas: en la app publicada no debe poder borrarse todo.
          if (kDebugMode) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Restaurar datos de demostración (pruebas)'),
              onPressed: () {
                state.resetData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Datos de demostración restaurados'),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  /// Encabezado: foto (tocarla la cambia), nombre, cargo y descripción.
  Widget _header(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Cambiar foto de perfil',
            child: GestureDetector(
              onTap: () => showProfilePhotoOptions(
                context,
                currentUrl: _s.avatarUrl,
                onSave: (url) =>
                    state.updateSettings(_s.copyWith(avatarUrl: url)),
              ),
              child: Stack(
                children: [
                  AvatarWidget(
                    name: _ownerName,
                    size: 64,
                    imageUrl: _s.avatarUrl,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.navy,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.card, width: 2),
                      ),
                      child: Icon(
                        Icons.photo_camera_outlined,
                        size: 12,
                        color: AppColors.onInk,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _ownerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Propietario · ${_s.bizName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                if (_s.profileDescription.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _s.profileDescription,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: AppColors.textDark),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Renglón editable: ícono, título, valor actual y flecha.
  Widget _row(IconData icon, String title, String value, VoidCallback onTap) {
    return BoxRow(
      leading: IconBadge(icon),
      title: title,
      subtitle: value,
      trailing: _chevron,
      onTap: onTap,
    );
  }

  Widget get _chevron => Icon(Icons.chevron_right, color: AppColors.textMuted);
}

/// Un campo de la hoja de edición.
class _Field {
  final String key;
  final String label;
  final String initial;
  final String? hint;
  final String? helper;
  final String? prefix;
  final String? suffix;
  final TextInputType? keyboard;
  final List<TextInputFormatter>? formatters;
  final TextCapitalization capitalization;
  final int maxLines;
  final String? Function(String value)? validator;

  const _Field(
    this.key,
    this.label, {
    this.initial = '',
    this.hint,
    this.helper,
    this.prefix,
    this.suffix,
    this.keyboard,
    this.formatters,
    this.capitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.validator,
  });
}
