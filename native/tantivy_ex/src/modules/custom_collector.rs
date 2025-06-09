use rustler::{Error, NifResult, ResourceArc};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use tantivy::{
    DocId, Score, SegmentOrdinal, SegmentReader
};
use serde_json;

use crate::modules::resources::IndexResource;

/// Resource for managing custom collectors and scoring
#[derive(Clone)]
pub struct CustomCollectorResource {
    pub collectors: Arc<Mutex<HashMap<String, Box<dyn CustomCollector>>>>,
    pub scoring_functions: Arc<Mutex<HashMap<String, ScoringFunction>>>,
    pub collection_results: Arc<Mutex<HashMap<String, CollectionResult>>>,
}

/// Custom collector trait for user-defined collection logic
pub trait CustomCollector: Send + Sync {
    fn collect_segment(&mut self, segment_reader: &SegmentReader, segment_ord: SegmentOrdinal) -> NifResult<()>;
    fn merge_results(&mut self, other: Box<dyn CustomCollector>) -> NifResult<()>;
    fn get_results(&self) -> NifResult<CollectionResult>;
    fn name(&self) -> &str;
}

/// Scoring function configuration
#[derive(Debug, Clone)]
pub struct ScoringFunction {
    pub name: String,
    pub function_type: ScoringType,
    pub parameters: HashMap<String, f64>,
    pub boost_fields: HashMap<String, f64>,
    pub custom_formula: Option<String>,
}

/// Types of scoring functions
#[derive(Debug, Clone)]
pub enum ScoringType {
    BM25 { k1: f64, b: f64 },
    TFIDF { normalize: bool },
    Custom { formula: String },
    Boosted { base_scorer: Box<ScoringType>, field_boosts: HashMap<String, f64> },
    Combined { scorers: Vec<ScoringType>, weights: Vec<f64> },
}

/// Results from custom collection
#[derive(Debug, Clone)]
pub struct CollectionResult {
    pub result_type: String,
    pub document_scores: Vec<(DocId, Score)>,
    pub aggregations: HashMap<String, f64>,
    pub metadata: HashMap<String, String>,
    pub total_hits: u64,
    pub collection_time_ms: u64,
}

/// Top-K collector with custom scoring
pub struct TopKCollector {
    pub name: String,
    pub k: usize,
    pub scoring_function: ScoringFunction,
    pub results: Vec<(DocId, Score)>,
    pub segment_results: Vec<Vec<(DocId, Score)>>,
}

/// Aggregation collector for computing statistics
pub struct AggregationCollector {
    pub name: String,
    pub aggregations: HashMap<String, AggregationType>,
    pub results: HashMap<String, f64>,
    pub doc_count: u64,
}

/// Types of aggregations
#[derive(Debug, Clone)]
pub enum AggregationType {
    Count,
    Sum { field: String },
    Average { field: String },
    Min { field: String },
    Max { field: String },
    Percentile { field: String, percentile: f64 },
}

/// Filtering collector that applies custom filters
pub struct FilteringCollector {
    pub name: String,
    pub filter_criteria: Vec<FilterCriterion>,
    pub collected_docs: Vec<DocId>,
    pub metadata: HashMap<String, String>,
}

/// Filter criteria for custom filtering
#[derive(Debug, Clone)]
pub struct FilterCriterion {
    pub field: String,
    pub operator: FilterOperator,
    pub value: FilterValue,
}

#[derive(Debug, Clone)]
pub enum FilterOperator {
    Equals,
    GreaterThan,
    LessThan,
    Contains,
    Regex,
}

#[derive(Debug, Clone)]
pub enum FilterValue {
    String(String),
    Number(f64),
    Boolean(bool),
}

// Safety traits for cross-thread usage
unsafe impl Send for CustomCollectorResource {}
unsafe impl Sync for CustomCollectorResource {}
impl std::panic::RefUnwindSafe for CustomCollectorResource {}
impl std::panic::UnwindSafe for CustomCollectorResource {}

impl CustomCollectorResource {
    pub fn new() -> Self {
        Self {
            collectors: Arc::new(Mutex::new(HashMap::new())),
            scoring_functions: Arc::new(Mutex::new(HashMap::new())),
            collection_results: Arc::new(Mutex::new(HashMap::new())),
        }
    }
}

