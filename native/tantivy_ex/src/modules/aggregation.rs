use rustler::{Encoder, Env, NifResult, ResourceArc, Term};
use serde_json::{json, Map, Value as JsonValue};
use std::collections::HashMap;
use tantivy::aggregation::agg_req::{Aggregation, AggregationVariants, Aggregations};
use tantivy::aggregation::agg_result::AggregationResults;
use tantivy::aggregation::bucket::RangeAggregationRange;
use tantivy::aggregation::bucket::{
    DateHistogramAggregationReq, HistogramAggregation, RangeAggregation, TermsAggregation,
};
use tantivy::aggregation::metric::{
    AverageAggregation, CountAggregation, MaxAggregation, MinAggregation, PercentileValues,
    PercentilesAggregationReq, StatsAggregation, SumAggregation,
};
use tantivy::aggregation::{AggregationCollector, AggregationLimitsGuard, Key};
use tantivy::schema::OwnedValue;
use tantivy::schema::Schema;

use crate::modules::resources::{QueryResource, SearcherResource};

#[derive(Debug, Clone)]
pub struct AggregationRequest {
    pub name: String,
    pub aggregation_type: AggregationType,
    pub field: String,
    pub sub_aggregations: HashMap<String, AggregationRequest>,
    pub options: AggregationOptions,
}

#[derive(Debug, Clone)]
pub enum AggregationType {
    // Bucket aggregations
    Terms { size: Option<usize> },
    Histogram { interval: f64 },
    DateHistogram { interval: String },
    Range { ranges: Vec<RangeSpec> },

    // Metric aggregations
    Avg,
    Min,
    Max,
    Sum,
    Count,
    Stats,
    Percentiles { percents: Vec<f64> },
}

#[derive(Debug, Clone)]
pub struct RangeSpec {
    pub from: Option<f64>,
    pub to: Option<f64>,
    pub key: Option<String>,
}

#[derive(Debug, Clone, Default)]
pub struct AggregationOptions {
    pub min_doc_count: Option<u64>,
    pub missing: Option<String>,
    pub keyed: Option<bool>,
}

