import os, json, uuid, datetime as dt
from flask import Flask, request, jsonify
from google.cloud import bigquery

app = Flask(__name__)
DATASET = os.environ["BQ_DATASET"]
TABLE   = os.environ["BQ_ALERTS_TABLE"]
client  = bigquery.Client()

@app.get("/healthz")
def healthz(): return "ok", 200

@app.post("/")
def ingest():
    try:
        body = request.get_json(silent=True) or {}
        row = [{
            "id": str(uuid.uuid4()),
            "event_time": dt.datetime.utcnow().isoformat(),
            "event_type": body.get("event_type","budget.alert"),
            "payload": json.dumps(body)
        }]
        table_id = f"{client.project}.{DATASET}.{TABLE}"
        errors = client.insert_rows_json(table_id, row)
        if errors: return jsonify({"status":"error","errors":errors}), 500
        return jsonify({"status":"ok"}), 200
    except Exception as e:
        return jsonify({"status":"error","msg":str(e)}), 500

if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    app.run(host="0.0.0.0", port=port)


