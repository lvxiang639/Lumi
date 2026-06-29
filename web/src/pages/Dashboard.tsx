export default function Dashboard() {
  return (
    <div className="space-y-12">
      {/* Greeting */}
      <div>
        <h1 className="text-[28px] font-semibold text-[#2c2c2c] tracking-tight">下午好</h1>
        <p className="text-[#8e8e8e] text-base mt-2">来看看小明今天的学习情况</p>
      </div>

      {/* Stats — spacious 3-column grid */}
      <div className="grid grid-cols-3 gap-6">
        <StatCard value="28" label="本周做题" note="较上周 +12%" />
        <StatCard value="67%" label="掌握率" note="较上周 +5%" />
        <StatCard value="12" label="待复习错题" note="3 个知识点" />
      </div>

      {/* Actions — large touch targets */}
      <div className="space-y-4">
        <h2 className="text-lg font-medium text-[#2c2c2c]">快捷操作</h2>
        <div className="grid grid-cols-2 gap-3">
          <ActionCard emoji="🎯" title="AI 出题" desc="根据知识点智能生成练习" />
          <ActionCard emoji="📷" title="拍照解题" desc="拍照上传，AI 分步讲解" />
          <ActionCard emoji="📝" title="错题复习" desc="12 道错题待巩固" />
          <ActionCard emoji="📊" title="学习周报" desc="查看本周学习报告" />
        </div>
      </div>

      {/* Today */}
      <div className="space-y-4">
        <h2 className="text-lg font-medium text-[#2c2c2c]">今日任务</h2>
        <div className="space-y-2">
          <TaskItem emoji="📐" title="分数加减法练习" desc="5 道题 · 预计 15 分钟" done />
          <TaskItem emoji="📖" title="古诗词《静夜思》" desc="背诵 + 理解赏析" />
          <TaskItem emoji="🔤" title="Unit 3 单词复习" desc="20 个单词 · 拼写练习" />
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

function ActionCard({ emoji, title, desc }: { emoji: string; title: string; desc: string }) {
  return (
    <div className="bg-white rounded-2xl border border-[#f0efed] p-6 flex items-center gap-5 cursor-pointer hover:border-[#e0dff0] hover:bg-[#fafafc] transition-all duration-200">
      <div className="text-2xl">{emoji}</div>
      <div>
        <div className="font-medium text-[#2c2c2c]">{title}</div>
        <div className="text-sm text-[#8e8e8e] mt-0.5">{desc}</div>
      </div>
    </div>
  )
}

function TaskItem({ emoji, title, desc, done }: { emoji: string; title: string; desc: string; done?: boolean }) {
  return (
    <div className={`flex items-center gap-4 bg-white rounded-2xl border border-[#f0efed] p-5 ${done ? 'opacity-50' : ''}`}>
      <div className="text-xl">{done ? '✅' : emoji}</div>
      <div>
        <div className="font-medium text-[#2c2c2c]">{title}</div>
        <div className="text-sm text-[#8e8e8e]">{desc}</div>
      </div>
    </div>
  )
}