#[rustler::nif(schedule = "DirtyCpu")]
pub fn run_aggregations<'a>(
    env: Env<'a>,
    searcher_res: ResourceArc<SearcherResource>,
    query_res: ResourceArc<QueryResource>,
    aggregations_json: String,
) -> NifResult<Term<'a>> {
    let aggregation_requests = match parse_aggregation_requests(&aggregations_json) {
        Ok(requests) => requests,
        Err(e) => return Ok(format!("Error parsing aggregations: {}", e).encode(env)),
    };

    let tantivy_aggregations =
        match build_tantivy_aggregations(&aggregation_requests, &searcher_res.searcher.schema()) {
            Ok(aggs) => aggs,
            Err(e) => return Ok(format!("Error building aggregations: {}", e).encode(env)),
        };

    let limits = AggregationLimitsGuard::new(
        Some(500_000_000), // 500MB default memory limit
        Some(65535),       // Default bucket limit
    );
    let collector = AggregationCollector::from_aggs(tantivy_aggregations, limits);

    match searcher_res.searcher.search(&query_res.query, &collector) {
        Ok(agg_result) => {
            let json_result =
                convert_aggregation_result_to_json(&agg_result, &aggregation_requests);
            match serde_json::to_string(&json_result) {
                Ok(json_str) => Ok(json_str.encode(env)),
                Err(e) => Ok(format!("Error serializing result: {}", e).encode(env)),
            }
        }
        Err(e) => Ok(format!("Error executing aggregations: {}", e).encode(env)),
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
pub fn run_search_with_aggregations<'a>(
    env: Env<'a>,
    searcher_res: ResourceArc<SearcherResource>,
    query_res: ResourceArc<QueryResource>,
    aggregations_json: String,
    search_limit: usize,
) -> NifResult<Term<'a>> {
    use tantivy::collector::{MultiCollector, TopDocs};

    let aggregation_requests = match parse_aggregation_requests(&aggregations_json) {
        Ok(requests) => requests,
        Err(e) => return Ok(format!("Error parsing aggregations: {}", e).encode(env)),
    };

    let tantivy_aggregations =
        match build_tantivy_aggregations(&aggregation_requests, &searcher_res.searcher.schema()) {
            Ok(aggs) => aggs,
            Err(e) => return Ok(format!("Error building aggregations: {}", e).encode(env)),
        };

    let limits = AggregationLimitsGuard::new(
        Some(500_000_000), // 500MB default memory limit
        Some(65535),       // Default bucket limit
    );
    let agg_collector = AggregationCollector::from_aggs(tantivy_aggregations, limits);
    let top_docs_collector = TopDocs::with_limit(search_limit);

    let mut multi_collector = MultiCollector::new();
    let agg_handle = multi_collector.add_collector(agg_collector);
    let top_docs_handle = multi_collector.add_collector(top_docs_collector);

    match searcher_res
        .searcher
        .search(&query_res.query, &multi_collector)
    {
        Ok(mut multi_fruit) => {
            let agg_result = agg_handle.extract(&mut multi_fruit);
            let top_docs = top_docs_handle.extract(&mut multi_fruit);
            // Convert search results to JSON
            let mut hits = Vec::new();
            for (_score, doc_address) in top_docs {
                match searcher_res
                    .searcher
                    .doc::<tantivy::TantivyDocument>(doc_address)
                {
                    Ok(doc) => {
                        let mut doc_map = serde_json::Map::new();
                        for (field, field_value) in doc.field_values() {
                            let field_name = searcher_res.searcher.schema().get_field_name(field);
                            let owned_value: OwnedValue = field_value.into();
                            let value = convert_owned_value_to_json(&owned_value);
                            doc_map.insert(field_name.to_string(), value);
                        }
                        hits.push(JsonValue::Object(doc_map));
                    }
                    Err(_) => continue,
                }
            }

            // Build combined result
            let agg_json = convert_aggregation_result_to_json(&agg_result, &aggregation_requests);
            let combined_result = json!({
                "hits": {
                    "total": {
                        "value": hits.len(),
                        "relation": "eq"
                    },
                    "hits": hits
                },
                "aggregations": agg_json
            });

            match serde_json::to_string(&combined_result) {
                Ok(json_str) => Ok(json_str.encode(env)),
                Err(e) => Ok(format!("Error serializing combined result: {}", e).encode(env)),
            }
        }
        Err(e) => Ok(format!("Error executing search with aggregations: {}", e).encode(env)),
    }
}

fn parse_aggregation_requests(
    json_str: &str,
) -> Result<HashMap<String, AggregationRequest>, String> {
    let json_value: JsonValue =
        serde_json::from_str(json_str).map_err(|e| format!("Invalid JSON: {}", e))?;

    let obj = json_value
        .as_object()
        .ok_or("Aggregations must be a JSON object")?;

    let mut requests = HashMap::new();

    for (name, agg_def) in obj {
        let request = parse_single_aggregation(name.clone(), agg_def)?;
        requests.insert(name.clone(), request);
    }

    Ok(requests)
}

fn parse_single_aggregation(
    name: String,
    agg_def: &JsonValue,
) -> Result<AggregationRequest, String> {
    let obj = agg_def
        .as_object()
        .ok_or("Aggregation definition must be an object")?;

    // Find the aggregation type
    let (agg_type_name, agg_config) = obj
        .iter()
        .find(|(k, _)| k != &"aggs" && k != &"aggregations")
        .ok_or("No aggregation type found")?;

    let aggregation_type = parse_aggregation_type(agg_type_name, agg_config)?;

    let field = agg_config
        .get("field")
        .and_then(|v| v.as_str())
        .ok_or("Field is required for aggregations")?
        .to_string();

    let options = parse_aggregation_options(agg_config)?;

    // Parse sub-aggregations
    let mut sub_aggregations = HashMap::new();
    if let Some(sub_aggs) = obj.get("aggs").or_else(|| obj.get("aggregations")) {
        if let Some(sub_obj) = sub_aggs.as_object() {
            for (sub_name, sub_def) in sub_obj {
                let sub_request = parse_single_aggregation(sub_name.clone(), sub_def)?;
                sub_aggregations.insert(sub_name.clone(), sub_request);
            }
        }
    }

    Ok(AggregationRequest {
        name,
        aggregation_type,
        field,
        sub_aggregations,
        options,
    })
}

