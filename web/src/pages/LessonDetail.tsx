import { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { api } from '../services/api'

export default function LessonDetail() {
  const { bookId, lessonName } = useParams<{ bookId: string; lessonName: string }>()
  const [data, setData] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const nav = useNavigate()

  const lesson = decodeURIComponent(lessonName || '')

  useEffect(() => {
    if (!bookId || !lessonName) return
    setLoading(true)
    api.lessonDetail(bookId, lessonName)
      .then(setData)
      .catch(() => {})
      .finally(() => setLoading(false))
  }, [bookId, lessonName])

  if (loading) return <div className="text-center text-[#8e8e8e] py-20 text-lg">加载中...</div>
  if (!data) return <div className="text-center text-[#8e8e8e] py-20">加载失败</div>

  return (
    <div className="space-y-8 max-w-2xl mx-auto">
      <button onClick={() => nav(-1)} className="text-sm text-[#5b6abf] hover:underline">← 返回</button>

      <div className="bg-white rounded-2xl border border-[#f0efed] p-8">
        <div className="text-xs text-[#8e8e8e] mb-2">{data.book} · {data.unit}</div>
        <h1 className="text-2xl font-semibold text-[#2c2c2c] tracking-tight mb-6">{data.lesson}</h1>

        {/* Content */}
        <div className="text-[15px] text-[#2c2c2c] leading-relaxed space-y-3 mb-8">
          {data.content?.split('\n').filter(Boolean).map((p: string, i: number) => (
            <p key={i}>{p}</p>
          ))}
        </div>

        {/* Key points */}
        {data.key_points?.length > 0 && (
          <div className="mb-8">
            <h3 className="text-sm font-medium text-[#8e8e8e] mb-3">关键知识点</h3>
            <div className="flex flex-wrap gap-2">
              {data.key_points.map((kp: string, i: number) => (
                <span key={i} className="px-3 py-1.5 bg-[#f3f2f8] text-[#5b6abf] text-sm rounded-lg">{kp}</span>
              ))}
            </div>
          </div>
        )}

        <button
          onClick={() => nav(`/practice?topic=${encodeURIComponent(lesson)}&subject=${encodeURIComponent(data.subject)}`)}
          className="w-full py-4 bg-[#5b6abf] text-white rounded-xl text-base font-medium hover:bg-[#4f5cb0] transition-colors"
        >
          出题练习 →
        </button>

        {data.cached !== undefined && (
          <div className="text-xs text-[#8e8e8e] text-center mt-4">
            {data.cached ? '（已缓存）' : '（AI 生成，已保存）'}
          </div>
        )}
      </div>
    </div>
  )
}
