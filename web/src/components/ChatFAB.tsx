import { useState } from 'react'
import { MessageCircle, X } from 'lucide-react'

export default function ChatFAB() {
  const [open, setOpen] = useState(false)

  return (
    <>
      {/* Floating button */}
      <button
        onClick={() => setOpen(!open)}
        style={{
          position: 'fixed', bottom: 24, right: 24,
          width: 56, height: 56, borderRadius: 28,
          background: '#6366f1', color: '#fff', border: 'none',
          cursor: 'pointer', boxShadow: '0 4px 16px rgba(99,102,241,0.3)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          zIndex: 1000,
        }}
      >
        {open ? <X size={24} /> : <MessageCircle size={24} />}
      </button>

      {/* Chat panel */}
      {open && (
        <div style={{
          position: 'fixed', bottom: 92, right: 24, width: 380, height: 520,
          background: '#fff', borderRadius: 16, border: '1px solid #e5e7eb',
          boxShadow: '0 8px 32px rgba(0,0,0,0.08)', zIndex: 999,
          display: 'flex', flexDirection: 'column',
        }}>
          {/* Header */}
          <div style={{
            padding: '14px 18px', borderBottom: '1px solid #e5e7eb',
            fontWeight: 600, fontSize: 15, display: 'flex', alignItems: 'center', gap: 8,
          }}>
            <span>💬</span> AI 学习助手
            <span style={{ fontSize: 11, color: '#9ca3af', fontWeight: 400, marginLeft: 8 }}>
              (当前页面上下文自动带入)
            </span>
          </div>

          {/* Messages area */}
          <div style={{ flex: 1, padding: 16, overflow: 'auto', color: '#9ca3af', fontSize: 13, textAlign: 'center' }}>
            <div style={{ marginTop: 100 }}>
              <div style={{ fontSize: 32, marginBottom: 12 }}>🤖</div>
              有学习方面的问题直接问我<br />
              我会结合当前页面内容帮你解答
            </div>
          </div>

          {/* Input */}
          <div style={{ padding: 12, borderTop: '1px solid #e5e7eb' }}>
            <div style={{ display: 'flex', gap: 8 }}>
              <input
                type="text"
                placeholder="输入你的问题..."
                style={{
                  flex: 1, padding: '10px 14px', borderRadius: 10,
                  border: '1px solid #e5e7eb', fontSize: 14, outline: 'none',
                }}
              />
              <button style={{
                padding: '10px 16px', borderRadius: 10, border: 'none',
                background: '#6366f1', color: '#fff', cursor: 'pointer',
                fontWeight: 500,
              }}>
                发送
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}
