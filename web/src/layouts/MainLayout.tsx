import { Outlet, NavLink } from 'react-router-dom'
import { LayoutDashboard, BookOpen, Pencil, AlertTriangle, TrendingUp } from 'lucide-react'

const NAV = [
  { to: '/dashboard', icon: LayoutDashboard, label: '学习中心' },
  { to: '/textbooks', icon: BookOpen, label: '课本' },
  { to: '/practice', icon: Pencil, label: '练习' },
  { to: '/wrong-book', icon: AlertTriangle, label: '错题本' },
  { to: '/growth', icon: TrendingUp, label: '成长' },
]

export default function MainLayout() {
  return (
    <div style={{ display: 'flex', height: '100vh', background: '#f5f5f5' }}>
      {/* Sidebar */}
      <aside style={{
        width: 200, background: '#fff', borderRight: '1px solid #e5e7eb',
        display: 'flex', flexDirection: 'column', padding: '20px 0',
      }}>
        <div style={{ padding: '0 20px 20px', fontWeight: 700, fontSize: 18, color: '#6366f1' }}>
          📚 灵犀教育
        </div>
        <nav style={{ flex: 1 }}>
          {NAV.map(({ to, icon: Icon, label }) => (
            <NavLink
              key={to}
              to={to}
              style={({ isActive }) => ({
                display: 'flex', alignItems: 'center', gap: 10,
                padding: '10px 20px', textDecoration: 'none',
                color: isActive ? '#6366f1' : '#6b7280',
                background: isActive ? '#eef2ff' : 'transparent',
                fontWeight: isActive ? 600 : 400,
              })}
            >
              <Icon size={18} />
              {label}
            </NavLink>
          ))}
        </nav>
      </aside>

      {/* Main content */}
      <main style={{ flex: 1, overflow: 'auto', padding: 24 }}>
        <Outlet />
      </main>
    </div>
  )
}
