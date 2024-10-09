import 'package:dash_chat_2/dash_chat_2.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vision_offline/provider.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.blueGrey,
        title: const Text('Edu vision'),
        centerTitle: true,
      ),
      drawer: _buildDrawer(context),
      body: const ChatPage(),
    );
  }
// Function to build the Drawer with settings option
  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text('Settings', style: TextStyle(color: Colors.white, fontSize: 24)),
          ),
          // ListTile for accessing TTS settings
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('TTS Settings'),
            onTap: () {
              Navigator.pop(context);
              _showSettingsDialog(context);
            },
          ),
        ],
      ),
    );
  }
  // Function to show the TTS settings dialog allowing the user to
  // adjust speech rate, pitch, and language
  void _showSettingsDialog(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('TTS Settings'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Speech Rate: ${chatProvider.speechRate.toStringAsFixed(2)}'),
                  // Slider to adjust speech rate for TTS
                  Slider(
                    value: chatProvider.speechRate,
                    min: 0.0,
                    max: 1.0,
                    divisions: 15,
                    label: chatProvider.speechRate.toStringAsFixed(2),
                    onChanged: (value) {
                      setState(() {
                        chatProvider.speechRate = value;
                      });
                    },
                  ),
                  Text('Pitch: ${chatProvider.speechPitch.toStringAsFixed(2)}'),
                  // Slider to adjust Pitch for TTS
                  Slider(
                    value: chatProvider.speechPitch,
                    min: 0.5,
                    max: 2.0,
                    divisions: 15,
                    label: chatProvider.speechPitch.toStringAsFixed(2),
                    onChanged: (value) {
                      setState(() {
                        chatProvider.speechPitch = value;
                      });
                    },
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    // Dropdown for selecting TTS language Accent
                    child: DropdownButton<String>(
                      value: chatProvider.language,
                      items: const [
                        DropdownMenuItem(value: "en-US", child: Text("English (United States)")),
                        DropdownMenuItem(value: "en-GB", child: Text("English (United Kingdom)")),
                        DropdownMenuItem(value: "en-CA", child: Text("English (Canada)")),
                        DropdownMenuItem(value: "en-AU", child: Text("English (Australia)")),
                        DropdownMenuItem(value: "en-IN", child: Text("English (India)")),
                      ],
                      onChanged: (value) {
                        chatProvider.language = value!;
                        switch (value) {
                          case "en-US":
                            chatProvider.speak("You select English United States Accent");
                            break;
                          case "en-GB":
                            chatProvider.speak("You select English United Kingdom Accent");
                            break;
                          case "en-CA":
                            chatProvider.speak("You select English Canadian Accent");
                            break;
                          case "en-AU":
                            chatProvider.speak("You select English Australian Accent");
                            break;
                          case "en-IN":
                            chatProvider.speak("You select English Indian Accent");
                            break;
                          default:
                            chatProvider.speak("You select English United States Accent");
                        }
                      },
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    // Dropdown for selecting the voice for TTS
                    child: DropdownButton(
                      value: chatProvider.selectedVoice,
                      items: chatProvider.voiceItems,
                      onChanged: (Map<String, String>? newVoice) async {
                        if (newVoice != null) {
                          await chatProvider.setVoice(newVoice);
                        }
                      },
                    ),
                  )
                ],
              );
            },
          ),
          actions: [
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                chatProvider.settings();
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});
// Builds the chat page UI, displaying messages and input options
  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    chatProvider.getVoices();
    return GestureDetector(
      // Handles long-press actions to start/stop speech-to-text listening
      onLongPressStart: (_) => chatProvider.startListening(),
      onLongPressEnd: (_) => chatProvider.stopListening(),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: DashChat(
                      currentUser: chatProvider.currentUser,
                      onSend: chatProvider.onSend,
                      messages: chatProvider.messages,
                      inputOptions: InputOptions(
                        inputToolbarPadding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                        sendOnEnter: true,
                        inputMaxLines: 5,
                        autocorrect: true,
                        textController: chatProvider.questionController,
                        inputTextStyle: const TextStyle(
                          color: Colors.black87,
                        ),
                        sendButtonBuilder: (message) {
                          return ElevatedButton(
                            onPressed: () {
                              if (chatProvider.questionController.text.isNotEmpty) {
                                var questionControllerMessage = chatProvider.questionController.text;
                                ChatMessage message = ChatMessage(
                                  user: chatProvider.currentUser,
                                  createdAt: DateTime.now(),
                                  text: questionControllerMessage,
                                );

                                chatProvider.onSend(message); // Send the message
                                chatProvider.questionController.clear(); // Clear the text field
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                            ),
                            child: const Icon(
                              Icons.send,
                              color: Colors.white, // Set the icon color to white
                            ),
                          );
                        },
                      ),
                      messageOptions: const MessageOptions(
                        showTime: true,
                        // showCurrentUserAvatar: true,
                        containerColor: Colors.black,
                        textColor: Colors.white,
                        currentUserTextColor: Colors.white,
                        currentUserContainerColor: Colors.black,
                      ),
                      scrollToBottomOptions: const ScrollToBottomOptions(
                        disabled: true,
                      ),
                      typingUsers: chatProvider.typingUser,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.attach_file,
                          color: Colors.black87,
                        ),
                        onPressed: () => chatProvider.pickFile(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () async {
                          if (chatProvider.isSpeaking && !chatProvider.isPaused) {
                            await chatProvider.pause();
                          } else if (chatProvider.isPaused) {
                            await chatProvider.resume();
                          } else {
                            await chatProvider.play();
                          }
                        },
                        icon: Icon(
                          (chatProvider.isSpeaking && !chatProvider.isPaused)
                              ? Icons.pause
                              : (chatProvider.isPaused ? Icons.play_arrow : Icons.play_arrow), // Show play if paused or not speaking
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () => chatProvider.repeatSpeak(),
                        icon: const Icon(Icons.repeat, color: Colors.black87),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
