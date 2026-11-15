"""Build a self-contained, offline review page for Luna conversions."""
import argparse
import json
from email import policy
from email.parser import BytesParser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_NAMES = ['club-2026-08-13', 'club-2026-09-17', 'club-2026-10-22']
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('names', nargs='*', help='Conversion basenames under docs/workouts/examples')
parser.add_argument('--output', type=Path, default=ROOT / 'docs/workouts/review.html')
args = parser.parse_args()
feedback = json.loads((ROOT / 'docs/workouts/review-feedback.json').read_text())
reviews = {r['conversion']: r for r in feedback.get('conversionReviews', {}).get('reviews', [])}
records = []
for name in args.names or DEFAULT_NAMES:
    path = ROOT / 'docs/workouts/examples' / f'{name}.json'
    plan = json.loads(path.read_text())
    source = next(s['reference'] for s in plan['sources'] if s['type'] == 'email')
    mail = BytesParser(policy=policy.default).parsebytes((ROOT / source).read_bytes())
    body = mail.get_body(preferencelist=('plain',))
    if body is None:
        raise ValueError(f'No plain-text email body: {source}')
    records.append(dict(key=name, plan=plan, source=source, subject=str(mail['Subject']),
                        date=str(mail['Date']), text=body.get_content(), review=reviews.get(name)))

TEMPLATE = ROOT / 'tool/workout_review.template.html'
# Escape script delimiters even when source content contains HTML or script text.
payload = json.dumps(records, ensure_ascii=False).replace('<', '\\u003c').replace('>', '\\u003e').replace('&', '\\u0026')
args.output.write_text(TEMPLATE.read_text().replace('/*__WORKOUT_DATA__*/', payload))
print(args.output)