fn parse_aggregation_type(type_name: &str, config: &JsonValue) -> Result<AggregationType, String> {
    match type_name {
        "terms" => {
            let size = config
                .get("size")
                .and_then(|v| v.as_u64())
                .map(|v| v as usize);
            Ok(AggregationType::Terms { size })
        }
        "histogram" => {
            let interval = config
                .get("interval")
                .and_then(|v| v.as_f64())
                .ok_or("Histogram requires interval")?;
            Ok(AggregationType::Histogram { interval })
        }
        "date_histogram" => {
            let interval = config
                .get("calendar_interval")
                .or_else(|| config.get("fixed_interval"))
                .and_then(|v| v.as_str())
                .ok_or("Date histogram requires interval")?
                .to_string();
            Ok(AggregationType::DateHistogram { interval })
        }
        "range" => {
            let ranges_json = config
                .get("ranges")
                .ok_or("Range aggregation requires ranges")?;
            let ranges_array = ranges_json.as_array().ok_or("Ranges must be an array")?;

            let mut ranges = Vec::new();
            for range_def in ranges_array {
                let range_obj = range_def
                    .as_object()
                    .ok_or("Each range must be an object")?;

                let from = range_obj.get("from").and_then(|v| v.as_f64());
                let to = range_obj.get("to").and_then(|v| v.as_f64());
                let key = range_obj
                    .get("key")
                    .and_then(|v| v.as_str())
                    .map(|s| s.to_string());

                ranges.push(RangeSpec { from, to, key });
            }

            Ok(AggregationType::Range { ranges })
        }
        "avg" => Ok(AggregationType::Avg),
        "min" => Ok(AggregationType::Min),
        "max" => Ok(AggregationType::Max),
        "sum" => Ok(AggregationType::Sum),
        "count" => Ok(AggregationType::Count),
        "stats" => Ok(AggregationType::Stats),
        "percentiles" => {
            let percents = config
                .get("percents")
                .and_then(|v| v.as_array())
                .map(|arr| arr.iter().filter_map(|v| v.as_f64()).collect())
                .unwrap_or_else(|| vec![1.0, 5.0, 25.0, 50.0, 75.0, 95.0, 99.0]);
            Ok(AggregationType::Percentiles { percents })
        }
        _ => Err(format!("Unknown aggregation type: {}", type_name)),
    }
}

fn parse_aggregation_options(config: &JsonValue) -> Result<AggregationOptions, String> {
    let mut options = AggregationOptions::default();

    if let Some(min_doc_count) = config.get("min_doc_count").and_then(|v| v.as_u64()) {
        options.min_doc_count = Some(min_doc_count);
    }

    if let Some(missing) = config.get("missing").and_then(|v| v.as_str()) {
        options.missing = Some(missing.to_string());
    }

    if let Some(keyed) = config.get("keyed").and_then(|v| v.as_bool()) {
        options.keyed = Some(keyed);
    }

    Ok(options)
}

fn build_tantivy_aggregations(
    requests: &HashMap<String, AggregationRequest>,
    schema: &Schema,
) -> Result<Aggregations, String> {
    let mut aggregations = HashMap::new();

    for (name, request) in requests {
        let tantivy_agg = build_single_tantivy_aggregation(request, schema)?;
        aggregations.insert(name.clone(), tantivy_agg);
    }

    Ok(Aggregations::from(aggregations))
}

