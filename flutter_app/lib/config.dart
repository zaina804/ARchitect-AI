// ── Server configuration ──────────────────────────────────────────────────────
// Change this IP to your PC's local WiFi IP (run ipconfig to find it)
const String serverBaseUrl = 'http://192.168.1.212:8000';
const String detectUrl     = '$serverBaseUrl/detect';
const String modelsUrl     = '$serverBaseUrl/models';
// ─────────────────────────────────────────────────────────────────────────────

// ── OpenAI configuration ──────────────────────────────────────────────────────
// Replace with your own OpenAI API key — never commit the real key!
const String openAiApiKey = 'YOUR_OPENAI_API_KEY_HERE';
// ─────────────────────────────────────────────────────────────────────────────

