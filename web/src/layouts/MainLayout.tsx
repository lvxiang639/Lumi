import { Outlet, NavLink, useLocation } from 'react-router-dom'

const NAV = [
  { to: '/dashboard', label: '学习中心' },
  { to: '/textbooks', label: '课本' },
  { to: '/practice', label: '练习' },
  { to: '/wrong-book', label: '错题本' },
  { to: '/growth', label: '成长' },
]

export default function MainLayout() {
  const loc = useLocation()

  return (
    <div className="flex h-screen bg-[#fafaf9]">
      {/* Sidebar — minimal, airy */}
      <aside className="w-52 flex flex-col shrink-0 border-r border-[#f0efed] bg-white">
        <div className="px-6 pt-10 pb-8">
          <div className="text-xl font-semibold text-[#2c2c2c] tracking-tight">灵犀教育</div>
          <div className="text-sm text-[#8e8e8e] mt-1">AI 学习助手</div>
        </div>

        <nav className="flex-1 px-4 space-y-0.5">
          {NAV.map(({ to, label }) => {
            const active = loc.pathname === to
            return (
              <NavLink
                key={to}
                to={to}
                className={`block px-4 py-2.5 rounded-lg text-[15px] transition-colors ${
                  active
                    ? 'bg-[#f3f2f8] text-[#5b6abf] font-medium'
                    : 'text-[#8e8e8e] hover:bg-[#fafaf9] hover:text-[#2c2c2c]'
                }`}
              >
                {label}
              </NavLink>
            )
          })}
        </nav>

        <div className="px-6 py-6 border-t border-[#f0efed]">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-full bg-[#f3f2f8] flex items-center justify-center text-sm text-[#5b6abf] font-medium">
              明
            </div>
            <div>
              <div className="text-sm font-medium text-[#2c2c2c]">小明</div>
              <div className="text-xs text-[#8e8e8e]">三年级</div>
            </div>
          </div>
        </div>
      </aside>

      {/* Content — generous padding */}
      <main className="flex-1 overflow-auto">
        <div className="max-w-3xl mx-auto px-12 py-12">
          <Outlet />
        </div>
      </main>
    </div>
  )
}
