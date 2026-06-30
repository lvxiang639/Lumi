import { useState, useEffect } from 'react'
import { api } from '../services/api'

interface Child { id: string; name: string; grade: string }

type Mode = 'menu' | 'generate' | 'quiz' | 'result'

export default function Practice() {
  const [mode, setMode] = useState<Mode>('menu')
  const [children, setChildren] = useState<Child[]>([])
  const [childId, setChildId] = useState('')
  const [subject, setSubject] = useState('数学')
  const [topic, setTopic] = useState('')
  const [loading, setLoading] = useState(false)
  const [questions, setQuestions] = useState<string[]>([])
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
      const resp = await api.generateQuestions({
        subject,
        topic: topic || undefined,
        count: 5,
      })
      if (resp.questions?.length) {
        setQuestions(resp.questions)
        setMode('quiz')
      } else {
        setFeedback('生成失败，请换个知识点试试')
      }
    } catch {
      setFeedback('请求失败，请确认后端已启动')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="space-y-12">
      <div>
        <h1 className="text-[28px] font-semibold text-[#2c2c2c] tracking-tight">练习中心</h1>
        <p className="text-[#8e8e8e] text-base mt-2">AI 出题 · 智能批改 · 薄弱强化</p>
      </div>

      {mode === 'menu' && (
        <div className="space-y-8">
          {/* Quick generate */}
          <div className="bg-white rounded-2xl border border-[#f0efed] p-8">
            <h2 className="text-lg font-medium text-[#2c2c2c] mb-6">AI 智能出题</h2>
            <div className="grid grid-cols-4 gap-4 mb-6">
              {children.map(c => (
                <button key={c.id}
                  onClick={() => setChildId(c.id)}
                  className={`px-4 py-2.5 rounded-xl text-sm border transition-colors ${
                    childId === c.id ? 'border-[#5b6abf] bg-[#f3f2f8] text-[#5b6abf] font-medium' : 'border-[#f0efed] text-[#8e8e8e]'
                  }`}>{c.name} · {c.grade}</button>
              ))}
            </div>
            <div className="flex gap-4 mb-6">
              {['数学', '语文', '英语'].map(s => (
                <button key={s}
                  onClick={() => setSubject(s)}
                  className={`px-4 py-2.5 rounded-xl text-sm border transition-colors ${
                    subject === s ? 'border-[#5b6abf] bg-[#f3f2f8] text-[#5b6abf] font-medium' : 'border-[#f0efed] text-[#8e8e8e]'
                  }`}>{s}</button>
              ))}
            </div>
            <div className="flex gap-3">
              <input
                value={topic}
                onChange={e => setTopic(e.target.value)}
                placeholder="输入知识点，如：分数加减法（留空则综合出题）"
                className="flex-1 px-4 py-3 bg-[#fafaf9] border border-[#f0efed] rounded-xl text-sm outline-none focus:bg-white focus:border-[#e0dff0]"
              />
              <button
                onClick={handleGenerate}
                disabled={loading}
                className="px-8 py-3 bg-[#5b6abf] text-white rounded-xl text-sm font-medium hover:bg-[#4f5cb0] disabled:opacity-50 transition-colors"
              >{loading ? '生成中...' : '生成题目'}</button>
            </div>
            {feedback && <div className="mt-4 text-sm text-[#8e8e8e] bg-[#fafaf9] px-4 py-3 rounded-xl">{feedback}</div>}
          </div>

          {/* Practice types */}
          <div className="grid grid-cols-2 gap-4">
            {[
              { emoji: '🎯', title: 'AI 智能出题', desc: '按知识点、年级、难度自动生成' },
              { emoji: '📷', title: '拍照解题', desc: '拍照上传，AI 分步讲解' },
              { emoji: '🏆', title: '奥数专项', desc: '思维训练、竞赛题型' },
              { emoji: '📜', title: '古诗词练习', desc: '填空、默写、鉴赏、背诵检测' },
              { emoji: '📖', title: '文言文翻译', desc: '逐句翻译、实词虚词、断句练习' },
              { emoji: '✨', title: '自定义专题', desc: '输入描述，AI 生成专项练习' },
            ].map(s => (
              <div key={s.title}
                onClick={() => setTopic(s.title === 'AI 智能出题' ? '' : s.desc)}
                className="bg-white rounded-2xl border border-[#f0efed] p-7 flex items-center gap-6 cursor-pointer hover:border-[#e0dff0] hover:bg-[#fafafc] transition-all duration-200">
                <div className="text-3xl">{s.emoji}</div>
                <div>
                  <div className="font-medium text-[#2c2c2c] text-lg">{s.title}</div>
                  <div className="text-sm text-[#8e8e8e] mt-1.5">{s.desc}</div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {mode === 'quiz' && (
        <div className="bg-white rounded-2xl border border-[#f0efed] p-8 space-y-6">
          <h2 className="text-lg font-medium text-[#2c2c2c]">练习题</h2>
          {questions.map((q, i) => (
            <div key={i} className="border border-[#f0efed] rounded-xl p-5">
              <div className="text-sm font-medium text-[#2c2c2c] mb-3">第{i + 1}题</div>
              <div className="text-sm text-[#2c2c2c] whitespace-pre-wrap leading-relaxed">{q}</div>
            </div>
          ))}
          <div className="flex gap-3 pt-4">
            <button onClick={() => setMode('menu')} className="px-6 py-2.5 rounded-xl border border-[#f0efed] text-sm text-[#8e8e8e] hover:bg-[#fafafc]">返回</button>
            <button onClick={() => { setMode('menu'); setFeedback('练习完成！去错题本查看结果'); }} className="px-6 py-2.5 rounded-xl bg-[#5b6abf] text-white text-sm font-medium hover:bg-[#4f5cb0]">完成练习</button>
          </div>
        </div>
      )}
    </div>
  )
}