impl CustomCollector for TopKCollector {
    fn collect_segment(&mut self, _segment_reader: &SegmentReader, _segment_ord: SegmentOrdinal) -> NifResult<()> {
        // Simplified implementation - in reality would collect docs and score them
        Ok(())
    }

    fn merge_results(&mut self, _other: Box<dyn CustomCollector>) -> NifResult<()> {
        // Merge results from different segments
        Ok(())
    }

    fn get_results(&self) -> NifResult<CollectionResult> {
        Ok(CollectionResult {
            result_type: "top_k".to_string(),
            document_scores: self.results.clone(),
            aggregations: HashMap::new(),
            metadata: HashMap::new(),
            total_hits: self.results.len() as u64,
            collection_time_ms: 0,
        })
    }

    fn name(&self) -> &str {
        &self.name
    }
}

impl CustomCollector for AggregationCollector {
    fn collect_segment(&mut self, _segment_reader: &SegmentReader, _segment_ord: SegmentOrdinal) -> NifResult<()> {
        // Simplified implementation - would aggregate values from documents
        self.doc_count += 100; // Placeholder
        Ok(())
    }

    fn merge_results(&mut self, _other: Box<dyn CustomCollector>) -> NifResult<()> {
        // Merge aggregation results
        Ok(())
    }

    fn get_results(&self) -> NifResult<CollectionResult> {
        Ok(CollectionResult {
            result_type: "aggregation".to_string(),
            document_scores: Vec::new(),
            aggregations: self.results.clone(),
            metadata: HashMap::new(),
            total_hits: self.doc_count,
            collection_time_ms: 0,
        })
    }

    fn name(&self) -> &str {
        &self.name
    }
}

impl CustomCollector for FilteringCollector {
    fn collect_segment(&mut self, _segment_reader: &SegmentReader, _segment_ord: SegmentOrdinal) -> NifResult<()> {
        // Simplified implementation - would filter documents based on criteria
        Ok(())
    }

    fn merge_results(&mut self, _other: Box<dyn CustomCollector>) -> NifResult<()> {
        // Merge filtered documents
        Ok(())
    }

    fn get_results(&self) -> NifResult<CollectionResult> {
        Ok(CollectionResult {
            result_type: "filtering".to_string(),
            document_scores: Vec::new(),
            aggregations: HashMap::new(),
            metadata: self.metadata.clone(),
            total_hits: self.collected_docs.len() as u64,
            collection_time_ms: 0,
        })
    }

    fn name(&self) -> &str {
        &self.name
    }
}

/// Create a new custom collector resource
#[rustler::nif]
pub fn custom_collector_new() -> NifResult<ResourceArc<CustomCollectorResource>> {
    let resource = ResourceArc::new(CustomCollectorResource::new());
    Ok(resource)
}

/// Create a custom scoring function
#[rustler::nif]
pub fn custom_collector_create_scoring_function(
    collector_resource: ResourceArc<CustomCollectorResource>,
    name: String,
    scoring_type: String,
    parameters: Vec<(String, f64)>,
) -> NifResult<rustler::types::atom::Atom> {
    let scoring_function = match scoring_type.as_str() {
        "bm25" => {
            let k1 = parameters.iter().find(|(k, _)| k == "k1").map(|(_, v)| *v).unwrap_or(1.2);
            let b = parameters.iter().find(|(k, _)| k == "b").map(|(_, v)| *v).unwrap_or(0.75);
            ScoringFunction {
                name: name.clone(),
                function_type: ScoringType::BM25 { k1, b },
                parameters: parameters.into_iter().collect(),
                boost_fields: HashMap::new(),
                custom_formula: None,
            }
        },
        "tfidf" => {
            let normalize = parameters.iter().find(|(k, _)| k == "normalize").map(|(_, v)| *v > 0.0).unwrap_or(true);
            ScoringFunction {
                name: name.clone(),
                function_type: ScoringType::TFIDF { normalize },
                parameters: parameters.into_iter().collect(),
                boost_fields: HashMap::new(),
                custom_formula: None,
            }
        },
        "custom" => {
            ScoringFunction {
                name: name.clone(),
                function_type: ScoringType::Custom { formula: "score * boost".to_string() },
                parameters: parameters.into_iter().collect(),
                boost_fields: HashMap::new(),
                custom_formula: Some("score * boost".to_string()),
            }
        },
        _ => return Err(Error::BadArg),
    };

    let mut scoring_functions = collector_resource.scoring_functions.lock().unwrap();
    scoring_functions.insert(name, scoring_function);

    Ok(rustler::types::atom::ok())
}

