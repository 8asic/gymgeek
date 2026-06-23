import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../utils/app_constants.dart';
import 'database_service.dart';

class ResearchPaper {
  final String id;
  final String title;
  final List<String> authors;
  final int year;
  final String abstract;
  final List<String> keywords;

  ResearchPaper({
    required this.id,
    required this.title,
    required this.authors,
    required this.year,
    required this.abstract,
    required this.keywords,
  });

  factory ResearchPaper.fromJson(Map<String, dynamic> j) => ResearchPaper(
        id: j['id'] as String,
        title: j['title'] as String,
        authors: List<String>.from(j['authors'] as List),
        year: j['year'] as int,
        abstract: j['abstract'] as String,
        keywords: List<String>.from(j['keywords'] as List),
      );

  String get citation => '${authors.first} et al. ($year)';
}

class ResearchSummaryResult {
  final String summary;
  final List<ResearchPaper> sources;
  final bool isAiGenerated;
  final String? error;

  ResearchSummaryResult({
    required this.summary,
    required this.sources,
    this.isAiGenerated = true,
    this.error,
  });
}

class ResearchService {
  static final ResearchService _instance = ResearchService._internal();
  factory ResearchService() => _instance;
  ResearchService._internal();

  List<ResearchPaper> _papers = [];
  bool _papersLoaded = false;

  // ─── RAG: Load knowledge base ─────────────────────────────────────────

  Future<void> loadResearchBase() async {
    if (_papersLoaded) return;
    final jsonStr = await rootBundle.loadString('assets/research.json');
    final List<dynamic> list = json.decode(jsonStr) as List;
    _papers = list.map((e) => ResearchPaper.fromJson(e as Map<String, dynamic>)).toList();
    _papersLoaded = true;
  }

  /// RAG retrieval: find papers relevant to the query
  List<ResearchPaper> _retrieveRelevant(String query) {
    final q = query.toLowerCase();
    final scored = <MapEntry<ResearchPaper, int>>[];
    for (final paper in _papers) {
      int score = 0;
      for (final kw in paper.keywords) {
        if (q.contains(kw.toLowerCase()) || kw.toLowerCase().contains(q)) score += 2;
      }
      if (paper.title.toLowerCase().contains(q)) score += 3;
      if (paper.abstract.toLowerCase().contains(q)) score += 1;
      if (score > 0) scored.add(MapEntry(paper, score));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    // Return top 3
    return scored.take(3).map((e) => e.key).toList();
  }

  // ─── Safety guardrails ────────────────────────────────────────────────

  static const _unsafeKeywords = [
    'steroid', 'anabolic', 'illegal', 'drug', 'overdose',
    'extreme starvation', 'self-harm', 'dangerous dose',
  ];

  bool _isSafe(String text) {
    final lower = text.toLowerCase();
    return !_unsafeKeywords.any((kw) => lower.contains(kw));
  }

  String _addDisclaimer(String text) =>
      '$text\n\n⚠️ *This is AI-generated fitness information, not medical advice. Consult a healthcare professional before starting any new exercise programme.*';

  String _friendlyError(String raw) {
    if (raw.contains('quota') || raw.contains('RESOURCE_EXHAUSTED')) {
      return 'Gemini API quota exceeded. Get a new key at aistudio.google.com/app/apikey.';
    }
    if (raw.contains('API_KEY_INVALID') || raw.contains('invalid')) {
      return 'Invalid Gemini API key. Check your key in constants.dart.';
    }
    if (raw.contains('not found') || raw.contains('404')) {
      return 'Gemini model not available for this API key.';
    }
    if (raw.contains('SocketException') || raw.contains('network')) {
      return 'No internet connection. Check your network and try again.';
    }
    return 'AI summary unavailable. Showing research excerpts instead.';
  }

  // ─── Main summarise method ────────────────────────────────────────────

  Future<ResearchSummaryResult> summarise(String userQuery) async {
    await loadResearchBase();

    // 1. RAG retrieval
    final relevantPapers = _retrieveRelevant(userQuery);

    if (relevantPapers.isEmpty) {
      return ResearchSummaryResult(
        summary: _addDisclaimer(
          'No specific research found for "$userQuery" in the knowledge base. '
          'Try keywords like: stretching, strength, cardio, protein, sleep, HIIT, warm up.',
        ),
        sources: [],
        isAiGenerated: false,
      );
    }

    // 2. Build context for LLM
    final context = relevantPapers.map((p) {
      return 'Title: ${p.title}\nAuthors: ${p.citation}\nAbstract: ${p.abstract}';
    }).join('\n\n---\n\n');

    final prompt = '''You are a helpful fitness assistant. Using ONLY the research below, 
write a concise, practical summary (3-5 sentences) answering this question: "$userQuery"

Research:
$context

Rules:
- Use only facts from the provided research
- Write in plain language for a gym-goer
- Do not invent statistics or claims not in the research
- Be practical and actionable''';

    // 3. Call Gemini
    try {
      final model = GenerativeModel(
        model: AppConstants.geminiModel,
        apiKey: AppConstants.geminiApiKey,
        generationConfig: GenerationConfig(
          temperature: 0.3,
          maxOutputTokens: 300,
        ),
      );

      final response = await model
          .generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 30));

      String summary = (response.text ?? '').trim();

      // 4. Safety check
      if (!_isSafe(summary)) {
        summary = 'The generated response was flagged by safety guardrails. '
            'Please rephrase your question or consult a certified trainer.';
      }

      await DatabaseService().logAuditEvent(
        eventType: 'llm_summary',
        details: 'query="$userQuery" sources=${relevantPapers.length}',
      );

      return ResearchSummaryResult(
        summary: _addDisclaimer(summary),
        sources: relevantPapers,
        isAiGenerated: true,
      );
    } catch (e) {
      // 5. Fallback: return retrieved abstracts directly
      final fallback = relevantPapers.map((p) {
        return '**${p.title}** (${p.citation})\n${p.abstract}';
      }).join('\n\n');

      await DatabaseService().logAuditEvent(
        eventType: 'llm_fallback',
        details: 'Gemini unavailable: $e',
      );

      final friendly = _friendlyError(e.toString());
      return ResearchSummaryResult(
        summary: _addDisclaimer(
          '⚡ *AI summary unavailable — showing raw research excerpts:*\n\n$fallback',
        ),
        sources: relevantPapers,
        isAiGenerated: false,
        error: friendly,
      );
    }
  }
}
