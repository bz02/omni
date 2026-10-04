from datetime import date
import pytest
from pydantic import ValidationError
from omni_memory.birth import BirthInput, birth_clock, elements_for
from omni_memory.connect import ConnectProfile, normalize, report

def test_unknown_time_is_excluded_and_supplied_element_cannot_override_calculation():
    p = ConnectProfile(name='Alex', birth_date='1995-04-03', five_element='fire', consent_version='connect-v1')
    a = normalize(p, date(2026,10,3))
    assert a['element'] is None
    assert report(a,a,'dating')['dimensions'][5]['score'] is None
    for key in ['birth_date','birth_time','birth_timezone','birth_place','birth_longitude']:
        assert key not in a
    known = p.model_copy(update={'birth_time':'13:25', 'birth_timezone':'America/New_York'})
    a = normalize(known, date(2026,10,3))
    assert a['element'] == elements_for(known)['element']
    assert sum(a['element_counts'].values()) == 8

def test_timezone_historical_dst_and_mean_solar_date_boundary():
    p = BirthInput(birth_date='1995-04-03', birth_time='00:10', birth_timezone='America/New_York', birth_longitude=-74)
    aware, clock = birth_clock(p)
    assert aware.utcoffset().total_seconds() == -14400
    assert clock.isoformat().startswith('1995-04-02T23:14')
    assert elements_for(p)['element_basis'] == 'local_mean_solar_time'
    assert elements_for(p)['element'] != elements_for(p.model_copy(update={'birth_longitude':None}))['element']

@pytest.mark.parametrize('values',[
    dict(birth_time='12:00'),dict(birth_time='25:00',birth_timezone='America/New_York'),
    dict(birth_timezone='Mars/Olympus'),
    dict(birth_date='1995-04-02',birth_time='02:30',birth_timezone='America/New_York'),
    dict(birth_date='1995-10-29',birth_time='01:30',birth_timezone='America/New_York'),
])
def test_invalid_or_ambiguous_birth_inputs_rejected(values):
    with pytest.raises(ValidationError): BirthInput(**{'birth_date':'1995-04-03',**values})

def test_clock_repeat_explicit_fold_resolves_distinct_instants():
    a = BirthInput(birth_date='1995-10-29',birth_time='01:30',birth_timezone='America/New_York',birth_fold=0)
    b = a.model_copy(update={'birth_fold':1})
    assert birth_clock(a)[0].utcoffset() != birth_clock(b)[0].utcoffset()
