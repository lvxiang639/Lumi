import { useState, useEffect } from 'react'
import { api } from '../services/api'

interface Textbook {
  id: string; title: string; publisher: string; grade: number; subject: string
  units: { name: string; lessons: string[] }[]
}

export default function Textbooks() {
  const [books, setBooks] = useState<Textbook[]>([])
  const [selected, setSelected] = useState<Textbook | null>(null)
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    api.getTextbooks().then(d => setBooks(d.items)).catch(() => {})
  }, [])

  async function openBook(book: Textbook) {
    setLoading(true)
    try {
      const detail = await api.getTextbook(book.id)
      setSelected(detail)
    } catch { }
    setLoading(false)
  }

  const emojiMap: Record<string, string> = { '数学': '📐', '语文': '📖', '英语': '🔤' }

  return (
    <div className="space-y-12">
      <div>
        <h1 className="text-[28px] font-semibold text-[#2c2c2c] tracking-tight">课本管理</h1>
        <p className="text-[#8e8e8e] text-base mt-2">苏教版 / 译林版教材，点击查看目录</p>
      </div>

      {selected ? (
        <div className="space-y-6">
          <button onClick={() => setSelected(null)}
            className="text-sm text-[#5b6abf] hover:underline mb-4">← 返回课本列表</button>

          <div className="bg-white rounded-2xl border border-[#f0efed] p-8">
            <div className="flex items-center gap-4 mb-8">
              <div className="text-3xl">{emojiMap[selected.subject] || '📚'}</div>
              <div>
                <h2 className="text-xl font-semibold text-[#2c2c2c]">{selected.title}</h2>
                <p className="text-sm text-[#8e8e8e] mt-1">{selected.publisher} · {selected.units?.length || 0} 个单元</p>
              </div>
            </div>

            <div className="space-y-4">
              {selected.units?.map((unit, i) => (
                <div key={i} className="border border-[#f0efed] rounded-xl p-5">
                  <div className="font-medium text-[#2c2c2c] mb-3">{unit.name}</div>
                  <div className="grid grid-cols-2 gap-2">
                    {unit.lessons.map((lesson, j) => (
                      <div key={j} className="flex items-center gap-2 text-sm text-[#5b6abf] px-3 py-2 rounded-lg bg-[#fafaf9] hover:bg-[#f3f2f8] cursor-pointer transition-colors">
                        <span className="text-xs text-[#8e8e8e]">📖</span>
                        {lesson}
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      ) : (
        <>
          <div className="grid grid-cols-3 gap-6">
            {books.map((book) => (
              <div key={book.id}
                onClick={() => openBook(book)}
                className="bg-white rounded-2xl border border-[#f0efed] p-8 cursor-pointer hover:border-[#e0dff0] transition-all duration-200">
                <div className="text-3xl mb-6">{emojiMap[book.subject] || '📚'}</div>
                <div className="text-xs text-[#8e8e8e] mb-2">{book.publisher} · {book.units?.length || 0} 单元</div>
                <div className="text-lg font-medium text-[#2c2c2c]">{book.title}</div>
                <div className="text-sm text-[#5b6abf] mt-4">查看目录 →</div>
              </div>
            ))}
          </div>

          <label className="block bg-white rounded-2xl border border-dashed border-[#e0dff0] p-16 text-center cursor-pointer hover:bg-[#fafafc] transition-colors">
            <input type="file" accept=".pdf" className="hidden" onChange={e => {
              const f = e.target.files?.[0]
              if (f) alert(`已选择: ${f.name}\n\n上传功能开发中...`)
            }} />
            <div className="text-3xl mb-4">📤</div>
            <div className="text-lg font-medium text-[#2c2c2c] mb-2">上传课本 PDF</div>
            <div className="text-sm text-[#8e8e8e]">自动识别章节和知识点</div>
          </label>
        </>
      )}

      {loading && <div className="text-center text-[#8e8e8e] py-8">加载中...</div>}
    </div>
  )
}
