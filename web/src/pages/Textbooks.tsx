import { Upload, ChevronRight } from 'lucide-react'

const BOOKS = [
  { grade: '三年级上', subject: '数学', publisher: '苏教版', units: 10, color: 'from-indigo-500 to-blue-600', emoji: '📐' },
  { grade: '三年级上', subject: '语文', publisher: '苏教版', units: 8, color: 'from-emerald-500 to-teal-600', emoji: '📖' },
  { grade: '三年级上', subject: '英语', publisher: '译林版', units: 8, color: 'from-amber-500 to-orange-600', emoji: '🔤' },
]

export default function Textbooks() {
  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold text-slate-800">📚 课本管理</h1>
        <p className="text-slate-500 text-sm mt-1">预置苏教版教材，支持上传自定义课本</p>
      </div>

      {/* Textbook cards */}
      <div className="grid grid-cols-3 gap-5">
        {BOOKS.map((book) => (
          <div key={book.subject} className="bg-white rounded-2xl border border-slate-200 overflow-hidden shadow-sm card-hover cursor-pointer">
            <div className={`h-24 bg-gradient-to-br ${book.color} flex items-center justify-center`}>
              <span className="text-4xl">{book.emoji}</span>
            </div>
            <div className="p-5">
              <div className="flex items-center justify-between mb-2">
                <span className="text-xs font-medium text-slate-400 bg-slate-100 px-2.5 py-1 rounded-full">{book.publisher}</span>
                <span className="text-xs text-slate-400">{book.units} 个单元</span>
              </div>
              <h3 className="font-semibold text-slate-800">{book.grade}{book.subject}</h3>
              <div className="flex items-center gap-1 mt-3 text-indigo-600 text-sm font-medium">
                查看目录 <ChevronRight size={14} />
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Upload area */}
      <div className="bg-white rounded-2xl border-2 border-dashed border-slate-200 p-12 text-center hover:border-indigo-300 hover:bg-indigo-50/30 transition-colors cursor-pointer">
        <div className="w-16 h-16 rounded-2xl bg-indigo-100 flex items-center justify-center mx-auto mb-4">
          <Upload size={28} className="text-indigo-500" />
        </div>
        <h3 className="font-semibold text-slate-700 mb-1">上传课本 PDF</h3>
        <p className="text-sm text-slate-400">支持上传 PDF 课本，自动识别章节和知识点<br />拖拽文件到此处或点击上传</p>
      </div>
    </div>
  )
}
