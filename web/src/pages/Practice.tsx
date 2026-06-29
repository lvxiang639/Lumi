const SECTIONS = [
  { emoji: '🎯', title: 'AI 智能出题', desc: '根据知识点、年级、难度自动生成练习题', color: 'indigo' },
  { emoji: '📷', title: '拍照解题', desc: '不会的题拍照上传，AI 分步讲解思路', color: 'emerald' },
  { emoji: '🏆', title: '奥数专项', desc: '思维训练、竞赛题，从基础到进阶', color: 'amber' },
  { emoji: '📜', title: '古诗词练习', desc: '填空默写、意境鉴赏、背诵检测', color: 'purple' },
  { emoji: '📖', title: '文言文翻译', desc: '逐句翻译、实词虚词、断句练习', color: 'rose' },
  { emoji: '✨', title: '自定义专题', desc: '输入描述，AI 生成专项练习题', color: 'cyan' },
]

const COLORS: Record<string, string> = {
  indigo: 'bg-indigo-50 text-indigo-600 border-indigo-200',
  emerald: 'bg-emerald-50 text-emerald-600 border-emerald-200',
  amber: 'bg-amber-50 text-amber-600 border-amber-200',
  purple: 'bg-purple-50 text-purple-600 border-purple-200',
  rose: 'bg-rose-50 text-rose-600 border-rose-200',
  cyan: 'bg-cyan-50 text-cyan-600 border-cyan-200',
}

export default function Practice() {
  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold text-slate-800">📝 练习中心</h1>
        <p className="text-slate-500 text-sm mt-1">多种练习模式，AI 助力高效学习</p>
      </div>

      <div className="grid grid-cols-2 gap-4">
        {SECTIONS.map((s) => (
          <div key={s.title} className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm card-hover cursor-pointer flex items-center gap-5">
            <div className={`w-14 h-14 rounded-2xl ${COLORS[s.color].split(' ')[0]} border ${COLORS[s.color].split(' ')[2]} flex items-center justify-center text-2xl shrink-0`}>
              {s.emoji}
            </div>
            <div>
              <h3 className="font-semibold text-slate-800">{s.title}</h3>
              <p className="text-sm text-slate-500 mt-1">{s.desc}</p>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
