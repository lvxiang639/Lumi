import { Outlet, NavLink, useLocation } from 'react-router-dom'
import { LayoutDashboard, BookOpen, Pencil, AlertTriangle, TrendingUp } from 'lucide-react'

const NAV = [
  { to: '/dashboard', icon: LayoutDashboard, label: '学习中心' },
  { to: '/textbooks', icon: BookOpen, label: '课本' },
  { to: '/practice', icon: Pencil, label: '练习' },
  { to: '/wrong-book', icon: AlertTriangle, label: '错题本' },
  { to: '/growth', icon: TrendingUp, label: '成长' },
]

export default function MainLayout() {
  const loc = useLocation()

  return (
    <div className="flex h-screen bg-slate-50">
      {/* Sidebar */}
      <aside className="w-56 bg-white border-r border-slate-200 flex flex-col shrink-0">
        {/* Logo */}
        <div className="px-5 py-6 border-b border-slate-100">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center text-white text-lg">
              📚
            </div>
            <div>
              <div className="font-bold text-base text-slate-800">灵犀教育</div>
              <div className="text-[11px] text-slate-400 -mt-0.5">AI 学习助手</div>
            </div>
          </div>
        </div>

        {/* Nav */}
        <nav className="flex-1 px-3 py-4 space-y-1">
          {NAV.map(({ to, icon: Icon, label }) => {
            const active = loc.pathname === to
            return (
              <NavLink
                key={to}
                to={to}
                className={`sidebar-link flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors ${
                  active
                    ? 'bg-indigo-50 text-indigo-600'
                    : 'text-slate-500 hover:bg-slate-50 hover:text-slate-700'
                }`}
              >
                <Icon size={18} strokeWidth={active ? 2.5 : 1.8} />
                {label}
                {active && (
                  <div className="ml-auto w-1.5 h-5 rounded-full bg-indigo-500" />
                )}
              </NavLink>
            )
          })}
        </nav>

        {/* Footer */}
        <div className="px-5 py-4 border-t border-slate-100">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-full bg-amber-100 flex items-center justify-center text-sm">
              👨‍👩‍👧
            </div>
            <div>
              <div className="text-sm font-medium text-slate-700">小明</div>
              <div className="text-[11px] text-slate-400">三年级</div>
            </div>
          </div>
        </div>
      </aside>

      {/* Main */}
      <main className="flex-1 overflow-auto">
        <div className="max-w-5xl mx-auto px-8 py-8">
          <Outlet />
        </div>
      </main>
    </div>
  )
}
