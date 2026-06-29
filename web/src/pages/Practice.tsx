const ITEMS = [
  { emoji: '🎯', title: 'AI 智能出题', desc: '按知识点、年级、难度自动生成练习题' },
  { emoji: '📷', title: '拍照解题', desc: '拍照上传，AI 分步讲解思路' },
  { emoji: '🏆', title: '奥数专项', desc: '思维训练、竞赛题型' },
  { emoji: '📜', title: '古诗词练习', desc: '填空、默写、鉴赏、背诵检测' },
  { emoji: '📖', title: '文言文翻译', desc: '逐句翻译、实词虚词、断句练习' },
  { emoji: '✨', title: '自定义专题', desc: '输入描述，AI 生成专项练习' },
]

export default function Practice() {
  return (
    <div className="space-y-12">
      <div>
        <h1 className="text-[28px] font-semibold text-[#2c2c2c] tracking-tight">练习中心</h1>
        <p className="text-[#8e8e8e] text-base mt-2">多种练习模式，AI 助力高效学习</p>
      </div>

      <div className="grid grid-cols-2 gap-4">
        {ITEMS.map((s) => (
          <div key={s.title} className="bg-white rounded-2xl border border-[#f0efed] p-7 flex items-center gap-6 cursor-pointer hover:border-[#e0dff0] hover:bg-[#fafafc] transition-all duration-200">
            <div className="text-3xl">{s.emoji}</div>
            <div>
              <div className="font-medium text-[#2c2c2c] text-lg">{s.title}</div>
              <div className="text-sm text-[#8e8e8e] mt-1.5">{s.desc}</div>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
