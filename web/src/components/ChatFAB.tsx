import { useState } from 'react'
import { MessageCircle, X, Send } from 'lucide-react'

export default function ChatFAB() {
  const [open, setOpen] = useState(false)

  return (
    <>
      {/* FAB */}
      <button
        onClick={() => setOpen(!open)}
        className="fixed bottom-6 right-6 z-50 w-14 h-14 rounded-2xl bg-gradient-to-br from-indigo-500 to-purple-600 text-white shadow-lg shadow-indigo-200 flex items-center justify-center transition-all hover:scale-105 hover:shadow-xl active:scale-95"
      >
        {open ? <X size={22} /> : <MessageCircle size={22} />}
      </button>

      {/* Chat panel */}
      {open && (
        <div className="fixed bottom-24 right-6 z-40 w-[400px] h-[560px] bg-white rounded-2xl border border-slate-200 shadow-2xl flex flex-col overflow-hidden animate-in">
          {/* Header */}
          <div className="px-5 py-4 border-b border-slate-100 bg-gradient-to-r from-indigo-50 to-purple-50">
            <div className="flex items-center gap-2.5">
              <div className="w-8 h-8 rounded-xl bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center text-white text-sm">
                🤖
              </div>
              <div>
                <div className="font-semibold text-sm text-slate-800">AI 学习助手</div>
                <div className="text-[11px] text-slate-400">基于当前页面内容回答</div>
              </div>
            </div>
          </div>

          {/* Messages */}
          <div className="flex-1 overflow-auto p-5 space-y-4">
            <div className="flex gap-3">
              <div className="w-7 h-7 rounded-lg bg-indigo-100 flex items-center justify-center text-xs shrink-0">🤖</div>
              <div className="bg-slate-50 rounded-2xl rounded-tl-md px-4 py-3 text-sm text-slate-600 max-w-[85%]">
                你好！我是 AI 学习助手，可以帮你解答学习相关的问题。我在当前页面看到了学习中心的数据，有什么想了解的吗？
              </div>
            </div>
          </div>

          {/* Input */}
          <div className="p-4 border-t border-slate-100">
            <div className="flex gap-2.5">
              <input
                type="text"
                placeholder="输入问题..."
                className="flex-1 px-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm outline-none focus:border-indigo-300 focus:bg-white transition-colors"
              />
              <button className="w-10 h-10 rounded-xl bg-indigo-500 text-white flex items-center justify-center hover:bg-indigo-600 transition-colors shrink-0">
                <Send size={16} />
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}
