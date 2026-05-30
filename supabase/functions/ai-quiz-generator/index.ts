// DAKKHO — AI Quiz Generator Edge Function
// Generates BTEB-style quiz questions using OpenAI or Gemini API
// Optionally saves quiz & questions to Appwrite via REST API

import "jsr:@supabase/functions-js/edge-runtime.d.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Appwrite REST API helpers
const APPWRITE_ENDPOINT = Deno.env.get('APPWRITE_ENDPOINT') || 'https://sgp.cloud.appwrite.io/v1'
const APPWRITE_PROJECT_ID = Deno.env.get('APPWRITE_PROJECT_ID') || 'dakkho'
const APPWRITE_API_KEY = Deno.env.get('APPWRITE_API_KEY')

const appwriteHeaders: Record<string, string> = {
  'Content-Type': 'application/json',
  'X-Appwrite-Project': APPWRITE_PROJECT_ID,
  'X-Appwrite-Key': APPWRITE_API_KEY || '',
  'X-Appwrite-Response-Format': '1.6.0',
}

const DATABASE_ID = 'dakkho-main'
const QUIZZES_COLLECTION = 'quizzes'
const QUIZ_QUESTIONS_COLLECTION = 'quiz_questions'

// Department-specific BTEB context for better AI generation
const DEPARTMENT_CONTEXT: Record<string, string> = {
  computer: 'Computer Science & Technology — BTEB Diploma topics: Programming (C/Java/Python), Data Structures, Database Management, Networking, Web Development, Operating Systems, Computer Architecture, Software Engineering',
  electrical: 'Electrical Technology — BTEB Diploma topics: Electrical Circuits, Power Systems, Electrical Machines, Control Systems, Measurement & Instrumentation, Power Electronics',
  mechanical: 'Mechanical Technology — BTEB Diploma topics: Thermodynamics, Fluid Mechanics, Manufacturing Processes, Machine Design, Material Science, Heat Transfer',
  civil: 'Civil Technology — BTEB Diploma topics: Structural Analysis, Surveying, Construction Materials, Geotechnical Engineering, Hydraulics, Estimating & Costing',
  electronics: 'Electronics Technology — BTEB Diploma topics: Analog Electronics, Digital Electronics, Microprocessors, Communication Systems, Signal Processing, VLSI Design',
  textile: 'Textile Technology — BTEB Diploma topics: Textile Fiber, Yarn Manufacturing, Fabric Manufacturing, Wet Processing, Apparel Manufacturing, Textile Testing',
  automobile: 'Automobile Technology — BTEB Diploma topics: Auto Engines, Auto Electrical Systems, Transmission Systems, Steering & Suspension, Auto Service & Maintenance',
}

interface QuizQuestion {
  question_text: string
  option_a: string
  option_b: string
  option_c: string
  option_d: string
  correct_answer: string
  explanation: string
  difficulty: string
  topic_tag: string
  // Alternate field names that AI might return
  question?: string
  options?: string[]
}

async function generateWithAI(
  topic: string,
  difficulty: string,
  questionCount: number,
  department: string,
  semester: number
): Promise<QuizQuestion[]> {
  const apiKey = Deno.env.get('OPENAI_API_KEY') || Deno.env.get('GEMINI_API_KEY')
  const useGemini = !!Deno.env.get('GEMINI_API_KEY')

  if (!apiKey) {
    throw new Error('No AI API key configured. Set OPENAI_API_KEY or GEMINI_API_KEY.')
  }

  const deptContext = DEPARTMENT_CONTEXT[department] || DEPARTMENT_CONTEXT.computer
  const difficultyBn = { easy: 'সহজ', medium: 'মাঝারি', hard: 'কঠিন' }[difficulty] || 'মাঝারি'

  const systemPrompt = `তুমি বাংলাদেশ কারিগরি শিক্ষা বোর্ড (BTEB) এর ডিপ্লোমা ইঞ্জিনিয়ারিং শিক্ষার্থীদের জন্য কুইজ প্রশ্ন তৈরি করো।
বিভাগ: ${deptContext}
সেমিস্টার: ${semester}
কঠিনতা: ${difficultyBn}

প্রতিটি প্রশ্ন অবশ্যই:
1. বাংলায় লেখা হবে
2. ৪টি অপশন থাকবে (ক, খ, গ, ঘ)
3. সঠিক উত্তর থাকবে
4. ব্যাখ্যা থাকবে

JSON array ফরম্যাটে আউটপুট দাও, প্রতিটি অবজেক্টে:
- question_text: বাংলায় প্রশ্ন
- option_a, option_b, option_c, option_d: অপশন (বাংলায়)
- correct_answer: "a" বা "b" বা "c" বা "d"
- explanation: বাংলায় ব্যাখ্যা
- difficulty: "${difficulty}"
- topic_tag: টপিকের নাম`

  const userPrompt = `"${topic}" বিষয়ে ${questionCount}টি ${difficultyBn} MCQ প্রশ্ন তৈরি করো।`

  if (useGemini) {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${Deno.env.get('GEMINI_API_KEY')}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          system_instruction: { parts: [{ text: systemPrompt }] },
          contents: [{ parts: [{ text: userPrompt }] }],
          generationConfig: {
            temperature: 0.7,
            responseMimeType: 'application/json',
          },
        }),
      }
    )

    const data = await response.json()
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text || '[]'
    return JSON.parse(text.replace(/```json\n?/g, '').replace(/```\n?/g, ''))
  } else {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt },
        ],
        temperature: 0.7,
        response_format: { type: 'json_object' },
      }),
    })

    const data = await response.json()
    const content = data.choices?.[0]?.message?.content || '{}'
    const parsed = JSON.parse(content)
    return Array.isArray(parsed) ? parsed : parsed.questions || []
  }
}