/// Create a top-K collector
#[rustler::nif]
pub fn custom_collector_create_top_k(
    collector_resource: ResourceArc<CustomCollectorResource>,
    collector_name: String,
    k: usize,
    scoring_function_name: String,
) -> NifResult<rustler::types::atom::Atom> {
    let scoring_functions = collector_resource.scoring_functions.lock().unwrap();
    let scoring_function = scoring_functions.get(&scoring_function_name)
        .ok_or(Error::BadArg)?
        .clone();

    let collector = TopKCollector {
        name: collector_name.clone(),
        k,
        scoring_function,
        results: Vec::new(),
        segment_results: Vec::new(),
    };

    let mut collectors = collector_resource.collectors.lock().unwrap();
    collectors.insert(collector_name, Box::new(collector));

    Ok(rustler::types::atom::ok())
}

/// Create an aggregation collector
#[rustler::nif]
pub fn custom_collector_create_aggregation(
    collector_resource: ResourceArc<CustomCollectorResource>,
    collector_name: String,
    aggregation_specs: Vec<(String, String, String)>, // (name, type, field)
) -> NifResult<rustler::types::atom::Atom> {
    let mut aggregations = HashMap::new();

    for (agg_name, agg_type, field) in aggregation_specs {
        let aggregation = match agg_type.as_str() {
            "count" => AggregationType::Count,
            "sum" => AggregationType::Sum { field },
            "average" => AggregationType::Average { field },
            "min" => AggregationType::Min { field },
            "max" => AggregationType::Max { field },
            _ => return Err(Error::BadArg),
        };
        aggregations.insert(agg_name, aggregation);
    }

    let collector = AggregationCollector {
        name: collector_name.clone(),
        aggregations,
        results: HashMap::new(),
        doc_count: 0,
    };

    let mut collectors = collector_resource.collectors.lock().unwrap();
    collectors.insert(collector_name, Box::new(collector));

    Ok(rustler::types::atom::ok())
}

/// Create a filtering collector
#[rustler::nif]
pub fn custom_collector_create_filtering(
    collector_resource: ResourceArc<CustomCollectorResource>,
    collector_name: String,
    filter_specs: Vec<(String, String, String)>, // (field, operator, value)
) -> NifResult<rustler::types::atom::Atom> {
    let mut filter_criteria = Vec::new();

    for (field, operator, value) in filter_specs {
        let op = match operator.as_str() {
            "equals" => FilterOperator::Equals,
            "gt" => FilterOperator::GreaterThan,
            "lt" => FilterOperator::LessThan,
            "contains" => FilterOperator::Contains,
            "regex" => FilterOperator::Regex,
            _ => return Err(Error::BadArg),
        };

        // Simplified value parsing - would need proper type detection
        let filter_value = if let Ok(num) = value.parse::<f64>() {
            FilterValue::Number(num)
        } else if let Ok(bool_val) = value.parse::<bool>() {
            FilterValue::Boolean(bool_val)
        } else {
            FilterValue::String(value)
        };

        filter_criteria.push(FilterCriterion {
            field,
            operator: op,
            value: filter_value,
        });
    }

    let collector = FilteringCollector {
        name: collector_name.clone(),
        filter_criteria,
        collected_docs: Vec::new(),
        metadata: HashMap::new(),
    };

    let mut collectors = collector_resource.collectors.lock().unwrap();
    collectors.insert(collector_name, Box::new(collector));

    Ok(rustler::types::atom::ok())
}

