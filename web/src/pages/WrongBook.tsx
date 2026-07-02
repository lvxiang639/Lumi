import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { api } from '../services/api'

export default function WrongBook() {
  const [children, setChildren] = useState<any[]>([])
  const [childId, setChildId] = useState('')
  const [subject, setSubject] = useState('')
  const [records, setRecords] = useState<any[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [expanded, setExpanded] = useState<string | null>(null)
  const [generating, setGenerating] = useState<string | null>(null)
  const nav = useNavigate()

  useEffect(() => {
    api.getChildren().then(d => { setChildren(d.items); if (d.items.length) setChildId(d.items[0].id) }).catch(() => {})
  }, [])

  function load() {
    if (!childId) return
    setLoading(true)
    const params: any = { child_id: childId }
    if (subject) params.subject = subject
    api.getRecords(params)
      .then(d => {
        const all = (d.items || []).map((r: any) => {
          let extra: any = {}
          try { extra = JSON.parse(r.answer || '{}') } catch { }
          return { ...r, student_answer: extra.student_answer || '', correct_answer: extra.correct_answer || '', feedback: extra.feedback || '', explanation: extra.explanation || '' }
        })
        setRecords(all.filter((r: any) => r.status !== '已掌握'))
        setError('')
      })
      .catch(() => setError('加载失败'))
      .finally(() => setLoading(false))
  }

  useEffect(() => { load() }, [childId, subject])

  async function handleMarkReviewed(id: string) {
    await api.updateRecord(id, { status: '已复习' })
    setRecords(prev => prev.map(r => r.id === id ? { ...r, status: '已复习' } : r))
  }

  async function handleGenerateSimilar(r: any) {
    setGenerating(r.id)
    try {
      await api.generateQuestions({ subject: r.subject, topic: r.tags || r.question.slice(0, 20), count: 3 })
      nav(`/practice?topic=${encodeURIComponent(r.tags || '相似题')}&subject=${encodeURIComponent(r.subject)}`)
    } catch { }
    setGenerating(null)
  }

  const wrong = records.filter((r: any) => r.status === '未掌握')
  const reviewed = records.filter((r: any) => r.status === '已复习')

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-[28px] font-semibold text-[#2c2c2c] tracking-tight">错题本</h1>
        <p className="text-[#8e8e8e] text-base mt-2">曾错过的题 · 反复练习 · 直到掌握</p>
      </div>

      <div className="flex gap-3">
        <select value={childId} onChange={e => setChildId(e.target.value)} className="bg-white border border-[#f0efed] rounded-xl px-4 py-2.5 text-sm text-[#2c2c2c] outline-none cursor-pointer">
          {children.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
        </select>
        <select value={subject} onChange={e => setSubject(e.target.value)} className="bg-white border border-[#f0efed] rounded-xl px-4 py-2.5 text-sm text-[#2c2c2c] outline-none cursor-pointer">
          <option value="">全部科目</option><option value="数学">数学</option><option value="语文">语文</option><option value="英语">英语</option>
        </select>
        <div className="ml-auto flex gap-2 text-xs text-[#8e8e8e] items-center">
          <span className="w-2 h-2 rounded-full bg-rose-200" /> {wrong.length} 待复习
          <span className="w-2 h-2 rounded-full bg-emerald-200 ml-2" /> {reviewed.length} 已复习
        </div>
      </div>

      {error ? <div className="text-center py-16"><div className="text-4xl mb-4">⚠️</div><div className="text-sm text-[#8e8e8e]">{error}</div><button onClick={load} className="mt-4 px-4 py-2 rounded-xl border text-sm text-[#5b6abf]">重试</button></div>
       : loading ? <div className="text-center text-[#8e8e8e] py-16">加载中...</div>
       : records.length === 0 ? <div className="text-center py-16"><div className="text-4xl mb-4">🎉</div><div className="text-lg font-medium text-[#2c2c2c]">没有错题</div><div className="text-sm text-[#8e8e8e] mt-1">去练习中心做几道题吧</div></div>
       : <div className="space-y-3">
          {records.map((r: any) => (
            <div key={r.id} className={`bg-white rounded-2xl border p-5 ${r.status === '未掌握' ? 'border-rose-100' : 'border-emerald-100'}`}>
              <div className="flex items-center gap-3 mb-2 cursor-pointer" onClick={() => setExpanded(expanded === r.id ? null : r.id)}>
                <span className={`text-xs px-2 py-0.5 rounded-full ${r.status === '未掌握' ? 'bg-rose-50 text-rose-600' : 'bg-emerald-50 text-emerald-600'}`}>{r.status === '未掌握' ? '待复习' : '已复习'}</span>
                <span className="text-xs text-[#8e8e8e]">{r.subject}</span>
                <span className="text-xs text-[#8e8e8e] ml-auto">{r.created_at ? new Date(r.created_at).toLocaleDateString('zh-CN') : ''}</span>
                <span className="text-xs text-[#5b6abf]">{expanded === r.id ? '收起 ▲' : '详情 ▼'}</span>
              </div>
              <div className="text-sm text-[#2c2c2c] mb-3">{r.question}</div>
              {expanded === r.id && (
                <div className="space-y-2 mb-3 ml-2 pl-3 border-l-2 border-[#f0efed]">
                  {r.student_answer && <div className="text-xs"><span className="text-[#8e8e8e]">你的答案：</span><span className={r.status === '未掌握' ? 'text-rose-500' : 'text-emerald-500'}>{r.student_answer}</span></div>}
                  {r.correct_answer && <div className="text-xs"><span className="text-[#8e8e8e]">正确答案：</span><span className="text-[#2c2c2c]">{r.correct_answer}</span></div>}
                  {r.explanation && <div className="text-xs text-[#5b6abf]">💡 {r.explanation}</div>}
                  {r.feedback && <div className="text-xs text-[#8e8e8e] italic">{r.feedback}</div>}
                </div>
              )}
              <div className="flex gap-2">
                {r.status === '未掌握' && <button onClick={() => handleMarkReviewed(r.id)} className="px-4 py-2 rounded-xl border border-emerald-200 text-xs text-emerald-600 hover:bg-emerald-50">标记已复习</button>}
                <button onClick={() => handleGenerateSimilar(r)} disabled={generating === r.id} className="px-4 py-2 rounded-xl bg-[#5b6abf] text-white text-xs font-medium hover:bg-[#4f5cb0] disabled:opacity-50">{generating === r.id ? '生成中...' : '练习相似题'}</button>
              </div>
            </div>
          ))}
        </div>
      }
    </div>
  )
}