fn build_single_tantivy_aggregation(
    request: &AggregationRequest,
    schema: &Schema,
) -> Result<Aggregation, String> {
    let _field = schema
        .get_field(&request.field)
        .map_err(|_| format!("Field '{}' not found in schema", request.field))?;

    let field_name = request.field.clone();
    let sub_aggregations = build_sub_aggregations(&request.sub_aggregations, schema)?;

    let aggregation_variant = match &request.aggregation_type {
        AggregationType::Terms { size } => {
            let terms_agg = TermsAggregation {
                field: field_name,
                size: Some(size.unwrap_or(10) as u32),
                segment_size: None,
                min_doc_count: Some(request.options.min_doc_count.unwrap_or(1)),
                order: None,
                missing: None, // Convert to Key if needed
                show_term_doc_count_error: Some(false),
            };
            AggregationVariants::Terms(terms_agg)
        }
        AggregationType::Histogram { interval } => {
            let histogram_agg = HistogramAggregation {
                field: field_name,
                interval: *interval,
                offset: None,
                min_doc_count: Some(request.options.min_doc_count.unwrap_or(1)),
                extended_bounds: None,
                hard_bounds: None,
                keyed: request.options.keyed.unwrap_or(false),
                is_normalized_to_ns: false,
            };
            AggregationVariants::Histogram(histogram_agg)
        }
        AggregationType::DateHistogram { interval } => {
            let date_histogram_agg = DateHistogramAggregationReq {
                field: field_name,
                fixed_interval: Some(interval.clone()),
                interval: None,
                calendar_interval: None,
                offset: None,
                min_doc_count: Some(request.options.min_doc_count.unwrap_or(1)),
                extended_bounds: None,
                hard_bounds: None,
                keyed: request.options.keyed.unwrap_or(false),
                format: None,
            };
            AggregationVariants::DateHistogram(date_histogram_agg)
        }
        AggregationType::Range { ranges } => {
            let tantivy_ranges: Vec<_> = ranges
                .iter()
                .map(|r| RangeAggregationRange {
                    from: r.from,
                    to: r.to,
                    key: r.key.clone(),
                })
                .collect();

            let range_agg = RangeAggregation {
                field: field_name,
                ranges: tantivy_ranges,
                keyed: request.options.keyed.unwrap_or(false),
            };
            AggregationVariants::Range(range_agg)
        }
        AggregationType::Avg => {
            let avg_agg = AverageAggregation {
                field: field_name,
                missing: None,
            };
            AggregationVariants::Average(avg_agg)
        }
        AggregationType::Min => {
            let min_agg = MinAggregation {
                field: field_name,
                missing: None,
            };
            AggregationVariants::Min(min_agg)
        }
        AggregationType::Max => {
            let max_agg = MaxAggregation {
                field: field_name,
                missing: None,
            };
            AggregationVariants::Max(max_agg)
        }
        AggregationType::Sum => {
            let sum_agg = SumAggregation {
                field: field_name,
                missing: None,
            };
            AggregationVariants::Sum(sum_agg)
        }
        AggregationType::Count => {
            let count_agg = CountAggregation {
                field: field_name,
                missing: None,
            };
            AggregationVariants::Count(count_agg)
        }
        AggregationType::Stats => {
            let stats_agg = StatsAggregation {
                field: field_name,
                missing: None,
            };
            AggregationVariants::Stats(stats_agg)
        }
        AggregationType::Percentiles { percents } => {
            let percentiles_agg = PercentilesAggregationReq {
                field: field_name,
                percents: Some(percents.clone()),
                keyed: request.options.keyed.unwrap_or(true),
                missing: None,
            };
            AggregationVariants::Percentiles(percentiles_agg)
        }
    };

    Ok(Aggregation {
        agg: aggregation_variant,
        sub_aggregation: sub_aggregations,
    })
}

fn build_sub_aggregations(
    sub_requests: &HashMap<String, AggregationRequest>,
    schema: &Schema,
) -> Result<Aggregations, String> {
    let mut sub_aggregations = HashMap::new();

    for (name, request) in sub_requests {
        let tantivy_agg = build_single_tantivy_aggregation(request, schema)?;
        sub_aggregations.insert(name.clone(), tantivy_agg);
    }

    Ok(Aggregations::from(sub_aggregations))
}

fn convert_aggregation_result_to_json(
    result: &AggregationResults,
    requests: &HashMap<String, AggregationRequest>,
) -> JsonValue {
    let mut json_obj = Map::new();

    for (name, agg_result) in &result.0 {
        if let Some(request) = requests.get(name) {
            let json_value = convert_agg_result_to_json(agg_result, request);
            json_obj.insert(name.clone(), json_value);
        }
    }

    JsonValue::Object(json_obj)
}

