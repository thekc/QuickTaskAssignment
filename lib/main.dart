import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const keyApplicationId = '3ZmMK1wKaY7YfblLgtwpqyjveY5CnPbn6poGH3A6';
  const keyClientKey = 'o1R1tp6zMic2Vezs4kuLzQWJKzZth0oMkveqHEqv';
  const keyParseServerUrl = 'https://parseapi.back4app.com';

  await Parse().initialize(keyApplicationId, keyParseServerUrl, clientKey: keyClientKey, autoSendSessionId: true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuickTask',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: LoginPage(),
    );
  }
}

class LoginPage extends StatelessWidget {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('QuickTask Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
              ),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
              ),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                var user = ParseUser(_emailController.text, _passwordController.text, _emailController.text);
                var response = await user.login();

                if (response.success) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => TaskManagerHomePage(user: user)),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Login failed: ${response.error?.message}'),
                    ),
                  );
                }
              },
              child: Text('Login'),
            ),
            TextButton(
              onPressed: () async {
                var user = ParseUser(_emailController.text, _passwordController.text, _emailController.text);
                var response = await user.signUp();

                if (response.success) {
                  // Show success message
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sign up failed: ${response.error?.message}'),
                    ),
                  );
                }
              },
              child: Text('Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}

class TaskManagerHomePage extends StatefulWidget {
  final ParseUser user;

  TaskManagerHomePage({required this.user});

  @override
  _TaskManagerHomePageState createState() => _TaskManagerHomePageState();
}

class _TaskManagerHomePageState extends State<TaskManagerHomePage> {
  late Future<List<ParseObject>> _tasksFuture;

  @override
  void initState() {
    super.initState();
    _tasksFuture = _getTasks();
  }

  Future<List<ParseObject>> _getTasks() async {
    var query = QueryBuilder<ParseObject>(ParseObject('Task'))
      ..whereEqualTo('user', widget.user)
      ..orderByAscending('dueDate');
    var response = await query.query();
    if (response.success && response.results != null) {
      return response.results as List<ParseObject>;
    } else {
      return [];
    }
  }

  void _refreshTasks() {
    setState(() {
      _tasksFuture = _getTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Your Tasks'),
      ),
      body: FutureBuilder<List<ParseObject>>(
        future: _tasksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No tasks found'));
          } else {
            var tasks = snapshot.data!;
            return ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                var task = tasks[index];
                return ListTile(
                  title: Text(task.get<String>('title')!),
                  subtitle: Text('Due: ${task.get<DateTime>('dueDate')!.toLocal()}'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => EditTaskPage(task: task),
                      ),
                    ).then((_) => _refreshTasks());
                  },
                  trailing: Checkbox(
                    value: task.get('isComplete') ?? false,
                    onChanged: (bool? value) async {
                      setState(() {
                        task.set('isComplete', value);
                      });
                      await task.save();
                      _refreshTasks();
                    },
                  ),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AddTaskPage(user: widget.user),
            ),
          ).then((_) => _refreshTasks());
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

class EditTaskPage extends StatelessWidget {
  final ParseObject task;

  EditTaskPage({required this.task});

  @override
  Widget build(BuildContext context) {
    final TextEditingController _titleController = TextEditingController(text: task.get<String>('title'));
    final TextEditingController _dueDateController = TextEditingController(text: task.get<DateTime>('dueDate')?.toIso8601String() ?? '');

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Task'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () async {
              var response = await task.delete();
              if (response.success) {
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete task: ${response.error?.message}'),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
              ),
            ),
            TextField(
              controller: _dueDateController,
              decoration: InputDecoration(
                labelText: 'Due Date',
              ),
              onTap: () async {
                FocusScope.of(context).requestFocus(new FocusNode()); // To prevent opening the keyboard
                var date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(Duration(days: 365)),
                );
                if (date != null) {
                  var time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null) {
                    final DateTime pickedDateTime = DateTime(
                      date.year,
                      date.month,
                      date.day,
                      time.hour,
                      time.minute,
                    );
                    _dueDateController.text = pickedDateTime.toIso8601String();
                  }
                }
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                task
                  ..set<String>('title', _titleController.text)
                  ..set<DateTime>('dueDate', DateTime.parse(_dueDateController.text));
                var response = await task.save();
                if (response.success) {
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to save task: ${response.error?.message}'),
                    ),
                  );
                }
              },
              child: Text('Save Task'),
            ),
          ],
        ),
      ),
    );
  }
}

class AddTaskPage extends StatelessWidget {
  final ParseUser user;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();

  AddTaskPage({required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Task'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
              ),
            ),
            TextField(
              controller: _dueDateController,
              decoration: InputDecoration(
                labelText: 'Due Date',
              ),
              onTap: () async {
                FocusScope.of(context).requestFocus(new FocusNode()); // To prevent opening the keyboard
                var date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(Duration(days: 365)),
                );
                if (date != null) {
                  var time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null) {
                    final DateTime pickedDateTime = DateTime(
                      date.year,
                      date.month,
                      date.day,
                      time.hour,
                      time.minute,
                    );
                    _dueDateController.text = pickedDateTime.toIso8601String();
                  }
                }
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                var task = ParseObject('Task')
                  ..set<String>('title', _titleController.text)
                  ..set<DateTime>('dueDate', DateTime.parse(_dueDateController.text))
                  ..set<ParseUser>('user', user);
                var response = await task.save();
                if (response.success) {
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to save task: ${response.error?.message}'),
                    ),
                  );
                }
              },
              child: Text('Save Task'),
            ),
          ],
        ),
      ),
    );
  }
}