import 'package:flutter/material.dart';

class CardPaymentResult {
  final String brand; // "visa", "mastercard", etc (best-effort)
  final String last4;
  final String transactionId; // fake/simulated id

  CardPaymentResult({
    required this.brand,
    required this.last4,
    required this.transactionId,
  });

  Map<String, dynamic> toMap() => {
    'brand': brand,
    'last4': last4,
    'transactionId': transactionId,
  };
}

/// Simulated card payment screen (NO real processing).
/// Shows a 3% service fee breakdown (for paid events) before payment.
class CardPaymentScreen extends StatefulWidget {
  /// Ticket subtotal (before fee). For your current flow, this equals event price.
  final int subtotalJod;

  /// 3% service fee rate (default 0.03)
  final double feeRate;

  const CardPaymentScreen({
    super.key,
    required this.subtotalJod,
    this.feeRate = 0.03,
  });

  @override
  State<CardPaymentScreen> createState() => _CardPaymentScreenState();
}

class _CardPaymentScreenState extends State<CardPaymentScreen> {
  final _formKey = GlobalKey<FormState>();

  final _cardCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _expCtrl = TextEditingController(); // MM/YY
  final _cvvCtrl = TextEditingController();

  bool _paying = false;

  @override
  void dispose() {
    _cardCtrl.dispose();
    _nameCtrl.dispose();
    _expCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  String _digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  bool _luhnValid(String input) {
    final s = _digitsOnly(input);
    if (s.length < 13) return false;
    int sum = 0;
    bool alt = false;
    for (int i = s.length - 1; i >= 0; i--) {
      int n = int.parse(s[i]);
      if (alt) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alt = !alt;
    }
    return sum % 10 == 0;
  }

  String _guessBrand(String cardNumber) {
    final s = _digitsOnly(cardNumber);
    if (s.startsWith('4')) return 'visa';
    if (s.startsWith('5')) return 'mastercard';
    if (s.startsWith('34') || s.startsWith('37')) return 'amex';
    return 'card';
  }

  bool _expiryValid(String exp) {
    final raw = exp.trim();
    final m = RegExp(r'^(\d{2})\/(\d{2})$').firstMatch(raw);
    if (m == null) return false;

    final mm = int.tryParse(m.group(1)!) ?? 0;
    final yy = int.tryParse(m.group(2)!) ?? -1;
    if (mm < 1 || mm > 12) return false;

    final year = 2000 + yy;
    final now = DateTime.now();
    final expDate = DateTime(year, mm + 1, 0, 23, 59, 59);
    return expDate.isAfter(now);
  }

  String _fmt(double v) => v.toStringAsFixed(2);

  double get _subtotal => widget.subtotalJod.toDouble();

  double get _fee => (_subtotal * widget.feeRate);

  double get _total => _subtotal + _fee;

  Future<void> _pay() async {
    if (_paying) return;

    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _paying = true);

    try {
      await Future.delayed(const Duration(milliseconds: 700));

      final digits = _digitsOnly(_cardCtrl.text);
      final last4 = digits.substring(digits.length - 4);
      final brand = _guessBrand(digits);

      final txId = 'SIM-${DateTime.now().millisecondsSinceEpoch}-$last4';

      if (!mounted) return;
      Navigator.pop(
        context,
        CardPaymentResult(brand: brand, last4: last4, transactionId: txId),
      );
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pay by card')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        const ListTile(
                          leading: Icon(Icons.credit_card),
                          title: Text('Credit card (Visa only)'),
                          subtitle: Text('This is a simulated payment.'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        const Divider(height: 14),
                        _MoneyRow(label: 'Ticket price', value: '${_fmt(_subtotal)} JD'),
                        const SizedBox(height: 6),
                        _MoneyRow(label: 'Service fee (3%)', value: '+${_fmt(_fee)} JD'),
                        const SizedBox(height: 10),
                        const Divider(height: 14),
                        _MoneyRow(
                          label: 'Total to pay',
                          value: '${_fmt(_total)} JD',
                          bold: true,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Note: A 3% service fee is added to paid bookings.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.yellowAccent),
                          textAlign: TextAlign.left,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Cardholder name'),
                  validator: (v) => (v == null || v.trim().length < 3) ? 'Enter a valid name' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _cardCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Card number',
                    hintText: 'XXXX XXXX XXXX XXXX',
                  ),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return 'Required';
                    if (!_luhnValid(s)) return 'Invalid card number';
                    final digits = _digitsOnly(s);
                    if (!digits.startsWith('4')) return 'Visa cards only';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _expCtrl,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Expiry (MM/YY)',
                          hintText: '08/28',
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return 'Required';
                          if (!_expiryValid(s)) return 'Invalid expiry';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _cvvCtrl,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'CVV',
                          hintText: '123',
                        ),
                        validator: (v) {
                          final s = _digitsOnly((v ?? '').trim());
                          if (s.length < 3 || s.length > 4) return 'Invalid CVV';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _paying ? null : _pay,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: _paying
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text(
                        'Pay & confirm booking',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),
                Text(
                  'Note: This is a simulated payment for the graduation project (no real charge).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white60),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _MoneyRow({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? const TextStyle(fontWeight: FontWeight.w900)
        : const TextStyle(fontWeight: FontWeight.w700);

    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        Text(value, style: style),
      ],
    );
  }
}