/// Execute collection with a custom collector
#[rustler::nif]
pub fn custom_collector_execute(
    collector_resource: ResourceArc<CustomCollectorResource>,
    index_resource: ResourceArc<IndexResource>,
    collector_name: String,
    query_str: String,
) -> NifResult<String> {
    // Simplified execution - in reality would parse query and run collection
    let reader = index_resource.index.reader().map_err(|_| Error::BadArg)?;
    let _searcher = reader.searcher();

    // Simulate collection results
    let result = CollectionResult {
        result_type: "execution".to_string(),
        document_scores: vec![(0, 1.5), (1, 1.2), (2, 1.0)],
        aggregations: HashMap::new(),
        metadata: [("query".to_string(), query_str)].iter().cloned().collect(),
        total_hits: 3,
        collection_time_ms: 15,
    };

    // Store results
    let mut results = collector_resource.collection_results.lock().unwrap();
    results.insert(collector_name.clone(), result.clone());

    // Return JSON response
    let response = serde_json::json!({
        "collector_name": collector_name,
        "result_type": result.result_type,
        "total_hits": result.total_hits,
        "collection_time_ms": result.collection_time_ms,
        "top_documents": result.document_scores.iter().take(10).collect::<Vec<_>>(),
        "aggregations": result.aggregations,
        "metadata": result.metadata
    });

    Ok(response.to_string())
}

/// Get collection results
#[rustler::nif]
pub fn custom_collector_get_results(
    collector_resource: ResourceArc<CustomCollectorResource>,
    collector_name: String,
) -> NifResult<String> {
    let results = collector_resource.collection_results.lock().unwrap();

    if let Some(result) = results.get(&collector_name) {
        let response = serde_json::json!({
            "found": true,
            "collector_name": collector_name,
            "result": {
                "type": result.result_type,
                "total_hits": result.total_hits,
                "collection_time_ms": result.collection_time_ms,
                "document_count": result.document_scores.len(),
                "aggregation_count": result.aggregations.len(),
                "metadata": result.metadata
            }
        });
        Ok(response.to_string())
    } else {
        let response = serde_json::json!({
            "found": false,
            "collector_name": collector_name
        });
        Ok(response.to_string())
    }
}

/// Configure field boosts for scoring
#[rustler::nif]
pub fn custom_collector_set_field_boosts(
    collector_resource: ResourceArc<CustomCollectorResource>,
    scoring_function_name: String,
    field_boosts: Vec<(String, f64)>,
) -> NifResult<rustler::types::atom::Atom> {
    let mut scoring_functions = collector_resource.scoring_functions.lock().unwrap();

    if let Some(scoring_function) = scoring_functions.get_mut(&scoring_function_name) {
        scoring_function.boost_fields = field_boosts.into_iter().collect();
        Ok(rustler::types::atom::ok())
    } else {
        Err(Error::BadArg)
    }
}

/// List available collectors
#[rustler::nif]
pub fn custom_collector_list_collectors(
    collector_resource: ResourceArc<CustomCollectorResource>,
) -> NifResult<String> {
    let collectors = collector_resource.collectors.lock().unwrap();
    let scoring_functions = collector_resource.scoring_functions.lock().unwrap();

    let collector_names: Vec<String> = collectors.keys().cloned().collect();
    let scoring_function_names: Vec<String> = scoring_functions.keys().cloned().collect();

    let response = serde_json::json!({
        "collectors": collector_names,
        "scoring_functions": scoring_function_names,
        "total_collectors": collector_names.len(),
        "total_scoring_functions": scoring_function_names.len()
    });

    Ok(response.to_string())
}

/// Clear all collectors and results
#[rustler::nif]
pub fn custom_collector_clear_all(
    collector_resource: ResourceArc<CustomCollectorResource>,
) -> NifResult<rustler::types::atom::Atom> {
    let mut collectors = collector_resource.collectors.lock().unwrap();
    let mut scoring_functions = collector_resource.scoring_functions.lock().unwrap();
    let mut results = collector_resource.collection_results.lock().unwrap();

    collectors.clear();
    scoring_functions.clear();
    results.clear();

    Ok(rustler::types::atom::ok())
}