fn convert_agg_result_to_json(
    result: &tantivy::aggregation::agg_result::AggregationResult,
    request: &AggregationRequest,
) -> JsonValue {
    use tantivy::aggregation::agg_result::AggregationResult;

    match result {
        AggregationResult::BucketResult(bucket_result) => {
            convert_bucket_result_to_json(bucket_result, request)
        }
        AggregationResult::MetricResult(metric_result) => {
            convert_metric_result_to_json(metric_result, request)
        }
    }
}

fn convert_bucket_result_to_json(
    result: &tantivy::aggregation::agg_result::BucketResult,
    request: &AggregationRequest,
) -> JsonValue {
    use tantivy::aggregation::agg_result::{BucketEntries, BucketResult};

    match result {
        BucketResult::Terms {
            buckets,
            sum_other_doc_count,
            doc_count_error_upper_bound,
        } => {
            let buckets_json: Vec<JsonValue> = buckets
                .iter()
                .map(|bucket| {
                    let mut bucket_obj = Map::new();
                    bucket_obj.insert("key".to_string(), convert_key_to_json(&bucket.key));
                    bucket_obj.insert("doc_count".to_string(), json!(bucket.doc_count));

                    // Add sub-aggregations
                    if !bucket.sub_aggregation.0.is_empty() {
                        let sub_aggs = convert_aggregation_result_to_json(
                            &bucket.sub_aggregation,
                            &request.sub_aggregations,
                        );
                        for (sub_name, sub_value) in sub_aggs.as_object().unwrap() {
                            bucket_obj.insert(sub_name.clone(), sub_value.clone());
                        }
                    }

                    JsonValue::Object(bucket_obj)
                })
                .collect();
            json!({
                "doc_count_error_upper_bound": doc_count_error_upper_bound,
                "sum_other_doc_count": sum_other_doc_count,
                "buckets": buckets_json
            })
        }
        BucketResult::Histogram { buckets } => {
            let bucket_iter: Box<dyn Iterator<Item = _>> = match buckets {
                BucketEntries::Vec(vec) => Box::new(vec.iter()),
                BucketEntries::HashMap(map) => Box::new(map.values()),
            };
            let buckets_json: Vec<JsonValue> = bucket_iter
                .map(|bucket| {
                    let mut bucket_obj = Map::new();
                    bucket_obj.insert("key".to_string(), convert_key_to_json(&bucket.key));
                    bucket_obj.insert("doc_count".to_string(), json!(bucket.doc_count));

                    // Add sub-aggregations
                    if !bucket.sub_aggregation.0.is_empty() {
                        let sub_aggs = convert_aggregation_result_to_json(
                            &bucket.sub_aggregation,
                            &request.sub_aggregations,
                        );
                        for (sub_name, sub_value) in sub_aggs.as_object().unwrap() {
                            bucket_obj.insert(sub_name.clone(), sub_value.clone());
                        }
                    }

                    JsonValue::Object(bucket_obj)
                })
                .collect();

            json!({ "buckets": buckets_json })
        }
        BucketResult::Range { buckets } => {
            let bucket_iter: Box<dyn Iterator<Item = _>> = match buckets {
                BucketEntries::Vec(vec) => Box::new(vec.iter()),
                BucketEntries::HashMap(map) => Box::new(map.values()),
            };
            let buckets_json: Vec<JsonValue> = bucket_iter
                .map(|bucket| {
                    let mut bucket_obj = Map::new();

                    if let Some(from) = bucket.from {
                        bucket_obj.insert("from".to_string(), json!(from));
                    }
                    if let Some(to) = bucket.to {
                        bucket_obj.insert("to".to_string(), json!(to));
                    }
                    bucket_obj.insert("key".to_string(), json!(bucket.key));

                    bucket_obj.insert("doc_count".to_string(), json!(bucket.doc_count));
                    // Add sub-aggregations
                    if !bucket.sub_aggregation.0.is_empty() {
                        let sub_aggs = convert_aggregation_result_to_json(
                            &bucket.sub_aggregation,
                            &request.sub_aggregations,
                        );
                        for (sub_name, sub_value) in sub_aggs.as_object().unwrap() {
                            bucket_obj.insert(sub_name.clone(), sub_value.clone());
                        }
                    }

                    JsonValue::Object(bucket_obj)
                })
                .collect();

            json!({ "buckets": buckets_json })
        }
    }
}

