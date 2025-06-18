use rustler::{Error, NifResult, ResourceArc};
use serde_json;
use std::collections::{BTreeMap, HashMap};
use std::sync::{Arc, Mutex};
use tantivy::{Index, Segment};

use crate::modules::resources::IndexResource;

/// Resource for managing space usage analysis
#[derive(Clone)]
pub struct SpaceAnalysisResource {
    pub analysis_cache: Arc<Mutex<HashMap<String, SpaceAnalysis>>>,
    pub config: Arc<Mutex<AnalysisConfig>>,
}

/// Comprehensive space analysis for an index
#[derive(Debug, Clone)]
pub struct SpaceAnalysis {
    pub total_size_bytes: u64,
    pub segment_count: usize,
    pub segments: Vec<SegmentAnalysis>,
    pub field_analysis: BTreeMap<String, FieldSpaceUsage>,
    pub index_metadata: IndexMetadata,
    pub storage_breakdown: StorageBreakdown,
}

/// Analysis for individual segments
#[derive(Debug, Clone, serde::Serialize)]
pub struct SegmentAnalysis {
    pub segment_id: String,
    pub size_bytes: u64,
    pub doc_count: u32,
    pub deleted_docs: u32,
    pub compression_ratio: f64,
    pub files: Vec<SegmentFile>,
}

/// File information within a segment
#[derive(Debug, Clone, serde::Serialize)]
pub struct SegmentFile {
    pub file_type: String,
    pub file_name: String,
    pub size_bytes: u64,
    pub percentage_of_segment: f64,
}

/// Space usage per field
#[derive(Debug, Clone, serde::Serialize)]
pub struct FieldSpaceUsage {
    pub field_name: String,
    pub total_size_bytes: u64,
    pub indexed_size_bytes: u64,
    pub stored_size_bytes: u64,
    pub fast_fields_size_bytes: u64,
    pub percentage_of_index: f64,
}

/// Index metadata information
#[derive(Debug, Clone)]
pub struct IndexMetadata {
    pub total_docs: u64,
    pub deleted_docs: u64,
    pub schema_size_bytes: u64,
    pub num_fields: usize,
    pub index_settings: BTreeMap<String, String>,
}

/// Storage breakdown by category
#[derive(Debug, Clone)]
pub struct StorageBreakdown {
    pub postings: u64,
    pub term_dictionary: u64,
    pub fast_fields: u64,
    pub field_norms: u64,
    pub stored_fields: u64,
    pub positions: u64,
    pub delete_bitset: u64,
    pub other: u64,
}

/// Configuration for space analysis
#[derive(Debug, Clone)]
pub struct AnalysisConfig {
    pub include_file_details: bool,
    pub include_field_breakdown: bool,
    pub cache_results: bool,
    pub cache_ttl_seconds: u64,
}

// Safety traits for cross-thread usage
unsafe impl Send for SpaceAnalysisResource {}
unsafe impl Sync for SpaceAnalysisResource {}
impl std::panic::RefUnwindSafe for SpaceAnalysisResource {}
impl std::panic::UnwindSafe for SpaceAnalysisResource {}

impl SpaceAnalysisResource {
    pub fn new() -> Self {
        Self {
            analysis_cache: Arc::new(Mutex::new(HashMap::new())),
            config: Arc::new(Mutex::new(AnalysisConfig::default())),
        }
    }
}

impl Default for AnalysisConfig {
    fn default() -> Self {
        Self {
            include_file_details: true,
            include_field_breakdown: true,
            cache_results: true,
            cache_ttl_seconds: 300, // 5 minutes
        }
    }
}

/// Create a new space analysis resource
#[rustler::nif]
pub fn space_analysis_new() -> NifResult<ResourceArc<SpaceAnalysisResource>> {
    let resource = ResourceArc::new(SpaceAnalysisResource::new());
    Ok(resource)
}

