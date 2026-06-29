import { useState } from 'react'

export default function ChatFAB() {
  const [open, setOpen] = useState(false)

  return (
    <>
      <button
        onClick={() => setOpen(!open)}
        className="fixed bottom-8 right-8 z-50 w-12 h-12 rounded-2xl bg-[#5b6abf] text-white flex items-center justify-center text-lg shadow-sm hover:shadow-md hover:bg-[#4f5cb0] transition-all active:scale-95"
      >
        {open ? '✕' : '💬'}
      </button>

      {open && (
        <div className="fixed bottom-24 right-8 z-40 w-[380px] h-[520px] bg-white rounded-2xl border border-[#f0efed] shadow-lg flex flex-col overflow-hidden">
          <div className="px-6 py-5 border-b border-[#f0efed]">
            <div className="font-medium text-[#2c2c2c]">AI 学习助手</div>
            <div className="text-xs text-[#8e8e8e] mt-0.5">基于当前页面内容回答</div>
          </div>

          <div className="flex-1 overflow-auto p-6 space-y-4">
            <div className="flex gap-3">
              <div className="w-7 h-7 rounded-full bg-[#f3f2f8] flex items-center justify-center text-xs shrink-0">🤖</div>
              <div className="bg-[#fafaf9] rounded-2xl rounded-tl-md px-4 py-3 text-sm text-[#2c2c2c] max-w-[85%] leading-relaxed">
                你好！有什么学习方面的问题想问？
              </div>
            </div>
          </div>

          <div className="p-4 border-t border-[#f0efed]">
            <div className="flex gap-2">
              <input
                type="text"
                placeholder="输入问题..."
                className="flex-1 px-4 py-2.5 bg-[#fafaf9] border border-[#f0efed] rounded-xl text-sm outline-none focus:bg-white focus:border-[#e0dff0] transition-colors"
              />
              <button className="w-10 h-10 rounded-xl bg-[#5b6abf] text-white flex items-center justify-center hover:bg-[#4f5cb0] transition-colors shrink-0 text-sm">
                →
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}
