import { Routes, Route, Navigate } from 'react-router-dom'
import MainLayout from './layouts/MainLayout'
import Dashboard from './pages/Dashboard'
import Textbooks from './pages/Textbooks'
import Practice from './pages/Practice'
import WrongBook from './pages/WrongBook'
import Growth from './pages/Growth'
import ChatFAB from './components/ChatFAB'

export default function App() {
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
