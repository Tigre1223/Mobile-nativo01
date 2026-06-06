import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import 'database_factory.dart'
    if (dart.library.js_interop) 'database_factory_web.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => FinanceViewModel()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Controle Financeiro',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const LoginView(),
        '/register': (_) => const RegisterView(),
        '/dashboard': (_) => const DashboardView(),
        '/analysis': (_) => const AnalysisView(),
      },
    );
  }
}

enum TransactionType { income, expense }

class UserModel {
  final int id;
  final String name;
  final String email;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
  });

  factory UserModel.fromMap(Map<String, Object?> map) {
    return UserModel(
      id: map['id'] as int,
      name: map['name'] as String,
      email: map['email'] as String,
    );
  }
}

class TransactionModel {
  final int? id;
  final int userId;
  final String title;
  final double value;
  final DateTime date;
  final TransactionType type;

  const TransactionModel({
    this.id,
    required this.userId,
    required this.title,
    required this.value,
    required this.date,
    required this.type,
  });

  bool get isIncome => type == TransactionType.income;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'value': value,
      'date': date.toIso8601String(),
      'type': isIncome ? 'income' : 'expense',
    };
  }

  factory TransactionModel.fromMap(Map<String, Object?> map) {
    return TransactionModel(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      title: map['title'] as String,
      value: (map['value'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      type: map['type'] == 'income'
          ? TransactionType.income
          : TransactionType.expense,
    );
  }

  TransactionModel copyWith({
    int? id,
    int? userId,
    String? title,
    double? value,
    DateTime? date,
    TransactionType? type,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      value: value ?? this.value,
      date: date ?? this.date,
      type: type ?? this.type,
    );
  }
}

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    final factory = await createDatabaseFactory();
    final dbPath = await factory.getDatabasesPath();
    final path = p.join(dbPath, 'controle_financeiro.db');

    _database = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE users(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              email TEXT NOT NULL UNIQUE,
              password TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE transactions(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id INTEGER NOT NULL,
              title TEXT NOT NULL,
              value REAL NOT NULL,
              date TEXT NOT NULL,
              type TEXT NOT NULL,
              FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
            )
          ''');
        },
      ),
    );

    return _database!;
  }
}

class UserRepository {
  final AppDatabase _database = AppDatabase.instance;

  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final db = await _database.database;

    final id = await db.insert(
      'users',
      {'name': name, 'email': email, 'password': password},
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    return UserModel(id: id, name: name, email: email);
  }

  Future<UserModel?> login({
    required String email,
    required String password,
  }) async {
    final db = await _database.database;
    final result = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return UserModel.fromMap(result.first);
  }
}

class TransactionRepository {
  final AppDatabase _database = AppDatabase.instance;

  Future<List<TransactionModel>> findByUser(int userId) async {
    final db = await _database.database;
    final result = await db.query(
      'transactions',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'date DESC, id DESC',
    );

    return result.map(TransactionModel.fromMap).toList();
  }

  Future<void> insert(TransactionModel transaction) async {
    final db = await _database.database;
    await db.insert('transactions', transaction.toMap());
  }

  Future<void> update(TransactionModel transaction) async {
    final db = await _database.database;
    await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ? AND user_id = ?',
      whereArgs: [transaction.id, transaction.userId],
    );
  }

  Future<void> delete(int id, int userId) async {
    final db = await _database.database;
    await db.delete(
      'transactions',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }
}

class AuthViewModel extends ChangeNotifier {
  final UserRepository _repository = UserRepository();

  UserModel? _user;
  bool _loading = false;
  String? _error;

  UserModel? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get loading => _loading;
  String? get error => _error;

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _error = null;

    try {
      final user = await _repository.login(email: email, password: password);
      if (user == null) {
        _error = 'E-mail ou senha inválidos.';
        return false;
      }

      _user = user;
      return true;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register(String name, String email, String password) async {
    _setLoading(true);
    _error = null;

    try {
      _user = await _repository.register(
        name: name,
        email: email,
        password: password,
      );
      return true;
    } on DatabaseException catch (error) {
      _error = error.isUniqueConstraintError()
          ? 'Este e-mail já está cadastrado.'
          : 'Não foi possível cadastrar o usuário.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void logout() {
    _user = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }
}

class FinanceViewModel extends ChangeNotifier {
  final TransactionRepository _repository = TransactionRepository();

  List<TransactionModel> _transactions = [];
  bool _loading = false;

  List<TransactionModel> get transactions => List.unmodifiable(_transactions);
  bool get loading => _loading;

  double get balance => _transactions.fold(
        0,
        (sum, item) => item.isIncome ? sum + item.value : sum - item.value,
      );

  double get income => _transactions
      .where((transaction) => transaction.isIncome)
      .fold(0, (sum, transaction) => sum + transaction.value);

  double get expense => _transactions
      .where((transaction) => !transaction.isIncome)
      .fold(0, (sum, transaction) => sum + transaction.value);

  Future<void> loadTransactions(int userId) async {
    _loading = true;
    notifyListeners();

    _transactions = await _repository.findByUser(userId);
    _loading = false;
    notifyListeners();
  }

  Future<void> saveTransaction(TransactionModel transaction) async {
    if (transaction.id == null) {
      await _repository.insert(transaction);
    } else {
      await _repository.update(transaction);
    }

    await loadTransactions(transaction.userId);
  }

  Future<void> deleteTransaction(TransactionModel transaction) async {
    await _repository.delete(transaction.id!, transaction.userId);
    await loadTransactions(transaction.userId);
  }

  void clear() {
    _transactions = [];
    notifyListeners();
  }
}

class Validators {
  static String? requiredText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obrigatório.';
    }
    return null;
  }

  static String? email(String? value) {
    final empty = requiredText(value);
    if (empty != null) return empty;

    final regex = RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!regex.hasMatch(value!.trim())) {
      return 'Informe um e-mail válido.';
    }
    return null;
  }

  static String? money(String? value) {
    final empty = requiredText(value);
    if (empty != null) return empty;

    final normalized = value!.replaceAll(',', '.');
    final parsed = double.tryParse(normalized);
    if (parsed == null || parsed <= 0) {
      return 'Informe um valor numérico maior que zero.';
    }
    return null;
  }
}

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthViewModel>();
    final finance = context.read<FinanceViewModel>();
    final success = await auth.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      await finance.loadTransactions(auth.user!.id);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/dashboard');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(auth.error ?? 'Falha no login.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.account_balance_wallet, size: 64),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Senha',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: Validators.requiredText,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: auth.loading ? null : _submit,
                  child: auth.loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Entrar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  child: const Text('Criar conta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthViewModel>();
    final finance = context.read<FinanceViewModel>();
    final success = await auth.register(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      finance.clear();
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/dashboard',
        (route) => false,
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(auth.error ?? 'Falha no cadastro.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  border: OutlineInputBorder(),
                ),
                validator: Validators.requiredText,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Senha',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: Validators.requiredText,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: auth.loading ? null : _submit,
                child: auth.loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Cadastrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  void _openForm(BuildContext context, TransactionModel? transaction) {
    final user = context.read<AuthViewModel>().user;
    if (user == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TransactionFormSheet(
        userId: user.id,
        transaction: transaction,
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    context.read<AuthViewModel>().logout();
    context.read<FinanceViewModel>().clear();
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final vm = context.watch<FinanceViewModel>();
    final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      appBar: AppBar(
        title: Text('Olá, ${auth.user?.name ?? 'usuário'}'),
        actions: [
          IconButton(
            tooltip: 'Análise',
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () => Navigator.pushNamed(context, '/analysis'),
          ),
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Transação'),
      ),
      body: vm.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                final user = context.read<AuthViewModel>().user;
                if (user != null) {
                  await context.read<FinanceViewModel>().loadTransactions(
                        user.id,
                      );
                }
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SummaryCard(
                    balance: formatter.format(vm.balance),
                    income: formatter.format(vm.income),
                    expense: formatter.format(vm.expense),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Transações',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (vm.transactions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: Center(
                        child: Text('Nenhuma transação cadastrada.'),
                      ),
                    )
                  else
                    ...vm.transactions.map(
                      (transaction) => TransactionTile(
                        transaction: transaction,
                        formatter: formatter,
                        onEdit: () => _openForm(context, transaction),
                        onDelete: () => context
                            .read<FinanceViewModel>()
                            .deleteTransaction(transaction),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  final String balance;
  final String income;
  final String expense;

  const SummaryCard({
    super.key,
    required this.balance,
    required this.income,
    required this.expense,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saldo total', style: Theme.of(context).textTheme.labelLarge),
            Text(balance, style: Theme.of(context).textTheme.headlineMedium),
            const Divider(height: 28),
            Row(
              children: [
                Expanded(
                  child: Text('Receitas\n$income'),
                ),
                Expanded(
                  child: Text('Despesas\n$expense'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final NumberFormat formatter;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TransactionTile({
    super.key,
    required this.transaction,
    required this.formatter,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = transaction.isIncome ? Colors.green : Colors.red;
    final icon = transaction.isIncome ? Icons.trending_up : Icons.trending_down;
    final date = DateFormat('dd/MM/yyyy').format(transaction.date);

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(transaction.title),
        subtitle: Text(date),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatter.format(transaction.value),
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Alterar')),
                PopupMenuItem(value: 'delete', child: Text('Remover')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TransactionFormSheet extends StatefulWidget {
  final int userId;
  final TransactionModel? transaction;

  const TransactionFormSheet({
    super.key,
    required this.userId,
    this.transaction,
  });

  @override
  State<TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends State<TransactionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _valueController = TextEditingController();
  late DateTime _date;
  late TransactionType _type;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    _titleController.text = transaction?.title ?? '';
    _valueController.text = transaction?.value.toStringAsFixed(2) ?? '';
    _date = transaction?.date ?? DateTime.now();
    _type = transaction?.type ?? TransactionType.income;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final value = double.parse(_valueController.text.replaceAll(',', '.'));
    final transaction = TransactionModel(
      id: widget.transaction?.id,
      userId: widget.userId,
      title: _titleController.text.trim(),
      value: value,
      date: _date,
      type: _type,
    );

    await context.read<FinanceViewModel>().saveTransaction(transaction);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.transaction == null ? 'Nova transação' : 'Alterar',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título',
                border: OutlineInputBorder(),
              ),
              validator: Validators.requiredText,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _valueController,
              decoration: const InputDecoration(
                labelText: 'Valor',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: Validators.money,
            ),
            const SizedBox(height: 12),
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text('Entrada'),
                  icon: Icon(Icons.add_circle_outline),
                ),
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text('Saída'),
                  icon: Icon(Icons.remove_circle_outline),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selected) {
                setState(() => _type = selected.first);
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _selectDate,
              icon: const Icon(Icons.calendar_today),
              label: Text(DateFormat('dd/MM/yyyy').format(_date)),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}

class AnalysisView extends StatelessWidget {
  const AnalysisView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FinanceViewModel>();
    final total = vm.income + vm.expense;
    final expenseRatio = total == 0 ? 0.0 : vm.expense / total;
    final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      appBar: AppBar(title: const Text('Análise Financeira')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Uso do orçamento',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: expenseRatio),
                    const SizedBox(height: 12),
                    Text(
                      'Despesas representam ${(expenseRatio * 100).toStringAsFixed(1)}% do total movimentado.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long),
                title: const Text('Total de transações'),
                trailing: Text('${vm.transactions.length}'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_balance),
                title: const Text('Saldo atual'),
                trailing: Text(formatter.format(vm.balance)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
