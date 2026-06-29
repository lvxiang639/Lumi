import { Routes, Route, Navigate } from 'react-router-dom'
import { AuthProvider, useAuth } from './hooks/useAuth'
import MainLayout from './layouts/MainLayout'
import Login from './pages/Login'
import Dashboard from './pages/Dashboard'
import Textbooks from './pages/Textbooks'
import Practice from './pages/Practice'
import WrongBook from './pages/WrongBook'
import Growth from './pages/Growth'
import ChatFAB from './components/ChatFAB'

function AppRoutes() {
  const { user } = useAuth()

  if (user === undefined) {
    return <div style={{padding: 40, fontFamily: 'sans-serif'}}>Loading...</div>
  }

  if (!user) {
    return (
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="*" element={<Navigate to="/login" replace />} />
      </Routes>
    )
  }

  return (
    <>
      <Routes>
        <Route path="/" element={<MainLayout />}>
          <Route index element={<Navigate to="/dashboard" replace />} />
          <Route path="dashboard" element={<Dashboard />} />
          <Route path="textbooks" element={<Textbooks />} />
          <Route path="practice" element={<Practice />} />
          <Route path="wrong-book" element={<WrongBook />} />
          <Route path="growth" element={<Growth />} />
        </Route>
      </Routes>
      <ChatFAB />
    </>
  )
}

export default function App() {
  return (
    <AuthProvider>
      <AppRoutes />
    </AuthProvider>
  )
}
