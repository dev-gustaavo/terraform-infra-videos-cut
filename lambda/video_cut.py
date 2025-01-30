import boto3
import json
import os

s3_client = boto3.client('s3')
sqs_client = boto3.client('sqs')

SQS_URL = os.environ['SQS_URL']
SIGNED_URL_EXPIRATION = 3600

def lambda_handler(event, context):
    try:
        for record in event['Records']:
            bucket_name = record['s3']['bucket']['name']
            object_key = record['s3']['object']['key']

            presigned_url = generate_presigned_url(bucket_name, object_key)
            if not presigned_url:
                raise RuntimeError("Erro ao gerar URL presignada.")

            video_id = get_video_id(bucket_name, object_key)
            if not video_id:
                raise RuntimeError("Erro ao obter video id.")

            message = {
                "videoId": video_id,
                "bucket": bucket_name,
                "key": object_key,
                "presigned_url": presigned_url
            }

            response = sqs_client.send_message(
                QueueUrl=SQS_URL,
                MessageBody=json.dumps(message)
            )

            print(f"Mensagem enviada ao SQS: {response['MessageId']}")

        return {"statusCode": 200, "body": "Processamento concluído com sucesso."}

    except Exception as e:
        print(f"Erro ao processar evento: {str(e)}")
        return {"statusCode": 500, "body": f"Erro: {str(e)}"}

def generate_presigned_url(bucket_name, object_key):
    try:
        response = s3_client.generate_presigned_url(
            'get_object',
            Params={'Bucket': bucket_name, 'Key': object_key},
            ExpiresIn=SIGNED_URL_EXPIRATION
        )
        return response
    except Exception as e:
        print(f"Erro ao gerar URL: {str(e)}")
        return None

def get_video_id(bucket_name, object_key):
    try:
        response = s3_client.head_object(Bucket=bucket_name, Key=object_key)['Metadata']
        return response.get('videoid', 'N/A')
    except Exception as e:
        print(f"Erro ao obter metadata: {str(e)}")
        return None
