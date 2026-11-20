# VEXORA

VEXORA is a responsive AI and user-generated media website.

## Live application

- Production website: https://vexora-vexora-edb5.vercel.app
- Main interface: `index.html`
- Standalone sign-in/sign-up page: `login.html`
- AI chat endpoint: `POST /api/chat`

## Implemented

- Supabase email/password sign-up, sign-in and sign-out.
- User profile display name and bio.
- Private media storage in the `vexora-videos` bucket.
- Upload validation for supported image/video MIME types and 100 MB storage limit.
- AI moderation through the `moderate-upload` Supabase Edge Function.
- Safe media approval, confirmed-violation strikes, quarantine for uncertain files, and a seven-day suspension after three confirmed violations.
- Public/private visibility enforcement; only approved public media appears in search.
- My Uploads, moderation history, rejected-media appeals and admin review interface.
- Browser/device speech recognition and speech synthesis where supported.
- Gemini-powered chat through a server-side Vercel function. The Gemini API key is not exposed in browser code.
- Theme, language, voice and default privacy preferences stored on the device.

## Important operating limits and setup notes

- Media over 20 MB is currently kept private in quarantine because the moderation function uses inline Gemini inspection. It is not automatically approved.
- Video playback uses signed Supabase Storage URLs. A dedicated adaptive streaming/CDN service is not configured.
- The admin review interface requires an account with the `admin` role in `public.user_roles`. No account is currently assigned that role; assign it only after confirming the owner's exact sign-in account.
- Email confirmation and password security options depend on the Supabase Auth project settings.
- The leaked-password protection option is currently disabled in Supabase Auth and should be enabled in the dashboard.
- Voice availability depends on the browser and installed device voices; this is not cloned or custom AI voice generation.
- Real end-to-end browser testing of sign-in, file upload, Gemini moderation, appeals and admin actions is still required with a real signed-in test account.

## Environment configuration

Vercel:
- `GEMINI_API_KEY` (server-side secret)
- Optional `GEMINI_MODEL` (defaults to `gemini-2.5-flash`)

Supabase Edge Function secrets:
- `GEMINI_API_KEY`
- Supabase project-provided URL and server credentials

Never put a Gemini API key or Supabase service-role/secret key in client-side code or public repository files.
