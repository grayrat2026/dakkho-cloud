// DAKKHO — Email Sender Edge Function
// Sends branded emails via Resend API with 4 template types
// Stateless — no database required

import "jsr:@supabase/functions-js/edge-runtime.d.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Email templates with DAKKHO branding
const EMAIL_TEMPLATES: Record<string, {
  subject: string
  html: (data: Record<string, string>) => string
}> = {
  welcome: {
    subject: 'দক্ষ-এ স্বাগতম! | Welcome to DAKKHO',
    html: (data) => `
      <div style="font-family: 'Hind Siliguri', Arial, sans-serif; max-width: 600px; margin: 0 auto; background: #0A0E1A; color: #E2E8F0; border-radius: 16px; overflow: hidden;">
        <div style="background: linear-gradient(135deg, #06B6D4, #0A0E1A); padding: 40px 30px; text-align: center;">
          <h1 style="color: #06B6D4; margin: 0; font-size: 32px;">দক্ষ</h1>
          <p style="color: #94A3B8; margin: 8px 0 0;">Engineering Learning Platform</p>
        </div>
        <div style="padding: 30px;">
          <h2 style="color: #06B6D4;">স্বাগতম, ${data.name || 'শিক্ষার্থী'}! 🎉</h2>
          <p style="color: #CBD5E1; line-height: 1.8;">
            দক্ষ-এ আপনার অ্যাকাউন্ট সফলভাবে তৈরি হয়েছে। আপনি এখন BTEB ডিপ্লোমা ইঞ্জিনিয়ারিং এর সকল কোর্স, কুইজ এবং লাইভ ক্লাস অ্যাক্সেস করতে পারবেন।
          </p>
          <div style="background: #1E293B; border-radius: 12px; padding: 20px; margin: 20px 0;">
            <p style="color: #06B6D4; margin: 0 0 8px; font-weight: bold;">আপনার ১০ দিনের ফ্রি ট্রায়াল শুরু হয়েছে!</p>
            <p style="color: #94A3B8; margin: 0; font-size: 14px;">সকল প্রিমিয়াম ফিচার ফ্রিতে ব্যবহার করুন</p>
          </div>
          <a href="${data.appLink || 'https://dakkho.com'}" style="display: inline-block; background: #06B6D4; color: #0A0E1A; padding: 12px 32px; border-radius: 8px; text-decoration: none; font-weight: bold; margin-top: 16px;">
            কোর্স দেখুন →
          </a>
        </div>
        <div style="padding: 20px 30px; background: #1E293B; text-align: center;">
          <p style="color: #64748B; font-size: 12px; margin: 0;">
            দক্ষ (DAKKHO) — BTEB Diploma Engineering Learning Platform<br>
            সাহায্য: help@dakkho.com
          </p>
        </div>
      </div>`,
  },
  subscription_confirmation: {
    subject: 'সাবস্ক্রিপশন নিশ্চিত! | Subscription Confirmed',
    html: (data) => `
      <div style="font-family: 'Hind Siliguri', Arial, sans-serif; max-width: 600px; margin: 0 auto; background: #0A0E1A; color: #E2E8F0; border-radius: 16px; overflow: hidden;">
        <div style="background: linear-gradient(135deg, #06B6D4, #0A0E1A); padding: 40px 30px; text-align: center;">
          <h1 style="color: #06B6D4; margin: 0; font-size: 32px;">দক্ষ</h1>
        </div>
        <div style="padding: 30px;">
          <h2 style="color: #06B6D4;">✅ সাবস্ক্রিপশন নিশ্চিত!</h2>
          <p style="color: #CBD5E1; line-height: 1.8;">
            ${data.name || 'শিক্ষার্থী'}, আপনার ${data.plan || 'Basic'} প্ল্যান সক্রিয় হয়েছে।
          </p>
          <div style="background: #1E293B; border-radius: 12px; padding: 20px; margin: 20px 0;">
            <p style="color: #E2E8F0; margin: 0;"><strong>প্ল্যান:</strong> ${data.plan || 'Basic'}</p>
            <p style="color: #E2E8F0; margin: 8px 0 0;"><strong>মেয়াদ:</strong> ${data.startDate || ''} থেকে ${data.expiryDate || ''}</p>
            <p style="color: #E2E8F0; margin: 8px 0 0;"><strong>পরিমাণ:</strong> ৳${data.amount || '0'}</p>
            <p style="color: #E2E8F0; margin: 8px 0 0;"><strong>লেনদেন ID:</strong> ${data.trxId || 'N/A'}</p>
          </div>
        </div>
        <div style="padding: 20px 30px; background: #1E293B; text-align: center;">
          <p style="color: #64748B; font-size: 12px; margin: 0;">
            দক্ষ (DAKKHO) — BTEB Diploma Engineering Learning Platform
          </p>
        </div>
      </div>`,
  },
  payment_receipt: {
    subject: 'পেমেন্ট রসিদ | Payment Receipt',
    html: (data) => `
      <div style="font-family: 'Hind Siliguri', Arial, sans-serif; max-width: 600px; margin: 0 auto; background: #0A0E1A; color: #E2E8F0; border-radius: 16px; overflow: hidden;">
        <div style="background: linear-gradient(135deg, #06B6D4, #0A0E1A); padding: 40px 30px; text-align: center;">
          <h1 style="color: #06B6D4; margin: 0; font-size: 32px;">দক্ষ</h1>
        </div>
        <div style="padding: 30px;">
          <h2 style="color: #06B6D4;">🧾 পেমেন্ট রসিদ</h2>
          <div style="background: #1E293B; border-radius: 12px; padding: 20px; margin: 20px 0;">
            <p style="color: #E2E8F0; margin: 0;"><strong>পরিমাণ:</strong> ৳${data.amount || '0'}</p>
            <p style="color: #E2E8F0; margin: 8px 0 0;"><strong>পেমেন্ট মাধ্যম:</strong> ${data.gateway || 'N/A'}</p>
            <p style="color: #E2E8F0; margin: 8px 0 0;"><strong>লেনদেন ID:</strong> ${data.trxId || 'N/A'}</p>
            <p style="color: #E2E8F0; margin: 8px 0 0;"><strong>তারিখ:</strong> ${data.date || new Date().toLocaleDateString('bn-BD')}</p>
          </div>
        </div>
        <div style="padding: 20px 30px; background: #1E293B; text-align: center;">
          <p style="color: #64748B; font-size: 12px; margin: 0;">
            দক্ষ (DAKKHO) — BTEB Diploma Engineering Learning Platform
          </p>
        </div>
      </div>`,
  },
  device_swap_alert: {
    subject: 'ডিভাইস পরিবর্তন সতর্কতা | Device Change Alert',
    html: (data) => `
      <div style="font-family: 'Hind Siliguri', Arial, sans-serif; max-width: 600px; margin: 0 auto; background: #0A0E1A; color: #E2E8F0; border-radius: 16px; overflow: hidden;">
        <div style="background: linear-gradient(135deg, #F59E0B, #0A0E1A); padding: 40px 30px; text-align: center;">
          <h1 style="color: #F59E0B; margin: 0; font-size: 32px;">দক্ষ</h1>
        </div>
        <div style="padding: 30px;">
          <h2 style="color: #F59E0B;">⚠️ ডিভাইস পরিবর্তন সতর্কতা</h2>
          <p style="color: #CBD5E1; line-height: 1.8;">
            ${data.name || 'শিক্ষার্থী'}, আপনার অ্যাকাউন্টে একটি নতুন ডিভাইস থেকে লগইন করা হয়েছে।
          </p>
          <div style="background: #1E293B; border-radius: 12px; padding: 20px; margin: 20px 0;">
            <p style="color: #E2E8F0; margin: 0;"><strong>নতুন ডিভাইস:</strong> ${data.newDevice || 'Unknown'}</p>
            <p style="color: #E2E8F0; margin: 8px 0 0;"><strong>পুরাতন ডিভাইস:</strong> ${data.oldDevice || 'Unknown'}</p>
            <p style="color: #E2E8F0; margin: 8px 0 0;"><strong>সময়:</strong> ${data.swapTime || new Date().toLocaleString('bn-BD')}</p>
          </div>
          <p style="color: #F59E0B; font-size: 14px;">
            ⚠️ আপনি যদি এই পরিবর্তন না করে থাকেন, অনুগ্রহ করে অবিলম্বে help@dakkho.com এ যোগাযোগ করুন।
          </p>
        </div>
        <div style="padding: 20px 30px; background: #1E293B; text-align: center;">
          <p style="color: #64748B; font-size: 12px; margin: 0;">
            দক্ষ (DAKKHO) — BTEB Diploma Engineering Learning Platform
          </p>
        </div>
      </div>`,
  },
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { to, templateId, data = {} } = await req.json()

    if (!to || !templateId) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Missing required fields: to, templateId',
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const resendApiKey = Deno.env.get('RESEND_API_KEY')
    if (!resendApiKey) {
      console.error('RESEND_API_KEY not configured')
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Email service not configured',
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get template
    const template = EMAIL_TEMPLATES[templateId]
    if (!template) {
      return new Response(
        JSON.stringify({
          success: false,
          error: `Unknown template: ${templateId}. Available: ${Object.keys(EMAIL_TEMPLATES).join(', ')}`,
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const fromEmail = Deno.env.get('FROM_EMAIL') || 'DAKKHO <noreply@dakkho.com>'
    const htmlContent = template.html(data)

    // Send via Resend API
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${resendApiKey}`,
      },
      body: JSON.stringify({
        from: fromEmail,
        to: Array.isArray(to) ? to : [to],
        subject: template.subject,
        html: htmlContent,
      }),
    })

    const result = await response.json()

    if (!response.ok) {
      console.error(`Resend API error: ${JSON.stringify(result)}`)
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Failed to send email',
          details: result,
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`Email sent: template=${templateId}, to=${to}, emailId=${result.id}`)

    return new Response(
      JSON.stringify({
        success: true,
        emailId: result.id,
        templateId,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    console.error(`Email sending failed: ${err.message}`)
    return new Response(
      JSON.stringify({ success: false, error: err.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
