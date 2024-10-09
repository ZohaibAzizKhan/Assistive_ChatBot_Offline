import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
// The ChatProvider class manages the chat functionality, including speech-to-text, text-to-speech, file handling, and communicating with flutter_gemma.
class ChatProvider extends ChangeNotifier {
  //Instance of flutterGemma for interaction with gemma
  final flutterGemma = FlutterGemmaPlugin.instance;
  //Instance of TextEditing controller for capturing user input text
  TextEditingController questionController=TextEditingController();
  //Store the gemma reposes
  String? geminiResponse;
  //To keep track of chats between user and gemma
  final List<Message> conversationHistory=[];
  //Instance of FlutterTts for text_to_Speech functionality
  FlutterTts flutterTts=FlutterTts();
  // Speech-to-text instance for handling voice input
  stt.SpeechToText speechToText = stt.SpeechToText();
  // Define chat users (current user and Gemini)
  ChatUser currentUser = ChatUser(id: '0', firstName: 'user');
  ChatUser gemmaUser = ChatUser(id: '1', firstName: 'gemma',);
  // List to store chat messages
  List<ChatMessage> messages = [];
  // Default speech settings
  double speechRate = 0.5;
  double speechPitch = 1.0;
  String language = "en-US";
  // Flags to track if the app is listening or speaking
  String? lastSpokenText;
  bool isListening=false;
  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;
  // State variable to track if the speech is paused
  bool _isPaused = false;
  bool get isPaused => _isPaused;
  // Available voice options for text-to-speech
  List<DropdownMenuItem<Map<String, String>>> voiceItems = [];
  Map<String, String>? selectedVoice;
  // List to keep track of users currently typing
  List<ChatUser>  typingUser=[];
  // Constructor initializes the chatbot, TTS settings, and gets available voices
  ChatProvider() {
    initializeChatbot();
    getVoices();
    flutterTts=FlutterTts();
  }
  // Initializes the Gemini model by setting parameters like max tokens and temperature
  //Defualt max tokens is 512
  Future<void> initializeChatbot() async {
    await flutterGemma.init(
      maxTokens: 1024,
      temperature: 1.0,
      topK: 1,
      randomSeed: 1,
    );
    notifyListeners();
  }
  // Adds a user to the list of typing users
  void addUserTyping(String userId, String username) {
    typingUser.add(ChatUser(id: userId, firstName: username));
    notifyListeners();
  }
// Removes a user from the typing list
  void removeUserTyping(String userId) {
    typingUser.removeWhere((user) => user.id == userId);
    notifyListeners();
  }
// Sets the speech settings (rate, pitch, language) for TTS
  Future<void> settings()async{
    await flutterTts.setSpeechRate(speechRate);
    await flutterTts.setPitch(speechPitch);
    await flutterTts.setLanguage(language);
  }
  // Fetches the available voices from FlutterTTS and stores them in a dropdown menu
  Future<void> getVoices() async {
    List<dynamic>? voices = await flutterTts.getVoices;
    voiceItems = voices!.map((voice) {
      return DropdownMenuItem<Map<String, String>>(
        value: {"name": voice['name'], "locale": voice['locale']},
        child: Text("${voice['name']} (${voice['locale']})"),
      );
    }).toList();
    // Set the default voice (optional)
    selectedVoice = voiceItems.first.value;
    notifyListeners();
  }
// Sets the TTS voice based on user selection
  Future<void> setVoice(Map<String, String>? voice) async {
    await flutterTts.setVoice({
      'name': voice!["name"]!,
      'locale': voice['locale']!,
    });
    selectedVoice = voice;
    speak("you select $selectedVoice voice");
    notifyListeners();
  }
// Plays the Gemini response using text-to-speech
  Future<void> play() async {
    _isSpeaking = true;
    _isPaused = false;
    notifyListeners();
    await flutterTts.setVoice(selectedVoice!);
    await flutterTts.speak(geminiResponse!);
  }
// Speaks the given text using TTS
  Future<void> speak(String text) async {
    _isSpeaking = true;
    _isPaused = false;
    notifyListeners();
    await flutterTts.speak(text);
  }
// Stops the TTS and resets the speaking/paused flags
  Future<void> stop() async {
    await flutterTts.stop();
    _isSpeaking = false;
    _isPaused = false;
    notifyListeners();
  }
// Repeats the last spoken text using TTS
  Future<void> repeatSpeak() async {
    if (lastSpokenText != null && lastSpokenText!.isNotEmpty) {
      await stop();
      await speak(lastSpokenText!);
    }
  }
// Pauses the TTS, only if it is currently speaking
  Future<void> pause() async {
    if (_isSpeaking) {
      _isSpeaking = false;
      _isPaused = true;
      notifyListeners();
      await flutterTts.pause();
    }
  }
// Resumes the TTS if it was paused, or starts playing if not speaking
  Future<void> resume() async {
    if (_isPaused) {
      _isPaused = false;
      _isSpeaking = true;
      notifyListeners(); // Notify *before* resuming
      await play(); // Use play() to resume – it will handle setup
    } else if (!_isSpeaking && !_isPaused) {
      await play();
    }

  }
  // Sends a user message, displaying it in the chat and generating a Gemini response
  Future<void> onSend(ChatMessage chatMessage) async {
    ChatMessage markDownMessage=ChatMessage(
      isMarkdown: true,
      user: currentUser,
      createdAt: DateTime.now(),
      text: chatMessage.text
    );
    messages = [markDownMessage, ...messages];
    notifyListeners();
      String question = chatMessage.text;
      //this will generate response from gemini in stream
      gemmaResponses(question);

  }
  // Displays the extracted text content in the chat after processing a file
  Future<void> extractedContent(String extractedText) async {
    ChatMessage extractedMessage = ChatMessage(
        text: extractedText,
        user: currentUser,
        createdAt: DateTime.now(),
        isMarkdown: true);
    messages = [extractedMessage, ...messages];
    notifyListeners();
      gemmaResponses(extractedText);
  }
  Future<void> gemmaResponses(String userQuestion)async{
    String accumulatedResponse="";
    addUserTyping(gemmaUser.id, gemmaUser.firstName!);
    conversationHistory.add(Message(text: userQuestion,isUser: true));
    flutterGemma.getChatResponseAsync(messages: conversationHistory).listen((String? event){
      if(event!=null){
        accumulatedResponse +=event;
        ChatMessage? lastMessage=messages.firstOrNull;
        if(lastMessage !=null && lastMessage.user==gemmaUser){
           lastMessage.text=accumulatedResponse;
           messages[0]=lastMessage;
        }else{
          ChatMessage message=ChatMessage(
              user: gemmaUser,
              createdAt: DateTime.now(),
              isMarkdown: true,
            text: accumulatedResponse,
          );
          messages.insert(0, message);
        }
        notifyListeners();
      }if(event == null){
        removeUserTyping(gemmaUser.id);
      }
     });
    conversationHistory.add(Message(text: accumulatedResponse,isUser: false));
    geminiResponse=accumulatedResponse;
    lastSpokenText=accumulatedResponse;
    play();
  }
// Allows the user to pick a file from their device and process it
  Future<void> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      String fileName=result.files.first.name;
      String extension = file.path.split('.').last;
      if (extension == 'pdf' || extension == 'docx' || extension == 'pptx') {
        try {
          speak( "You Selected $fileName file ");
          String extractedData = await extractTextFromFile(file, extension);
          extractedContent(extractedData);
        } catch (e) {
          speak("Faild to extract text from $fileName file with erro $e");
        }
      }else{
        speak("The allowed files are pptx pdf docx but you select $fileName file");
      }
    }
  }
