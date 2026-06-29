import { createContext, useContext, useState, useEffect, ReactNode } from 'react'
import { api } from '../services/api'

interface User { nickname?: string; phone?: string; avatar?: string; email?: string }

interface AuthCtx {
  user: User | null
  login: (phone: string) => Promise<void>
  logout: () => void
}

const AuthContext = createContext<AuthCtx>({ user: null, login: async () => {}, logout: () => {} })

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null)

  useEffect(() => {
    const token = localStorage.getItem('token')
    if (token) {
      api.getProfile().then(setUser).catch(() => localStorage.removeItem('token'))
    }
  }, [])

  async function login(phone: string) {
    const data = await api.login(phone)
    localStorage.setItem('token', data.access_token)
    const profile = await api.getProfile()
    setUser(profile)
  }

  function logout() {
    localStorage.removeItem('token')
    setUser(null)
  }

  return (
    <AuthContext.Provider value={{ user, login, logout }}>
      {children}
    </AuthContext.Provider>
  )
}

export const useAuth = () => useContext(AuthContext)
