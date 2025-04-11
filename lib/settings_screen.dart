import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'login_screen.dart';
import 'theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Settings state
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _studyRemindersEnabled = true;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }
  
  Future<void> _loadUserSettings() async {
    try {
      User? user = _auth.currentUser;
      
      if (user != null) {
        DocumentSnapshot settingsDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc('preferences')
            .get();
        
        if (settingsDoc.exists) {
          Map<String, dynamic> settings = settingsDoc.data() as Map<String, dynamic>;
          setState(() {
            // Dark mode is now managed by ThemeProvider
            _notificationsEnabled = settings['notifications'] ?? true;
            _soundEnabled = settings['sound'] ?? true;
            _studyRemindersEnabled = settings['studyReminders'] ?? true;
            _isLoading = false;
          });
        } else {
          // Create default settings if they don't exist
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('settings')
              .doc('preferences')
              .set({
                'darkMode': Provider.of<ThemeProvider>(context, listen: false).isDarkMode,
                'notifications': _notificationsEnabled,
                'sound': _soundEnabled,
                'studyReminders': _studyRemindersEnabled,
              });
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading settings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _updateSetting(String setting, bool value) async {
    try {
      User? user = _auth.currentUser;
      
      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc('preferences')
            .update({
              setting: value,
            });
      }
    } catch (e) {
      print('Error updating setting: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating setting')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Get the theme provider
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text("Settings"),
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings"),
      ),
      body: ListView(
        children: [
          // Theme settings section
          _buildSectionHeader("Theme Settings"),
          SwitchListTile(
            title: Text("Dark Mode"),
            subtitle: Text("Switch between light and dark theme"),
            value: themeProvider.isDarkMode,
            onChanged: (value) {
              // Use ThemeProvider to update the theme
              themeProvider.setDarkMode(value);
            },
            secondary: Icon(Icons.brightness_4),
          ),
          Divider(),
          
          // Notification settings section
          _buildSectionHeader("Notification Settings"),
          SwitchListTile(
            title: Text("Enable Notifications"),
            subtitle: Text("Receive notifications from the app"),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
                _updateSetting('notifications', value);
              });
            },
            secondary: Icon(Icons.notifications),
          ),
          SwitchListTile(
            title: Text("Sound"),
            subtitle: Text("Play sound with notifications"),
            value: _soundEnabled,
            onChanged: _notificationsEnabled ? (value) {
              setState(() {
                _soundEnabled = value;
                _updateSetting('sound', value);
              });
            } : null,
            secondary: Icon(Icons.volume_up),
          ),
          SwitchListTile(
            title: Text("Study Reminders"),
            subtitle: Text("Get reminders for scheduled study sessions"),
            value: _studyRemindersEnabled,
            onChanged: _notificationsEnabled ? (value) {
              setState(() {
                _studyRemindersEnabled = value;
                _updateSetting('studyReminders', value);
              });
            } : null,
            secondary: Icon(Icons.alarm),
          ),
          Divider(),
          
          // Account settings section
          _buildSectionHeader("Account Settings"),
          ListTile(
            leading: Icon(Icons.lock),
            title: Text("Change Password"),
            subtitle: Text("Update your account password"),
            onTap: () {
              _showChangePasswordDialog();
            },
          ),
          ListTile(
            leading: Icon(Icons.email),
            title: Text("Update Email"),
            subtitle: Text("Change your registered email address"),
            onTap: () {
              _showUpdateEmailDialog();
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text("Delete Account"),
            subtitle: Text("Permanently remove your account and data"),
            onTap: () {
              _showDeleteAccountDialog();
            },
          ),
          Divider(),
          
          // App information section
          _buildSectionHeader("App Information"),
          ListTile(
            leading: Icon(Icons.info_outline),
            title: Text("About"),
            subtitle: Text("Learn more about Study Room"),
            onTap: () {
              // TODO: Implement about screen
              _showComingSoonDialog("About");
            },
          ),
          ListTile(
            leading: Icon(Icons.help_outline),
            title: Text("Help & Support"),
            subtitle: Text("Get help with using the app"),
            onTap: () {
              // TODO: Implement help & support functionality
              _showComingSoonDialog("Help & Support");
            },
          ),
          ListTile(
            leading: Icon(Icons.privacy_tip_outlined),
            title: Text("Privacy Policy"),
            subtitle: Text("Read our privacy policy"),
            onTap: () {
              // TODO: Implement privacy policy screen
              _showComingSoonDialog("Privacy Policy");
            },
          ),
          
          // App version
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                "Version 1.0.0",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
          
          // Logout button
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onPressed: () {
                _signOut();
              },
              child: Text("Logout"),
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.orangeAccent,
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      print('Error signing out: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out')),
      );
    }
  }

  void _showChangePasswordDialog() {
    final TextEditingController _currentPasswordController = TextEditingController();
    final TextEditingController _newPasswordController = TextEditingController();
    final TextEditingController _confirmPasswordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Change Password"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _currentPasswordController,
                decoration: InputDecoration(
                  labelText: "Current Password",
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _newPasswordController,
                decoration: InputDecoration(
                  labelText: "New Password",
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: "Confirm New Password",
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              if (_newPasswordController.text != _confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Passwords do not match')),
                );
                return;
              }
              
              try {
                User? user = _auth.currentUser;
                
                if (user != null && user.email != null) {
                  // Reauthenticate user
                  AuthCredential credential = EmailAuthProvider.credential(
                    email: user.email!,
                    password: _currentPasswordController.text,
                  );
                  
                  await user.reauthenticateWithCredential(credential);
                  
                  // Change password
                  await user.updatePassword(_newPasswordController.text);
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Password updated successfully')),
                  );
                }
              } catch (e) {
                print('Error changing password: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error changing password: ${e.toString()}')),
                );
              }
            },
            child: Text("Change"),
          ),
        ],
      ),
    );
  }

  void _showUpdateEmailDialog() {
    final TextEditingController _newEmailController = TextEditingController();
    final TextEditingController _passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Update Email"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _newEmailController,
                decoration: InputDecoration(
                  labelText: "New Email",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              try {
                User? user = _auth.currentUser;
                
                if (user != null && user.email != null) {
                  // Reauthenticate user
                  AuthCredential credential = EmailAuthProvider.credential(
                    email: user.email!,
                    password: _passwordController.text,
                  );
                  
                  await user.reauthenticateWithCredential(credential);
                  
                  // Update email
                  await user.updateEmail(_newEmailController.text);
                  
                  // Update email in Firestore
                  await _firestore
                      .collection('users')
                      .doc(user.uid)
                      .update({
                        'email': _newEmailController.text,
                      });
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Email updated successfully')),
                  );
                }
              } catch (e) {
                print('Error updating email: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error updating email: ${e.toString()}')),
                );
              }
            },
            child: Text("Update"),
          ),
        ],
      ),
    );
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Coming Soon"),
        content: Text("The $feature feature is coming soon!"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Account"),
        content: Text(
          "Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently lost.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              _showDeleteAccountConfirmationDialog();
            },
            child: Text("Delete"),
          ),
        ],
      ),
    );
  }
  
  void _showDeleteAccountConfirmationDialog() {
    final TextEditingController _passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Confirm Deletion"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Please enter your password to confirm account deletion:"),
            SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              try {
                User? user = _auth.currentUser;
                
                if (user != null && user.email != null) {
                  // Reauthenticate user
                  AuthCredential credential = EmailAuthProvider.credential(
                    email: user.email!,
                    password: _passwordController.text,
                  );
                  
                  await user.reauthenticateWithCredential(credential);
                  
                  // Delete user data from Firestore
                  await _firestore.collection('users').doc(user.uid).delete();
                  
                  // Delete user account
                  await user.delete();
                  
                  Navigator.pop(context);
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                    (route) => false,
                  );
                }
              } catch (e) {
                print('Error deleting account: $e');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting account: ${e.toString()}')),
                );
              }
            },
            child: Text("Confirm Delete"),
          ),
        ],
      ),
    );
  }
}