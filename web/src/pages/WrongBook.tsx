import { RotateCcw, Eye } from 'lucide-react'

const TOPICS = [
  { name: '分数加减法', count: 8, recent: '昨天', color: 'rose', pct: 40, desc: '通分、约分、异分母加减' },
  { name: '单位换算', count: 3, recent: '3天前', color: 'amber', pct: 15, desc: '厘米/米/千米转换' },
  { name: '两步计算应用题', count: 1, recent: '6天前', color: 'amber', pct: 5, desc: '加减混合运算应用题' },
]

export default function WrongBook() {
  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold text-slate-800">❌ 错题本</h1>
        <p className="text-slate-500 text-sm mt-1">按知识点归类，针对性强化练习</p>
      </div>

      {/* Filters */}
      <div className="flex gap-3">
        <select className="bg-white border border-slate-200 rounded-xl px-4 py-2.5 text-sm text-slate-600 outline-none focus:border-indigo-300 cursor-pointer">
          <option>全部孩子</option><option>小明</option>
        </select>
        <select className="bg-white border border-slate-200 rounded-xl px-4 py-2.5 text-sm text-slate-600 outline-none focus:border-indigo-300 cursor-pointer">
          <option>全部科目</option><option>数学</option><option>语文</option><option>英语</option>
        </select>
        <select className="bg-white border border-slate-200 rounded-xl px-4 py-2.5 text-sm text-slate-600 outline-none focus:border-indigo-300 cursor-pointer">
          <option>全部知识点</option>
        </select>
      </div>

      {/* Topic cards */}
      <div className="space-y-4">
        {TOPICS.map((t) => (
          <div key={t.name} className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm card-hover">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-4">
                <div className={`w-12 h-12 rounded-2xl ${t.color === 'rose' ? 'bg-rose-50 text-rose-500' : 'bg-amber-50 text-amber-500'} flex items-center justify-center text-xl`}>
                  📚
                </div>
                <div>
                  <h3 className="font-semibold text-slate-800">{t.name}</h3>
                  <p className="text-xs text-slate-400 mt-0.5">{t.desc}</p>
                </div>
              </div>
              <div className="flex items-center gap-3">
                <div className="text-right">
                  <div className={`text-lg font-bold ${t.color === 'rose' ? 'text-rose-500' : 'text-amber-500'}`}>{t.count} 道</div>
                  <div className="text-xs text-slate-400">最近: {t.recent}</div>
                </div>
              </div>
            </div>

            {/* Progress bar */}
            <div className="mt-4 mb-4">
              <div className="flex justify-between text-xs text-slate-400 mb-1.5">
                <span>掌握度</span><span>{100 - t.pct}% 待加强</span>
              </div>
              <div className="h-2 bg-slate-100 rounded-full overflow-hidden">
                <div className={`h-full rounded-full transition-all ${t.color === 'rose' ? 'bg-rose-400' : 'bg-amber-400'}`} style={{ width: `${100 - t.pct}%` }} />
              </div>
            </div>

            <div className="flex gap-3">
              <button className="btn-ghost text-sm flex items-center gap-2">
                <Eye size={15} /> 查看错题
              </button>
              <button className="btn-primary text-sm flex items-center gap-2">
                <RotateCcw size={15} /> 重新练习 ({t.count}题)
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
