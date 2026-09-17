"""Trusted local operator tool; never expose this as an HTTP handler."""

import argparse
import os

from .auth import issue_session
from .service import MemoryService


def main():
    parser = argparse.ArgumentParser(description="Provision a development entitlement or mint a short first-party session. This does not verify an Apple purchase.")
    parser.add_argument("subject", help="Opaque authenticated account identifier; never an email, contact or birth date.")
    parser.add_argument("--premium-until", type=int, help="UTC Unix expiration; 0 revokes. Trusted operator only.")
    parser.add_argument("--issue-session", action="store_true", help="Print a sensitive 15-minute bearer token. Do not paste it in logs or source control.")
    args = parser.parse_args()
    if args.premium_until is None and not args.issue_session:
        parser.error("Choose --premium-until or --issue-session.")
    service = MemoryService.from_env()
    if args.premium_until is not None:
        service.provision(args.subject, args.premium_until)
    if args.issue_session:
        print(issue_session(args.subject, os.environ.get("OMNI_MEMORY_SESSION_SECRET", "")))


if __name__ == "__main__":
    main()
