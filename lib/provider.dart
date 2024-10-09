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
class ChatProvider extends ChangeNotifier {
  final flutterGemma = FlutterGemmaPlugin.instance;
  TextEditingController questionController=TextEditingController();
  String? geminiResponse;
  final List<Message> conversationHistory=[];
  FlutterTts flutterTts=FlutterTts();
  stt.SpeechToText speechToText = stt.SpeechToText();
  ChatUser currentUser = ChatUser(id: '0', firstName: 'user');
  ChatUser geminiUser = ChatUser(id: '1', firstName: 'gemini',);
  List<ChatMessage> messages = [];
  double speechRate = 0.5;
  double speechPitch = 1.0;
  String language = "en-US";
  String? lastSpokenText;
  bool isListening=false;
  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;
  bool _isPaused = false; // Add a state variable to track pausing
  bool get isPaused => _isPaused;
  List<DropdownMenuItem<Map<String, String>>> voiceItems = [];
  Map<String, String>? selectedVoice;
  List<ChatUser>  typingUser=[];
  ChatProvider() {
    initializeChatbot();
    getVoices();
    flutterTts=FlutterTts();
  }
  Future<void> initializeChatbot() async {
    await flutterGemma.init(
      maxTokens: 1024,
      temperature: 1.0,
      topK: 1,
      randomSeed: 1,
    );
    notifyListeners();
  }
  void addUserTyping(String userId, String username) {
    typingUser.add(ChatUser(id: userId, firstName: username));
    notifyListeners();
  }

  void removeUserTyping(String userId) {
    typingUser.removeWhere((user) => user.id == userId);
    notifyListeners();
  }
  Future<void> settings()async{

    await flutterTts.setSpeechRate(speechRate);
    await flutterTts.setPitch(speechPitch);
    await flutterTts.setLanguage(language);

  }
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

  Future<void> setVoice(Map<String, String>? voice) async {
    await flutterTts.setVoice({
      'name': voice!["name"]!,
      'locale': voice['locale']!,
    });
    selectedVoice = voice;
    speak("you select $selectedVoice voice");
    notifyListeners();
  }

  Future<void> play() async {
    _isSpeaking = true;
    _isPaused = false;
    notifyListeners(); // Notify *before* starting to speak
    await flutterTts.setVoice(selectedVoice!);
    await flutterTts.speak(geminiResponse!);
  }

  Future<void> speak(String text) async {
    _isSpeaking = true;
    _isPaused = false;
    notifyListeners(); // Notify *before* starting to speak
    await flutterTts.speak(text);
  }

  Future<void> stop() async {
    await flutterTts.stop();
    _isSpeaking = false;
    _isPaused = false;
    notifyListeners();
  }

  Future<void> repeatSpeak() async {
    if (lastSpokenText != null && lastSpokenText!.isNotEmpty) {
      await stop();  // Stop before repeating
      await speak(lastSpokenText!);
    }
  }

  Future<void> pause() async {
    if (_isSpeaking) { // Only pause if currently speaking
      _isSpeaking = false;
      _isPaused = true;
      notifyListeners(); // Notify *before* pausing
      await flutterTts.pause();
    }
  }

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
    addUserTyping(geminiUser.id, geminiUser.firstName!);
    conversationHistory.add(Message(text: userQuestion,isUser: true));
    flutterGemma.getChatResponseAsync(messages: conversationHistory).listen((String? event){
      if(event!=null){
        accumulatedResponse +=event;
        ChatMessage? lastMessage=messages.firstOrNull;
        if(lastMessage !=null && lastMessage.user==geminiUser){
           lastMessage.text=accumulatedResponse;
           messages[0]=lastMessage;
        }else{
          ChatMessage message=ChatMessage(
              user: geminiUser,
              createdAt: DateTime.now(),
              isMarkdown: true,
            text: accumulatedResponse,
          );
          messages.insert(0, message);
          conversationHistory.add(Message(text: accumulatedResponse,isUser: false));
        }
        notifyListeners();
      }if(event == null){
        removeUserTyping(geminiUser.id);
      }
     });
    geminiResponse=accumulatedResponse;
    lastSpokenText=accumulatedResponse;
    play();
  }
  // Future<void> gemmaResponses(String userQuestion) async {
  //   // Add typing indicator for the Gemini user
  //   addUserTyping(geminiUser.id, geminiUser.firstName!);
  //
  //   // Add user's question to the conversation history
  //   conversationHistory.add(Message(text: userQuestion, isUser: true));
  //
  //   // Store the complete response
  //   String? accumulatedResponse = "";
  //
  //   // Call the async method to get the chat response
  //   try {
  //     // Wait for the complete response
  //     accumulatedResponse = await flutterGemma.getChatResponse(messages: conversationHistory);
  //
  //     // Remove typing indicator
  //     removeUserTyping(geminiUser.id);
  //
  //     // Create a chat message with the accumulated response
  //     ChatMessage message = ChatMessage(
  //       text: accumulatedResponse!,
  //       user: geminiUser,
  //       createdAt: DateTime.now(),
  //       isMarkdown: true,
  //     );
  //
  //     // Add the message to the messages list
  //     messages.add(message);
  //
  //     // Update the conversation history
  //     conversationHistory.add(Message(text: accumulatedResponse, isUser: false));
  //
  //     // Store the final response for speaking
  //     geminiResponse = accumulatedResponse;
  //     lastSpokenText = accumulatedResponse;
  //
  //     // Play the final response
  //     play();
  //
  //     // Notify listeners to update the UI
  //     notifyListeners();
  //
  //   } catch (error) {
  //     // Handle any errors that occur
  //     removeUserTyping(geminiUser.id);
  //     speak("There was an error during the conversation with Gemma: $error");
  //   }
  // }



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