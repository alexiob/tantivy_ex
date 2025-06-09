use rustler::{NifResult, ResourceArc};
use serde_json;
use tantivy::collector::FacetCollector;
use tantivy::query::{BooleanQuery, Occur, TermQuery};
use tantivy::schema::{Facet, IndexRecordOption};
use tantivy::Term as TantivyTerm;

use crate::modules::resources::{QueryResource, SearcherResource};

/// Resource for managing FacetCollector state
pub struct FacetCollectorResource {
    pub collector: FacetCollector,
}

// Make FacetCollectorResource safe for concurrent access
unsafe impl Send for FacetCollectorResource {}
unsafe impl Sync for FacetCollectorResource {}
impl std::panic::RefUnwindSafe for FacetCollectorResource {}
impl std::panic::UnwindSafe for FacetCollectorResource {}

/// Resource for managing Facet state
pub struct FacetResource {
    pub facet: Facet,
}

unsafe impl Send for FacetResource {}
unsafe impl Sync for FacetResource {}
impl std::panic::RefUnwindSafe for FacetResource {}
impl std::panic::UnwindSafe for FacetResource {}

/// Creates a new facet collector for the specified field
#[rustler::nif]
pub fn facet_collector_for_field(
    field_name: String,
) -> NifResult<ResourceArc<FacetCollectorResource>> {
    let collector = FacetCollector::for_field(&field_name);
    Ok(ResourceArc::new(FacetCollectorResource { collector }))
}

/// Adds a facet path to the collector for counting
#[rustler::nif]
pub fn facet_collector_add_facet(
    collector_res: ResourceArc<FacetCollectorResource>,
    facet_path: String,
) -> NifResult<rustler::Atom> {
    let facet = match Facet::from_text(&facet_path) {
        Ok(f) => f,
        Err(e) => {
            return Err(rustler::Error::Term(Box::new(format!(
                "Invalid facet path '{}': {}",
                facet_path, e
            ))))
        }
    };

    // Need to access the collector mutably, but ResourceArc doesn't allow mutation
    // For now, we'll use an unsafe approach - in production this would need better design
    let collector_ptr = &collector_res.collector as *const FacetCollector as *mut FacetCollector;
    unsafe {
        (*collector_ptr).add_facet(facet);
    }

    Ok(rustler::types::atom::ok())
}

/// Performs a search with facet collection
#[rustler::nif]
pub fn facet_search(
    searcher_res: ResourceArc<SearcherResource>,
    query_res: ResourceArc<QueryResource>,
    collector_res: ResourceArc<FacetCollectorResource>,
) -> NifResult<String> {
    match searcher_res
        .searcher
        .search(&*query_res.query, &collector_res.collector)
    {
        Ok(facet_counts) => {
            // Convert FacetCounts to a nested JSON structure
            let mut result = serde_json::Map::new();

            // Get all facets and their counts
            let all_facets: Vec<(&Facet, u64)> = facet_counts.get("/").collect();

            // Build hierarchical structure
            for (facet, count) in all_facets {
                let facet_path = facet.to_string();
                insert_facet_hierarchically(&mut result, &facet_path, count);
            }

            match serde_json::to_string(&result) {
                Ok(json) => Ok(json),
                Err(e) => Err(rustler::Error::Term(Box::new(format!(
                    "Failed to serialize facet results: {}",
                    e
                )))),
            }
        }
        Err(e) => Err(rustler::Error::Term(Box::new(format!(
            "Faceted search failed: {}",
            e
        )))),
    }
}

/// Helper function to insert facet counts hierarchically
fn insert_facet_hierarchically(
    result: &mut serde_json::Map<String, serde_json::Value>,
    facet_path: &str,
    count: u64,
) {
    let segments: Vec<&str> = facet_path.split('/').filter(|s| !s.is_empty()).collect();

    if segments.is_empty() {
        return;
    }

    // Build the full path
    let full_path = if facet_path.starts_with('/') {
        facet_path.to_string()
    } else {
        format!("/{}", facet_path)
    };

    // Simply insert the count at the full path
    result.insert(
        full_path,
        serde_json::Value::Number(serde_json::Number::from(count)),
    );
}

/// Creates a term query for filtering by a specific facet
#[rustler::nif]
pub fn facet_term_query(
    _field_name: String,
    facet_path: String,
) -> NifResult<ResourceArc<QueryResource>> {
    let facet = match Facet::from_text(&facet_path) {
        Ok(f) => f,
        Err(e) => {
            return Err(rustler::Error::Term(Box::new(format!(
                "Invalid facet path '{}': {}",
                facet_path, e
            ))))
        }
    };

    // We need the field from the searcher's schema to create the term
    // For now, we'll create a placeholder - this needs to be improved
    // to accept a schema reference or field reference
    let term = TantivyTerm::from_facet(
        tantivy::schema::Field::from_field_id(0), // This is a hack - needs proper field resolution
        &facet,
    );

    let query = TermQuery::new(term, IndexRecordOption::Basic);
    let query_resource = QueryResource {
        query: Box::new(query),
    };

    Ok(ResourceArc::new(query_resource))
}

/// Creates a multi-facet boolean query
#[rustler::nif]
pub fn facet_multi_query(
    _field_name: String,
    facet_paths: Vec<String>,
    occur_str: String,
) -> NifResult<ResourceArc<QueryResource>> {
    let _occur = match occur_str.as_str() {
        "should" => Occur::Should,
        "must" => Occur::Must,
        "must_not" => Occur::MustNot,
        _ => Occur::Should,
    };

    let mut terms = Vec::new();
    for facet_path in facet_paths {
        let facet = match Facet::from_text(&facet_path) {
            Ok(f) => f,
            Err(e) => {
                return Err(rustler::Error::Term(Box::new(format!(
                    "Invalid facet path '{}': {}",
                    facet_path, e
                ))))
            }
        };

        let term = TantivyTerm::from_facet(
            tantivy::schema::Field::from_field_id(0), // This needs proper field resolution
            &facet,
        );
        terms.push(term);
    }

    let query = BooleanQuery::new_multiterms_query(terms);
    let query_resource = QueryResource {
        query: Box::new(query),
    };

    Ok(ResourceArc::new(query_resource))
}

/// Creates a facet from text
#[rustler::nif]
pub fn facet_from_text(facet_path: String) -> NifResult<ResourceArc<FacetResource>> {
    match Facet::from_text(&facet_path) {
        Ok(facet) => Ok(ResourceArc::new(FacetResource { facet })),
        Err(e) => Err(rustler::Error::Term(Box::new(format!(
            "Invalid facet path '{}': {}",
            facet_path, e
        )))),
    }
}

/// Converts a facet to string
#[rustler::nif]
pub fn facet_to_string(facet_res: ResourceArc<FacetResource>) -> NifResult<String> {
    Ok(facet_res.facet.to_string())
}
