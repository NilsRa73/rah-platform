from pathlib import Path
p=Path('.github/scripts/build_home_control_v1_14.py')
s=p.read_text(encoding='utf-8')
old="function validConfigBackup(x){return !!(x&&x.schema===BACKUP_SCHEMA&&x.version===BACKUP_VERSION&&x.product==='RAH Home Control'&&validBackupState(x.state))}\"\nassert old_valid in html"
new="function validConfigBackup(x){return !!(x&&x.schema===BACKUP_SCHEMA&&x.version===BACKUP_VERSION&&x.product==='RAH Home Control'&&validBackupState(x.state))}\"\"\"\nassert old_valid in html"
assert old in s
p.write_text(s.replace(old,new,1),encoding='utf-8')
