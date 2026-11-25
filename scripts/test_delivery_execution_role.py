"""Prove ReifnirDeliveryExecution works as intended.

1. Start in Reifnir-Delivery as the GitLab pipeline role (OIDC web identity).
2. From there, assume ReifnirDeliveryExecution in Reifnir-Root and list the ACTIVE accounts.
3. Assume ReifnirDeliveryExecution in every ACTIVE account and make a trivial read:
   confirm the caller identity and count the account's IAM roles.
4. Negative check: a ReifnirDeliveryExecution session must NOT be able to assume
   ReifnirDeliveryExecution anywhere else (only the Delivery pipeline role may).

Required environment: GITLAB_OIDC_TOKEN, AWS_ACCOUNT_ID_ROOT, AWS_ACCOUNT_ID_DELIVERY,
DELIVERY_PIPELINE_ROLE. Exits non-zero if any check fails.
"""

from __future__ import annotations

import os
import sys
from dataclasses import dataclass

import boto3
from botocore.exceptions import BotoCoreError, ClientError
from rich.console import Console
from rich.panel import Panel
from rich.table import Table

EXECUTION_ROLE = "ReifnirDeliveryExecution"
REGION = "us-east-1"

# Only the credentials this script obtains may be used.
for name in (
    "AWS_PROFILE",
    "AWS_ACCESS_KEY_ID",
    "AWS_SECRET_ACCESS_KEY",
    "AWS_SESSION_TOKEN",
    "AWS_ROLE_ARN",
    "AWS_WEB_IDENTITY_TOKEN_FILE",
):
    os.environ.pop(name, None)

# GitLab job logs render ANSI colors, but aren't a TTY.
console = Console(force_terminal=bool(os.environ.get("CI")), width=160)


@dataclass
class AccountResult:
    name: str
    account_id: str
    passed: bool
    identity: str = ""
    iam_roles: int | None = None
    error: str = ""


def require_env(name: str) -> str:
    value = os.environ.get(name, "")
    if not value:
        console.print(f"[bold red]{name} is required but unset.[/]")
        sys.exit(2)
    return value


def error_text(error: Exception) -> str:
    if isinstance(error, ClientError):
        details = error.response.get("Error", {})
        return f"{details.get('Code', 'Error')}: {details.get('Message', str(error))}"
    return str(error)


def session_from(credentials: dict) -> boto3.Session:
    return boto3.Session(
        aws_access_key_id=credentials["AccessKeyId"],
        aws_secret_access_key=credentials["SecretAccessKey"],
        aws_session_token=credentials["SessionToken"],
        region_name=REGION,
    )


def assume_execution_role(
    source: boto3.Session, account_id: str, session_name: str
) -> boto3.Session:
    response = source.client("sts").assume_role(
        RoleArn=f"arn:aws:iam::{account_id}:role/{EXECUTION_ROLE}",
        RoleSessionName=session_name,
    )
    return session_from(response["Credentials"])


def start_in_delivery(
    delivery_account_id: str, pipeline_role: str, token: str, session_name: str
) -> boto3.Session:
    # AssumeRoleWithWebIdentity is unsigned; the OIDC token is the credential.
    response = boto3.client("sts", region_name=REGION).assume_role_with_web_identity(
        RoleArn=f"arn:aws:iam::{delivery_account_id}:role/{pipeline_role}",
        RoleSessionName=session_name,
        WebIdentityToken=token,
    )
    return session_from(response["Credentials"])


def active_accounts(root: boto3.Session) -> list[dict]:
    paginator = root.client("organizations").get_paginator("list_accounts")
    accounts = [
        account
        for page in paginator.paginate()
        for account in page["Accounts"]
        if account.get("State") == "ACTIVE"
    ]
    return sorted(accounts, key=lambda account: account["Name"])