/// Configure space analysis settings
#[rustler::nif]
pub fn space_analysis_configure(
    analysis_resource: ResourceArc<SpaceAnalysisResource>,
    include_file_details: bool,
    include_field_breakdown: bool,
    cache_results: bool,
    cache_ttl_seconds: u64,
) -> NifResult<rustler::types::atom::Atom> {
    let mut config = analysis_resource.config.lock().unwrap();
    config.include_file_details = include_file_details;
    config.include_field_breakdown = include_field_breakdown;
    config.cache_results = cache_results;
    config.cache_ttl_seconds = cache_ttl_seconds;

    Ok(rustler::types::atom::ok())
}

/// Analyze space usage for an index
#[rustler::nif(schedule = "DirtyCpu")]
pub fn space_analysis_analyze_index(
    analysis_resource: ResourceArc<SpaceAnalysisResource>,
    index_resource: ResourceArc<IndexResource>,
    analysis_id: String,
) -> NifResult<String> {
    let config = analysis_resource.config.lock().unwrap().clone();

    // Perform comprehensive space analysis
    let total_size = estimate_index_size(&index_resource.index);
    let segment_count = index_resource
        .index
        .searchable_segments()
        .unwrap_or_default()
        .len();

    // Analyze segments
    let segments = analyze_segments(&index_resource.index, &config)?;

    // Analyze fields
    let field_analysis = if config.include_field_breakdown {
        analyze_fields(&index_resource.index)?
    } else {
        BTreeMap::new()
    };

    // Get index metadata
    let metadata = analyze_index_metadata(&index_resource.index)?;

    // Breakdown storage by category
    let storage_breakdown = analyze_storage_breakdown(&index_resource.index, &segments);

    let analysis = SpaceAnalysis {
        total_size_bytes: total_size,
        segment_count,
        segments,
        field_analysis,
        index_metadata: metadata,
        storage_breakdown,
    };

    // Cache results if configured
    if config.cache_results {
        let mut cache = analysis_resource.analysis_cache.lock().unwrap();
        cache.insert(analysis_id, analysis.clone());
    }

    // Convert to JSON response
    let response = serde_json::json!({
        "total_size_bytes": analysis.total_size_bytes,
        "segment_count": analysis.segment_count,
        "segments": analysis.segments.iter().map(|s| {
            let empty_files = Vec::new();
            let files_ref = if config.include_file_details { &s.files } else { &empty_files };
            serde_json::json!({
                "segment_id": s.segment_id,
                "size_bytes": s.size_bytes,
                "doc_count": s.doc_count,
                "deleted_docs": s.deleted_docs,
                "compression_ratio": s.compression_ratio,
                "files": files_ref
            })
        }).collect::<Vec<_>>(),
        "field_analysis": analysis.field_analysis,
        "index_metadata": {
            "total_docs": analysis.index_metadata.total_docs,
            "deleted_docs": analysis.index_metadata.deleted_docs,
            "schema_size_bytes": analysis.index_metadata.schema_size_bytes,
            "num_fields": analysis.index_metadata.num_fields,
            "index_settings": analysis.index_metadata.index_settings
        },
        "storage_breakdown": {
            "postings": analysis.storage_breakdown.postings,
            "term_dictionary": analysis.storage_breakdown.term_dictionary,
            "fast_fields": analysis.storage_breakdown.fast_fields,
            "field_norms": analysis.storage_breakdown.field_norms,
            "stored_fields": analysis.storage_breakdown.stored_fields,
            "positions": analysis.storage_breakdown.positions,
            "delete_bitset": analysis.storage_breakdown.delete_bitset,
            "other": analysis.storage_breakdown.other
        }
    });

    Ok(response.to_string())
}

/// Get cached analysis results
#[rustler::nif]
pub fn space_analysis_get_cached(
    analysis_resource: ResourceArc<SpaceAnalysisResource>,
    analysis_id: String,
) -> NifResult<String> {
    let cache = analysis_resource.analysis_cache.lock().unwrap();

    if let Some(analysis) = cache.get(&analysis_id) {
        let response = serde_json::json!({
            "found": true,
            "analysis": {
                "total_size_bytes": analysis.total_size_bytes,
                "segment_count": analysis.segment_count,
                "field_count": analysis.field_analysis.len(),
                "total_docs": analysis.index_metadata.total_docs
            }
        });
        Ok(response.to_string())
    } else {
        let response = serde_json::json!({
            "found": false
        });
        Ok(response.to_string())
    }
}

