"""Local operator console. Run only on the protected server; output contains private reports."""
import argparse
import json
import os
from pathlib import Path

from .dating import DatingService
from .service import MemoryService


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("queue")
    review = commands.add_parser("profile")
    review.add_argument("id")
    review.add_argument("--revision", type=int, required=True)
    review.add_argument("--decision", choices=["approve", "suspend"], required=True)
    report = commands.add_parser("resolve-report")
    report.add_argument("id")
    photo = commands.add_parser('photo', help='Export a profile photo privately for visual review')
    photo.add_argument('id', help='Public profile ID')
    photo.add_argument('--revision', type=int, required=True)
    photo.add_argument('--output', required=True)
    args = parser.parse_args()
    memory = MemoryService.from_env()
    dating = DatingService(memory)
    if args.command == "queue":
        with memory.db() as db:
            profiles = [{"id": row["id"], "revision": row["revision"], "profile": json.loads(row["data"]), "photo_id": dating.photo_id(db, row["subject"])} for row in db.execute("SELECT * FROM dating_profiles WHERE status='pending' AND data IS NOT NULL LIMIT 100")]
            reports = [dict(row) for row in db.execute("SELECT r.id,p.id AS profile_id,r.reason,r.detail,r.created_at FROM dating_reports r JOIN dating_profiles p ON p.subject=r.receiver WHERE r.status='pending' ORDER BY r.created_at LIMIT 100")]
        print(json.dumps({"profiles": profiles, "reports": reports}, indent=2))
    elif args.command == 'photo':
        with memory.db() as db:
            row = db.execute('SELECT p.revision,f.image FROM dating_profiles p JOIN dating_photos f ON f.subject=p.subject WHERE p.id=?', (args.id,)).fetchone()
            if not row or row['revision'] != args.revision: parser.error('No photo at that reviewed revision.')
            # Never overwrite an existing path; owner-only access to personal photos.
            fd = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(fd, 'wb') as f: f.write(row['image'])
        print('Private review photo exported. Delete the local copy after review.')
    elif args.command == "profile":
        dating.moderate(args.id, revision=args.revision, approved=args.decision == "approve")
        print("Profile review saved.")
    else:
        with memory.db() as db:
            if not db.execute("UPDATE dating_reports SET status='resolved' WHERE id=? AND status='pending'", (args.id,)).rowcount:
                parser.error("No pending report with that ID.")
        print("Report resolved. Existing blocks remain in place.")


if __name__ == "__main__":
    main()
