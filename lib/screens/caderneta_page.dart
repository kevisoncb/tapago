import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/client_match.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../utils/masks.dart';
import 'bills_page.dart';
import 'contact_history_page.dart';

class CadernetaPage extends StatefulWidget {
  const CadernetaPage({super.key, this.initialTab = 0, this.focusSearch = false});

  final int initialTab;
  final bool focusSearch;

  @override
  State<CadernetaPage> createState() => _CadernetaPageState();
}

class _CadernetaPageState extends State<CadernetaPage> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needle = _query.text;

    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Caderneta'),
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.mutedDark,
            indicatorColor: AppColors.primary,
            labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
            tabs: const [
              Tab(text: 'Clientes'),
              Tab(text: 'Boletos'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: TextField(
                controller: _query,
                autofocus: widget.focusSearch,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Buscar pessoa, empresa ou telefone',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: needle.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _query.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _ClientesTab(needle: needle),
                  _FornecedoresTab(needle: needle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientesTab extends StatelessWidget {
  const _ClientesTab({required this.needle});

  final String needle;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    final contacts = groupContacts(state.debts)
        .where((contact) => contactMatchesQuery(contact, needle))
        .toList();

    return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                contacts.isEmpty
                    ? 'Nenhum contato encontrado.'
                    : '${contacts.length} ${contacts.length == 1 ? 'contato' : 'contatos'}',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color: AppColors.mutedDark,
                ),
              ),
            ),
          ),
          Expanded(
            child: contacts.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        state.debts.isEmpty
                            ? 'A caderneta ainda está vazia.'
                            : 'Nada com esse nome ou telefone.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.mutedDark,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    itemCount: contacts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      return CadernetaContactTile(
                        contact: contact,
                        saldo: contact.saldoAbertoOf(state.saldoOf),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ContactHistoryPage(
                                contactKey: contact.key,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      );
  }
}

class _Fornecedor {
  _Fornecedor(this.nome);

  final String nome;
  final List<Bill> bills = [];

  Iterable<Bill> get abertos => bills.where((bill) => !bill.pago);

  double get aberto => abertos.fold(0, (sum, bill) => sum + bill.valor);

  double get vencido => abertos
      .where((bill) => bill.isOverdue)
      .fold(0, (sum, bill) => sum + bill.valor);
}

class _FornecedoresTab extends StatelessWidget {
  const _FornecedoresTab({required this.needle});

  final String needle;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    final premium = state.user.premiumAtivo;
    final byKey = <String, _Fornecedor>{};
    for (final bill in state.bills) {
      final key = bill.fornecedor.trim().toLowerCase();
      byKey.putIfAbsent(key, () => _Fornecedor(bill.fornecedor.trim())).bills.add(bill);
    }
    final query = needle.trim().toLowerCase();
    final fornecedores = byKey.values
        .where((item) => query.isEmpty || item.nome.toLowerCase().contains(query))
        .toList()
      ..sort((a, b) {
        final atraso = (b.vencido > 0 ? 1 : 0) - (a.vencido > 0 ? 1 : 0);
        if (atraso != 0) return atraso;
        final aberto = b.aberto.compareTo(a.aberto);
        if (aberto != 0) return aberto;
        return a.nome.compareTo(b.nome);
      });

    if (fornecedores.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            !premium
                ? 'Boletos a pagar é Premium. Cadastre o boleto do fornecedor e o Pagô avisa antes de vencer.'
                : state.bills.isEmpty
                    ? 'Nenhum boleto ainda. Toque em Boletos a pagar no menu do Pagô!.'
                    : 'Nenhuma empresa com esse nome.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(color: AppColors.mutedDark),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      itemCount: fornecedores.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = fornecedores[index];
        final n = item.abertos.length;
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => BillsPage(fornecedor: item.nome)),
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF0F3F8)),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: Color(0xFFF1F5F9),
                    child: Icon(Icons.storefront_outlined, color: AppColors.text, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.nome,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          n == 0
                              ? 'Tudo pago'
                              : '$n ${n == 1 ? 'boleto em aberto' : 'boletos em aberto'}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.mutedDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        n == 0 ? 'Pago' : Money.full(item.aberto),
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          color: n == 0 ? AppColors.success : AppColors.text,
                        ),
                      ),
                      if (item.vencido > 0)
                        Text(
                          '${Money.full(item.vencido)} vencido',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.danger,
                          ),
                        ),
                    ],
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class CadernetaContactTile extends StatelessWidget {
  const CadernetaContactTile({
    super.key,
    required this.contact,
    required this.saldo,
    required this.onTap,
    this.padded = true,
  });

  final CadernetaContact contact;
  final double saldo;
  final VoidCallback onTap;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    final quitada = !contact.temAberto(state.saldoOf);
    final phone = contact.telefone.trim().isEmpty
        ? 'Sem WhatsApp'
        : formatPhoneBr(contact.telefone);
    final n = contact.lancamentos;
    final extra = n == 1 ? '1 lançamento' : '$n lançamentos';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(padded ? 20 : 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(padded ? 20 : 0),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          decoration: padded
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF0F3F8)),
                )
              : null,
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  initialsOf(contact.nome),
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.nome,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$phone · $extra',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.mutedDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    quitada ? 'Quitado' : Money.full(saldo),
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: quitada ? AppColors.success : AppColors.text,
                    ),
                  ),
                  if (!quitada && contact.temAtraso(state.saldoOf))
                    Text(
                      'Em atraso',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger,
                      ),
                    ),
                ],
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
