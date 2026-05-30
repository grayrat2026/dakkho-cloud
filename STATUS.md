# DAKKHO — Cloud Services Status Dashboard

> Last Updated: _2026-03-05_  
> Environment: **Production (Free Tier)**  
> Architecture: **100% Cloud, Zero VPS**

---

## Service Status Overview

| # | Service | Provider | Status | Free Tier | Setup Date |
|---|---------|----------|--------|-----------|------------|
| 1 | Object Storage | Cloudflare R2 | ⬜ Not Started | 10 GB + Zero Egress | — |
| 2 | Live Video | LiveKit Cloud | ⬜ Not Started | 5 rooms, 10K min/mo | — |
| 3 | Push Notifications | OneSignal | ⬜ Not Started | Unlimited | — |
| 4 | Email | Resend | ⬜ Not Started | 100/day, 3K/mo | — |
| 5 | Backend | Appwrite Cloud | ✅ Active | 1M reads, 500K writes | — |
| 6 | CDN (optional) | Bunny CDN | ⬜ Not Started | 1 TB egress/mo | — |

**Status Legend:** ⬜ Not Started | 🔧 Setup | ✅ Active | ⚠️ Warning | ❌ Down

---

## Free Tier Usage Dashboard

### Monthly Tracking Template (fill in each month)

#### Cloudflare R2

| Metric | Free Tier | Month 1 | Month 2 | Month 3 |
|--------|-----------|---------|---------|---------|
| Storage (GB) | 10 GB | — | — | — |
| Class A Operations (PUT/POST) | 10M/mo | — | — | — |
| Class B Operations (GET) | 1M/mo | — | — | — |
| Egress | **UNLIMITED** | — | — | — |
| **Usage %** | — | — | — | — |

**DAKKHO Estimate (500 students):** ~5 GB storage, ~50K Class A, ~500K Class B/mo

#### LiveKit Cloud

| Metric | Free Tier | Month 1 | Month 2 | Month 3 |
|--------|-----------|---------|---------|---------|
| Concurrent Rooms | 5 | — | — | — |
| Participants/Room | 100 | — | — | — |
| Minutes Used | 10,000/mo | — | — | — |
| **Usage %** | — | — | — | — |

**DAKKHO Estimate (5 live classes/week × 2hr × 30 students):** ~1,200 min/mo

#### OneSignal

| Metric | Free Tier | Month 1 | Month 2 | Month 3 |
|--------|-----------|---------|---------|---------|
| Subscribers | Unlimited | — | — | — |
| Notifications Sent | Unlimited | — | — | — |
| Click Rate | — | — | — | — |

**DAKKHO Estimate:** 2-3 notifications/user/week

#### Resend

| Metric | Free Tier | Month 1 | Month 2 | Month 3 |
|--------|-----------|---------|---------|---------|
| Emails Sent/Day | 100 | — | — | — |
| Emails Sent/Month | 3,000 | — | — | — |
| Custom Domains | 1 | — | — | — |
| **Usage %** | — | — | — | — |

**DAKKHO Estimate:** ~50 emails/day (welcome + transactional)

---

## Cost Projections

### Current: $0/month (Free Tier)

All services running within free tier limits.

### Scaling Tiers

| Users | R2 | LiveKit | Resend | OneSignal | Appwrite | **Total/mo** |
|-------|-----|---------|--------|-----------|----------|-------------|
| 0-500 | $0 | $0 | $0 | $0 | $0 | **$0** |
| 500-2K | $0 | $0 | $0 | $0 | $15 | **$15** |
| 2K-5K | $1.50 | $0 | $20 | $0 | $15 | **$36.50** |
| 5K-10K | $5 | $48 | $20 | $0 | $15 | **$88** |
| 10K-20K | $15 | $72 | $20 | $0 | $15 | **$122** |
| 20K+ | $30 | $144 | $20 | $0 | $15 | **$209** |

### Per-Service Breakdown

