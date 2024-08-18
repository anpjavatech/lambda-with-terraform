use aws_lambda_events::event::kinesis::KinesisEvent;
use lambda_runtime::{run, service_fn, Error, LambdaEvent};

async fn process_event(event: LambdaEvent<KinesisEvent>) -> Result<(), Error> {
    if event.payload.records.is_empty() {
        tracing::info!("No records found. Exiting.");
        return Ok(());
    }

    event.payload.records.iter().for_each(|record| {
        tracing::info!("EventId: {}",record.event_id.as_deref().unwrap_or_default());

        let record_data = std::str::from_utf8(&record.kinesis.data);

        match record_data { 
            Ok(data) => {
                // log the record data
                tracing::info!("Data: {}", data);
            }
            Err(e) => {
                tracing::error!("Error: {}", e);
            }
        }
    });

    tracing::info!(
        "Successfully processed {} records",
        event.payload.records.len()
    );

    Ok(())
}

#[tokio::main]
async fn main() -> Result<(), Error> {
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        // disable printing the name of the module in every log line.
        .with_target(false)
        // disabling time is handy because CloudWatch will add the ingestion time.
        .without_time()
        .init();

    run(service_fn(process_event)).await
}



#[cfg(test)]
mod tests {
    use super::*;
    use aws_lambda_events::encodings::Base64Data;
    use aws_lambda_events::event::kinesis::{KinesisEvent, KinesisEventRecord, KinesisRecord};
    use lambda_runtime::Context;
    use chrono::{DateTime, TimeZone, Utc};
    use aws_lambda_events::encodings::SecondTimestamp;

    #[tokio::test]
    async fn test_process_event_with_records() -> Result<(), Error> {
        let date_time_cus: DateTime<Utc> = Utc.with_ymd_and_hms(2017, 04, 02, 12, 50, 32).unwrap();
        let kinesis_record = KinesisRecord {
            data: Base64Data("Sample data".as_bytes().to_vec()),
            partition_key: Some("partition_key".to_string()),
            sequence_number: Some("sequence_number".to_string()),
            encryption_type: None,
            approximate_arrival_timestamp: SecondTimestamp(date_time_cus),
            kinesis_schema_version: Some("1.0".to_string()),
        };

        let event_record = KinesisEventRecord {
            event_id: Some("test_event_id".to_string()),
            event_name: Some("event_name".to_string()),
            event_source_arn: Some("event_source_arn".to_string()),
            event_version: Some("event_version".to_string()),
            event_source: Some("event_source".to_string()),
            aws_region: Some("aws_region".to_string()),
            kinesis: kinesis_record,
            invoke_identity_arn: Some("invoke_identity_arn".to_string()),
        };

        let kinesis_event = KinesisEvent {
            records: vec![event_record],
        };

        let context = Context::default();
        let lambda_event = LambdaEvent {
            payload: kinesis_event,
            context,
        };

        let result = process_event(lambda_event).await;
        assert!(result.is_ok());
        Ok(())
    }

    #[tokio::test]
    async fn test_process_event_with_empty_records() -> Result<(), Error> {
        let kinesis_event = KinesisEvent { records: vec![] };

        let context = Context::default();
        let lambda_event = LambdaEvent {
            payload: kinesis_event,
            context,
        };

        let result = process_event(lambda_event).await;
        assert!(result.is_ok());
        Ok(())
    }
}