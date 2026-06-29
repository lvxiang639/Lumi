import { ArrowUp, Zap, BookOpen, Camera, AlertTriangle, FileText } from 'lucide-react'

export default function Dashboard() {
  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-slate-800">下午好 👋</h1>
          <p className="text-slate-500 text-sm mt-1">来看看小明今天的学习情况</p>
        </div>
        <div className="flex items-center gap-3 bg-white rounded-xl px-4 py-2.5 border border-slate-200 shadow-sm">
          <div className="w-9 h-9 rounded-full bg-indigo-100 flex items-center justify-center text-lg">👦</div>
          <div>
            <div className="text-sm font-semibold text-slate-700">小明</div>
            <div className="text-[11px] text-slate-400">三年级</div>
          </div>
          <select className="text-xs text-slate-500 border-none bg-transparent cursor-pointer outline-none">
            <option>切换孩子</option>
          </select>
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-4 gap-4">
        <StatCard icon="📊" value="28" label="本周做题" trend="+12%" color="indigo" />
        <StatCard icon="✅" value="67%" label="掌握率" trend="+5%" color="emerald" />
        <StatCard icon="⚠️" value="12" label="待复习错题" trend="-3" color="amber" />
        <StatCard icon="📈" value="92" label="最近考试" trend="语文88 数92" color="blue" />
      </div>

      {/* Grid: quick actions + progress */}
      <div className="grid grid-cols-3 gap-6">
        {/* Quick actions */}
        <div className="col-span-2 bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
          <h2 className="font-semibold text-slate-800 mb-4">快捷操作</h2>
          <div className="grid grid-cols-2 gap-3">
            <ActionCard icon={<Zap size={20} />} label="AI 出题" desc="根据知识点智能生成练习题" color="indigo" />
            <ActionCard icon={<Camera size={20} />} label="拍照解题" desc="拍照上传，AI 分步讲解" color="emerald" />
            <ActionCard icon={<AlertTriangle size={20} />} label="错题复习" desc="12 道错题待巩固" color="amber" />
            <ActionCard icon={<FileText size={20} />} label="学习周报" desc="查看本周学习报告" color="purple" />
          </div>
        </div>

        {/* Today's task */}
        <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
          <h2 className="font-semibold text-slate-800 mb-4">今日任务</h2>
          <div className="space-y-4">
            <TaskItem emoji="📐" title="分数加减法练习" desc="5 道题 · 预计 15 分钟" done />
            <TaskItem emoji="📖" title="古诗词《静夜思》" desc="背诵 + 理解赏析" />
            <TaskItem emoji="🔤" title="Unit 3 单词复习" desc="20 个单词 · 拼写练习" />
          </div>
        </div>
      </div>
    </div>
  )
}

function StatCard({ icon, value, label, trend, color }: {
  icon: string; value: string; label: string; trend: string; color: string
}) {
  const colors: Record<string, string> = {
    indigo: 'bg-indigo-50 text-indigo-600',
    emerald: 'bg-emerald-50 text-emerald-600',
    amber: 'bg-amber-50 text-amber-600',
    blue: 'bg-blue-50 text-blue-600',
  }
  return (
    <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm card-hover">
      <div className="flex items-center justify-between mb-3">
        <span className="text-2xl">{icon}</span>
        <span className="text-xs font-medium text-emerald-600 bg-emerald-50 px-2 py-0.5 rounded-full flex items-center gap-0.5">
          <ArrowUp size={10} />{trend}
        </span>
      </div>
      <div className="text-2xl font-bold text-slate-800">{value}</div>
      <div className="text-sm text-slate-500 mt-0.5">{label}</div>
    </div>
  )
}

function ActionCard({ icon, label, desc, color }: {
  icon: React.ReactNode; label: string; desc: string; color: string
}) {
  const colors: Record<string, string> = {
    indigo: 'bg-indigo-50 text-indigo-600',
    emerald: 'bg-emerald-50 text-emerald-600',
    amber: 'bg-amber-50 text-amber-600',
    purple: 'bg-purple-50 text-purple-600',
  }
  return (
    <div className="flex items-center gap-4 p-4 rounded-xl border border-slate-100 bg-slate-50/50 cursor-pointer card-hover">
      <div className={`w-10 h-10 rounded-xl ${colors[color]} flex items-center justify-center shrink-0`}>
        {icon}
      </div>
      <div>
        <div className="font-medium text-sm text-slate-700">{label}</div>
        <div className="text-xs text-slate-400 mt-0.5">{desc}</div>
      </div>
    </div>
  )
}

function TaskItem({ emoji, title, desc, done }: {
  emoji: string; title: string; desc: string; done?: boolean
}) {
  return (
    <div className="flex items-start gap-3">
      <div className={`w-8 h-8 rounded-lg flex items-center justify-center text-sm shrink-0 ${done ? 'bg-emerald-100' : 'bg-slate-100'}`}>
        {done ? '✅' : emoji}
      </div>
      <div className={done ? 'opacity-60' : ''}>
        <div className="text-sm font-medium text-slate-700">{title}</div>
        <div className="text-xs text-slate-400">{desc}</div>
      </div>
    </div>
  )
}
