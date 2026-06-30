import { useState, useEffect } from 'react'
import { api } from '../services/api'

interface Child { id: string; name: string; grade: string }
interface Record { id: string; child_name: string; subject: string; tags: string; question: string; answer: string; status: string; created_at: string }

export default function WrongBook() {
  const [children, setChildren] = useState<Child[]>([])
  const [childId, setChildId] = useState('')
  const [subject, setSubject] = useState('')
  const [records, setRecords] = useState<Record[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    api.getChildren().then(d => {
      setChildren(d.items)
      if (d.items.length > 0) setChildId(d.items[0].id)
    }).catch(() => {})
  }, [])

  useEffect(() => {
    if (!childId) return
    setLoading(true)
    const params: any = { child_id: childId, status: '未掌握' }
    if (subject) params.subject = subject
    api.getRecords(params)
      .then(d => { setRecords(d.items); setError('') })
      .catch(() => setError('加载失败，请确认后端已启动'))
      .finally(() => setLoading(false))
  }, [childId, subject])

  async function handleDelete(id: string) {
    try {
      await api.deleteRecord(id)
      setRecords(prev => prev.filter(r => r.id !== id))
    } catch { }
  }

  async function handleMaster(id: string) {
    try {
      await api.updateRecord(id, { status: '已掌握' })
      setRecords(prev => prev.filter(r => r.id !== id))
    } catch { }
  }

  // Group by tags
  const grouped: Record<string, Record[]> = {}
  for (const r of records) {
    const key = r.tags || '未分类'
    if (!grouped[key]) grouped[key] = []
    grouped[key].push(r)
  }

  return (
    <div className="space-y-12">
      <div>
        <h1 className="text-[28px] font-semibold text-[#2c2c2c] tracking-tight">错题本</h1>
        <p className="text-[#8e8e8e] text-base mt-2">按知识点归类，针对性强化练习</p>
      </div>

      <div className="flex gap-4">
        <select value={childId} onChange={e => setChildId(e.target.value)} className="appearance-none bg-white border border-[#f0efed] rounded-xl px-5 py-2.5 text-sm outline-none cursor-pointer">
          {children.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
        </select>
        <select value={subject} onChange={e => setSubject(e.target.value)} className="appearance-none bg-white border border-[#f0efed] rounded-xl px-5 py-2.5 text-sm outline-none cursor-pointer">
          <option value="">全部科目</option>
          <option value="数学">数学</option>
          <option value="语文">语文</option>
          <option value="英语">英语</option>
        </select>
      </div>

      {error ? (
        <div className="text-center py-16">
          <div className="text-4xl mb-4">⚠️</div>
          <div className="text-sm text-[#8e8e8e]">{error}</div>
          <button onClick={() => { setError(''); setLoading(true); api.getRecords({ child_id: childId, status: '未掌握' }).then(d => { setRecords(d.items); setError('') }).catch(() => setError('重试失败')).finally(() => setLoading(false)) }}
            className="mt-4 px-4 py-2 rounded-xl border border-[#f0efed] text-sm text-[#5b6abf] hover:bg-[#fafafc]">重试</button>
        </div>
      ) : loading ? (
        <div className="text-center text-[#8e8e8e] py-16">加载中...</div>
      ) : Object.keys(grouped).length === 0 ? (
        <div className="text-center py-16">
          <div className="text-4xl mb-4">🎉</div>
          <div className="text-lg font-medium text-[#2c2c2c]">太棒了！</div>
          <div className="text-sm text-[#8e8e8e] mt-1">没有待复习的错题</div>
        </div>
      ) : (
        <div className="space-y-4">
          {Object.entries(grouped).map(([tag, items]) => (
            <div key={tag} className="bg-white rounded-2xl border border-[#f0efed] p-7">
              <div className="flex items-center justify-between mb-4">
                <div>
                  <div className="text-lg font-medium text-[#2c2c2c]">{tag}</div>
                  <div className="text-sm text-[#8e8e8e] mt-1">{items.length} 道错题</div>
                </div>
                <button onClick={() => items.forEach(r => handleMaster(r.id))} className="px-5 py-2.5 rounded-xl bg-[#5b6abf] text-white text-sm font-medium hover:bg-[#4f5cb0] transition-colors">
                  全部标记已掌握
                </button>
              </div>
              <div className="space-y-2">
                {items.map(r => (
                  <div key={r.id} className="flex items-center justify-between border border-[#f0efed] rounded-xl p-4">
                    <div className="flex-1 min-w-0">
                      <div className="text-sm text-[#2c2c2c] truncate">{r.question}</div>
                      <div className="text-xs text-[#8e8e8e] mt-1">{r.subject} · {new Date(r.created_at).toLocaleDateString('zh-CN')}</div>
                    </div>
                    <div className="flex gap-2 ml-4 shrink-0">
                      <button onClick={() => handleMaster(r.id)} className="px-3 py-1.5 rounded-lg border border-[#e0dff0] text-xs text-[#5b6abf] hover:bg-[#fafafc]">掌握</button>
                      <button onClick={() => handleDelete(r.id)} className="px-3 py-1.5 rounded-lg border border-[#f0efed] text-xs text-[#8e8e8e] hover:bg-red-50 hover:text-red-400">删除</button>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