/**
 * Create document in Appwrite via REST API
 */
async function createAppwriteDoc(collectionId: string, docData: Record<string, unknown>) {
  const resp = await fetch(
    `${APPWRITE_ENDPOINT}/databases/${DATABASE_ID}/collections/${collectionId}/documents`,
    {
      method: 'POST',
      headers: appwriteHeaders,
      body: JSON.stringify({ documentId: 'unique()', data: docData }),
    }
  )
  if (!resp.ok) {
    const errText = await resp.text()
    throw new Error(`Appwrite create failed (${resp.status}): ${errText}`)
  }
  return resp.json()
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const body = await req.json()
    const {
      topic,
      difficulty = 'medium',
      questionCount = 10,
      department = 'computer',
      semester = 1,
      saveToQuiz = false,
      courseId,
    } = body

    if (!topic) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Missing required field: topic',
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const count = Math.min(Math.max(questionCount, 1), 50)

    console.log(`Generating ${count} ${difficulty} questions on "${topic}" for ${department} semester ${semester}...`)

    const questions = await generateWithAI(topic, difficulty, count, department, semester)

    if (!Array.isArray(questions) || questions.length === 0) {
      console.error('AI returned no questions')
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Failed to generate questions — AI returned empty response',
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    let quizId: string | null = null

    // Optionally save as a quiz with questions to Appwrite
    if (saveToQuiz && courseId) {
      if (!APPWRITE_API_KEY) {
        console.error('APPWRITE_API_KEY not configured, skipping save')
      } else {
        const now = new Date().toISOString()

        // Create quiz document
        const quizDoc = await createAppwriteDoc(QUIZZES_COLLECTION, {
          course_id: courseId,
          title: `AI Quiz: ${topic}`,
          description: `AI-generated ${difficulty} quiz on ${topic}`,
          quiz_type: 'ai_generated',
          time_limit_minutes: Math.ceil(count * 1.5),
          passing_score_percent: 40,
          negative_marking: true,
          negative_mark_value: 0.25,
          is_published: false,
          shuffle_questions: true,
          shuffle_options: true,
          show_answers_after: 'attempt_end',
          total_questions: questions.length,
          is_premium_only: true,
          created_by: 'ai-quiz-generator',
        })

        quizId = quizDoc.$id

        // Create question documents
        for (let i = 0; i < questions.length; i++) {
          const q = questions[i] as QuizQuestion
          await createAppwriteDoc(QUIZ_QUESTIONS_COLLECTION, {
            quiz_id: quizId,
            question_text: q.question_text || q.question || '',
            option_a: q.option_a || q.options?.[0] || '',
            option_b: q.option_b || q.options?.[1] || '',
            option_c: q.option_c || q.options?.[2] || '',
            option_d: q.option_d || q.options?.[3] || '',
            correct_answer: q.correct_answer || 'a',
            explanation: q.explanation || '',
            marks: 1.0,
            difficulty: difficulty,
            topic_tag: topic,
            sort_order: i + 1,
          })
        }

        console.log(`Saved AI quiz with ${questions.length} questions (quizId: ${quizId})`)
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        questions,
        count: questions.length,
        quizId,
        metadata: {
          topic,
          difficulty,
          department,
          semester,
        },
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    console.error(`AI quiz generation failed: ${err.message}`)
    return new Response(
      JSON.stringify({ success: false, error: err.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
