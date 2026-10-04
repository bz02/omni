"""Private birth inputs; deterministic, declared calendrical conventions only."""
from __future__ import annotations
from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
from typing import Literal, Optional
from pydantic import BaseModel, Field, model_validator
from lunar_python import Solar
from lunar_python.util import LunarUtil

ELEMENTS = {'木': 'wood', '火': 'fire', '土': 'earth', '金': 'metal', '水': 'water'}

class BirthInput(BaseModel):
    birth_date: date
    birth_time: Optional[str] = Field(default=None, pattern=r'^(?:[01]\d|2[0-3]):[0-5]\d$')
    birth_timezone: Optional[str] = Field(default=None, max_length=80)
    birth_place: Optional[str] = Field(default=None, max_length=120)
    birth_longitude: Optional[float] = Field(default=None, ge=-180, le=180, allow_inf_nan=False)
    birth_fold: Optional[Literal[0, 1]] = None

    @model_validator(mode='after')
    def valid_birth(self):
        if self.birth_timezone:
            try: ZoneInfo(self.birth_timezone)
            except (ZoneInfoNotFoundError, ValueError): raise ValueError('Choose a valid birth timezone.')
        if self.birth_time:
            if not self.birth_timezone: raise ValueError('Birth time needs the birth location timezone.')
            birth_clock(self)  # Reject daylight-saving gaps and unresolved repeated times.
        return self

def birth_clock(p):
    local = datetime.fromisoformat(f'{p.birth_date.isoformat()}T{p.birth_time}')
    zone = ZoneInfo(p.birth_timezone)
    choices = {}
    for fold in (0, 1):
        candidate = local.replace(tzinfo=zone, fold=fold)
        if candidate.astimezone(timezone.utc).astimezone(zone).replace(tzinfo=None) == local:
            choices[fold] = candidate
    if not choices: raise ValueError('This birth time falls in a daylight-saving gap. Check the birth record.')
    if len({v.utcoffset() for v in choices.values()}) > 1 and p.birth_fold is None:
        raise ValueError('This birth time occurred twice. Choose the first or second occurrence.')
    aware = choices[p.birth_fold or 0]
    clock = aware.replace(tzinfo=None) if p.birth_longitude is None else aware.astimezone(timezone.utc).replace(tzinfo=None) + timedelta(minutes=p.birth_longitude * 4)
    return aware, clock

def elements_for(p):
    if not p.birth_time:
        return dict(element=None, element_basis='birth_time_unknown', element_counts=None)
    aware, clock = birth_clock(p)
    def chart(d):
        result = Solar.fromYmdHms(d.year, d.month, d.day, d.hour, d.minute, d.second).getLunar().getEightChar()
        result.setSect(2)  # midnight day boundary
        return result
    local = chart(clock)
    season = chart(aware.astimezone(timezone(timedelta(hours=8))))
    pillars = [season.getYear(), season.getMonth(), local.getDay(), local.getTime()]
    counts = {v: 0 for v in ELEMENTS.values()}
    for stem, branch in pillars:
        counts[ELEMENTS[LunarUtil.WU_XING_GAN[stem]]] += 1
        counts[ELEMENTS[LunarUtil.WU_XING_ZHI[branch]]] += 1
    return dict(element=ELEMENTS[LunarUtil.WU_XING_GAN[local.getDayGan()]],
                element_basis='local_mean_solar_time' if p.birth_longitude is not None else 'local_civil_time', element_counts=counts)
