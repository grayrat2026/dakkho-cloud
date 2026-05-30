import { Client, Databases, ID, Query } from 'node-appwrite';

const DATABASE_ID = 'dakkho-main';
const QUIZZES_COLLECTION = 'quizzes';
const QUIZ_QUESTIONS_COLLECTION = 'quiz_questions';

// Department-specific BTEB context for better AI generation
const DEPARTMENT_CONTEXT = {
  computer: 'Computer Science & Technology — BTEB Diploma topics: Programming (C/Java/Python), Data Structures, Database Management, Networking, Web Development, Operating Systems, Computer Architecture, Software Engineering',
  electrical: 'Electrical Technology — BTEB Diploma topics: Electrical Circuits, Power Systems, Electrical Machines, Control Systems, Measurement & Instrumentation, Power Electronics',
  mechanical: 'Mechanical Technology — BTEB Diploma topics: Thermodynamics, Fluid Mechanics, Manufacturing Processes, Machine Design, Material Science, Heat Transfer',
  civil: 'Civil Technology — BTEB Diploma topics: Structural Analysis, Surveying, Construction Materials, Geotechnical Engineering, Hydraulics, Estimating & Costing',
  electronics: 'Electronics Technology — BTEB Diploma topics: Analog Electronics, Digital Electronics, Microprocessors, Communication Systems, Signal Processing, VLSI Design',
  textile: 'Textile Technology — BTEB Diploma topics: Textile Fiber, Yarn Manufacturing, Fabric Manufacturing, Wet Processing, Apparel Manufacturing, Textile Testing',
  automobile: 'Automobile Technology — BTEB Diploma topics: Auto Engines, Auto Electrical Systems, Transmission Systems, Steering & Suspension, Auto Service & Maintenance',
};

async function generateWithAI(topic, difficulty, questionCount, department, semester) {
  const apiKey = process.env.OPENAI_API_KEY || process.env.GEMINI_API_KEY;
  const useGemini = !!process.env.GEMINI_API_KEY;

  const deptContext = DEPARTMENT_CONTEXT[department] || DEPARTMENT_CONTEXT.computer;
  const difficultyBn = { easy: 'সহজ', medium: 'মাঝারি', hard: 'কঠিন' }[difficulty] || 'মাঝারি';

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
- topic_tag: টপিকের নাম`;

  const userPrompt = `"${topic}" বিষয়ে ${questionCount}টি ${difficultyBn} MCQ প্রশ্ন তৈরি করো।`;

  if (useGemini) {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${process.env.GEMINI_API_KEY}`,
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
    );

    const data = await response.json();
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text || '[]';
    return JSON.parse(text.replace(/```json\n?/g, '').replace(/```\n?/g, ''));
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
    });

    const data = await response.json();
    const content = data.choices?.[0]?.message?.content || '{}';
    const parsed = JSON.parse(content);
    return Array.isArray(parsed) ? parsed : parsed.questions || [];
  }
}

function getAppwriteClient() {
  return new Client()
    .setEndpoint(process.env.APPWRITE_ENDPOINT || 'https://cloud.appwrite.io/v1')
    .setProject(process.env.APPWRITE_FUNCTION_PROJECT_ID)
    .setKey(process.env.APPWRITE_API_KEY);
}

export default async ({ req, res, log, error }) => {
  try {
    const body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;
    const { topic, difficulty = 'medium', questionCount = 10, department = 'computer', semester = 1, saveToQuiz = false, courseId } = body;

    if (!topic) {
      return res.json({
        success: false,
        error: 'Missing required field: topic'
      }, 400);
    }

    const count = Math.min(Math.max(questionCount, 1), 50);

    log(`Generating ${count} ${difficulty} questions on "${topic}" for ${department} semester ${semester}...`);

    const questions = await generateWithAI(topic, difficulty, count, department, semester);

    if (!Array.isArray(questions) || questions.length === 0) {
      error('AI returned no questions');
      return res.json({
        success: false,
        error: 'Failed to generate questions — AI returned empty response'
      }, 500);
    }

    let quizId = null;

    // Optionally save as a quiz with questions
    if (saveToQuiz && courseId) {
      const client = getAppwriteClient();
      const databases = new Databases(client);
      const now = new Date().toISOString();

      // Create quiz
      const quiz = await databases.createDocument(
        DATABASE_ID,
        QUIZZES_COLLECTION,
        ID.unique(),
        {
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
        }
      );

      quizId = quiz.$id;

      // Create questions
      for (let i = 0; i < questions.length; i++) {
        const q = questions[i];
        await databases.createDocument(
          DATABASE_ID,
          QUIZ_QUESTIONS_COLLECTION,
          ID.unique(),
          {
            quiz_id: quizId,
            question_text: q.question_text || q.question,
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
          }
        );
      }

      log(`Saved AI quiz with ${questions.length} questions (quizId: ${quizId})`);
    }

    return res.json({
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
    });
  } catch (err) {
    error(`AI quiz generation failed: ${err.message}`);
    return res.json({
      success: false,
      error: err.message
    }, 500);
  }
};