fn convert_metric_result_to_json(
    result: &tantivy::aggregation::agg_result::MetricResult,
    _request: &AggregationRequest,
) -> JsonValue {
    use tantivy::aggregation::agg_result::MetricResult;

    match result {
        MetricResult::Average(avg_result) => {
            json!({ "value": avg_result.value })
        }
        MetricResult::Count(count_result) => {
            json!({ "value": count_result.value })
        }
        MetricResult::Max(max_result) => {
            json!({ "value": max_result.value })
        }
        MetricResult::Min(min_result) => {
            json!({ "value": min_result.value })
        }
        MetricResult::Sum(sum_result) => {
            json!({ "value": sum_result.value })
        }
        MetricResult::Stats(stats_result) => {
            json!({
                "count": stats_result.count,
                "min": stats_result.min,
                "max": stats_result.max,
                "avg": stats_result.avg,
                "sum": stats_result.sum
            })
        }
        MetricResult::Percentiles(percentiles_result) => {
            let mut values = Map::new();
            match &percentiles_result.values {
                PercentileValues::HashMap(hash_map) => {
                    for (percentile, value) in hash_map {
                        values.insert(percentile.clone(), json!(value));
                    }
                }
                PercentileValues::Vec(vec_entries) => {
                    for entry in vec_entries {
                        // Since PercentileValuesVecEntry fields are private, we serialize it to JSON
                        // to extract the key and value
                        if let Ok(entry_json) = serde_json::to_value(entry) {
                            if let (Some(key), Some(value)) =
                                (entry_json.get("key"), entry_json.get("value"))
                            {
                                if let (Some(key_f64), Some(value_f64)) =
                                    (key.as_f64(), value.as_f64())
                                {
                                    values.insert(key_f64.to_string(), json!(value_f64));
                                }
                            }
                        }
                    }
                }
            }
            json!({ "values": values })
        }
        MetricResult::ExtendedStats(_) => {
            json!({ "error": "ExtendedStats not implemented yet" })
        }
        MetricResult::TopHits(_) => {
            json!({ "error": "TopHits not implemented yet" })
        }
        MetricResult::Cardinality(_) => {
            json!({ "error": "Cardinality not implemented yet" })
        }
    }
}

fn convert_key_to_json(key: &Key) -> JsonValue {
    match key {
        Key::Str(s) => json!(s),
        Key::F64(f) => json!(f),
        Key::I64(i) => json!(i),
        Key::U64(u) => json!(u),
    }
}

fn convert_owned_value_to_json(value: &tantivy::schema::OwnedValue) -> JsonValue {
    match value {
        tantivy::schema::OwnedValue::Str(s) => json!(s),
        tantivy::schema::OwnedValue::U64(u) => json!(u),
        tantivy::schema::OwnedValue::I64(i) => json!(i),
        tantivy::schema::OwnedValue::F64(f) => json!(f),
        tantivy::schema::OwnedValue::Bool(b) => json!(b),
        tantivy::schema::OwnedValue::Date(date) => {
            json!(date.into_timestamp_nanos())
        }
        tantivy::schema::OwnedValue::Facet(facet) => json!(facet.to_string()),
        tantivy::schema::OwnedValue::Bytes(bytes) => {
            // Encode bytes as base64
            use base64::{engine::general_purpose, Engine as _};
            json!(general_purpose::STANDARD.encode(bytes))
        }
        tantivy::schema::OwnedValue::PreTokStr(pre_tok_str) => json!(pre_tok_str.text),
        tantivy::schema::OwnedValue::IpAddr(ip) => json!(ip.to_string()),
        tantivy::schema::OwnedValue::Null => json!(null),
        tantivy::schema::OwnedValue::Array(array) => {
            let json_array: Vec<JsonValue> =
                array.iter().map(convert_owned_value_to_json).collect();
            json!(json_array)
        }
        tantivy::schema::OwnedValue::Object(obj) => {
            let mut json_obj = Map::new();
            for (key, value) in obj {
                json_obj.insert(key.clone(), convert_owned_value_to_json(value));
            }
            json!(json_obj)
        }
    }
}