// Sends the selected file to the server for text extraction and returns the extracted data
  Future<String> extractTextFromFile(File file, String extension) async {
    String apiUrl = '/upload'; // Replace with your Flask server URL
    var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    try {
      var response = await request.send().timeout(const Duration(minutes: 3));

      if (response.statusCode == 200) {
        speak("file uploaded successfully wait text is extracting");
        var responseBody = await http.Response.fromStream(response);
        var data = jsonDecode(responseBody.body);

        if (data.containsKey('extracted_data') && data['extracted_data'] is List) {
          List extractedData = data['extracted_data'];

          if (extension.toLowerCase() == 'pptx') {
            StringBuffer result = StringBuffer();
            for (var slideData in extractedData) { // Iterate through slides
              result.writeln('Slide ${slideData['slide_number']}:');
              if (slideData['title'] != null) {
                result.writeln('Title: ${slideData['title']}');
              }
              if (slideData['subtitle'] != null) {
                result.writeln('Subtitle: ${slideData['subtitle']}');
              }
              if (slideData['content'] != null && slideData['content'].isNotEmpty) {
                result.writeln('Content:');
                for (var content in slideData['content']) {
                  result.writeln('- $content');
                }
              }
            }
            return result.toString();
          }
          else if(extension.toLowerCase()=="docx"){
            StringBuffer result = StringBuffer();
            for (var pageData in extractedData) { //Iterate through pages
              if (pageData.containsKey('headings') && pageData['headings'] is List) {
                for (var headingData in pageData['headings']) {
                  if (headingData.containsKey('chapter')) {
                    result.writeln('Chapter ${headingData['chapter']}: ${headingData['heading']}');
                  } else {
                    result.writeln('Heading: ${headingData['heading']}');
                  }
                  if (headingData.containsKey('paragraphs') && headingData['paragraphs'] is List) {
                    for (var paragraph in headingData['paragraphs']) {
                      if (paragraph['type'] == 'bullet') {
                        result.writeln('  - ${paragraph['text']}');
                      } else {
                        result.writeln('  ${paragraph['text']}');
                      }
                    }
                  }
                }
                result.writeln('Page: ${pageData['page_number']}');
              }
            }
            return result.toString();
          }
          else if (extension.toLowerCase() == 'pdf') {
            StringBuffer result = StringBuffer();
            for (var pageData in extractedData) {
              result.writeln('Page ${pageData['page_number']}:');
              if (pageData['chapter'] != 0) { //Check if the chapter is available for the current page or not
                result.writeln('Chapter ${pageData['chapter']}');
              }

              if (pageData.containsKey("headings") && pageData["headings"] is List) {
                for (var heading in pageData['headings']) {
                  result.writeln("Heading ${heading['heading']}");
                }
              }
              if (pageData.containsKey('paragraphs') &&
                  pageData['paragraphs'] is List) {
                for (var paragraph in pageData['paragraphs']) {
                  if (paragraph['type'] == 'bullet') {
                    result.writeln('- ${paragraph['text']}');
                  } else {
                    result.writeln(paragraph['text']);
                  }
                }
              }
            }
            return result.toString();
          }
          else {
            return extractedData.map((e) => e['text']).join('\n');
          }
        } else {
          return "Invalid data format received from server.";
        }
      } else if(response.statusCode==400) {
        return "No File is Provided";
      }else if(response.statusCode==500){
        return "Error processing file";
      }
    } on TimeoutException {
      return "Request Timeout";
    } catch (e) {
      return "Error: ${e.toString()}";
    }
    return "Failed to Extract Data";
  }
  // Starts listening for voice input and processes the recognized speech
  Future<void> startListening() async {
    bool available = await speechToText.initialize(
      onStatus: (val) {
        if (val == 'done') {
          handleUserQuestion();
        }
      },
      onError: (val) => throw Exception('Speech to text error: $val'),
    );
    if (available) {
      // If speech recognition is available, start listening
      isListening = true;
      notifyListeners();
      speechToText.listen(onResult: (val) {
        questionController.text = val.recognizedWords;
        notifyListeners();
      });
    } else {
      throw Exception('Speech to text not available');
    }
  }
   //stop listening when longTap is released
  Future<void> stopListening() async {
    await speechToText.stop();
    isListening = false;
    notifyListeners();
  }

  // Handle recognized speech input as a user question
  void handleUserQuestion() {
    String question = questionController.text;
    ChatMessage userMessage = ChatMessage(
      text: question,
      user: currentUser,
      createdAt: DateTime.now(),
    );
    questionController.clear();
    onSend(userMessage);
  }
}