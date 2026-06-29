import { useState, useEffect } from 'react'
import { api } from '../services/api'

interface Child { id: string; name: string; grade: string }
interface ChildAnalysis {
  child_name: string; total: number; mastered: number; mastery_rate: number
  by_subject: Record<string, number>; weak_points: { tag: string; count: number }[]
  ai_suggestion: string; grade: string
}

export default function Growth() {
  const [children, setChildren] = useState<Child[]>([])
  const [childId, setChildId] = useState('')
  const [analysis, setAnalysis] = useState<any>(null)

  useEffect(() => {
    api.getChildren().then(d => {
      setChildren(d.items)
      if (d.items.length > 0) setChildId(d.items[0].id)
    }).catch(() => {})
  }, [])

  useEffect(() => {
    if (!childId) return
    api.getAnalysis(childId).then(setAnalysis).catch(() => {})
  }, [childId])

  const childData: ChildAnalysis | null = analysis?.children?.[0] || null
  const weakPoints = childData?.weak_points || []
  const bySubject = childData?.by_subject || {}

  return (
    <div className="space-y-12">
      <div>
        <h1 className="text-[28px] font-semibold text-[#2c2c2c] tracking-tight">成长记录</h1>
        <p className="text-[#8e8e8e] text-base mt-2">追踪每一步学习成长</p>
      </div>

      {children.length > 1 && (
        <select value={childId} onChange={e => setChildId(e.target.value)} className="bg-white border border-[#f0efed] rounded-xl px-5 py-2.5 text-sm text-[#2c2c2c] outline-none">
          {children.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
        </select>
      )}

      {/* Subject breakdown */}
      {Object.keys(bySubject).length > 0 && (
        <div className="space-y-4">
          <h2 className="text-lg font-medium text-[#2c2c2c]">科目分布</h2>
          <div className="grid grid-cols-3 gap-4">
            {Object.entries(bySubject).map(([subj, count]) => (
              <div key={subj} className="bg-white rounded-2xl border border-[#f0efed] p-6 text-center">
                <div className="text-2xl mb-2">{subj === '数学' ? '📐' : subj === '语文' ? '📖' : '🔤'}</div>
                <div className="text-2xl font-semibold text-[#2c2c2c]">{count as number}</div>
                <div className="text-sm text-[#8e8e8e] mt-1">{subj} · 本周题量</div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Weak points */}
      {weakPoints.length > 0 && (
        <div className="space-y-4">
          <h2 className="text-lg font-medium text-[#2c2c2c]">薄弱知识点</h2>
          <div className="bg-white rounded-2xl border border-[#f0efed] p-8 space-y-5">
            {weakPoints.map(w => {
              const maxCount = weakPoints[0]?.count || 1
              const pct = maxCount > 0 ? (w.count / maxCount) * 100 : 0
              return (
                <div key={w.tag} className="flex items-center gap-4">
                  <div className="w-24 text-sm text-[#2c2c2c] truncate">{w.tag}</div>
                  <div className="flex-1 h-2 bg-[#f5f4f2] rounded-full overflow-hidden">
                    <div className="h-full rounded-full bg-[#e8c0b0]" style={{ width: `${pct}%` }} />
                  </div>
                  <div className="w-12 text-xs text-right text-[#8e8e8e]">{w.count}次</div>
                </div>
              )
            })}
          </div>
          {childData?.ai_suggestion && (
            <div className="bg-[#fafaf9] rounded-2xl border border-[#f0efed] p-6 text-sm text-[#5b6abf]">
              💡 {childData.ai_suggestion}
            </div>
          )}
        </div>
      )}

      {/* Knowledge map */}
      <div className="space-y-4">
        <h2 className="text-lg font-medium text-[#2c2c2c]">知识图谱</h2>
        <div className="bg-white rounded-2xl border border-[#f0efed] p-8">
          <div className="flex gap-6 mb-6">
            {(['数学', '语文', '英语'] as const).map(subj => (
              <button key={subj} className="text-sm text-[#5b6abf] hover:underline">{subj}</button>
            ))}
          </div>
          <div className="text-sm text-[#8e8e8e] text-center py-8">
            知识点数据加载中...（需后端 API 支持）
          </div>
        </div>
      </div>
    </div>
  )
}
