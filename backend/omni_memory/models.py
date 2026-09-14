from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field, model_validator

Kind = Literal["profile", "preference", "relationship", "goal", "note"]


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class MemoryCreate(StrictModel):
    kind: Kind
    text: str = Field(min_length=1, max_length=1000)
    confirmed: Literal[True]
    source_conversation_id: Optional[str] = Field(default=None, min_length=1, max_length=64)


class MemoryUpdate(StrictModel):
    text: str = Field(min_length=1, max_length=1000)
    kind: Optional[Kind] = None
    confirmed: Literal[True]


class SettingsUpdate(StrictModel):
    enabled: bool


class LocalMemory(StrictModel):
    id: str = Field(min_length=1, max_length=64)
    kind: Kind
    text: str = Field(min_length=1, max_length=1000)


class LocalTurn(StrictModel):
    role: Literal["user", "assistant"]
    content: str = Field(min_length=1, max_length=6000)


class ChatRequest(StrictModel):
    message: str = Field(min_length=1, max_length=4000)
    conversation_id: Optional[str] = Field(default=None, min_length=1, max_length=64)
    temporary: bool = False
    persist: bool = True
    suggest_memories: bool = False
    local_context: list[LocalMemory] = Field(default_factory=list, max_length=6)
    local_history: list[LocalTurn] = Field(default_factory=list, max_length=8)

    @model_validator(mode="after")
    def modes(self):
        if sum(len(value.text) for value in self.local_context) > 3000:
            raise ValueError("Local memory context exceeds the 3000-character budget.")
        if self.temporary and (self.local_context or self.conversation_id):
            raise ValueError("Temporary chat cannot include long-term memory or a saved conversation.")
        if self.persist and (self.local_context or self.local_history):
            raise ValueError("Local context requires persist:false.")
        if not self.persist and self.conversation_id:
            raise ValueError("Native stateless chat cannot reference a server conversation.")
        return self
