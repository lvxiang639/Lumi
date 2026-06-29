export default function Growth() {
  return (
    <div className="space-y-12">
      <div>
        <h1 className="text-[28px] font-semibold text-[#2c2c2c] tracking-tight">成长记录</h1>
        <p className="text-[#8e8e8e] text-base mt-2">追踪每一步学习成长</p>
      </div>

      {/* Knowledge Map */}
      <div className="space-y-4">
        <h2 className="text-lg font-medium text-[#2c2c2c]">知识图谱</h2>
        <div className="bg-white rounded-2xl border border-[#f0efed] p-8 space-y-5">
          {[
            { name: '万以内加减法', pct: 95 },
            { name: '多位数乘法', pct: 67 },
            { name: '分数初步', pct: 30 },
            { name: '周长与面积', pct: 0 },
            { name: '时间与日历', pct: 85 },
            { name: '重量单位', pct: 72 },
          ].map((kp) => (
            <div key={kp.name} className="flex items-center gap-4">
              <div className="w-32 text-sm text-[#2c2c2c]">{kp.name}</div>
              <div className="flex-1 h-2 bg-[#f5f4f2] rounded-full overflow-hidden">
                <div
                  className="h-full rounded-full transition-all duration-700"
                  style={{
                    width: `${kp.pct || 100}%`,
                    background: kp.pct >= 70 ? '#b8c5b0' : kp.pct >= 30 ? '#e8d5b0' : kp.pct > 0 ? '#e8c0b0' : '#e8e6e3',
                  }}
                />
              </div>
              <div className="w-12 text-xs text-right text-[#8e8e8e]">
                {kp.pct > 0 ? `${kp.pct}%` : '未学'}
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Exam Records */}
      <div className="space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-medium text-[#2c2c2c]">考试记录</h2>
          <button className="text-sm text-[#5b6abf] hover:underline">+ 录入成绩</button>
        </div>
        <div className="bg-white rounded-2xl border border-[#f0efed] divide-y divide-[#f0efed]">
          {[
            { date: '6月25日', subject: '数学', score: 92, total: 100 },
            { date: '6月20日', subject: '语文', score: 88, total: 100 },
            { date: '6月15日', subject: '英语', score: 95, total: 100 },
          ].map((exam, i) => (
            <div key={i} className="flex items-center justify-between px-8 py-5">
              <div className="flex items-center gap-4">
                <span className="text-xl">{exam.subject === '数学' ? '📐' : exam.subject === '语文' ? '📖' : '🔤'}</span>
                <div>
                  <div className="font-medium text-[#2c2c2c]">{exam.subject}</div>
                  <div className="text-sm text-[#8e8e8e]">{exam.date}</div>
                </div>
              </div>
              <div>
                <span className="text-2xl font-semibold text-[#5b6abf]">{exam.score}</span>
                <span className="text-sm text-[#8e8e8e]"> / {exam.total}</span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
