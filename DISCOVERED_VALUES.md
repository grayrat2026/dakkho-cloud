# DAKKHO Cloud — Service Credentials & Configuration

> **⚠️ All secrets are in `.env` (git-ignored). Never commit real credentials.**

## Supabase (DEPLOYED ✅)
- Project URL: https://spomlopbjuihpgpzwdqb.supabase.co
- Project Ref: spomlopbjuihpgpzwdqb
- Anon Key: `SUPABASE_ANON_KEY` → see `.env`
- Access Token: `SUPABASE_ACCESS_TOKEN` → see `.env`
- PostgreSQL: 17.6 on aarch64
- Region: Auto-assigned by Supabase
- Role: Complementary to Appwrite (Analytics, AI/ML, Realtime, Cron, Complex Queries)
- Status: 11 tables deployed, 5 Edge Functions deployed, 4 pg_cron jobs active

## Appwrite Cloud (VERIFIED ✅)
- Project ID: dakkho
- Endpoint: https://sgp.cloud.appwrite.io/v1
- Region: Singapore (sgp)
- API Key: `APPWRITE_API_KEY` → see `.env`
- Role: Auth + Document DB + Realtime (free plan: 1 bucket, 2 functions)

## Cloudflare R2 (VERIFIED ✅)
- Account ID: `R2_ACCOUNT_ID` → see `.env`
- S3 Endpoint: `R2_ENDPOINT` → see `.env`
- Bucket Name: dakkho (APAC region)
- Access Key ID: `R2_ACCESS_KEY` → see `.env`
- Secret Access Key: `R2_SECRET_KEY` → see `.env`
- API Token: `R2_API_TOKEN` → see `.env`
- Role: PRIMARY storage (zero egress cost) — replaces Appwrite buckets

## LiveKit Cloud (VERIFIED ✅)
- WebSocket URL: wss://dakkho-u74kq16n.livekit.cloud
- API Key: `LIVEKIT_API_KEY` → see `.env`
- API Secret: `LIVEKIT_API_SECRET` → see `.env`
- Role: Live class video/audio (cloud only, no VPS fallback)

## OneSignal (VERIFIED ✅)
- App ID: `ONESIGNAL_APP_ID` → see `.env`
- Rest API Key: `ONESIGNAL_REST_API_KEY` → see `.env`
- Role: Push notifications (5 categories, 7 segments)

## Resend (VERIFIED ✅)
- API Key: `RESEND_API_KEY` → see `.env`
- Domain: dakkho.pro.bd (VERIFIED)
- From Email: noreply@dakkho.pro.bd
- Role: Transactional email (welcome, payment, subscription, device swap)

## GitHub (VERIFIED ✅)
- Username: grayrat2026
- Repo Student: https://github.com/grayrat2026/dakkho-student (private)
- Repo Cloud: https://github.com/grayrat2026/dakkho-cloud (private)
- Role: Source code hosting + CI/CD (GitHub Actions)

## Architecture Summary ($0/month — All Free Tiers)
- **Appwrite** = Auth + DB + Realtime (2 functions max on free plan)
- **Supabase** = 13 Edge Functions + Analytics + AI/ML + Vector Search + pg_cron
- **R2** = ALL file storage (videos, documents, avatars, assets — zero egress)
- **LiveKit** = Live Classes
- **OneSignal** = Push Notifications
- **Resend** = Transactional Email
