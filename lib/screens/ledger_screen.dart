import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/ledger_repository.dart';
import '../models/ledger.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  final _repo = LedgerRepository.instance;
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = DateTime.now();
    _repo.addListener(_onChange);
    _repo.load();
  }

  @override
  void dispose() {
    _repo.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta, 1);
    });
  }

  Future<void> _openEdit({LedgerEntry? entry}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LedgerEditScreen(entry: entry, defaultDate: _month),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final monthEntries = _repo.forMonth(_month);
    final summary = _repo.summary(_month);
    final f = NumberFormat('#,###', 'ko_KR');

    return Scaffold(
      appBar: AppBar(title: const Text('가계부')),
      body: SafeArea(
        child: Column(
          children: [
            // 월 선택 + 합계
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded),
                          onPressed: () => _changeMonth(-1),
                        ),
                        Text(
                          DateFormat('y년 M월', 'ko_KR').format(_month),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded),
                          onPressed: () => _changeMonth(1),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      children: [
                        _SummaryCell(
                          label: '입금',
                          amount: summary.income,
                          color: LedgerType.income.color,
                          formatter: f,
                        ),
                        _SummaryCell(
                          label: '출금',
                          amount: summary.expense,
                          color: LedgerType.expense.color,
                          formatter: f,
                        ),
                        _SummaryCell(
                          label: '잔액',
                          amount: summary.balance,
                          color: scheme.primary,
                          formatter: f,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // 항목 리스트
            Expanded(
              child: monthEntries.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text(
                          '이번 달 항목이 없습니다.\n오른쪽 아래 [+ 추가]로 입력해 보세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      itemCount: monthEntries.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final e = monthEntries[i];
                        return _LedgerTile(
                          entry: e,
                          formatter: f,
                          onTap: () => _openEdit(entry: e),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEdit(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('추가'),
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.label,
    required this.amount,
    required this.color,
    required this.formatter,
  });
  final String label;
  final int amount;
  final Color color;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )),
          const SizedBox(height: 4),
          Text(
            '${formatter.format(amount)}원',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  const _LedgerTile({
    required this.entry,
    required this.formatter,
    required this.onTap,
  });
  final LedgerEntry entry;
  final NumberFormat formatter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: entry.type.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(entry.type.icon, color: entry.type.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.note.isEmpty ? entry.type.label : entry.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('M월 d일 (E)', 'ko_KR').format(entry.date),
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${entry.type == LedgerType.expense ? '-' : '+'}${formatter.format(entry.amount)}원',
                style: TextStyle(
                  color: entry.type.color,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LedgerEditScreen extends StatefulWidget {
  const LedgerEditScreen({super.key, this.entry, this.defaultDate});
  final LedgerEntry? entry;
  final DateTime? defaultDate;

  @override
  State<LedgerEditScreen> createState() => _LedgerEditScreenState();
}

class _LedgerEditScreenState extends State<LedgerEditScreen> {
  late LedgerType _type;
  late DateTime _date;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _type = e?.type ?? LedgerType.expense;
    _date = e?.date ?? widget.defaultDate ?? DateTime.now();
    _amountCtrl = TextEditingController(text: e == null ? '' : '${e.amount}');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('ko', 'KR'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final amount = int.tryParse(_amountCtrl.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('올바른 금액을 입력해 주세요.')),
      );
      return;
    }
    final note = _noteCtrl.text.trim();
    final repo = LedgerRepository.instance;
    if (_isEditing) {
      await repo.update(widget.entry!.copyWith(
        date: _date,
        type: _type,
        amount: amount,
        note: note,
      ));
    } else {
      await repo.add(date: _date, type: _type, amount: amount, note: note);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        title: const Text('삭제하시겠어요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;
    await LedgerRepository.instance.remove(widget.entry!.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('y년 M월 d일 (E)', 'ko_KR').format(_date);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '항목 수정' : '항목 추가'),
        actions: [
          if (_isEditing)
            IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: _delete),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Label('구분'),
              SegmentedButton<LedgerType>(
                segments: const [
                  ButtonSegment(
                    value: LedgerType.income,
                    label: Text('입금'),
                    icon: Icon(Icons.arrow_circle_down_rounded),
                  ),
                  ButtonSegment(
                    value: LedgerType.expense,
                    label: Text('출금'),
                    icon: Icon(Icons.arrow_circle_up_rounded),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) =>
                    setState(() => _type = s.first),
              ),
              const SizedBox(height: 16),
              const _Label('날짜'),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(20),
                child: InputDecorator(
                  decoration:
                      const InputDecoration(prefixIcon: Icon(Icons.event)),
                  child: Text(dateText),
                ),
              ),
              const SizedBox(height: 16),
              const _Label('금액 (원)'),
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  hintText: '예: 12000',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),
              const SizedBox(height: 16),
              const _Label('내역'),
              TextField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: '예: 점심 식대, 월급 등',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(_isEditing ? '수정 완료' : '추가하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF555566),
        ),
      ),
    );
  }
}
