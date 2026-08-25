from __future__ import annotations

"""Canonical RAH Home Control room model v0.1.0.

This module defines only the initial logical room layout. It performs no device
search, pairing, Wi-Fi discovery, clustering, persistence or control actions.
Those remain separate roadmap items.
"""

from dataclasses import dataclass, asdict

ROOM_MODEL_VERSION = "0.1.0"


@dataclass(frozen=True, slots=True)
class Room:
    room_id: str
    name: str
    order: int
    enabled: bool = True

    def to_dict(self) -> dict[str, object]:
        return asdict(self)


ROOMS: tuple[Room, ...] = (
    Room(room_id="datarom", name="Datarom", order=1),
    Room(room_id="stue-1", name="Stue 1", order=2),
    Room(room_id="stue-2", name="Stue 2", order=3),
    Room(room_id="soverom", name="Soverom", order=4),
)

ROOMS_BY_ID: dict[str, Room] = {room.room_id: room for room in ROOMS}


def list_rooms() -> list[dict[str, object]]:
    """Return the canonical rooms in stable display order."""
    return [room.to_dict() for room in ROOMS]


def get_room(room_id: str) -> dict[str, object] | None:
    """Return one room by stable ID, or None when it is unknown."""
    room = ROOMS_BY_ID.get(room_id)
    return room.to_dict() if room else None


def validate_room_model() -> None:
    """Raise ValueError if the canonical room contract is internally invalid."""
    ids = [room.room_id for room in ROOMS]
    names = [room.name for room in ROOMS]
    orders = [room.order for room in ROOMS]

    if len(ids) != len(set(ids)):
        raise ValueError("room_id må være unik.")
    if len(names) != len(set(names)):
        raise ValueError("romnavn må være unikt.")
    if orders != sorted(orders) or len(orders) != len(set(orders)):
        raise ValueError("room order må være unik og stigende.")
    if any(not room.room_id or not room.name for room in ROOMS):
        raise ValueError("rom må ha room_id og name.")


validate_room_model()
