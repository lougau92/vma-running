"""Decode email or validate conversion structure; never interpret workout meaning."""
import argparse
import json
import sys
from email import policy
from email.parser import BytesParser
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT))
from tool.scripts.workout_validation import validate_document


class PlainHTML(HTMLParser):
    def __init__(self):
        super().__init__()
        self.parts = []
        self.skip = 0

    def handle_starttag(self, tag, attrs):
        if tag in ('script', 'style'):
            self.skip += 1
        if not self.skip and tag in ('br', 'p', 'div', 'li', 'tr', 'h1', 'h2', 'h3'):
            self.parts.append('\n')
        if not self.skip and tag in ('td', 'th'):
            self.parts.append(' ')

    def handle_endtag(self, tag):
        if tag in ('script', 'style'):
            self.skip = max(0, self.skip - 1)
        if not self.skip and tag in ('p', 'div', 'li', 'tr'):
            self.parts.append('\n')

    def handle_data(self, data):
        if not self.skip:
            self.parts.append(data)


def read_email(path):
    mail = BytesParser(policy=policy.default).parsebytes(path.read_bytes())
    body = mail.get_body(preferencelist=('plain', 'html'))
    if body is None:
        raise ValueError('No readable body; inspect attachments and record unreadable if needed')
    text = body.get_content()
    if body.get_content_type() == 'text/html':
        parser = PlainHTML()
        parser.feed(text)
        text = ''.join(parser.parts)
    result = {'source': str(path), 'subject': str(mail.get('Subject', '')),
              'sentAt': mail['Date'].datetime.isoformat() if mail.get('Date') else None,
              'bodyType': body.get_content_type(), 'text': text,
              'attachments': [{'filename': p.get_filename(), 'type': p.get_content_type()}
                              for p in mail.walk()
                              if p.get_filename() or p.get_content_disposition() == 'attachment']}
    print(json.dumps(result, ensure_ascii=False, indent=2))


def validate(path):
    checks = validate_document(json.loads(path.read_text()))
    print(f'{path}: PASS ({", ".join(checks)}); source completeness requires cross-check')

if __name__ == '__main__':
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument('action', choices=['read', 'validate'])
    cli.add_argument('path', type=Path)
    args = cli.parse_args()
    try:
        (read_email if args.action == 'read' else validate)(args.path)
    except (ValueError, TypeError, KeyError, IndexError, OSError) as exc:
        cli.exit(1, f'ERROR: {exc}\n')
