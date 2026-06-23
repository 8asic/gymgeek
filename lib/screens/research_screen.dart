import 'package:flutter/material.dart';
import '../services/research_service.dart';
import '../utils/app_theme.dart';

class ResearchScreen extends StatefulWidget {
  const ResearchScreen({super.key});

  @override
  State<ResearchScreen> createState() => _ResearchScreenState();
}

class _ResearchScreenState extends State<ResearchScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  ResearchSummaryResult? _result;

  final _suggestions = [
    'stretching injury prevention',
    'how much protein do I need',
    'HIIT vs steady cardio fat loss',
    'progressive overload strength',
    'sleep and muscle recovery',
    'warm up before workout',
  ];

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() { _loading = true; _result = null; });
    final result = await ResearchService().summarise(query);
    if (mounted) setState(() { _result = result; _loading = false; });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Row(
          children: [
            Text('Research'),
            SizedBox(width: 8),
            _AiBadge(),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search input
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    textInputAction: TextInputAction.search,
                    onSubmitted: _search,
                    decoration: const InputDecoration(
                      hintText: 'Ask a fitness research question...',
                      prefixIcon: Icon(Icons.science_outlined, color: AppColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _loading ? null : () => _search(_ctrl.text),
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(52, 52), padding: EdgeInsets.zero),
                  child: const Icon(Icons.send, size: 20),
                ),
              ],
            ),
          ),

          // Suggestions
          if (_result == null && !_loading) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Try asking:',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _suggestions.map((s) => Padding(
                padding: const EdgeInsets.only(left: 16),
                child: ActionChip(
                  label: Text(s, style: const TextStyle(fontSize: 12)),
                  backgroundColor: AppColors.card,
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  onPressed: () {
                    _ctrl.text = s;
                    _search(s);
                  },
                ),
              )).toList(),
            ),
          ],

          // Loading
          if (_loading)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text('Retrieving research & generating summary...',
                        style: TextStyle(color: AppColors.textSecondary)),
                    SizedBox(height: 6),
                    Text('(Powered by Gemini 1.5 Flash)',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ),

          // Result
          if (_result != null && !_loading)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Error banner if Ollama offline
                    if (_result!.error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_result!.error!,
                                  style: const TextStyle(color: Colors.orange, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),

                    // AI / Raw badge
                    Row(
                      children: [
                        const Text('Summary',
                            style: TextStyle(color: AppColors.textPrimary,
                                fontSize: 17, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        if (_result!.isAiGenerated) const _AiBadge()
                        else const _RawBadge(),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Summary text
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _result!.summary,
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 14, height: 1.6),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Sources (RAG)
                    if (_result!.sources.isNotEmpty) ...[
                      const Text('Sources (RAG Knowledge Base)',
                          style: TextStyle(color: AppColors.textPrimary,
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      ..._result!.sources.map((p) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.cardLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.title,
                                style: const TextStyle(color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(p.citation,
                                style: const TextStyle(
                                    color: AppColors.primary, fontSize: 12)),
                          ],
                        ),
                      )),
                    ],

                    // New search button
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () {
                        _ctrl.clear();
                        setState(() => _result = null);
                      },
                      icon: const Icon(Icons.search, size: 16),
                      label: const Text('Ask another question'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AiBadge extends StatelessWidget {
  const _AiBadge();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.auto_awesome, color: Colors.white, size: 11),
        SizedBox(width: 4),
        Text('AI + RAG', style: TextStyle(color: Colors.white,
            fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

class _RawBadge extends StatelessWidget {
  const _RawBadge();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.orange,
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Text('RAG Only',
        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
  );
}