/// Compare space usage between two analyses
#[rustler::nif(schedule = "DirtyCpu")]
pub fn space_analysis_compare(
    analysis_resource: ResourceArc<SpaceAnalysisResource>,
    analysis_id_1: String,
    analysis_id_2: String,
) -> NifResult<String> {
    let cache = analysis_resource.analysis_cache.lock().unwrap();

    let analysis_1 = cache.get(&analysis_id_1).ok_or(Error::BadArg)?;
    let analysis_2 = cache.get(&analysis_id_2).ok_or(Error::BadArg)?;

    let size_diff = analysis_2.total_size_bytes as i64 - analysis_1.total_size_bytes as i64;
    let segment_diff = analysis_2.segment_count as i32 - analysis_1.segment_count as i32;
    let doc_diff =
        analysis_2.index_metadata.total_docs as i64 - analysis_1.index_metadata.total_docs as i64;

    let response = serde_json::json!({
        "comparison": {
            "size_difference_bytes": size_diff,
            "size_change_percentage": if analysis_1.total_size_bytes > 0 {
                (size_diff as f64 / analysis_1.total_size_bytes as f64) * 100.0
            } else {
                0.0
            },
            "segment_difference": segment_diff,
            "document_difference": doc_diff,
            "analysis_1": {
                "id": analysis_id_1,
                "size_bytes": analysis_1.total_size_bytes,
                "segments": analysis_1.segment_count,
                "docs": analysis_1.index_metadata.total_docs
            },
            "analysis_2": {
                "id": analysis_id_2,
                "size_bytes": analysis_2.total_size_bytes,
                "segments": analysis_2.segment_count,
                "docs": analysis_2.index_metadata.total_docs
            }
        }
    });

    Ok(response.to_string())
}

/// Get space optimization recommendations
#[rustler::nif]
pub fn space_analysis_get_recommendations(
    analysis_resource: ResourceArc<SpaceAnalysisResource>,
    analysis_id: String,
) -> NifResult<String> {
    let cache = analysis_resource.analysis_cache.lock().unwrap();
    let analysis = cache.get(&analysis_id).ok_or(Error::BadArg)?;

    let mut recommendations = Vec::new();

    // Check for too many segments
    if analysis.segment_count > 10 {
        recommendations.push(serde_json::json!({
            "type": "merge_segments",
            "priority": "high",
            "description": format!("Consider merging segments. Current count: {}", analysis.segment_count),
            "potential_savings_bytes": estimate_merge_savings(analysis)
        }));
    }

    // Check for deleted documents
    let deletion_ratio =
        analysis.index_metadata.deleted_docs as f64 / analysis.index_metadata.total_docs as f64;
    if deletion_ratio > 0.1 {
        recommendations.push(serde_json::json!({
            "type": "optimize_deletes",
            "priority": "medium",
            "description": format!("High deletion ratio: {:.1}%. Consider optimization.", deletion_ratio * 100.0),
            "potential_savings_bytes": estimate_deletion_savings(analysis)
        }));
    }

    // Check for field storage efficiency
    for (_field_name, field_usage) in &analysis.field_analysis {
        if field_usage.percentage_of_index > 50.0 {
            recommendations.push(serde_json::json!({
                "type": "field_optimization",
                "priority": "low",
                "description": format!("Field '{}' uses {:.1}% of index space", field_usage.field_name, field_usage.percentage_of_index),
                "potential_savings_bytes": 0
            }));
        }
    }

    let response = serde_json::json!({
        "analysis_id": analysis_id,
        "recommendations": recommendations,
        "total_recommendations": recommendations.len()
    });

    Ok(response.to_string())
}

/// Clear analysis cache
#[rustler::nif]
pub fn space_analysis_clear_cache(
    analysis_resource: ResourceArc<SpaceAnalysisResource>,
) -> NifResult<rustler::types::atom::Atom> {
    let mut cache = analysis_resource.analysis_cache.lock().unwrap();
    cache.clear();
    Ok(rustler::types::atom::ok())
}

// Helper functions for space analysis

