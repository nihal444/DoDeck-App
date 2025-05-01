import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() {
  runApp(const DoDeckApp());
}

class DoDeckApp extends StatelessWidget {
  const DoDeckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TaskProvider()..init(),
      child: Consumer<TaskProvider>(
        builder: (context, provider, _) {
          return MaterialApp(
            title: 'DoDeck',
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: provider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const HomeScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

class Task {
  int? id;
  String title;
  String description;
  String status;

  Task({
    this.id,
    required this.title,
    required this.description,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      status: map['status'],
    );
  }
}


class TaskProvider extends ChangeNotifier {
  List<Task> _tasks = [];
  bool _isDarkMode = false;

  List<Task> get tasks => _tasks;
  bool get isDarkMode => _isDarkMode;

  Future<void> init() async {
    await _loadPreferences();
    await _loadTasks();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('darkMode') ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', _isDarkMode);
    notifyListeners();
  }

  Future<void> _loadTasks() async {
    _tasks = await DBHelper.instance.getTasks();
    notifyListeners();
  }

  Future<void> addTask(Task task) async {
    await DBHelper.instance.insertTask(task);
    await _loadTasks();
  }

  Future<void> updateTask(Task task) async {
    await DBHelper.instance.updateTask(task);
    await _loadTasks();
  }

  Future<void> deleteTask(int id) async {
    await DBHelper.instance.deleteTask(id);
    await _loadTasks();
  }
}

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;

  DBHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    final path = join(await getDatabasesPath(), 'tasks.db');
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute('''
          CREATE TABLE tasks (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, description TEXT, status TEXT )
        ''');
      },
    );
    return _database!;
  }

  Future<List<Task>> getTasks() async {
    final db = await database;
    final maps = await db.query('tasks');
    return maps.map((m) => Task.fromMap(m)).toList();
  }

  Future<void> insertTask(Task task) async {
    final db = await database;
    await db.insert('tasks', task.toMap());
  }

  Future<void> updateTask(Task task) async {
    final db = await database;
    await db.update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
  }

  Future<void> deleteTask(int id) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }
}


class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaskProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DoDeck'),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: () => provider.toggleTheme(),
          ),
        ],
      ),
      body: provider.tasks.isEmpty
          ? const Center(child: Text("No tasks added yet."))
          : ListView.builder(
        itemCount: provider.tasks.length,
        itemBuilder: (context, index) {
          final task = provider.tasks[index];
          return ListTile(
            title: Text(task.title),
            subtitle: Text('${task.description} | ${task.status}'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TaskFormScreen(task: task),
                ),
              );
            },
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => provider.deleteTask(task.id!),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TaskFormScreen()),
        ),
      ),
    );
  }
}


class TaskFormScreen extends StatefulWidget {
  final Task? task;
  const TaskFormScreen({super.key, this.task});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _title;
  late String _description;
  String _status = 'Not Started';

  @override
  void initState() {
    super.initState();
    _title = widget.task?.title ?? '';
    _description = widget.task?.description ?? '';
    _status = widget.task?.status ?? 'Not Started';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaskProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'Add Task' : 'Edit Task'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                initialValue: _title,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                onSaved: (val) => _title = val!,
              ),
              TextFormField(
                initialValue: _description,
                decoration: const InputDecoration(labelText: 'Description'),
                onSaved: (val) => _description = val ?? '',
              ),
              DropdownButtonFormField(
                value: _status,
                items: ['Not Started', 'In Progress', 'Completed']
                    .map((status) => DropdownMenuItem(value: status, child: Text(status)))
                    .toList(),
                onChanged: (val) => setState(() => _status = val!),
                decoration: const InputDecoration(labelText: 'Status'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                child: Text(widget.task == null ? 'Add' : 'Update'),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    final task = Task(
                      id: widget.task?.id,
                      title: _title,
                      description: _description,
                      status: _status,
                    );
                    widget.task == null
                        ? provider.addTask(task)
                        : provider.updateTask(task);
                    Navigator.pop(context);
                  }
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}
