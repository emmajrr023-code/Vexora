// Vercel serverless function: Gemini chat proxy. Keep GEMINI_API_KEY in Vercel Environment Variables.
export default async function handler(req, res) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    return res.status(503).json({ error: 'AI is not configured yet. Add GEMINI_API_KEY in the Vercel project settings.' });
  }

  const prompt = typeof req.body?.message === 'string' ? req.body.message.trim() : '';
  if (!prompt) return res.status(400).json({ error: 'Please enter a message.' });
  if (prompt.length > 8000) return res.status(413).json({ error: 'Message is too long. Please keep it under 8,000 characters.' });

  try {
    const model = process.env.GEMINI_MODEL || 'gemini-2.5-flash';
    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey
      },
      body: JSON.stringify({
        systemInstruction: {
          parts: [{ text: 'You are Vexora, a helpful multilingual AI assistant. Reply in the language used by the user. Support Hindi and English and other languages when possible. Be clear, respectful, and concise.' }]
        },
        contents: [{ role: 'user', parts: [{ text: prompt }] }],
        generationConfig: { temperature: 0.7, maxOutputTokens: 1200 }
      })
    });

    const data = await response.json();
    if (!response.ok) {
      console.error('Gemini API error:', response.status, data?.error?.message || 'Unknown error');
      return res.status(502).json({ error: 'The AI service could not complete the request. Please try again later.' });
    }

    const answer = data?.candidates?.[0]?.content?.parts
      ?.map(part => part.text || '')
      .join('')
      .trim();
    if (!answer) return res.status(502).json({ error: 'The AI service returned an empty response.' });
    return res.status(200).json({ reply: answer });
  } catch (error) {
    console.error('Vexora chat error:', error);
    return res.status(500).json({ error: 'A server error occurred. Please try again.' });
  }
}
