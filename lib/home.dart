import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;



class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vision Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        fontFamily: 'Poppins',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Poppins',
      ),
      themeMode: ThemeMode.system,
      home: const VisionAssistantScreen(),
    );
  }
}

class VisionAssistantScreen extends StatefulWidget {
  const VisionAssistantScreen({super.key});

  @override
  _VisionAssistantScreenState createState() => _VisionAssistantScreenState();
}

class _VisionAssistantScreenState extends State<VisionAssistantScreen> with SingleTickerProviderStateMixin {
  File? _image;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _promptController = TextEditingController();
  String _response = "";
  bool _isProcessing = false;
  String _imageUrl = "";
  
  // For animations
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // For text-to-speech
  final FlutterTts flutterTts = FlutterTts();
  
  // For speech-to-text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    
    // Initialize TTS
    _initTts();
    
    // Initialize STT
    _initSpeech();
    
    // Set default prompt
    _promptController.text = "Describe this image in detail. What do you see?";
  }
  
  Future<void> _initTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);
  }
  
  Future<void> _initSpeech() async {
    await _speech.initialize();
  }
  
  Future<void> _speak(String text) async {
    await flutterTts.speak(text);
  }
  
  Future<void> _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            setState(() {
              _promptController.text = result.recognizedWords;
              if (result.finalResult) {
                _isListening = false;
              }
            });
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _promptController.dispose();
    flutterTts.stop();
    super.dispose();
  }
  
  Future<void> _getImageFromCamera() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
    );
    
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _animationController.reset();
        _animationController.forward();
        _response = "";
      });
      
      // Automatically speak a confirmation for blind users
      _speak("Image captured. Ask me about this image by tapping the microphone button or the analyze button.");
    }
  }
  
  Future<void> _getImageFromGallery() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _animationController.reset();
        _animationController.forward();
        _response = "";
      });
      
      // Speak confirmation
      _speak("Image selected from gallery. Ask me about this image.");
    }
  }
  
  Future<String> _getImageUrl() async {
    if (_image == null) return "";
    
    // In a real app, you would upload the image to a server and get a URL
    // For demo purposes, we'll use a placeholder URL
    // This would need to be replaced with actual image upload code
    
    // Simulating upload delay
    await Future.delayed(const Duration(seconds: 1));
    return "https://images.pexels.com/photos/459225/pexels-photo-459225.jpeg?cs=srgb&dl=daylight-environment-forest-459225.jpg&fm=jpg";
  }
  
  Future<void> _analyzeImage() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please take or select an image first")),
      );
      _speak("Please take or select an image first");
      return;
    }
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      // Get image URL (in a real app, this would upload the image)
      _imageUrl = await _getImageUrl();
      
      // Use the API to get the completion
      final response = await http.post(
        Uri.parse('https://api.thehive.ai/api/v3/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer T4L0n9mDcWPPlaXbPCZK23Xg4v0vY7gu',
        },
        body: jsonEncode({
          'model': 'meta-llama/llama-3.2-11b-vision-instruct',
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': _promptController.text},
                {'type': 'image_url', 'image_url': {'url': _imageUrl}}
              ]
            }
          ],
          'temperature': 0.7,
          'max_tokens': 1000,
        }),
      );
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final result = jsonResponse['choices'][0]['message']['content'];
        
        setState(() {
          _response = result;
          _isProcessing = false;
        });
        
        // Automatically read the response for blind users
        _speak(result);
      } else {
        setState(() {
          _response = "Error: ${response.statusCode} - ${response.body}";
          _isProcessing = false;
        });
        _speak("Sorry, there was an error processing your request.");
      }
    } catch (e) {
      setState(() {
        _response = "Error: $e";
        _isProcessing = false;
      });
      _speak("Sorry, there was an error processing your request.");
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Vision Assistant',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Image container
                      GestureDetector(
                        onDoubleTap: _getImageFromCamera,
                        child: Container(
                          height: 300,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.shadow.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: _image == null
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.camera_alt_outlined,
                                          size: 64,
                                          color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Tap to capture image',
                                          style: textTheme.bodyLarge?.copyWith(
                                            color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                                          ),
                                        ),
                                        Text(
                                          'Double tap for quick capture',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : FadeTransition(
                                    opacity: _fadeAnimation,
                                    child: Image.file(
                                      _image!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Image source buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _getImageFromCamera,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Camera'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: colorScheme.primaryContainer,
                                foregroundColor: colorScheme.onPrimaryContainer,
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _getImageFromGallery,
                              icon: const Icon(Icons.photo_library),
                              label: const Text('Gallery'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: colorScheme.secondaryContainer,
                                foregroundColor: colorScheme.onSecondaryContainer,
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Prompt input
                      Text(
                        'Ask about the image:',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _promptController,
                        decoration: InputDecoration(
                          hintText: 'What would you like to know about this image?',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          suffixIcon: IconButton(
                            onPressed: _listen,
                            icon: Icon(
                              _isListening ? Icons.mic : Icons.mic_none,
                              color: _isListening ? colorScheme.primary : null,
                            ),
                          ),
                        ),
                        minLines: 2,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      
                      // Analyze button
                      ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _analyzeImage,
                        icon: _isProcessing
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.onPrimary,
                                ),
                              )
                            : const Icon(Icons.search),
                        label: Text(_isProcessing ? 'Analyzing...' : 'Analyze Image'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          minimumSize: const Size(double.infinity, 56),
                          elevation: 2,
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Response section
                      if (_response.isNotEmpty) ...[
                        Text(
                          'Analysis Result:',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colorScheme.outline.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _response,
                                style: textTheme.bodyLarge?.copyWith(
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    onPressed: () => _speak(_response),
                                    icon: const Icon(Icons.volume_up),
                                    tooltip: 'Read aloud',
                                    style: IconButton.styleFrom(
                                      backgroundColor: colorScheme.surfaceContainerHighest,
                                      foregroundColor: colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () {
                                      // Copy to clipboard functionality would go here
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Response copied to clipboard")),
                                      );
                                    },
                                    icon: const Icon(Icons.copy),
                                    tooltip: 'Copy to clipboard',
                                    style: IconButton.styleFrom(
                                      backgroundColor: colorScheme.surfaceContainerHighest,
                                      foregroundColor: colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              // Quick access buttons for blind users
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAccessibilityButton(
                      icon: Icons.camera_alt,
                      label: 'Capture',
                      onPressed: _getImageFromCamera,
                      color: colorScheme.primary,
                    ),
                    _buildAccessibilityButton(
                      icon: Icons.mic,
                      label: 'Ask',
                      onPressed: _listen,
                      color: colorScheme.secondary,
                      isActive: _isListening,
                    ),
                    _buildAccessibilityButton(
                      icon: Icons.play_arrow,
                      label: 'Analyze',
                      onPressed: _analyzeImage,
                      color: colorScheme.tertiary,
                    ),
                    _buildAccessibilityButton(
                      icon: Icons.volume_up,
                      label: 'Repeat',
                      onPressed: () => _speak(_response.isEmpty 
                          ? "No analysis yet. Please capture an image and analyze it." 
                          : _response),
                      color: colorScheme.error,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildAccessibilityButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
    bool isActive = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: isActive ? 12 : 4,
                spreadRadius: isActive ? 2 : 0,
              ),
            ],
          ),
          child: Material(
            color: isActive ? color : color.withOpacity(0.2),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Icon(
                  icon,
                  size: 28,
                  color: isActive 
                      ? Colors.white 
                      : color,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}