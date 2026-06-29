import { useState } from 'react'
import { useAuth } from '../hooks/useAuth'

export default function Login() {
  const [phone, setPhone] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const { login } = useAuth()

  async function handleLogin(e: React.FormEvent) {
    e.preventDefault()
    if (!phone.trim()) return
    setLoading(true)
    setError('')
    try {
      await login(phone.trim())
    } catch (err: any) {
      setError(err.message || '登录失败')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-[#fafaf9] flex items-center justify-center">
      <div className="w-full max-w-sm">
        <div className="text-center mb-10">
          <div className="text-3xl mb-3">📚</div>
          <h1 className="text-2xl font-semibold text-[#2c2c2c] tracking-tight">灵犀教育</h1>
          <p className="text-[#8e8e8e] text-sm mt-2">AI 驱动的学习助手</p>
        </div>

        <form onSubmit={handleLogin} className="bg-white rounded-2xl border border-[#f0efed] p-8 space-y-5">
          <div>
            <label className="block text-sm font-medium text-[#2c2c2c] mb-2">手机号登录</label>
            <input
              type="text"
              value={phone}
              onChange={e => setPhone(e.target.value)}
              placeholder="输入手机号"
              className="w-full px-4 py-3 bg-[#fafaf9] border border-[#f0efed] rounded-xl text-sm outline-none focus:bg-white focus:border-[#e0dff0] transition-colors"
            />
          </div>

          {error && (
            <div className="text-sm text-red-400 bg-red-50 px-4 py-2 rounded-lg">{error}</div>
          )}

          <button
            type="submit"
            disabled={loading}
            className="w-full py-3 bg-[#5b6abf] text-white rounded-xl text-sm font-medium hover:bg-[#4f5cb0] transition-colors disabled:opacity-50"
          >
            {loading ? '登录中...' : '登录'}
          </button>
        </form>
      </div>
    </div>
  )
}
