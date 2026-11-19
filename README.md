# Vexora

Vexora is a bilingual-ready AI and media platform starter. The current website includes a responsive media interface, Public/Private visibility selection, multilingual and voice controls, and a server-side Gemini chat endpoint.

## Current status

- Website preview: `index.html`
- AI chat endpoint: `POST /api/chat`
- The Gemini API key is read only on the server from `GEMINI_API_KEY`.
- Media selection currently previews files in the browser; cloud uploads and account-based privacy are not connected yet.
- Voice controls are interface placeholders; speech recognition and generated voice replies are not connected yet.

## Run and configure

1. Deploy this repository to Vercel.
2. In Vercel Project Settings → Environment Variables, add `GEMINI_API_KEY` with a key created in Google AI Studio.
3. Optionally add `GEMINI_MODEL` to select a model; the current default is `gemini-2.5-flash`.
4. Redeploy after adding or changing environment variables.
5. Open the deployed site and test the chat.

Never put the Gemini API key in `index.html`, client-side JavaScript, or a public repository file.

## Next implementation steps

1. Connect speech-to-text and text-to-speech.
2. Add authentication and user profiles.
3. Add cloud media storage, upload validation, and access rules for Public and Private files.
4. Add a video delivery/streaming service and moderation tools.

## Notes

Hiding a download control does not prevent screen recording or all other forms of copying. Public/Private selection becomes enforceable only after authentication and server-side storage access rules are implemented.
