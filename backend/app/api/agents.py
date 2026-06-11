"""User Agent CRUD + execution API."""

import json
import logging
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from app.database import get_db
from app.models import User
from app.models.user_agent import UserAgent, AgentStep
from app.api.deps import get_current_user
from app.services.llm_service import llm_router
from pydantic import BaseModel

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/agents", tags=["agents"])


class AgentCreate(BaseModel):
    name: str
    description: str = ""
    icon: str = "🤖"
    system_prompt: str = ""
    steps: list[dict] = []


class AgentUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    icon: str | None = None
    system_prompt: str | None = None
    steps: list[dict] | None = None


class AgentRunRequest(BaseModel):
    answers: dict[str, str] = {}  # step_id → answer


# ── CRUD ──

@router.get("")
async def list_agents(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    # Show public agents + user's own agents
    from sqlalchemy import or_
    r = await db.execute(select(UserAgent).where(or_(UserAgent.is_public == True, UserAgent.user_id == current_user.id)).order_by(UserAgent.created_at.desc()))
    agents = r.scalars().all()
    # Get step counts
    return {"items": [{"id": str(a.id), "name": a.name, "description": a.description, "icon": a.icon, "step_count": 0, "is_public": a.is_public, "owner": a.is_public, "created_at": a.created_at.isoformat() if a.created_at else ""} for a in agents]}


@router.get("/{agent_id}/history")
async def get_agent_history(agent_id: UUID, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Get run history for an agent."""
    from app.models.agent_run import AgentRun
    r = await db.execute(select(AgentRun).where(AgentRun.agent_id == agent_id, AgentRun.user_id == current_user.id).order_by(AgentRun.created_at.desc()).limit(20))
    runs = r.scalars().all()
    return {"items": [{"id": str(rn.id), "answers": rn.answers, "result": rn.result[:500], "created_at": rn.created_at.isoformat() if rn.created_at else ""} for rn in runs]}


@router.get("/history")
async def list_run_history(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """List all agent run history for user."""
    from app.models.agent_run import AgentRun
    r = await db.execute(select(AgentRun).where(AgentRun.user_id == current_user.id).order_by(AgentRun.created_at.desc()).limit(50))
    runs = r.scalars().all()
    return {"items": [{"id": str(rn.id), "agent_id": str(rn.agent_id), "agent_name": rn.agent_name, "result": rn.result[:200], "created_at": rn.created_at.isoformat() if rn.created_at else ""} for rn in runs]}


@router.post("", status_code=201)
async def create_agent(req: AgentCreate, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    agent = UserAgent(user_id=current_user.id, name=req.name, description=req.description, icon=req.icon, system_prompt=req.system_prompt)
    db.add(agent)
    await db.flush()
    for i, s in enumerate(req.steps):
        db.add(AgentStep(agent_id=agent.id, step_order=i + 1, question=s.get("question", ""), answer_type=s.get("answer_type", "text"), choices=s.get("choices", ""), next_step=s.get("next_step")))
    await db.commit()
    return {"id": str(agent.id)}


@router.get("/{agent_id}")
async def get_agent(agent_id: UUID, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    r = await db.execute(select(UserAgent).where(UserAgent.id == agent_id, UserAgent.user_id == current_user.id))
    agent = r.scalar_one_or_none()
    if not agent: raise HTTPException(404, "Not found")
    sr = await db.execute(select(AgentStep).where(AgentStep.agent_id == agent_id).order_by(AgentStep.step_order))
    steps = [{"id": str(s.id), "step_order": s.step_order, "question": s.question, "answer_type": s.answer_type, "choices": s.choices, "next_step": s.next_step} for s in sr.scalars().all()]
    return {"id": str(agent.id), "name": agent.name, "description": agent.description, "icon": agent.icon, "system_prompt": agent.system_prompt, "steps": steps}


@router.put("/{agent_id}")
async def update_agent(agent_id: UUID, req: AgentUpdate, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    r = await db.execute(select(UserAgent).where(UserAgent.id == agent_id, UserAgent.user_id == current_user.id))
    agent = r.scalar_one_or_none()
    if not agent: raise HTTPException(404, "Not found")
    for k in ("name", "description", "icon", "system_prompt"):
        if getattr(req, k) is not None: setattr(agent, k, getattr(req, k))
    if req.steps is not None:
        await db.execute(delete(AgentStep).where(AgentStep.agent_id == agent_id))
        for i, s in enumerate(req.steps):
            db.add(AgentStep(agent_id=agent_id, step_order=i + 1, question=s.get("question", ""), answer_type=s.get("answer_type", "text"), choices=s.get("choices", ""), next_step=s.get("next_step")))
    await db.commit()
    return {"status": "updated"}


@router.delete("/{agent_id}")
async def delete_agent(agent_id: UUID, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    r = await db.execute(delete(UserAgent).where(UserAgent.id == agent_id, UserAgent.user_id == current_user.id))
    await db.commit()
    if r.rowcount == 0: raise HTTPException(404, "Not found")
    return {"status": "deleted"}


# ── Save run ──

class SaveRunRequest(BaseModel):
    answers: dict = {}
    result: str = ""

@router.post("/{agent_id}/save-run")
async def save_run(agent_id: UUID, req: SaveRunRequest, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    r = await db.execute(select(UserAgent).where(UserAgent.id == agent_id))
    agent = r.scalar_one_or_none()
    if not agent: raise HTTPException(404, "Not found")
    from app.models.agent_run import AgentRun
    db.add(AgentRun(user_id=current_user.id, agent_id=agent_id, agent_name=agent.name, answers=json.dumps(req.answers, ensure_ascii=False), result=req.result))
    await db.commit()
    return {"status": "saved"}


# ── Execution ──

@router.post("/{agent_id}/run")
async def run_agent(agent_id: UUID, req: AgentRunRequest, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    r = await db.execute(select(UserAgent).where(UserAgent.id == agent_id, UserAgent.user_id == current_user.id))
    agent = r.scalar_one_or_none()
    if not agent: raise HTTPException(404, "Not found")
    sr = await db.execute(select(AgentStep).where(AgentStep.agent_id == agent_id).order_by(AgentStep.step_order))
    steps = list(sr.scalars().all())

    # Find current step
    answered = req.answers
    current_step = None
    for s in steps:
        if str(s.id) not in answered:
            current_step = s
            break

    if current_step is None:
        # All steps done — generate final output
        qa_lines = []
        for s in steps:
            ans = answered.get(str(s.id), "")
            if ans: qa_lines.append(f"问: {s.question}\n答: {ans}")
        qa_text = "\n\n".join(qa_lines)
        prompt = f"{agent.system_prompt}\n\n用户信息:\n{qa_text}\n\n请根据以上信息生成完整的建议或方案:"
        try:
            result = await llm_router.chat([{"role": "user", "content": prompt}])
            return {"status": "done", "result": result or "生成失败"}
        except Exception:
            return {"status": "done", "result": "生成失败，请重试"}
    else:
        return {
            "status": "next_step",
            "step_id": str(current_step.id),
            "step_order": current_step.step_order,
            "question": current_step.question,
            "answer_type": current_step.answer_type,
            "choices": json.loads(current_step.choices) if current_step.choices else [],
            "total_steps": len(steps),
        }
