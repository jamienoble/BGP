import 'package:flutter/material.dart';

class EducationScreen extends StatelessWidget {
  const EducationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Women\'s Health Insights',
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          // Health News Summary Box
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: const Color(0xFFE8D7C3)),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with icon
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDEEFE8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.health_and_safety,
                          color: const Color(0xFF2D5A4A),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Latest in Women\'s Health',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2D5A4A),
                              ),
                            ),
                            Text(
                              'AI-curated news',
                              style: TextStyle(
                                fontSize: 12,
                                color: const Color(0xFF8BA39E),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // News content
                  Text(
                    'The Government has unveiled a major renewal of its Women\'s Health Strategy, pledging a ten-year overhaul to eradicate "medical misogyny" within the NHS. Health Secretary Wes Streeting announced that the strategy will combat the systemic "gaslighting" often faced by women, introducing a new standard of care to ensure appropriate pain relief during invasive gynaecological procedures and implementing a "single referral point" to end the frustrating delays currently plaguing diagnoses for conditions like endometriosis and fibroids. Supported by a new Femtech challenge fund and improved menstrual education programmes, the reforms aim to shift care from hospitals into the community and mandate menopause screening as part of routine NHS health checks, ultimately seeking to close the stark health inequality gap that leaves women spending more of their lives in poor health than men.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: const Color(0xFF4A6B62),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // TODO: Add dynamic content push logic here
                  // This space is reserved for:
                  // - Fetching latest health news from API
                  // - AI summarization service integration
                  // - User notification preferences
                  // - News refresh timestamps
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // TODO: Add additional education content sections below
        ],
      ),
    );
  }
}
