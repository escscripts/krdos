import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});
  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _display = '0';
  String _expression = '';
  double? _prev;
  String? _op;
  bool _justEvaluated = false;
  bool _isError = false;

  static const _ops = {'+', '-', '×', '÷', '%', '^'};

  void _press(String key) {
    setState(() {
      _isError = false;
      if (key == 'C') {
        _display = '0'; _expression = ''; _prev = null; _op = null; _justEvaluated = false;
        return;
      }
      if (key == '?') {
        if (_display.length > 1) {
          _display = _display.substring(0, _display.length - 1);
        } else {
          _display = '0';
        }
        _justEvaluated = false;
        return;
      }
      if (key == '±') {
        final v = double.tryParse(_display);
        if (v != null) _display = _fmt(-v);
        return;
      }
      if (key == '?') {
        final v = double.tryParse(_display) ?? 0;
        if (v < 0) { _isError = true; _display = 'Error'; return; }
        _display = _fmt(math.sqrt(v));
        _expression = '?(${_fmt(v)}) =';
        _justEvaluated = true;
        return;
      }
      if (key == 'x²') {
        final v = double.tryParse(_display) ?? 0;
        _expression = '(${_fmt(v)})² =';
        _display = _fmt(v * v);
        _justEvaluated = true;
        return;
      }
      if (key == '1/x') {
        final v = double.tryParse(_display) ?? 0;
        if (v == 0) { _isError = true; _display = 'Error'; return; }
        _expression = '1/(${_fmt(v)}) =';
        _display = _fmt(1 / v);
        _justEvaluated = true;
        return;
      }
      if (_ops.contains(key)) {
        _prev = double.tryParse(_display);
        _op = key;
        _expression = '${_display} $key';
        _justEvaluated = false;
        _display = '0';
        return;
      }
      if (key == '=') {
        if (_prev != null && _op != null) {
          final b = double.tryParse(_display) ?? 0;
          final result = _evaluate(_prev!, _op!, b);
          _expression = '${_fmt(_prev!)} $_op ${_fmt(b)} =';
          if (result == null) { _isError = true; _display = 'Error'; }
          else { _display = _fmt(result); }
          _prev = null; _op = null; _justEvaluated = true;
        }
        return;
      }
  // Digit or decimal
      if (_justEvaluated) { _display = '0'; _justEvaluated = false; }
      if (key == '.') {
        if (!_display.contains('.')) _display += '.';
        return;
      }
      _display = _display == '0' ? key : _display + key;
      if (_display.length > 15) _display = _display.substring(0, 15);
    });
  }

  double? _evaluate(double a, String op, double b) {
    switch (op) {
      case '+': return a + b;
      case '-': return a - b;
      case '×': return a * b;
      case '÷': return b == 0 ? null : a / b;
      case '%': return b == 0 ? null : a % b;
      case '^': return math.pow(a, b).toDouble();
    }
    return null;
  }

  String _fmt(double v) {
    if (v == v.truncate()) return v.truncate().toString();
    final s = v.toStringAsPrecision(10).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return s.length > 14 ? v.toStringAsExponential(6) : s;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: Column(children: [
  // Display
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_expression, style: TextStyle(
              color: AppTheme.textSecondary, fontSize: 13,
            ), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                _isError ? 'Error' : _display,
                style: TextStyle(
                  color: _isError ? AppTheme.danger : AppTheme.textPrimary,
                  fontSize: 48,
                  fontWeight: FontWeight.w300,
                  letterSpacing: -1,
                ),
              ),
            ),
          ]),
        ),
  // Keypad
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              _row(['C', 'Del', '%', '÷']),
              _row(['7', '8', '9', '×']),
              _row(['4', '5', '6', '-']),
              _row(['1', '2', '3', '+']),
              _row(['±', '0', '.', '=']),
              const SizedBox(height: 6),
              Row(children: [
                _key('?', flex: 1),
                const SizedBox(width: 8),
                _key('x²', flex: 1),
                const SizedBox(width: 8),
                _key('1/x', flex: 1),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _row(List<String> keys) => Expanded(
    child: Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: keys.map((k) => _key(k)).toList()),
    ),
  );

  Widget _key(String label, {int flex = 1}) {
    final isOp = _ops.contains(label) || label == '=';
    final isDanger = label == 'C' || label == '?';
    final isEquals = label == '=';
    Color bg;
    Color fg;
    if (isEquals) {
      bg = AppTheme.accent;
      fg = Colors.white;
    } else if (isOp) {
      bg = AppTheme.accentDim;
      fg = AppTheme.accent;
    } else if (isDanger) {
      bg = const Color(0xFF1A0A0A);
      fg = AppTheme.danger;
    } else {
      bg = AppTheme.surfaceAlt;
      fg = AppTheme.textPrimary;
    }
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _press(label);
          },
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border.withValues(alpha: 0.4)),
            ),
            alignment: Alignment.center,
            child: Text(label, style: TextStyle(
              color: fg, fontSize: 20, fontWeight: FontWeight.w500,
            )),
          ),
        ),
      ),
    );
  }
}