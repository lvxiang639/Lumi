const BASE = 'http://localhost:8000'

function token(): string {
  return localStorage.getItem('token') || ''
}

async function request<T = any>(path: string, options: RequestInit = {}): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token()}`,
      ...options.headers,
    },
  })
  if (res.status === 401) {
    localStorage.removeItem('token')
    if (!window.location.pathname.includes('/login')) {
      window.location.href = '/login'
    }
    throw new Error('未登录')
  }
  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: res.statusText }))
    throw new Error(err.detail || `HTTP ${res.status}`)
  }
  return res.json()
}

export const api = {
  // Auth
  login: (phone: string) =>
    request<{ access_token: string }>('/api/auth/login', {
      method: 'POST', body: JSON.stringify({ phone }),
    }),

  getProfile: () => request('/api/auth/profile'),

  // Children
  getChildren: () =>
    request<{ items: { id: string; name: string; grade: string }[] }>('/api/study/children'),

  // Records
  getRecords: (params?: { child_id?: string; subject?: string; status?: string }) => {
    const qs = new URLSearchParams(params as any).toString()
    return request<{ items: any[] }>(`/api/study/records${qs ? '?' + qs : ''}`)
  },

  updateRecord: (id: string, body: { status?: string; child_id?: string }) =>
    request(`/api/study/records/${id}`, { method: 'PUT', body: JSON.stringify(body) }),

  deleteRecord: (id: string) =>
    request(`/api/study/records/${id}`, { method: 'DELETE' }),

  // Solve
  solve: (form: FormData) =>
    fetch(`${BASE}/api/study/solve`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token()}` },
      body: form,
    }).then(r => r.json()),

  // Analysis
  getAnalysis: (child_id?: string) => {
    const qs = child_id ? `?child_id=${child_id}` : ''
    return request(`/api/study/analysis${qs}`)
  },

  // Practice
  generateQuestions: (params: { subject?: string; topic?: string; grade?: number; count?: number }) =>
    request<{ questions: string[] }>('/api/study/generate-questions', {
      method: 'POST', body: JSON.stringify(params),
    }),

  generatePractice: (child_id?: string) => {
    const form = new FormData()
    if (child_id) form.append('child_id', child_id)
    return fetch(`${BASE}/api/study/practice`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token()}` },
      body: form,
    }).then(r => r.json())
  },

  // Knowledge points
  getKnowledgePoints: (subject?: string) => {
    const qs = subject ? `?subject=${subject}` : ''
    return request(`/api/study/knowledge-points${qs}`)
  },

  // Textbooks
  getTextbooks: () => request<{ items: any[] }>('/api/textbooks'),
  getTextbook: (id: string) => request<any>(`/api/textbooks/${id}`),
}