def exercise_account(
    pipeline: boto3.Session, account: dict, session_name: str
) -> AccountResult:
    name, account_id = account["Name"], account["Id"]
    try:
        execution = assume_execution_role(pipeline, account_id, session_name)
    except (ClientError, BotoCoreError) as error:
        return AccountResult(
            name, account_id, False, error=f"could not assume role: {error_text(error)}"
        )

    expected = f"arn:aws:sts::{account_id}:assumed-role/{EXECUTION_ROLE}/{session_name}"
    try:
        identity = execution.client("sts").get_caller_identity()["Arn"]
        if identity != expected:
            return AccountResult(
                name, account_id, False, identity, error=f"expected {expected}"
            )
        roles = execution.client("iam").get_account_summary()["SummaryMap"]["Roles"]
    except (ClientError, BotoCoreError) as error:
        return AccountResult(
            name, account_id, False, error=f"trivial read failed: {error_text(error)}"
        )

    return AccountResult(name, account_id, True, identity, roles)


def chained_session_is_denied(
    root: boto3.Session, delivery_account_id: str, session_name: str
) -> tuple[bool, str]:
    try:
        assume_execution_role(root, delivery_account_id, f"{session_name}-negative")
    except ClientError as error:
        return True, error_text(error)
    return (
        False,
        f"a {EXECUTION_ROLE} session assumed {EXECUTION_ROLE} in Delivery; the trust policy is too broad",
    )


def main() -> int:
    token = require_env("GITLAB_OIDC_TOKEN")
    root_account_id = require_env("AWS_ACCOUNT_ID_ROOT")
    delivery_account_id = require_env("AWS_ACCOUNT_ID_DELIVERY")
    pipeline_role = require_env("DELIVERY_PIPELINE_ROLE")
    session_name = f"gitlab-{os.environ.get('CI_PROJECT_ID', 'local')}-{os.environ.get('CI_PIPELINE_ID', '0')}"

    console.rule(f"[bold]{EXECUTION_ROLE} end-to-end test")

    try:
        pipeline = start_in_delivery(
            delivery_account_id, pipeline_role, token, session_name
        )
        pipeline_arn = pipeline.client("sts").get_caller_identity()["Arn"]
    except (ClientError, BotoCoreError) as error:
        console.print(
            f"[bold red]✗ Could not start in Reifnir-Delivery as {pipeline_role}:[/] {error_text(error)}"
        )
        return 1
    console.print(f"[green]✓[/] Started in Reifnir-Delivery as [cyan]{pipeline_arn}[/]")

    try:
        root = assume_execution_role(pipeline, root_account_id, session_name)
        accounts = active_accounts(root)
    except (ClientError, BotoCoreError) as error:
        console.print(
            f"[bold red]✗ Could not list accounts through Reifnir-Root:[/] {error_text(error)}"
        )
        return 1
    console.print(f"[green]✓[/] Found [bold]{len(accounts)}[/] ACTIVE accounts")

    results = [
        exercise_account(pipeline, account, session_name) for account in accounts
    ]

    table = Table(
        title=f"{EXECUTION_ROLE} in each ACTIVE account", title_justify="left"
    )
    table.add_column("Account", style="bold")
    table.add_column("ID")
    table.add_column("Result")
    table.add_column("IAM roles", justify="right")
    table.add_column("Identity / error", overflow="fold")
    for result in results:
        table.add_row(
            result.name,
            result.account_id,
            "[green]PASS[/]" if result.passed else "[bold red]FAIL[/]",
            "" if result.iam_roles is None else str(result.iam_roles),
            result.identity if result.passed else f"[red]{result.error}[/]",
        )
    console.print(table)

    denied, detail = chained_session_is_denied(root, delivery_account_id, session_name)
    if denied:
        console.print(
            f"[green]✓[/] Negative check: a {EXECUTION_ROLE} session can't assume {EXECUTION_ROLE} elsewhere ([dim]{detail}[/])"
        )
    else:
        console.print(f"[bold red]✗ Negative check failed:[/] {detail}")

    passed = sum(result.passed for result in results)
    failed = len(results) - passed + (0 if denied else 1)
    console.print(
        Panel(
            f"{passed}/{len(results)} accounts passed · negative check {'passed' if denied else 'FAILED'}",
            style="green" if failed == 0 else "bold red",
            expand=False,
        )
    )
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
