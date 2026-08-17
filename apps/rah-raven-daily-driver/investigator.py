import csv
import io
import json
import re
import zipfile
from html.parser import HTMLParser
from pathlib import Path


EMAIL_RE = re.compile(r"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b", re.I)
PHONE_RE = re.compile(
    r"(?<!\w)(?:\+\d{1,3}[\s.-]?)?(?:\(?\d{2,4}\)?[\s.-]?)?\d(?:[\s.-]?\d){6,12}(?!\w)"
)
URL_RE = re.compile(r"\bhttps?://[^\s<>'\"]+", re.I)
USERNAME_LABEL_RE = re.compile(
    r"(?:username|user name|screen name|handle|brukernavn|bruker)\s*[:=]\s*[@\"]?([A-Za-z][A-Za-z0-9._-]{2,40})",
    re.I,
)
NAME_LABEL_RE = re.compile(
    r"""(?<![A-Za-z0-9_])["']?(?:name|full[_ ]name|profile[_ ]name|sender(?:[_ ]name)?|from|participant|navn|avsender)["']?\s*[:=]\s*["']?([A-ZÆØÅ][A-Za-zÆØÅæøå .'-]{2,80})""",
    re.I,
)
PROFILE_RULES = [
    (re.compile(r"facebook\.com/([^/?#]+)", re.I), "Facebook"),
    (re.compile(r"instagram\.com/([^/?#]+)", re.I), "Instagram"),
    (re.compile(r"github\.com/([^/?#]+)", re.I), "GitHub"),
    (re.compile(r"reddit\.com/user/([^/?#]+)", re.I), "Reddit"),
    (re.compile(r"linkedin\.com/in/([^/?#]+)", re.I), "LinkedIn"),
    (re.compile(r"tiktok\.com/@([^/?#]+)", re.I), "TikTok"),
    (re.compile(r"(?:x|twitter)\.com/([^/?#]+)", re.I), "X/Twitter"),
]
PROVIDERS = {
    "gmail.com": "Google",
    "googlemail.com": "Google",
    "yahoo.com": "Yahoo",
    "hotmail.com": "Microsoft",
    "outlook.com": "Microsoft",
    "live.com": "Microsoft",
    "icloud.com": "Apple",
    "me.com": "Apple",
    "proton.me": "Proton",
    "protonmail.com": "Proton",
}
TEXT_SUFFIXES = {".json", ".html", ".htm", ".txt", ".csv", ".log", ".xml"}
MAX_ENTRY_BYTES = 25 * 1024 * 1024
MAX_TOTAL_BYTES = 350 * 1024 * 1024
MAX_ENTRIES = 15000


class TextStripper(HTMLParser):
    def __init__(self):
        super().__init__()
        self.parts = []

    def handle_data(self, data):
        if data.strip():
            self.parts.append(data.strip())

    def text(self):
        return "\n".join(self.parts)


def html_to_text(text):
    parser = TextStripper()
    try:
        parser.feed(text)
        return parser.text()
    except Exception:
        return text


def provider_for_email(email):
    return PROVIDERS.get(email.rsplit("@", 1)[-1].lower(), "")


def entity_id(kind, value):
    return f"{kind}:{value}".casefold()


