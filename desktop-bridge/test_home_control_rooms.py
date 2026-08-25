from __future__ import annotations

"""Standard-library regression test for RAH Home Control room model v0.1."""

from home_control_rooms import ROOM_MODEL_VERSION, get_room, list_rooms, validate_room_model


def main() -> None:
    validate_room_model()

    rooms = list_rooms()
    assert ROOM_MODEL_VERSION == "0.1.0"
    assert [room["room_id"] for room in rooms] == ["datarom", "stue-1", "stue-2", "soverom"]
    assert [room["name"] for room in rooms] == ["Datarom", "Stue 1", "Stue 2", "Soverom"]
    assert [room["order"] for room in rooms] == [1, 2, 3, 4]
    assert all(room["enabled"] is True for room in rooms)

    datarom = get_room("datarom")
    assert datarom is not None
    assert datarom["name"] == "Datarom"
    assert get_room("unknown-room") is None

    rooms[0]["name"] = "Mutated copy"
    assert get_room("datarom")["name"] == "Datarom"

    print("PASS: RAH Home Control room model v0.1 contract")


if __name__ == "__main__":
    main()
