export default function Textbooks() {
  return (
    <div className="space-y-12">
      <div>
        <h1 className="text-[28px] font-semibold text-[#2c2c2c] tracking-tight">课本管理</h1>
        <p className="text-[#8e8e8e] text-base mt-2">苏教版教材，支持上传自定义课本</p>
      </div>

      <div className="grid grid-cols-3 gap-6">
        {[
          { grade: '三年级上', subject: '数学', publisher: '苏教版', units: 10, emoji: '📐' },
          { grade: '三年级上', subject: '语文', publisher: '苏教版', units: 8, emoji: '📖' },
          { grade: '三年级上', subject: '英语', publisher: '译林版', units: 8, emoji: '🔤' },
        ].map((book) => (
          <div key={book.subject} className="bg-white rounded-2xl border border-[#f0efed] p-8 cursor-pointer hover:border-[#e0dff0] transition-all duration-200">
            <div className="text-3xl mb-6">{book.emoji}</div>
            <div className="text-xs text-[#8e8e8e] mb-2">{book.publisher} · {book.units} 单元</div>
            <div className="text-lg font-medium text-[#2c2c2c]">{book.grade}{book.subject}</div>
            <div className="text-sm text-[#5b6abf] mt-4">查看目录 →</div>
          </div>
        ))}
      </div>

      <div className="bg-white rounded-2xl border border-dashed border-[#e0dff0] p-16 text-center cursor-pointer hover:bg-[#fafafc] transition-colors">
        <div className="text-3xl mb-4">📤</div>
        <div className="text-lg font-medium text-[#2c2c2c] mb-2">上传课本 PDF</div>
        <div className="text-sm text-[#8e8e8e]">自动识别章节和知识点，支持拖拽上传</div>
      </div>
    </div>
  )
}
