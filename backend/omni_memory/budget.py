"""Atomic shared API allowance. Uncertain requests keep their full reservation."""
import math
import uuid
from datetime import datetime, timezone

from fastapi import HTTPException


class ModelBudget:
    # Ten dollars per UTC calendar month across this deployment's chat and images.
    # Values are integer microdollars, not floating-point currency.
    def __init__(self, memory, monthly_limit=10_000_000):
        self.memory = memory
        self.limit = monthly_limit
        with memory.db() as db:
            db.execute("CREATE TABLE IF NOT EXISTS model_budget (id TEXT PRIMARY KEY, month TEXT NOT NULL, amount INTEGER NOT NULL)")

    def reserve(self, amount):
        month = datetime.fromtimestamp(self.memory.clock(), timezone.utc).strftime("%Y-%m")
        identifier = str(uuid.uuid4())
        with self.memory.content_db() as db:
            total = db.execute("SELECT COALESCE(SUM(amount),0) FROM model_budget WHERE month=?", (month,)).fetchone()[0]
            if total + amount > self.limit:
                raise HTTPException(429, "Omni's monthly AI allowance is currently used up. Your saved data remains available.")
            db.execute("INSERT INTO model_budget VALUES(?,?,?)", (identifier, month, amount))
        return identifier

    def settle(self, identifier, actual):
        if type(actual) is not int or actual < 0:
            return  # Unknown usage must not release a reservation.
        with self.memory.db() as db:
            row = db.execute("SELECT amount FROM model_budget WHERE id=?", (identifier,)).fetchone()
            if row and actual <= row[0]:
                db.execute("UPDATE model_budget SET amount=? WHERE id=?", (actual, identifier))

    def settle_chat(self, identifier, usage):
        if not isinstance(usage, dict):
            return
        a, b = usage.get("input_tokens"), usage.get("output_tokens")
        if type(a) is int and type(b) is int and a >= 0 and b >= 0:
            # GPT-4.1 mini: $0.40 / $1.60 per million. Count cached input at full price.
            self.settle(identifier, math.ceil(a * 0.4 + b * 1.6))
