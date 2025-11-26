import os, json, uuid, time, datetime as dt
from flask import Flask, request, jsonify
from google.cloud import bigquery
import requests  # NEW

app = Flask(__name__)
DATASET = os.environ["BQ_DATASET"]
TABLE   = os.environ["BQ_ALERTS_TABLE"]
SLACK   = os.environ.get("SLACK_WEBHOOK_URL")  # NEW (from Secret Manager via Cloud Run)
client  = bigquery.Client()

# safe Slack notifier with simple retries
def post_to_slack(url: str, payload: dict, attempts: int = 3, timeout: float = 5.0) -> bool:
    """
    Best-effort Slack post. Never raises; returns True on 2xx, else False.
    Retries a couple times with short backoff so we don't block the request.
    """
    if not url:
        return False
    for i in range(attempts):
        try:
            r = requests.post(url, json=payload, timeout=timeout)
            if 200 <= r.status_code < 300:
                return True
        except Exception:
            pass
        time.sleep(1 + i)  # 1s, 2s backoff
    return False


@app.get("/healthz")
def healthz(): 
    return "ok", 200

@app.post("/")
def ingest():
    try:
        body = request.get_json(silent=True) or {}
        row = [{
            "id": str(uuid.uuid4()),
            "event_time": dt.datetime.utcnow().isoformat(),
            "event_type": body.get("event_type", "budget.alert"),
            "payload": json.dumps(body)
        }]

        table_id = f"{client.project}.{DATASET}.{TABLE}"
        errors = client.insert_rows_json(table_id, row)
        if errors:
            return jsonify({"status": "error", "errors": errors}), 500

        # best-effort Slack notification AFTER successful insert
        try:
            post_to_slack(
                SLACK, 
                {"text": f":money_with_wings: FinOps alert stored: `{row[0]['event_type']}` at `{row[0]['event_time']}`"}
            )
        except Exception:
            # swallow: do not fail ingestion because Slack hiccuped
            pass

        return jsonify({"status": "ok"}), 200
    except Exception as e:
        return jsonify({"status": "error", "msg": str(e)}), 500

if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    app.run(host="0.0.0.0", port=port)
