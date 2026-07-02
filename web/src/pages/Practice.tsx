import { useState, useEffect } from 'react'
import { useSearchParams } from 'react-router-dom'
import { api } from '../services/api'

interface Child { id: string; name: string; grade: string }
interface QuizItem { id: number; question: string; answer: string; correct_answer: string; feedback?: string; explanation?: string; is_correct?: boolean }

type View = 'menu' | 'quiz' | 'history'

export default function Practice() {
  const [searchParams] = useSearchParams()
  const [view, setView] = useState<View>('menu')
  const [children, setChildren] = useState<Child[]>([])
  const [childId, setChildId] = useState('')
  const [subject, setSubject] = useState(searchParams.get('subject') || '数学')
  const [topic, setTopic] = useState(searchParams.get('topic') || '')
  const [loading, setLoading] = useState(false)
  const [quizzes, setQuizzes] = useState<QuizItem[]>([])
  const [history, setHistory] = useState<any[]>([])
  const [feedback, setFeedback] = useState('')

  useEffect(() => {
    api.getChildren().then(d => {
      setChildren(d.items)
      if (d.items.length) setChildId(d.items[0].id)
    }).catch(() => {})
  }, [])

  async function handleGenerate() {
    setLoading(true)
    try {
      const resp = await api.generateQuestions({ subject, topic: topic || undefined, count: 5 })
      if (resp.questions?.length) {
        setQuizzes(resp.questions.map((q, i) => {
          // Split question from answer — handles multiple formats
          let question = q, correct = ''
          const sep = q.match(/\n答案[:：]/)
          if (sep) {
            const idx = q.indexOf(sep[0])
            question = q.slice(0, idx).replace(/^\d+[\.\、]\s*/, '').trim()
            correct = q.slice(idx + sep[0].length).trim()
          }
          return { id: i, question, answer: '', correct_answer: correct }
        }))
        setView('quiz')
      } else { setFeedback('生成失败') }
    } catch { setFeedback('请求失败，后端是否已启动？') }
    finally { setLoading(false) }
  }

  async function gradeOne(item: QuizItem): Promise<QuizItem> {
    const child = children.find(c => c.id === childId)
    try {
      const result = await api.gradeAnswer({
        question: item.question, answer: item.answer, correct_answer: item.correct_answer,
        subject, child_id: childId || undefined, child_name: child?.name || '',
      })
      return { ...item, ...result }
    } catch { return item }
  }

  async function handleGradeOne(item: QuizItem) {
    if (!item.answer.trim()) return
    const updated = await gradeOne(item)
    setQuizzes(prev => prev.map(q => q.id === item.id ? updated : q))
  }

  async function handleSubmitAll() {
    setLoading(true)
    const pending = quizzes.filter(q => q.is_correct === undefined && q.answer.trim())
    if (pending.length === 0) { setLoading(false); return }
    const results = await Promise.all(pending.map(q => gradeOne(q)))
    setQuizzes(prev => prev.map(q => results.find(r => r.id === q.id) || q))
    setLoading(false)
  }

  const pendingCount = quizzes.filter(q => q.is_correct === undefined).length

  async function loadHistory() {
    try {
      const data = await api.getPracticeRecords(childId ? { child_id: childId } : {})
      setHistory(data.items)
      setView('history')
    } catch { }
  }

  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between">
        <h1 className="text-[28px] font-semibold text-[#2c2c2c] tracking-tight">练习中心</h1>
        <button onClick={loadHistory}
          className="text-sm text-[#5b6abf] hover:underline">📋 做题记录</button>
      </div>

      {/* ── Menu ── */}
      {view === 'menu' && (
        <div className="space-y-8">
          <div className="bg-white rounded-2xl border border-[#f0efed] p-8">
            <h2 className="text-lg font-medium text-[#2c2c2c] mb-6">AI 智能出题</h2>
            {children.length > 0 && (
              <div className="flex gap-3 mb-6">
                {children.map(c => (
                  <button key={c.id} onClick={() => setChildId(c.id)}
                    className={`px-4 py-2 rounded-xl text-sm border ${childId === c.id ? 'border-[#5b6abf] bg-[#f3f2f8] text-[#5b6abf] font-medium' : 'border-[#f0efed] text-[#8e8e8e]'}`}
                  >{c.name}</button>
                ))}
              </div>
            )}
            <div className="flex gap-3 mb-6">
              {['数学', '语文', '英语'].map(s => (
                <button key={s} onClick={() => setSubject(s)}
                  className={`px-4 py-2 rounded-xl text-sm border ${subject === s ? 'border-[#5b6abf] bg-[#f3f2f8] text-[#5b6abf] font-medium' : 'border-[#f0efed] text-[#8e8e8e]'}`}
                >{s}</button>
              ))}
            </div>
            <div className="flex gap-3">
              <input value={topic} onChange={e => setTopic(e.target.value)}
                placeholder="输入知识点，如：分数加减法（留空出综合题）"
                className="flex-1 px-4 py-3 bg-[#fafaf9] border border-[#f0efed] rounded-xl text-sm outline-none focus:bg-white focus:border-[#e0dff0]" />
              <button onClick={handleGenerate} disabled={loading}
                className="px-8 py-3 bg-[#5b6abf] text-white rounded-xl text-sm font-medium hover:bg-[#4f5cb0] disabled:opacity-50"
              >{loading ? '生成中...' : '生成题目'}</button>
            </div>
            {feedback && <div className="mt-4 text-sm text-[#8e8e8e] bg-[#fafaf9] px-4 py-3 rounded-xl">{feedback}</div>}
          </div>
          <div className="grid grid-cols-2 gap-4">
            {[{ emoji: '🎯', title: 'AI 智能出题', desc: '选知识点自动生成' },
              { emoji: '🏆', title: '奥数专项', desc: '思维训练、竞赛题型' },
              { emoji: '📜', title: '古诗词练习', desc: '填空默写鉴赏' },
              { emoji: '✨', title: '自定义专题', desc: '输入描述生成练习题' },
            ].map(s => (
              <div key={s.title} onClick={() => { if (s.title === 'AI 智能出题') handleGenerate() }}
                className="bg-white rounded-2xl border border-[#f0efed] p-6 flex items-center gap-4 cursor-pointer hover:border-[#e0dff0]">
                <div className="text-2xl">{s.emoji}</div>
                <div><div className="font-medium text-[#2c2c2c]">{s.title}</div><div className="text-sm text-[#8e8e8e] mt-0.5">{s.desc}</div></div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* ── Quiz ── */}
      {view === 'quiz' && (
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <button onClick={() => setView('menu')} className="text-sm text-[#5b6abf] hover:underline">← 返回</button>
            {pendingCount > 0 && (
              <button onClick={handleSubmitAll} disabled={loading}
                className="px-6 py-2.5 bg-[#5b6abf] text-white rounded-xl text-sm font-medium hover:bg-[#4f5cb0] disabled:opacity-40"
              >{loading ? '批改中...' : `提交全部 (${pendingCount}题)`}</button>
            )}
          </div>
          {quizzes.map((q) => (
            <div key={q.id} className={`bg-white rounded-2xl border p-6 ${q.is_correct === true ? 'border-emerald-200 bg-emerald-50/30' : q.is_correct === false ? 'border-rose-200 bg-rose-50/30' : 'border-[#f0efed]'}`}>
              <div className="flex items-start gap-2 mb-3">
                <span className="text-sm font-medium text-[#8e8e8e] shrink-0 mt-0.5">第{q.id + 1}题</span>
                <span className="text-sm text-[#2c2c2c] leading-relaxed">{q.question}</span>
                {q.is_correct !== undefined && (
                  <span className="shrink-0 ml-auto text-lg">{q.is_correct ? '✅' : '❌'}</span>
                )}
              </div>
              <div className="flex gap-2 items-center">
                <input value={q.answer}
                  onChange={e => setQuizzes(prev => prev.map(x => x.id === q.id ? { ...x, answer: e.target.value } : x))}
                  disabled={q.is_correct !== undefined}
                  placeholder="输入你的答案..."
                  className="flex-1 px-4 py-2.5 bg-[#fafaf9] border border-[#f0efed] rounded-xl text-sm outline-none focus:bg-white disabled:opacity-60" />
                {q.is_correct !== undefined && q.correct_answer && (
                  <span className="text-xs text-[#8e8e8e] shrink-0">正确答案: {q.correct_answer}</span>
                )}
              </div>
              {(q.feedback || q.explanation) && (
                <div className="mt-3 text-sm text-[#5b6abf] bg-[#f3f2f8] px-4 py-2.5 rounded-xl">
                  {q.feedback}{q.explanation && ` — ${q.explanation}`}
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      {/* ── History ── */}
      {view === 'history' && (
        <div className="space-y-4">
          <button onClick={() => setView('menu')} className="text-sm text-[#5b6abf] hover:underline mb-4">← 返回</button>
          {history.length === 0 ? (
            <div className="text-center py-16 text-[#8e8e8e]">暂无做题记录</div>
          ) : (
            history.map((r) => (
              <div key={r.id} className={`bg-white rounded-2xl border p-5 ${r.is_correct ? 'border-emerald-100' : 'border-rose-100'}`}>
                <div className="flex items-center gap-2 mb-2">
                  <span className="text-xs text-[#8e8e8e]">{r.subject}</span>
                  <span className={`text-xs px-2 py-0.5 rounded-full ${r.is_correct ? 'bg-emerald-50 text-emerald-600' : 'bg-rose-50 text-rose-600'}`}>
                    {r.is_correct ? '正确' : '错误'}
                  </span>
                  <span className="text-xs text-[#8e8e8e] ml-auto">{r.created_at ? new Date(r.created_at).toLocaleDateString('zh-CN') : ''}</span>
                </div>
                <div className="text-sm text-[#2c2c2c]">{r.question}</div>
                <div className="text-xs text-[#8e8e8e] mt-1">你的答案: {r.student_answer || r.answer} · 正确答案: {r.correct_answer}</div>
                {r.feedback && <div className="text-xs text-[#5b6abf] mt-1">{r.feedback}</div>}
              </div>
            ))
          )}
        </div>
      )}
    </div>
  )
}
