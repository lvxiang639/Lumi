export default function Textbooks() {
  return (
    <div>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 20 }}>📚 课本管理</h1>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16 }}>
        {[
          { grade: '三年级', subject: '数学', publisher: '苏教版', units: 10, color: '#6366f1' },
          { grade: '三年级', subject: '语文', publisher: '苏教版', units: 8, color: '#10b981' },
          { grade: '三年级', subject: '英语', publisher: '译林版', units: 8, color: '#f59e0b' },
        ].map((book) => (
          <div key={book.subject} style={{
            background: '#fff', borderRadius: 12, padding: 20,
            border: '1px solid #e5e7eb', cursor: 'pointer',
          }}>
            <div style={{
              width: 40, height: 40, borderRadius: 10,
              background: book.color + '15', color: book.color,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: 18, marginBottom: 12,
            }}>
              {book.subject === '数学' ? '📐' : book.subject === '语文' ? '📖' : '🔤'}
            </div>
            <div style={{ fontWeight: 600, fontSize: 15 }}>
              {book.grade}{book.subject}（{book.publisher}）
            </div>
            <div style={{ color: '#9ca3af', fontSize: 12, marginTop: 4 }}>
              {book.units} 个单元 · 点击查看目录
            </div>
          </div>
        ))}
      </div>

      <div style={{
        marginTop: 24, padding: 24, background: '#fff', borderRadius: 12,
        border: '2px dashed #e5e7eb', textAlign: 'center',
      }}>
        <div style={{ fontSize: 32 }}>📤</div>
        <div style={{ fontWeight: 600, marginTop: 8 }}>上传课本 PDF</div>
        <div style={{ color: '#9ca3af', fontSize: 13, marginTop: 4 }}>
          支持上传 PDF 课本，自动识别章节和知识点
        </div>
      </div>
    </div>
  )
}
