export default function Practice() {
  return (
    <div>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 20 }}>📝 练习中心</h1>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 16 }}>
        <Section emoji="🎯" title="AI 出题" desc="根据知识点、年级、难度，AI 自动生成练习题" />
        <Section emoji="📷" title="拍照解题" desc="不会的题拍照上传，AI 分步讲解" />
        <Section emoji="🏆" title="奥数专项" desc="思维训练、竞赛题，从基础到进阶" />
        <Section emoji="📜" title="古诗词练习" desc="填空、默写、鉴赏、背诵检测" />
        <Section emoji="📖" title="文言文翻译" desc="逐句翻译、实词虚词、断句练习" />
        <Section emoji="✨" title="自定义专题" desc="输入描述，AI 生成专项练习题" />
      </div>
    </div>
  )
}

function Section({ emoji, title, desc }: { emoji: string; title: string; desc: string }) {
  return (
    <div style={{
      background: '#fff', borderRadius: 12, padding: 20, cursor: 'pointer',
      border: '1px solid #e5e7eb', display: 'flex', gap: 14, alignItems: 'center',
    }}>
      <div style={{ fontSize: 32 }}>{emoji}</div>
      <div>
        <div style={{ fontWeight: 600, fontSize: 15 }}>{title}</div>
        <div style={{ color: '#9ca3af', fontSize: 12, marginTop: 2 }}>{desc}</div>
      </div>
    </div>
  )
}
