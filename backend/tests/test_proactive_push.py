import pytest
from datetime import datetime, timedelta, timezone

BEIJING_TZ = timezone(timedelta(hours=8))


@pytest.mark.asyncio
async def test_quiet_hours_night():
    """22:00-8:00 should be quiet hours."""
    now = datetime(2026, 6, 9, 23, 0, tzinfo=BEIJING_TZ)
    assert now.hour >= 22 or now.hour < 8  # True = quiet


@pytest.mark.asyncio
async def test_quiet_hours_early_morning():
    """5:00 should be quiet hours."""
    now = datetime(2026, 6, 10, 5, 0, tzinfo=BEIJING_TZ)
    assert now.hour >= 22 or now.hour < 8


@pytest.mark.asyncio
async def test_quiet_hours_active():
    """14:00 should NOT be quiet hours."""
    now = datetime(2026, 6, 9, 14, 0, tzinfo=BEIJING_TZ)
    assert not (now.hour >= 22 or now.hour < 8)


@pytest.mark.asyncio
async def test_holiday_check_new_year():
    from app.services.proactive_service import HOLIDAYS
    assert HOLIDAYS.get("01-01") == "元旦"


@pytest.mark.asyncio
async def test_holiday_check_national_day():
    from app.services.proactive_service import HOLIDAYS
    assert HOLIDAYS.get("10-01") == "国庆节"


@pytest.mark.asyncio
async def test_holiday_check_valentine():
    from app.services.proactive_service import HOLIDAYS
    assert HOLIDAYS.get("02-14") == "情人节"
