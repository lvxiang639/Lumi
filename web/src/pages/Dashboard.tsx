import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { api } from '../services/api'

interface Child { id: string; name: string; grade: string }
interface Analysis { children: any[]; overall: { total: number; mastered: number; mastery_rate: number } }

export default function Dashboard() {
  const [child, setChild] = useState<Child | null>(null)
  const [children, setChildren] = useState<Child[]>([])
  const [analysis, setAnalysis] = useState<Analysis | null>(null)
  const [records, setRecords] = useState<any[]>([])
  const nav = useNavigate()

  useEffect(() => {
    api.getChildren().then(data => {
      setChildren(data.items)
      if (data.items.length > 0) setChild(data.items[0])
    }).catch(() => {})
  }, [])

  useEffect(() => {
    if (!child) return
    api.getAnalysis(child.id).then(setAnalysis).catch(() => {})
    api.getRecords({ child_id: child.id, status: '未掌握' }).then(r => setRecords(r.items)).catch(() => {})
  }, [child])

  const total = analysis?.overall?.total ?? 0
  const mastered = analysis?.overall?.mastered ?? 0
  const rate = Math.round((analysis?.overall?.mastery_rate ?? 0) * 100)
  const wrongCount = records.length

  return (
    <div className="space-y-12">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-[28px] font-semibold text-[#2c2c2c] tracking-tight">学习中心</h1>
          <p className="text-[#8e8e8e] text-base mt-2">
            {child ? `${child.name} ${child.grade} · ` : ''}AI 学习助手
          </p>
        </div>
        {children.length > 1 && (
          <select
            value={child?.id || ''}
            onChange={e => setChild(children.find(c => c.id === e.target.value) || null)}
            className="bg-white border border-[#f0efed] rounded-xl px-5 py-2.5 text-sm text-[#2c2c2c] outline-none"
          >
            {children.map(c => (
              <option key={c.id} value={c.id}>{c.name} · {c.grade}</option>
            ))}
          </select>
        )}
      </div>

      <div className="grid grid-cols-3 gap-6">
        <StatCard value={String(total)} label="本周做题" note={total > 0 ? `${mastered} 道已掌握` : '暂无记录'} />
        <StatCard value={`${rate}%`} label="掌握率" note={rate >= 70 ? '继续保持' : '需要加油'} />
        <StatCard value={String(wrongCount)} label="待复习错题" note={wrongCount > 0 ? `${wrongCount} 道未掌握` : '暂无错题'} />
      </div>

      <div className="space-y-4">
        <h2 className="text-lg font-medium text-[#2c2c2c]">快捷操作</h2>
        <div className="grid grid-cols-2 gap-3">
          <Action emoji="🎯" label="AI 出题" desc="根据知识点智能生成" onClick={() => nav('/practice')} />
          <Action emoji="📷" label="拍照解题" desc="拍照上传，AI 分步讲解" onClick={() => nav('/practice')} />
          <Action emoji="📝" label="错题复习" desc="巩固薄弱知识点" onClick={() => nav('/wrong-book')} />
          <Action emoji="📊" label="成长记录" desc="查看知识图谱 + 考试" onClick={() => nav('/growth')} />
        </div>
      </div>
    </div>
  )
}

function StatCard({ value, label, note }: { value: string; label: string; note: string }) {
  return (
    <div className="bg-white rounded-2xl border border-[#f0efed] p-8">
      <div className="text-[32px] font-semibold text-[#2c2c2c] tracking-tight">{value}</div>
      <div className="text-sm text-[#8e8e8e] mt-2">{label}</div>
      <div className="text-xs text-[#5b6abf] mt-3">{note}</div>
    </div>
  )
}

function Action({ emoji, label, desc, onClick }: { emoji: string; label: string; desc: string; onClick: () => void }) {
  return (
    <div onClick={onClick} className="bg-white rounded-2xl border border-[#f0efed] p-6 flex items-center gap-5 cursor-pointer hover:border-[#e0dff0] hover:bg-[#fafafc] transition-all duration-200">
      <div className="text-2xl">{emoji}</div>
      <div>
        <div className="font-medium text-[#2c2c2c]">{label}</div>
        <div className="text-sm text-[#8e8e8e] mt-0.5">{desc}</div>
      </div>
    </div>
  )
}
