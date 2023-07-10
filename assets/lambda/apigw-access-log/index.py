import json
import os
import zlib
from base64 import b64decode

import boto3

SQS_QUEUE_URL = os.getenv("SQS_QUEUE_URL")
SQS_QUEUE_REGION = os.getenv("SQS_QUEUE_REGION")

CONVERT_TO_INT_FIELDS = ["integrationLatency",
                         "latency", "status", "time", "responseLength"]

sqs = boto3.session.Session().client(
    'sqs', region_name=SQS_QUEUE_REGION, use_ssl=True)


def lambda_handler(event, context):
    decoded_data = decode_cwl_event(event["awslogs"]["data"])

    count = 0
    messages = []
    for log_event in decoded_data["logEvents"]:
        message_payload = json.loads(log_event["message"])

        # transform str into int
        for k, v in message_payload.items():
            if k in CONVERT_TO_INT_FIELDS:
                try:
                    message_payload[k] = int(v)
                except:
                    message_payload[k] = 0

        messages.append({
            "Id": str(count),
            "MessageBody": json.dumps(message_payload)
        })
        count = count + 1
        if count == 10:
            sqs.send_message_batch(
                QueueUrl=SQS_QUEUE_URL,
                Entries=messages
            )
            print(f"{count} message(s) sent to SQS at {SQS_QUEUE_URL}")
            count = 0
            messages = []

    if len(messages) > 0:
        sqs.send_message_batch(
            QueueUrl=SQS_QUEUE_URL,
            Entries=messages
        )
        print(f"{count} message(s) sent to SQS at {SQS_QUEUE_URL}")


def decode_cwl_event(encoded_data: str) -> dict:
    compressed_data = b64decode(encoded_data)
    json_payload = zlib.decompress(compressed_data, 16+zlib.MAX_WBITS)
    return json.loads(json_payload)
