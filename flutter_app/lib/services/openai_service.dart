import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/chat_message.dart';

class OpenAIService {
  static const _url          = 'https://api.openai.com/v1/chat/completions';
  static const _model        = 'gpt-4o-mini';        // building editor (commands)
  static const _searchModel  = 'gpt-4o-search-preview'; // general chatbot (web search)

  static String _systemPrompt(String lang, {String? buildingContext}) {
    final base = lang == 'ar'
        ? '''أنت مساعد ذكي متخصص حصرياً في مجال البناء والعقارات في الأردن.

قاعدة صارمة: يُحظر عليك تماماً الإجابة عن أي سؤال خارج نطاق البناء والعقارات في الأردن. إذا سألك المستخدم عن أي موضوع آخر (مثل الأدوية أو الطب أو السياسة أو الطبخ أو غير ذلك)، فقل له فقط: "أنا متخصص في البناء والعقارات في الأردن فقط، لا أستطيع مساعدتك في هذا الموضوع."

مجالات مساعدتك المسموح بها فقط:
- نصائح البناء والإنشاء الخاصة بالأردن
- أسعار مواد البناء ومستلزماته في الأردن (أسمنت، حديد، بلاط، طابوق، إلخ)
- أفضل الأسواق والمحلات لشراء مواد البناء في المدن الأردنية (عمّان، الزرقاء، إربد، العقبة، إلخ)
- المناطق الأرخص والأغلى لشراء مواد ومستلزمات البناء في الأردن
- أنظمة وتراخيص البناء في الأردن
- أسعار الأراضي والعقارات حسب المنطقة في الأردن
- تكاليف العمالة في قطاع البناء بالأردن
- نصائح حول التخطيط والتصميم المعماري في الأردن'''
        : '''You are an AI assistant specializing exclusively in construction and real estate in Jordan.

STRICT RULE: You are FORBIDDEN from answering any question outside the topic of construction and real estate in Jordan. If the user asks about anything else (medicine, drugs, politics, food, general knowledge, or any other topic), you must respond with only: "I specialize in construction and real estate in Jordan only. I cannot help with that topic."

You are only allowed to help with:
- Building and construction advice specific to Jordan
- Building material prices in Jordan (cement, iron, tiles, blocks, etc.)
- Best markets and shops for construction materials in Jordanian cities (Amman, Zarqa, Irbid, Aqaba, etc.)
- Cheapest vs most expensive regions to buy building materials and tools in Jordan
- Building permits and regulations in Jordan
- Land and real estate prices by region in Jordan
- Construction labor costs in Jordan
- Planning and architectural advice for building in Jordan''';

    if (buildingContext != null) {
      return lang == 'ar'
          ? '$base\n\nاختار المستخدم نموذج "$buildingContext" لأرضه في الأردن.\nساعده في:\n- هل هذا النوع من المباني مناسب لأرضه؟\n- ما هي التكاليف التقديرية لبناء هذا النوع في الأردن؟\n- ما أنواع الإسمنت والمواد الأفضل لهذا المبنى في الأردن؟\n- هل يفضل مبنى أكبر أو أصغر بناءً على الأرض؟\n- نصائح عملية حول التراخيص والمقاولين في الأردن\nاستخدم أحدث المعلومات المتاحة عن أسعار مواد البناء في الأردن.'
          : '$base\n\nThe user has selected the "$buildingContext" model for their land in Jordan.\nHelp them with:\n- Is this building type suitable for their land?\n- Estimated construction costs for this building type in Jordan\n- Best cement types and materials for this building in Jordan\n- Would a larger or smaller building be better for their land?\n- Practical advice on permits and contractors in Jordan\nSearch for the latest building material prices in Jordan when answering about costs.';
    }
    return base;
  }

