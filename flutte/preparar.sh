#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
flutter create --empty --project-name casa_da_praia --platforms=android,web .
python3 - <<'PY'
from pathlib import Path
import re
p=Path('android/app/src/main/AndroidManifest.xml')
s=p.read_text()
if 'android.permission.INTERNET' not in s:
    s=re.sub(r'(<manifest[^>]*>)', r'\1<uses-permission android:name="android.permission.INTERNET" />', s, count=1)
if 'android:allowBackup=' not in s:
    s=s.replace('<application', '<application android:allowBackup="false"', 1)
p.write_text(s)
p=Path('android/app/src/debug/AndroidManifest.xml');p.parent.mkdir(parents=True,exist_ok=True)
p.write_text('''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
<uses-permission android:name="android.permission.INTERNET" />
<application android:usesCleartextTraffic="true" />
</manifest>''')
PY
flutter pub get
