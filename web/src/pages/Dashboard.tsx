export default function Dashboard() {
  return (
    <div>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 20 }}>🏠 学习中心</h1>

      {/* Summary cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16, marginBottom: 24 }}>
        <Card color="#6366f1" emoji="👦" title="小明" subtitle="三年级 · 苏教版" stat="掌握率 67%" />
        <Card color="#10b981" emoji="📊" title="本周学习" subtitle="6月23日 - 6月29日" stat="做了 28 题" />
        <Card color="#f59e0b" emoji="⚠️" title="待复习" subtitle="3 个薄弱知识点" stat="错题 12 道" />
      </div>

      {/* Quick actions */}
      <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>快捷操作</h2>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12 }}>
        <ActionCard emoji="📝" label="出几道题" desc="按知识点出题练习" />
        <ActionCard emoji="📷" label="拍照解题" desc="拍照上传，AI 讲解" />
        <ActionCard emoji="📖" label="查看错题本" desc="回顾薄弱知识点" />
        <ActionCard emoji="📈" label="学习周报" desc="查看本周进步" />
      </div>
    </div>
  )
}

function Card({ color, emoji, title, subtitle, stat }: {
  color: string; emoji: string; title: string; subtitle: string; stat: string
}) {
  return (
    <div style={{
      background: '#fff', borderRadius: 12, padding: 20,
      border: '1px solid #e5e7eb', borderLeft: `4px solid ${color}`,
    }}>
      <div style={{ fontSize: 28, marginBottom: 8 }}>{emoji}</div>
      <div style={{ fontWeight: 600, fontSize: 15 }}>{title}</div>
      <div style={{ color: '#9ca3af', fontSize: 12, marginTop: 2 }}>{subtitle}</div>
      <div style={{ color, fontWeight: 700, fontSize: 18, marginTop: 8 }}>{stat}</div>
    </div>
  )
}

function ActionCard({ emoji, label, desc }: { emoji: string; label: string; desc: string }) {
  return (
    <div style={{
      background: '#fff', borderRadius: 10, padding: 16, cursor: 'pointer',
      border: '1px solid #e5e7eb', textAlign: 'center',
    }}>
      <div style={{ fontSize: 28 }}>{emoji}</div>
      <div style={{ fontWeight: 600, fontSize: 14, marginTop: 6 }}>{label}</div>
      <div style={{ color: '#9ca3af', fontSize: 11, marginTop: 2 }}>{desc}</div>
    </div>
  )
}
