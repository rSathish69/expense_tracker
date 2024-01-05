import 'package:expense_tracker/firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

final expensesProvider = StateNotifierProvider<ExpensesNotifier, List<Expense>>(
    (ref) => ExpensesNotifier(ref));

class Expense {
  final String id;
  final String title;
  final double amount;

  Expense({required this.id, required this.title, required this.amount});
}

class ExpensesNotifier extends StateNotifier<List<Expense>> {
  ExpensesNotifier(Ref read) : super([]) {
    _initExpenses(read);
  }

  Future<void> _initExpenses(Ref ref) async {
    final expenses = await ref.read(expensesRepositoryProvider).getExpenses();
    state = expenses;
  }

  void addExpense(Expense expense) {
    state = [...state, expense];
    //ref.read(expensesRepositoryProvider).addExpense(expense);
  }
}

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  return ExpensesRepository(FirebaseFirestore.instance);
});

class ExpensesRepository {
  final FirebaseFirestore _firestore;

  ExpensesRepository(this._firestore);

  Future<List<Expense>> getExpenses() async {
    final snapshot = await _firestore.collection('expenses').get();
    return snapshot.docs
        .map((doc) => Expense(
              id: doc.id,
              title: doc['title'] as String,
              amount: (doc['amount'] as num).toDouble(),
            ))
        .toList();
  }

  Future<void> addExpense(Expense expense) async {
    await _firestore.collection('expenses').add({
      'title': expense.title,
      'amount': expense.amount,
    });
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends ConsumerStatefulWidget {
  @override
  ConsumerState<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends ConsumerState<MyHomePage> {
  final TextEditingController _titleController = TextEditingController();

  final TextEditingController _amountController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Expense Tracker'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer(
              builder: (context, watch, _) {
                final expenses = ref.watch(expensesProvider);

                return ListView.builder(
                  itemCount: expenses.length,
                  itemBuilder: (context, index) {
                    final expense = expenses[index];
                    return ListTile(
                      title: Text(expense.title),
                      subtitle: Text('\$${expense.amount.toStringAsFixed(2)}'),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: _amountController,
                  decoration: InputDecoration(labelText: 'Amount'),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    final title = _titleController.text.trim();
                    final amount =
                        double.tryParse(_amountController.text) ?? 0.0;

                    if (title.isNotEmpty && amount > 0) {
                      final expense = Expense(
                        id: DateTime.now().toIso8601String(),
                        title: title,
                        amount: amount,
                      );

                      ref.read(expensesProvider.notifier).addExpense(expense);
                      _titleController.clear();
                      _amountController.clear();
                    }
                  },
                  child: Text('Add Expense'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
