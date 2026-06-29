export default function WrongBook() {
  return (
    <div className="space-y-12">
      <div>
        <h1 className="text-[28px] font-semibold text-[#2c2c2c] tracking-tight">错题本</h1>
        <p className="text-[#8e8e8e] text-base mt-2">按知识点归类，针对性强化练习</p>
      </div>

      <div className="flex gap-4">
        <Filter label="全部孩子" />
        <Filter label="全部科目" />
        <Filter label="全部知识点" />
      </div>

      <div className="space-y-4">
        {[
          { name: '分数加减法', count: 8, desc: '通分、约分、异分母加减', recent: '昨天' },
          { name: '单位换算', count: 3, desc: '厘米、米、千米转换', recent: '3天前' },
          { name: '两步计算应用题', count: 1, desc: '加减混合运算应用题', recent: '6天前' },
        ].map((t) => (
          <div key={t.name} className="bg-white rounded-2xl border border-[#f0efed] p-7">
            <div className="flex items-center justify-between">
              <div>
                <div className="text-lg font-medium text-[#2c2c2c]">{t.name}</div>
                <div className="text-sm text-[#8e8e8e] mt-1">{t.desc}</div>
              </div>
              <div className="flex items-center gap-8">
                <div className="text-right">
                  <div className="text-2xl font-semibold text-[#2c2c2c]">{t.count}</div>
                  <div className="text-xs text-[#8e8e8e] mt-1">道错题</div>
                </div>
                <div className="text-xs text-[#8e8e8e]">最近: {t.recent}</div>
              </div>
            </div>
            <div className="flex gap-3 mt-6">
              <button className="px-5 py-2.5 rounded-xl border border-[#e0dff0] text-sm text-[#5b6abf] hover:bg-[#fafafc] transition-colors">查看错题</button>
              <button className="px-5 py-2.5 rounded-xl bg-[#5b6abf] text-white text-sm font-medium hover:bg-[#4f5cb0] transition-colors">重新练习</button>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}

function Filter({ label }: { label: string }) {
  return (
    <select className="appearance-none bg-white border border-[#f0efed] rounded-xl px-5 py-2.5 text-sm text-[#2c2c2c] outline-none cursor-pointer hover:border-[#e0dff0]">
      <option>{label}</option>
    </select>
  )
}
