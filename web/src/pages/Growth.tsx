export default function Growth() {
  return (
    <div>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 20 }}>📈 成长记录</h1>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginBottom: 20 }}>
        {/* Knowledge graph preview */}
        <div style={{ background: '#fff', borderRadius: 12, padding: 20, border: '1px solid #e5e7eb' }}>
          <h3 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12 }}>📖 知识图谱 · 三年级数学</h3>
          {[
            { name: '万以内加减法', pct: 95, color: '#10b981' },
            { name: '多位数乘法', pct: 67, color: '#f59e0b' },
            { name: '分数初步', pct: 30, color: '#ef4444' },
            { name: '周长与面积', pct: 0, color: '#d1d5db' },
          ].map((kp) => (
            <div key={kp.name} style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 10 }}>
              <div style={{ width: 120, fontSize: 13, color: '#374151' }}>{kp.name}</div>
              <div style={{ flex: 1, height: 8, background: '#f3f4f6', borderRadius: 4 }}>
                <div style={{ width: `${kp.pct}%`, height: 8, background: kp.color, borderRadius: 4 }} />
              </div>
              <div style={{ width: 40, fontSize: 12, color: kp.color, fontWeight: 600, textAlign: 'right' }}>
                {kp.pct > 0 ? `${kp.pct}%` : '未学'}
              </div>
            </div>
          ))}
        </div>

        {/* Exam records */}
        <div style={{ background: '#fff', borderRadius: 12, padding: 20, border: '1px solid #e5e7eb' }}>
          <h3 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12 }}>📋 考试记录</h3>
          {[
            { date: '6月25日', subject: '数学', score: 92, total: 100 },
            { date: '6月20日', subject: '语文', score: 88, total: 100 },
            { date: '6月15日', subject: '英语', score: 95, total: 100 },
          ].map((exam, i) => (
            <div key={i} style={{
              display: 'flex', justifyContent: 'space-between', padding: '8px 0',
              borderBottom: i < 2 ? '1px solid #f3f4f6' : 'none',
            }}>
              <div>
                <span style={{ fontWeight: 600, fontSize: 13 }}>{exam.subject}</span>
                <span style={{ color: '#9ca3af', fontSize: 12, marginLeft: 10 }}>{exam.date}</span>
              </div>
              <div>
                <span style={{ fontWeight: 700, fontSize: 16, color: '#6366f1' }}>{exam.score}</span>
                <span style={{ color: '#9ca3af', fontSize: 13 }}> / {exam.total}</span>
              </div>
            </div>
          ))}
          <button style={{
            marginTop: 12, padding: '8px 16px', borderRadius: 8, border: '1px dashed #d1d5db',
            background: 'transparent', color: '#6366f1', cursor: 'pointer', width: '100%',
          }}>
            + 录入考试成绩
          </button>
        </div>
      </div>
    </div>
  )
}