fn estimate_index_size(_index: &Index) -> u64 {
    // Simplified estimation - in a real implementation, this would walk the directory
    // and sum up all file sizes
    1024 * 1024 * 10 // 10MB placeholder
}

fn analyze_segments(index: &Index, config: &AnalysisConfig) -> NifResult<Vec<SegmentAnalysis>> {
    let mut segments = Vec::new();

    if let Ok(searchable_segments) = index.searchable_segments() {
        for (i, segment) in searchable_segments.iter().enumerate() {
            let segment_analysis = SegmentAnalysis {
                segment_id: format!("segment_{}", i),
                size_bytes: 1024 * 1024, // Placeholder
                doc_count: 1000,         // Placeholder - would need segment reader
                deleted_docs: 0,         // Placeholder - would need segment reader
                compression_ratio: 0.8,  // Placeholder
                files: if config.include_file_details {
                    analyze_segment_files(segment)
                } else {
                    Vec::new()
                },
            };
            segments.push(segment_analysis);
        }
    }

    Ok(segments)
}

fn analyze_segment_files(_segment: &Segment) -> Vec<SegmentFile> {
    // Placeholder implementation
    vec![
        SegmentFile {
            file_type: "postings".to_string(),
            file_name: "postings.idx".to_string(),
            size_bytes: 512 * 1024,
            percentage_of_segment: 50.0,
        },
        SegmentFile {
            file_type: "terms".to_string(),
            file_name: "terms.idx".to_string(),
            size_bytes: 256 * 1024,
            percentage_of_segment: 25.0,
        },
    ]
}

fn analyze_fields(index: &Index) -> NifResult<BTreeMap<String, FieldSpaceUsage>> {
    let mut field_analysis = BTreeMap::new();
    let schema = index.schema();

    for (_field, field_entry) in schema.fields() {
        let field_name = field_entry.name().to_string();
        let usage = FieldSpaceUsage {
            field_name: field_name.clone(),
            total_size_bytes: 1024 * 1024, // Placeholder
            indexed_size_bytes: 512 * 1024,
            stored_size_bytes: 256 * 1024,
            fast_fields_size_bytes: 256 * 1024,
            percentage_of_index: 10.0, // Placeholder
        };
        field_analysis.insert(field_name, usage);
    }

    Ok(field_analysis)
}

fn analyze_index_metadata(index: &Index) -> NifResult<IndexMetadata> {
    let schema = index.schema();
    let reader = index.reader().map_err(|_| Error::BadArg)?;
    let searcher = reader.searcher();

    let metadata = IndexMetadata {
        total_docs: searcher.num_docs() as u64,
        deleted_docs: 0,         // Simplified
        schema_size_bytes: 1024, // Placeholder
        num_fields: schema.fields().count(),
        index_settings: BTreeMap::new(), // Placeholder
    };

    Ok(metadata)
}

fn analyze_storage_breakdown(_index: &Index, segments: &[SegmentAnalysis]) -> StorageBreakdown {
    // Simplified analysis based on segment data
    let total_size: u64 = segments.iter().map(|s| s.size_bytes).sum();

    StorageBreakdown {
        postings: total_size / 3,
        term_dictionary: total_size / 6,
        fast_fields: total_size / 6,
        field_norms: total_size / 12,
        stored_fields: total_size / 6,
        positions: total_size / 12,
        delete_bitset: total_size / 24,
        other: total_size / 24,
    }
}

fn estimate_merge_savings(analysis: &SpaceAnalysis) -> u64 {
    // Estimate savings from merging segments (typically 10-20% for many small segments)
    if analysis.segment_count > 5 {
        analysis.total_size_bytes / 10 // 10% savings estimate
    } else {
        0
    }
}

fn estimate_deletion_savings(analysis: &SpaceAnalysis) -> u64 {
    // Estimate savings from optimizing deleted documents
    let deletion_ratio =
        analysis.index_metadata.deleted_docs as f64 / analysis.index_metadata.total_docs as f64;
    (analysis.total_size_bytes as f64 * deletion_ratio * 0.8) as u64 // 80% of deleted doc space can be reclaimed
}
