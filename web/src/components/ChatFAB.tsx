import { useState } from 'react'
import { useLocation } from 'react-router-dom'

const BASE = 'http://localhost:8000'

interface Msg { role: 'user' | 'ai'; text: string }

export default function ChatFAB() {
  const [open, setOpen] = useState(false)
  const [msgs, setMsgs] = useState<Msg[]>([{ role: 'ai', text: '你好！有什么学习方面的问题想问？' }])
  const [input, setInput] = useState('')
  const [sending, setSending] = useState(false)
  const loc = useLocation()

  async function send() {
    const text = input.trim()
    if (!text || sending) return
    setInput('')
    setMsgs(prev => [...prev, { role: 'user', text }])
    setSending(true)

    try {
      const token = localStorage.getItem('token') || ''
      const resp = await fetch(`${BASE}/ws/chat`, {
        method: 'GET',
        headers: { Authorization: `Bearer ${token}` },
      })

      // Fallback: use REST-like call since WebSocket is complex
      const httpResp = await fetch(`${BASE}/api/study/solve`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
        },
        body: (() => {
          const fd = new FormData()
          fd.append('question', text)
          fd.append('subject', '')
          return fd
        })(),
      })

      if (httpResp.ok) {
        const data = await httpResp.json()
        const answer = data.answer || data.steps?.join('\n') || '抱歉，暂时无法回答'
        setMsgs(prev => [...prev, { role: 'ai', text: answer }])
      } else {
        setMsgs(prev => [...prev, { role: 'ai', text: `请求失败 (${httpResp.status})` }])
      }
    } catch {
      // If backend not available, respond with context
      const pageCtx = loc.pathname === '/dashboard' ? '学习中心' :
        loc.pathname === '/textbooks' ? '课本管理' :
        loc.pathname === '/practice' ? '练习中心' :
        loc.pathname === '/wrong-book' ? '错题本' :
        loc.pathname === '/growth' ? '成长记录' : '当前页面'
      setMsgs(prev => [...prev, { role: 'ai', text: `（后端未启动）\n你正在「${pageCtx}」页面，有关于这个功能的问题可以直接问我。` }])
    } finally {
      setSending(false)
    }
  }

  return (
    <>
      <button
        onClick={() => setOpen(!open)}
        className="fixed bottom-8 right-8 z-50 w-12 h-12 rounded-2xl bg-[#5b6abf] text-white flex items-center justify-center text-lg shadow-sm hover:shadow-md hover:bg-[#4f5cb0] transition-all active:scale-95"
      >{open ? '✕' : '💬'}</button>

      {open && (
        <div className="fixed bottom-24 right-8 z-40 w-[380px] h-[520px] bg-white rounded-2xl border border-[#f0efed] shadow-lg flex flex-col overflow-hidden">
          <div className="px-6 py-5 border-b border-[#f0efed]">
            <div className="font-medium text-[#2c2c2c]">AI 学习助手</div>
            <div className="text-xs text-[#8e8e8e] mt-0.5">基于当前页面上下文回答</div>
          </div>

          <div className="flex-1 overflow-auto p-6 space-y-4">
            {msgs.map((m, i) => (
              <div key={i} className={`flex gap-3 ${m.role === 'user' ? 'flex-row-reverse' : ''}`}>
                <div className={`w-7 h-7 rounded-full flex items-center justify-center text-xs shrink-0 ${m.role === 'ai' ? 'bg-[#f3f2f8]' : 'bg-[#5b6abf] text-white'}`}>
                  {m.role === 'ai' ? '🤖' : '👤'}
                </div>
                <div className={`rounded-2xl px-4 py-3 text-sm max-w-[85%] leading-relaxed whitespace-pre-wrap ${
                  m.role === 'user'
                    ? 'bg-[#5b6abf] text-white rounded-tr-md'
                    : 'bg-[#fafaf9] text-[#2c2c2c] rounded-tl-md'
                }`}>{m.text}</div>
              </div>
            ))}
            {sending && <div className="text-xs text-[#8e8e8e] pl-10">思考中...</div>}
          </div>

          <div className="p-4 border-t border-[#f0efed]">
            <div className="flex gap-2">
              <input
                value={input}
                onChange={e => setInput(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && send()}
                placeholder="输入问题..."
                className="flex-1 px-4 py-2.5 bg-[#fafaf9] border border-[#f0efed] rounded-xl text-sm outline-none focus:bg-white focus:border-[#e0dff0] transition-colors"
              />
              <button onClick={send} disabled={sending}
                className="w-10 h-10 rounded-xl bg-[#5b6abf] text-white flex items-center justify-center hover:bg-[#4f5cb0] transition-colors shrink-0 text-sm disabled:opacity-50">→</button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}
