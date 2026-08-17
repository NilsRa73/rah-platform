import json
import sqlite3
from datetime import datetime, timedelta
from pathlib import Path


STAGES = ["Prototype", "Candidate", "Runtime Test", "Stable", "Frozen"]


def now_iso():
    return datetime.now().isoformat(timespec="seconds")


class Chronicle:
    def __init__(self, db_path):
        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._init()

    def connect(self):
        con = sqlite3.connect(self.db_path)
        con.row_factory = sqlite3.Row
        return con

    def _init(self):
        with self.connect() as con:
            con.executescript(
                """
                CREATE TABLE IF NOT EXISTS events(
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    ts TEXT NOT NULL,
                    kind TEXT NOT NULL,
                    module TEXT NOT NULL,
                    title TEXT NOT NULL,
                    body TEXT NOT NULL DEFAULT '',
                    metadata_json TEXT NOT NULL DEFAULT '{}'
                );
                CREATE INDEX IF NOT EXISTS ix_events_ts ON events(ts);
                CREATE INDEX IF NOT EXISTS ix_events_kind ON events(kind);

                CREATE TABLE IF NOT EXISTS accounts(
                    identifier TEXT PRIMARY KEY,
                    kind TEXT NOT NULL,
                    provider TEXT NOT NULL DEFAULT '',
                    status TEXT NOT NULL DEFAULT 'Pending',
                    confidence REAL NOT NULL DEFAULT 0,
                    evidence_json TEXT NOT NULL DEFAULT '[]',
                    updated_at TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS projects(
                    name TEXT PRIMARY KEY,
                    version TEXT NOT NULL DEFAULT '',
                    stage TEXT NOT NULL DEFAULT 'Prototype',
                    frozen INTEGER NOT NULL DEFAULT 0,
                    score REAL NOT NULL DEFAULT 0,
                    metadata_json TEXT NOT NULL DEFAULT '{}',
                    updated_at TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS entities(
                    entity_id TEXT PRIMARY KEY,
                    kind TEXT NOT NULL,
                    value TEXT NOT NULL,
                    metadata_json TEXT NOT NULL DEFAULT '{}',
                    updated_at TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS relations(
                    source_id TEXT NOT NULL,
                    target_id TEXT NOT NULL,
                    relation TEXT NOT NULL,
                    evidence TEXT NOT NULL DEFAULT '',
                    confidence REAL NOT NULL DEFAULT 0.5,
                    PRIMARY KEY(source_id, target_id, relation)
                );
                """
            )

    def remember(self, kind, module, title, body="", metadata=None):
        with self.connect() as con:
            cur = con.execute(
                "INSERT INTO events(ts,kind,module,title,body,metadata_json) VALUES(?,?,?,?,?,?)",
                (now_iso(), kind, module, title, body, json.dumps(metadata or {}, ensure_ascii=False)),
            )
            return cur.lastrowid

    def decision(self, title, body="", module="Command Center", metadata=None):
        return self.remember("decision", module, title, body, metadata)

    def search(self, query, limit=50):
        pattern = f"%{query}%"
        with self.connect() as con:
            rows = con.execute(
                """
                SELECT * FROM events
                WHERE title LIKE ? OR body LIKE ? OR metadata_json LIKE ?
                ORDER BY ts DESC LIMIT ?
                """,
                (pattern, pattern, pattern, int(limit)),
            ).fetchall()
        return [dict(row) for row in rows]

    def decisions_last_days(self, days=7):
        cutoff = (datetime.now() - timedelta(days=days)).isoformat(timespec="seconds")
        with self.connect() as con:
            rows = con.execute(
                "SELECT * FROM events WHERE kind='decision' AND ts>=? ORDER BY ts DESC",
                (cutoff,),
            ).fetchall()
        return [dict(row) for row in rows]

    def upsert_account(self, identifier, kind, provider="", confidence=0, evidence=None, status=None):
        current = self.get_account(identifier)
        merged_evidence = list(current.get("evidence", [])) if current else []
        for item in list(evidence or []):
            if item not in merged_evidence:
                merged_evidence.append(item)
        final_status = status or (current.get("status") if current else "Pending")
        final_confidence = max(float(confidence or 0), float(current.get("confidence", 0) if current else 0))
        with self.connect() as con:
            con.execute(
                """
                INSERT INTO accounts(identifier,kind,provider,status,confidence,evidence_json,updated_at)
                VALUES(?,?,?,?,?,?,?)
                ON CONFLICT(identifier) DO UPDATE SET
                    kind=excluded.kind,
                    provider=CASE WHEN excluded.provider!='' THEN excluded.provider ELSE accounts.provider END,
                    status=excluded.status,
                    confidence=MAX(accounts.confidence, excluded.confidence),
                    evidence_json=excluded.evidence_json,
                    updated_at=excluded.updated_at
                """,
                (
                    identifier,
                    kind,
                    provider,
                    final_status,
                    final_confidence,
                    json.dumps(merged_evidence, ensure_ascii=False),
                    now_iso(),
                ),
            )

    def get_account(self, identifier):
        with self.connect() as con:
            row = con.execute("SELECT * FROM accounts WHERE identifier=?", (identifier,)).fetchone()
        if not row:
            return None
        data = dict(row)
        data["evidence"] = json.loads(data.pop("evidence_json") or "[]")
        return data

    def accounts(self, statuses=None):
        sql = "SELECT * FROM accounts"
        args = []
        if statuses:
            marks = ",".join("?" for _ in statuses)
            sql += f" WHERE status IN ({marks})"
            args.extend(statuses)
        sql += " ORDER BY confidence DESC, updated_at DESC"
        with self.connect() as con:
            rows = con.execute(sql, args).fetchall()
        result = []
        for row in rows:
            item = dict(row)
            item["evidence"] = json.loads(item.pop("evidence_json") or "[]")
            result.append(item)
        return result

    def set_account_status(self, identifier, status):
        if status not in {"Recovered", "Pending", "Lost", "Not mine"}:
            raise ValueError("invalid recovery status")
        with self.connect() as con:
            con.execute(
                "UPDATE accounts SET status=?, updated_at=? WHERE identifier=?",
                (status, now_iso(), identifier),
            )

    def upsert_project(self, name, version="", stage="Prototype", frozen=False, score=0, metadata=None):
        if stage not in STAGES:
            raise ValueError("invalid stage")
        with self.connect() as con:
            con.execute(
                """
                INSERT INTO projects(name,version,stage,frozen,score,metadata_json,updated_at)
                VALUES(?,?,?,?,?,?,?)
                ON CONFLICT(name) DO UPDATE SET
                    version=excluded.version,
                    stage=excluded.stage,
                    frozen=excluded.frozen,
                    score=excluded.score,
                    metadata_json=excluded.metadata_json,
                    updated_at=excluded.updated_at
                """,
                (
                    name,
                    version,
                    stage,
                    1 if frozen else 0,
                    float(score),
                    json.dumps(metadata or {}, ensure_ascii=False),
                    now_iso(),
                ),
            )

    def projects(self):
        with self.connect() as con:
            rows = con.execute("SELECT * FROM projects ORDER BY score DESC, name").fetchall()
        return [dict(row) for row in rows]

    def closest_to_stable(self):
        stage_rank = {"Prototype": 0, "Candidate": 1, "Runtime Test": 2, "Stable": 3, "Frozen": 4}
        candidates = [p for p in self.projects() if p["stage"] not in {"Stable", "Frozen"}]
        candidates.sort(key=lambda p: (stage_rank[p["stage"]], p["score"]), reverse=True)
        return candidates[0] if candidates else None

    def upsert_entity(self, entity_id, kind, value, metadata=None):
        with self.connect() as con:
            con.execute(
                """
                INSERT INTO entities(entity_id,kind,value,metadata_json,updated_at)
                VALUES(?,?,?,?,?)
                ON CONFLICT(entity_id) DO UPDATE SET
                    kind=excluded.kind,value=excluded.value,metadata_json=excluded.metadata_json,updated_at=excluded.updated_at
                """,
                (entity_id, kind, value, json.dumps(metadata or {}, ensure_ascii=False), now_iso()),
            )

    def relation(self, source_id, target_id, relation, evidence="", confidence=0.5):
        a, b = sorted((source_id, target_id))
        with self.connect() as con:
            con.execute(
                """
                INSERT INTO relations(source_id,target_id,relation,evidence,confidence)
                VALUES(?,?,?,?,?)
                ON CONFLICT(source_id,target_id,relation) DO UPDATE SET
                    evidence=excluded.evidence, confidence=MAX(relations.confidence,excluded.confidence)
                """,
                (a, b, relation, evidence, float(confidence)),
            )

    def ask(self, question):
        q = question.casefold()
        if ("forrige uke" in q or "last week" in q) and ("bestem" in q or "decid" in q):
            return self.decisions_last_days(7)
        if ("konto" in q or "account" in q) and (
            "ikke gjenopprettet" in q or "not recovered" in q or "mangler" in q
        ):
            return self.accounts(["Pending", "Lost"])
        if "nærmest stable" in q or "closest to stable" in q:
            return self.closest_to_stable()
        return self.search(question)
