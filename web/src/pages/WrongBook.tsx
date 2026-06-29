export default function WrongBook() {
  const topics = [
    { name: '分数加减法', count: 8, recent: '昨天', color: '#ef4444' },
    { name: '单位换算', count: 3, recent: '3天前', color: '#f59e0b' },
    { name: '两步计算应用题', count: 1, recent: '6天前', color: '#f59e0b' },
  ]

  return (
    <div>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 20 }}>❌ 错题本</h1>

      {/* Filters */}
      <div style={{ display: 'flex', gap: 10, marginBottom: 20 }}>
        <select style={selectStyle}><option>全部孩子</option><option>小明</option></select>
        <select style={selectStyle}><option>全部科目</option><option>数学</option><option>语文</option><option>英语</option></select>
        <select style={selectStyle}><option>全部知识点</option></select>
      </div>

      {topics.map((t) => (
        <div key={t.name} style={{
          background: '#fff', borderRadius: 12, padding: 16, marginBottom: 12,
          border: '1px solid #e5e7eb',
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <div style={{ fontWeight: 600, fontSize: 15 }}>📚 {t.name}</div>
              <div style={{ color: '#9ca3af', fontSize: 12, marginTop: 2 }}>
                错 {t.count} 次 · 最近: {t.recent}
              </div>
            </div>
            <div style={{ display: 'flex', gap: 8 }}>
              <button style={btnOutline}>查看错题</button>
              <button style={btnPrimary}>重新练习</button>
            </div>
          </div>
        </div>
      ))}
    </div>
  )
}

const selectStyle: React.CSSProperties = {
  padding: '6px 12px', borderRadius: 8, border: '1px solid #e5e7eb',
  background: '#fff', fontSize: 13,
}

const btnPrimary: React.CSSProperties = {
  padding: '6px 16px', borderRadius: 8, border: 'none',
  background: '#6366f1', color: '#fff', cursor: 'pointer', fontSize: 13, fontWeight: 500,
}

const btnOutline: React.CSSProperties = {
  ...btnPrimary, background: 'transparent', color: '#6366f1', border: '1px solid #6366f1',
}