class Investigator:
    def __init__(self, chronicle, identity=None):
        self.chronicle = chronicle
        self.identity = dict(identity or {})

    def _identity_seeds(self):
        values = set()
        for key in ("known_emails", "known_usernames", "known_phones"):
            values.update(str(x).casefold() for x in self.identity.get(key, []) if str(x).strip())
        return values

    def _scan_text(self, text, source, result):
        source_key = entity_id("artifact", source)
        self._add(result, "artifact", source, source, "", 1.0, extra={"artifact_type": "message/file"})
        self_id = entity_id("person", "self")
        self._add(
            result,
            "person",
            "self",
            source,
            "",
            1.0,
            extra={"display_name": self.identity.get("display_name", "You"), "identity_root": True},
        )
        emails = sorted(set(EMAIL_RE.findall(text)), key=str.casefold)
        phones = sorted(set(p.strip() for p in PHONE_RE.findall(text)))
        usernames = set(USERNAME_LABEL_RE.findall(text))
        urls = sorted(set(URL_RE.findall(text)))
        profiles = []
        people = sorted(set(x.strip().strip("\"' ") for x in NAME_LABEL_RE.findall(text) if x.strip()), key=str.casefold)

        for url in urls:
            for rule, provider in PROFILE_RULES:
                match = rule.search(url)
                if match:
                    username = match.group(1)
                    usernames.add(username)
                    profiles.append({"provider": provider, "username": username, "url": url})

        seeds = self._identity_seeds()
        for email in emails:
            self._add(result, "email", email, source, provider_for_email(email), 0.85)
            self._relation(result, entity_id("email", email), source_key, "observed_in_artifact", source, 0.95)
            if email.casefold() in seeds:
                self._relation(result, self_id, entity_id("email", email), "owns_identifier", source, 1.0)
        for phone in phones:
            digits = re.sub(r"\D", "", phone)
            if 7 <= len(digits) <= 15:
                self._add(result, "phone", phone, source, "", 0.65)
                self._relation(result, entity_id("phone", phone), source_key, "observed_in_artifact", source, 0.95)
                normalized_seed_match = any(re.sub(r"\D", "", seed) == digits for seed in seeds)
                if normalized_seed_match:
                    self._relation(result, self_id, entity_id("phone", phone), "owns_identifier", source, 1.0)
        for username in sorted(usernames, key=str.casefold):
            self._add(result, "username", username, source, "", 0.60)
            self._relation(result, entity_id("username", username), source_key, "observed_in_artifact", source, 0.95)
            if username.casefold() in seeds:
                self._relation(result, self_id, entity_id("username", username), "owns_identifier", source, 1.0)
        for person in people:
            self._add(result, "person", person, source, "", 0.60)
            self._relation(result, entity_id("person", person), source_key, "mentioned_in_artifact", source, 0.75)
        for profile in profiles:
            self._add(
                result,
                "account",
                profile["url"],
                source,
                profile["provider"],
                0.80,
                extra={"username": profile["username"]},
            )
            self._relation(
                result,
                entity_id("username", profile["username"]),
                entity_id("account", profile["url"]),
                "username_of_account",
                source,
                0.85,
            )
            self._relation(
                result,
                entity_id("account", profile["url"]),
                source_key,
                "observed_in_artifact",
                source,
                0.95,
            )
            if profile["username"].casefold() in seeds:
                self._relation(result, self_id, entity_id("username", profile["username"]), "owns_identifier", source, 1.0)

        present = []
        present.extend(entity_id("email", x) for x in emails)
        present.extend(entity_id("phone", x) for x in phones)
        present.extend(entity_id("username", x) for x in usernames)
        for i, a in enumerate(present[:100]):
            for b in present[i + 1 : 100]:
                self._relation(result, a, b, "appears_in_same_file", source, 0.45)

    def _add(self, result, kind, value, source, provider="", confidence=0.5, extra=None):
        key = entity_id(kind, value)
        item = result["entities"].setdefault(
            key,
            {
                "id": key,
                "kind": kind,
                "value": value,
                "provider": provider,
                "confidence": 0,
                "sources": [],
                "extra": {},
            },
        )
        item["confidence"] = max(item["confidence"], float(confidence))
        if provider:
            item["provider"] = provider
        if source not in item["sources"]:
            item["sources"].append(source)
        if extra:
            item["extra"].update(extra)

    def _relation(self, result, source_id, target_id, relation, evidence, confidence):
        if source_id == target_id:
            return
        a, b = sorted((source_id, target_id))
        key = (a, b, relation)
        result["relations"][key] = {
            "source": a,
            "target": b,
            "relation": relation,
            "evidence": evidence,
            "confidence": confidence,
        }

    def analyze_text(self, text, source="manual"):
        result = {"files": [source], "entities": {}, "relations": {}, "warnings": []}
        self._scan_text(text, source, result)
        return self.finalize(result)

    def import_path(self, path):
        path = Path(path)
        if path.suffix.lower() == ".zip":
            return self.import_zip(path)
        result = {"files": [], "entities": {}, "relations": {}, "warnings": []}
        if path.is_dir():
            for file in path.rglob("*"):
                if file.is_file() and file.suffix.lower() in TEXT_SUFFIXES and file.stat().st_size <= MAX_ENTRY_BYTES:
                    self._read_file(file, result, str(file))
        elif path.is_file():
            self._read_file(path, result, str(path))
        return self.finalize(result)

    def _read_file(self, path, result, source):
        raw = path.read_bytes()
        text = raw.decode("utf-8", errors="replace")
        if path.suffix.lower() in {".html", ".htm"}:
            text = html_to_text(text)
        elif path.suffix.lower() == ".json":
            try:
                text = json.dumps(json.loads(text), ensure_ascii=False)
            except Exception:
                pass
        result["files"].append(source)
        self._scan_text(text, source, result)

    def import_zip(self, path):
        result = {"files": [], "entities": {}, "relations": {}, "warnings": []}
        total = 0
        with zipfile.ZipFile(path) as zf:
            infos = zf.infolist()
            if len(infos) > MAX_ENTRIES:
                raise ValueError("archive has too many entries")
            for info in infos:
                if info.is_dir():
                    continue
                suffix = Path(info.filename).suffix.lower()
                if suffix not in TEXT_SUFFIXES:
                    continue
                if info.file_size > MAX_ENTRY_BYTES:
                    result["warnings"].append(f"skipped large entry: {info.filename}")
                    continue
                total += info.file_size
                if total > MAX_TOTAL_BYTES:
                    result["warnings"].append("archive text limit reached")
                    break
                raw = zf.read(info)
                text = raw.decode("utf-8", errors="replace")
                if suffix in {".html", ".htm"}:
                    text = html_to_text(text)
                elif suffix == ".json":
                    try:
                        text = json.dumps(json.loads(text), ensure_ascii=False)
                    except Exception:
                        pass
                source = f"{path.name}:{info.filename}"
                result["files"].append(source)
                self._scan_text(text, source, result)
        return self.finalize(result)

    def import_tool_export(self, path):
        path = Path(path)
        result = {"files": [str(path)], "entities": {}, "relations": {}, "warnings": []}
        text = path.read_text(encoding="utf-8", errors="replace")
        low = path.name.lower()
        if path.suffix.lower() == ".csv":
            rows = list(csv.DictReader(io.StringIO(text)))
            for row in rows[:50000]:
                username = row.get("username") or row.get("user") or ""
                url = row.get("url_user") or row.get("url") or ""
                site = row.get("name") or row.get("site") or ""
                exists = str(row.get("exists", "")).casefold()
                if username and (not exists or any(x in exists for x in ("true", "claimed", "found", "yes"))):
                    self._add(result, "username", username, str(path), site, 0.70)
                    if url:
                        self._add(result, "account", url, str(path), site, 0.75)
                        self._relation(
                            result,
                            entity_id("username", username),
                            entity_id("account", url),
                            "username_of_account",
                            str(path),
                            0.80,
                        )
        elif path.suffix.lower() == ".json":
            try:
                data = json.loads(text)
                flattened = json.dumps(data, ensure_ascii=False)
                self._scan_text(flattened, str(path), result)
            except Exception:
                self._scan_text(text, str(path), result)
        else:
            self._scan_text(text, str(path), result)
        return self.finalize(result)

    def finalize(self, result):
        entities = list(result["entities"].values())
        relations = list(result["relations"].values())
        for item in entities:
            self.chronicle.upsert_entity(item["id"], item["kind"], item["value"], item)
            if item["kind"] in {"email", "username", "account"}:
                self.chronicle.upsert_account(
                    item["value"],
                    item["kind"],
                    provider=item.get("provider", ""),
                    confidence=item.get("confidence", 0),
                    evidence=item.get("sources", []),
                )
        for rel in relations:
            self.chronicle.relation(
                rel["source"],
                rel["target"],
                rel["relation"],
                rel["evidence"],
                rel["confidence"],
            )
        self.chronicle.remember(
            "investigation",
            "Investigator",
            f"Imported {len(result['files'])} evidence file(s)",
            metadata={"entities": len(entities), "relations": len(relations), "warnings": result["warnings"]},
        )
        return {
            "files": result["files"],
            "entities": entities,
            "relations": relations,
            "warnings": result["warnings"],
        }

    def recovery_dashboard(self):
        return self.chronicle.accounts()