  static String _buildingCommandSystemPrompt(String lang) {
    return lang == 'ar'
        ? '''أنت مساعد ذكاء اصطناعي متخصص في البناء والعقارات في الأردن، ويمكنك أيضاً التحكم في نموذج المبنى ثلاثي الأبعاد.

قاعدة صارمة: يُحظر عليك تماماً الإجابة عن أي سؤال خارج نطاق:
1. البناء والعقارات في الأردن (أسعار المواد، الأنظمة، التكاليف، النصائح)
2. التحكم في نموذج المبنى ثلاثي الأبعاد (الألوان، التكبير، الدوران)

إذا سألك المستخدم عن أي موضوع آخر، أجب فقط: "أنا متخصص في البناء والعقارات في الأردن فقط، لا أستطيع مساعدتك في هذا الموضوع."

أوامر التحكم في النموذج المتاحة:
- تغيير اللون: changeColor (target: walls/roof/floor, color: قيمة hex مثل #FF0000)
- التكبير/التصغير: zoom (level: in/out/reset)
- الدوران: rotate (degrees: رقم موجب أو سالب)
- إعادة الألوان الأصلية: resetColors
- إضافة كائنات: addObject (type: tree/car/lamppost, count: رقم 1-5)

أجب دائماً بـ JSON فقط بهذا الشكل بالضبط:
{"response":"رسالتك للمستخدم","commands":[{"action":"changeColor","target":"walls","color":"#1A73E8"}]}

قواعد:
- إذا كان الطلب نصيحة بناء وليس تعديل نموذج، أعد commands كمصفوفة فارغة []
- يمكنك تنفيذ عدة أوامر معاً في نفس الرد
- أجب بنفس لغة المستخدم'''
        : '''You are an AI assistant specializing in construction and real estate in Jordan. You can also control the 3D building model being viewed.

STRICT RULE: You are FORBIDDEN from answering anything outside of:
1. Construction and real estate in Jordan (material prices, regulations, costs, advice)
2. Controlling/editing the 3D building model (colors, zoom, rotation)

If the user asks about anything else (medicine, politics, food, general knowledge), respond ONLY with: "I specialize in construction, real estate in Jordan, and building visualization only."

Available 3D model commands:
- Change color: changeColor (target: walls/roof/floor, color: hex like #FF0000)
- Zoom: zoom (level: in/out/reset)
- Rotate: rotate (degrees: positive or negative number)
- Reset original colors: resetColors
- Add objects: addObject (type: tree/car/lamppost, count: 1-5)

Always respond with JSON ONLY in exactly this format:
{"response":"Your message to the user","commands":[{"action":"changeColor","target":"walls","color":"#1A73E8"}]}

Rules:
- If the request is construction advice (not a model edit), return commands as empty array []
- You can run multiple commands in the same response
- Respond in the same language as the user''';
  }

  static Future<Map<String, dynamic>> sendBuildingCommand({
    required String userMessage,
    required String lang,
    required String buildingTitle,
    String? landInfo,
  }) async {
    final systemContent = landInfo != null && landInfo.isNotEmpty
        ? '${_buildingCommandSystemPrompt(lang)}\n\n$landInfo'
        : _buildingCommandSystemPrompt(lang);
    final messages = [
      {'role': 'system', 'content': systemContent},
      {
        'role': 'user',
        'content': lang == 'ar'
            ? 'أعمل على نموذج "$buildingTitle". $userMessage'
            : 'Working on a "$buildingTitle" model. $userMessage',
      },
    ];

    final response = await http.post(
      Uri.parse(_url),
      headers: {
        'Authorization': 'Bearer $openAiApiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'messages': messages,
        'max_tokens': 400,
        'temperature': 0.3,
        'response_format': {'type': 'json_object'},
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content = (data['choices'][0]['message']['content'] as String).trim();
      return jsonDecode(content) as Map<String, dynamic>;
    }
    final err = jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(err['error']?['message'] ?? 'Error ${response.statusCode}');
  }

  static Future<String> send({
    required List<ChatMessage> history,
    required String userMessage,
    required String lang,
    String? buildingContext,
    String? landInfo,
    bool useSearch = true, // false → gpt-4o-mini (reliably follows land data in prompt)
  }) async {
    String systemContent = _systemPrompt(lang, buildingContext: buildingContext);
    if (landInfo != null && landInfo.isNotEmpty) {
      systemContent += '\n\n$landInfo';
    }
    final messages = [
      {'role': 'system', 'content': systemContent},
      ...history.map((m) => {'role': m.role, 'content': m.content}),
      {'role': 'user', 'content': userMessage},
    ];

    final model = useSearch ? _searchModel : _model;
    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
    };
    // search model does not support temperature / max_tokens
    if (!useSearch) {
      body['temperature'] = 0.4;
      body['max_tokens']  = 1200;
    }

    final response = await http.post(
      Uri.parse(_url),
      headers: {
        'Authorization': 'Bearer $openAiApiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['choices'][0]['message']['content'] as String).trim();
    }
    final err = jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(err['error']?['message'] ?? 'Error ${response.statusCode}');
  }
}
