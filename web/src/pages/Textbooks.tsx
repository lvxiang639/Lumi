import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { api } from '../services/api'

interface Textbook { id: string; title: string; publisher: string; grade: number; subject: string; units: { name: string; lessons: string[] }[] }

export default function Textbooks() {
  const [books, setBooks] = useState<Textbook[]>([])
  const [selected, setSelected] = useState<Textbook | null>(null)
  const [loading, setLoading] = useState(false)
  const nav = useNavigate()

  useEffect(() => { api.getTextbooks().then(d => setBooks(d.items)).catch(() => {}) }, [])

  async function openBook(book: Textbook) {
    setLoading(true)
    try { const detail = await api.getTextbook(book.id); setSelected(detail) } catch { }
    setLoading(false)
  }

  function goDetail(lesson: string) {
    if (!selected) return
    nav(`/textbooks/${selected.id}/lesson/${encodeURIComponent(lesson)}`)
  }

  function goPractice(lesson: string) {
    if (!selected) return
    nav(`/practice?topic=${encodeURIComponent(lesson)}&subject=${encodeURIComponent(selected.subject)}`)
  }

  const emojiMap: Record<string, string> = { '数学': '📐', '语文': '📖', '英语': '🔤' }

  return (
    <div className="space-y-12">
      <div>
        <h1 className="text-[28px] font-semibold text-[#2c2c2c] tracking-tight">课本管理</h1>
        <p className="text-[#8e8e8e] text-base mt-2">苏教版 / 译林版教材 · 点击课时查看详情</p>
      </div>

      {selected ? (
        <div className="space-y-6">
          <button onClick={() => setSelected(null)} className="text-sm text-[#5b6abf] hover:underline">← 返回课本列表</button>
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
                <div key={i} className="border border-[#f0efed] rounded-xl overflow-hidden">
                  <div className="font-medium text-[#2c2c2c] bg-[#fafaf9] px-5 py-3 border-b border-[#f0efed]">{unit.name}</div>
                  <div className="p-3 space-y-1">
                    {unit.lessons.map((lesson, j) => (
                      <div key={j} className="flex items-center gap-2">
                        <button onClick={() => goDetail(lesson)}
                          className="flex-1 text-left text-sm text-[#5b6abf] px-3 py-2.5 rounded-lg hover:bg-[#f3f2f8] transition-colors">
                          📖 {lesson}
                        </button>
                        <button onClick={() => goPractice(lesson)}
                          className="shrink-0 text-xs px-3 py-1.5 rounded-lg bg-[#5b6abf] text-white hover:bg-[#4f5cb0] transition-colors">
                          出题
                        </button>
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
              <div key={book.id} onClick={() => openBook(book)}
                className="bg-white rounded-2xl border border-[#f0efed] p-8 cursor-pointer hover:border-[#e0dff0] transition-all duration-200">
                <div className="text-3xl mb-6">{emojiMap[book.subject] || '📚'}</div>
                <div className="text-xs text-[#8e8e8e] mb-2">{book.publisher} · {book.units?.length || 0} 单元</div>
                <div className="text-lg font-medium text-[#2c2c2c]">{book.title}</div>
                <div className="text-sm text-[#5b6abf] mt-4">查看目录 →</div>
              </div>
            ))}
          </div>
          <label className="block bg-white rounded-2xl border border-dashed border-[#e0dff0] p-16 text-center cursor-pointer hover:bg-[#fafafc] transition-colors">
            <input type="file" accept=".pdf" className="hidden" />
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
