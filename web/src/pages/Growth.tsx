import { Plus, TrendingUp } from 'lucide-react'

const KNOWLEDGE = [
  { name: '万以内加减法', pct: 95, color: '#10b981' },
  { name: '多位数乘法', pct: 67, color: '#f59e0b' },
  { name: '分数初步', pct: 30, color: '#ef4444' },
  { name: '周长与面积', pct: 0, color: '#d1d5db' },
  { name: '时间与日历', pct: 85, color: '#10b981' },
  { name: '重量单位', pct: 72, color: '#f59e0b' },
]

const EXAMS = [
  { date: '6月25日', subject: '数学', score: 92, total: 100 },
  { date: '6月20日', subject: '语文', score: 88, total: 100 },
  { date: '6月15日', subject: '英语', score: 95, total: 100 },
]

export default function Growth() {
  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold text-slate-800">📈 成长记录</h1>
        <p className="text-slate-500 text-sm mt-1">知识图谱 + 考试记录，追踪每一步成长</p>
      </div>

      <div className="grid grid-cols-2 gap-6">
        {/* Knowledge Map */}
        <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
          <div className="flex items-center justify-between mb-5">
            <h3 className="font-semibold text-slate-800">📖 知识图谱</h3>
            <select className="text-xs text-slate-500 border border-slate-200 rounded-lg px-3 py-1.5 outline-none cursor-pointer">
              <option>三年级数学</option>
              <option>三年级语文</option>
              <option>三年级英语</option>
            </select>
          </div>

          <div className="space-y-3">
            {KNOWLEDGE.map((kp) => (
              <div key={kp.name} className="flex items-center gap-3">
                <div className="w-24 text-sm text-slate-600 truncate" title={kp.name}>{kp.name}</div>
                <div className="flex-1 h-2.5 bg-slate-100 rounded-full overflow-hidden">
                  <div
                    className="h-full rounded-full transition-all duration-700"
                    style={{ width: `${kp.pct || 100}%`, background: kp.color }}
                  />
                </div>
                <div className="w-12 text-xs font-semibold text-right" style={{ color: kp.color }}>
                  {kp.pct > 0 ? `${kp.pct}%` : '未学'}
                </div>
              </div>
            ))}
          </div>

          {/* Legend */}
          <div className="flex gap-4 mt-5 pt-4 border-t border-slate-100">
            {[
              { color: '#10b981', label: '掌握 ≥70%' },
              { color: '#f59e0b', label: '进行中 30-70%' },
              { color: '#ef4444', label: '薄弱 <30%' },
              { color: '#d1d5db', label: '未学' },
            ].map((l) => (
              <div key={l.label} className="flex items-center gap-1.5">
                <div className="w-2.5 h-2.5 rounded-full" style={{ background: l.color }} />
                <span className="text-[11px] text-slate-400">{l.label}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Exam Records */}
        <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
          <div className="flex items-center justify-between mb-5">
            <h3 className="font-semibold text-slate-800">📋 考试记录</h3>
            <button className="flex items-center gap-1.5 text-xs text-indigo-600 font-medium hover:text-indigo-700 transition-colors">
              <Plus size={14} /> 录入成绩
            </button>
          </div>

          <div className="space-y-1">
            {EXAMS.map((exam, i) => (
              <div key={i} className="flex items-center justify-between py-3 border-b border-slate-50 last:border-0">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-xl bg-slate-100 flex items-center justify-center text-lg">
                    {exam.subject === '数学' ? '📐' : exam.subject === '语文' ? '📖' : '🔤'}
                  </div>
                  <div>
                    <div className="text-sm font-medium text-slate-700">{exam.subject}</div>
                    <div className="text-xs text-slate-400">{exam.date}</div>
                  </div>
                </div>
                <div className="flex items-baseline gap-1">
                  <span className="text-xl font-bold text-indigo-600">{exam.score}</span>
                  <span className="text-sm text-slate-400">/ {exam.total}</span>
                </div>
              </div>
            ))}
          </div>

          {/* Trend */}
          <div className="mt-5 pt-4 border-t border-slate-100">
            <div className="flex items-center gap-2 text-sm text-slate-500 mb-3">
              <TrendingUp size={14} className="text-emerald-500" />
              近期趋势
            </div>
            <div className="h-20 flex items-end gap-2">
              {[75, 80, 82, 88, 85, 92, 92].map((v, i) => (
                <div key={i} className="flex-1 flex flex-col items-center gap-1">
                  <div
                    className="w-full bg-indigo-200 rounded-t-md transition-all hover:bg-indigo-400"
                    style={{ height: `${v}%`, maxHeight: 80 }}
                  />
                  <span className="text-[10px] text-slate-400">{['一','二','三','四','五','六','日'][i]}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