#### Cloudflare R2
- **$0/mo** up to 10 GB storage
- **$0.015/GB/mo** storage after free tier
- **$0** egress (always free — this is R2's killer feature)
- **$4.50/mo** per million Class A operations
- **$0.36/mo** per million Class B operations

#### LiveKit Cloud
- **$0/mo** free tier (5 rooms, 10K minutes)
- **$0.004/min/participant** after free tier
- Estimate: 30 students × 5 classes/week × 2hr = 1,200 min/mo → stays free
- At 5K users: ~12,000 min/mo → $48/mo

#### OneSignal
- **$0/mo** forever (unlimited subscribers, unlimited notifications)
- Paid plan ($9/mo) adds: A/B testing, advanced analytics, delivery windows

#### Resend
- **$0/mo** free tier (100 emails/day, 3K/month)
- **$20/mo** Pro plan (100K emails/month, custom domains, templates)
- DAKKHO estimate: ~1,500 emails/mo → stays on free tier for a while

---

## Alert Thresholds

When to take action before hitting free tier limits.

### Critical Alerts (immediate action required)

| Service | Metric | Threshold | Alert Level | Action |
|---------|--------|-----------|-------------|--------|
| R2 | Storage | 8 GB (80%) | 🔴 Critical | Clean up temp files, optimize video encoding |
| LiveKit | Minutes | 8,000 (80%) | 🔴 Critical | Schedule fewer classes, upgrade plan |
| Resend | Daily emails | 90 (90%) | 🔴 Critical | Batch notifications, reduce email frequency |
| Resend | Monthly emails | 2,500 (83%) | 🔴 Critical | Same as above |

### Warning Alerts (monitor closely)

| Service | Metric | Threshold | Alert Level | Action |
|---------|--------|-----------|-------------|--------|
| R2 | Class A ops | 8M/mo (80%) | 🟡 Warning | Check upload patterns, batch operations |
| R2 | Class B ops | 800K/mo (80%) | 🟡 Warning | Enable CDN caching (Bunny) |
| LiveKit | Concurrent rooms | 4 (80%) | 🟡 Warning | Schedule classes at different times |
| Resend | Daily emails | 70 (70%) | 🟡 Warning | Review email strategy |

### Info Alerts (just FYI)

| Service | Metric | Threshold | Alert Level | Action |
|---------|--------|-----------|-------------|--------|
| R2 | Storage | 5 GB (50%) | 🔵 Info | Normal growth, no action needed |
| LiveKit | Minutes | 5,000 (50%) | 🔵 Info | Normal usage |
| Resend | Monthly emails | 1,500 (50%) | 🔵 Info | Normal usage |

---

## Monthly Checklist

### First of Each Month

- [ ] Update usage numbers in the dashboard above
- [ ] Check R2 storage usage in [Cloudflare Dashboard](https://dash.cloudflare.com/)
- [ ] Check LiveKit minutes in [LiveKit Cloud Dashboard](https://cloud.livekit.io/)
- [ ] Check email count in [Resend Dashboard](https://resend.com/emails)
- [ ] Review OneSignal notification performance
- [ ] Verify no unexpected charges
- [ ] Update this STATUS.md file

### Weekly

- [ ] Monitor R2 lifecycle rules are cleaning up temp/processing/failed directories
- [ ] Check LiveKit room utilization
- [ ] Review notification delivery rates (OneSignal)
- [ ] Check for bounced emails (Resend)

---

## Emergency Procedures

### R2 Storage Full

1. Check lifecycle rules are active: Dashboard → R2 → Bucket → Settings → Object lifecycle
2. Manually delete old temp/processing/failed files
3. Enable Bunny CDN for caching (reduces R2 read operations)
4. Upgrade to paid plan ($0.015/GB)

### LiveKit Minutes Exhausted

1. Reduce live class frequency
2. Shorter class durations
3. Record classes instead of live (upload to R2)
4. Upgrade to Starter plan ($49/mo for 50K minutes)

### Resend Daily Limit Hit

1. Batch non-urgent emails for next day
2. Use OneSignal push notifications as alternative
3. Prioritize transactional emails (payment, device swap) over marketing
4. Upgrade to Pro plan ($20/mo)

### Service Outage

| Service | Status Page | Fallback |
|---------|------------|----------|
| Cloudflare R2 | https://www.cloudflarestatus.com/ | Show cached videos (offline mode) |
| LiveKit Cloud | https://status.livekit.io/ | Show "Live class unavailable" message |
| OneSignal | https://status.onesignal.com/ | In-app notifications via Appwrite Realtime |
| Resend | https://status.resend.com/ | Queue emails for retry, show in-app message |

---

## Service Links

| Service | Dashboard | Documentation |
|---------|-----------|---------------|
| Cloudflare R2 | https://dash.cloudflare.com/ | https://developers.cloudflare.com/r2/ |
| LiveKit Cloud | https://cloud.livekit.io/ | https://docs.livekit.io/ |
| OneSignal | https://app.onesignal.com/ | https://documentation.onesignal.com/ |
| Resend | https://resend.com/overview | https://resend.com/docs |
| Appwrite | https://cloud.appwrite.io/ | https://appwrite.io/docs |
| Bunny CDN | https://dash.bunny.net/ | https://docs.bunny.net/ |
