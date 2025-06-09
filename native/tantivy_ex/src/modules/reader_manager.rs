use rustler::{Error, NifResult, ResourceArc};
use std::collections::HashMap;
use std::sync::{Arc, Mutex, RwLock};
use std::time::{Instant, SystemTime, UNIX_EPOCH};
use tantivy::{IndexReader, ReloadPolicy};
use serde_json;

use crate::modules::resources::IndexResource;

/// Resource for managing index readers and reload policies
#[derive(Clone)]
pub struct ReaderManagerResource {
    pub readers: Arc<RwLock<HashMap<String, Arc<IndexReader>>>>,
    pub policies: Arc<Mutex<HashMap<String, ReaderPolicy>>>,
    pub reload_stats: Arc<Mutex<HashMap<String, ReaderStats>>>,
    pub monitoring_config: Arc<Mutex<MonitoringConfig>>,
}

/// Configuration for index reader reload policies
#[derive(Debug, Clone)]
pub struct ReaderPolicy {
    pub name: String,
    pub policy_type: ReaderPolicyType,
    pub max_age_seconds: u64,
    pub check_interval_seconds: u64,
    pub auto_reload: bool,
    pub background_reload: bool,
    pub preload_segments: bool,
}

/// Types of reader reload policies
#[derive(Debug, Clone)]
pub enum ReaderPolicyType {
    Manual,
    Periodic { interval_seconds: u64 },
    OnChange { check_interval_seconds: u64 },
    Hybrid { periodic_seconds: u64, change_check_seconds: u64 },
    Smart { max_age_seconds: u64, min_interval_seconds: u64 },
}

/// Statistics for reader usage and reloads
#[derive(Debug, Clone)]
pub struct ReaderStats {
    pub reader_id: String,
    pub creation_time: u64,
    pub last_reload_time: u64,
    pub reload_count: u64,
    pub search_count: u64,
    pub total_search_time_ms: u64,
    pub average_search_time_ms: f64,
    pub memory_usage_bytes: u64,
    pub segment_count: usize,
    pub policy_name: String,
}

/// Monitoring configuration for reader management
#[derive(Debug, Clone)]
pub struct MonitoringConfig {
    pub track_usage_stats: bool,
    pub track_performance: bool,
    pub log_reload_events: bool,
    pub alert_on_slow_reloads: bool,
    pub slow_reload_threshold_ms: u64,
}

/// Reader lifecycle events
#[derive(Debug, Clone)]
pub enum ReaderEvent {
    Created { reader_id: String, timestamp: u64 },
    Reloaded { reader_id: String, timestamp: u64, duration_ms: u64 },
    SearchPerformed { reader_id: String, duration_ms: u64 },
    Disposed { reader_id: String, timestamp: u64 },
}

/// Reader health information
#[derive(Debug, Clone)]
pub struct ReaderHealth {
    pub reader_id: String,
    pub is_healthy: bool,
    pub age_seconds: u64,
    pub last_reload_seconds_ago: u64,
    pub search_rate_per_minute: f64,
    pub average_reload_time_ms: f64,
    pub memory_usage_mb: f64,
    pub recommendations: Vec<String>,
}

// Safety traits for cross-thread usage
unsafe impl Send for ReaderManagerResource {}
unsafe impl Sync for ReaderManagerResource {}
impl std::panic::RefUnwindSafe for ReaderManagerResource {}
impl std::panic::UnwindSafe for ReaderManagerResource {}

impl ReaderManagerResource {
    pub fn new() -> Self {
        Self {
            readers: Arc::new(RwLock::new(HashMap::new())),
            policies: Arc::new(Mutex::new(HashMap::new())),
            reload_stats: Arc::new(Mutex::new(HashMap::new())),
            monitoring_config: Arc::new(Mutex::new(MonitoringConfig::default())),
        }
    }
}

impl Default for MonitoringConfig {
    fn default() -> Self {
        Self {
            track_usage_stats: true,
            track_performance: true,
            log_reload_events: true,
            alert_on_slow_reloads: true,
            slow_reload_threshold_ms: 1000,
        }
    }
}

impl Default for ReaderPolicy {
    fn default() -> Self {
        Self {
            name: "default".to_string(),
            policy_type: ReaderPolicyType::Periodic { interval_seconds: 60 },
            max_age_seconds: 300,
            check_interval_seconds: 10,
            auto_reload: true,
            background_reload: true,
            preload_segments: false,
        }
    }
}

/// Create a new reader manager resource
#[rustler::nif]
pub fn reader_manager_new() -> NifResult<ResourceArc<ReaderManagerResource>> {
    let resource = ResourceArc::new(ReaderManagerResource::new());
    Ok(resource)
}

/// Configure monitoring settings
#[rustler::nif]
pub fn reader_manager_configure_monitoring(
    manager: ResourceArc<ReaderManagerResource>,
    track_usage_stats: bool,
    track_performance: bool,
    log_reload_events: bool,
    alert_on_slow_reloads: bool,
    slow_reload_threshold_ms: u64,
) -> NifResult<rustler::types::atom::Atom> {
    let mut config = manager.monitoring_config.lock().unwrap();
    config.track_usage_stats = track_usage_stats;
    config.track_performance = track_performance;
    config.log_reload_events = log_reload_events;
    config.alert_on_slow_reloads = alert_on_slow_reloads;
    config.slow_reload_threshold_ms = slow_reload_threshold_ms;

    Ok(rustler::types::atom::ok())
}

/// Create a reload policy
#[rustler::nif]
pub fn reader_manager_create_policy(
    manager: ResourceArc<ReaderManagerResource>,
    policy_name: String,
    policy_type: String,
    max_age_seconds: u64,
    check_interval_seconds: u64,
    auto_reload: bool,
    background_reload: bool,
    preload_segments: bool,
) -> NifResult<rustler::types::atom::Atom> {
    let policy_type_enum = match policy_type.as_str() {
        "manual" => ReaderPolicyType::Manual,
        "periodic" => ReaderPolicyType::Periodic { interval_seconds: check_interval_seconds },
        "on_change" => ReaderPolicyType::OnChange { check_interval_seconds },
        "hybrid" => ReaderPolicyType::Hybrid {
            periodic_seconds: max_age_seconds / 2,
            change_check_seconds: check_interval_seconds,
        },
        "smart" => ReaderPolicyType::Smart {
            max_age_seconds,
            min_interval_seconds: check_interval_seconds,
        },
        _ => return Err(Error::BadArg),
    };

    let policy = ReaderPolicy {
        name: policy_name.clone(),
        policy_type: policy_type_enum,
        max_age_seconds,
        check_interval_seconds,
        auto_reload,
        background_reload,
        preload_segments,
    };

    let mut policies = manager.policies.lock().unwrap();
    policies.insert(policy_name, policy);

    Ok(rustler::types::atom::ok())
}

/// Create and register an index reader
#[rustler::nif]
pub fn reader_manager_create_reader(
    manager: ResourceArc<ReaderManagerResource>,
    index_resource: ResourceArc<IndexResource>,
    reader_id: String,
    policy_name: String,
) -> NifResult<rustler::types::atom::Atom> {
    let policies = manager.policies.lock().unwrap();
    let policy = policies.get(&policy_name).ok_or(Error::BadArg)?;

    // Create the reader based on policy settings
    let reader = match policy.policy_type {
        ReaderPolicyType::Manual => index_resource.index.reader().map_err(|_| Error::BadArg)?,
        ReaderPolicyType::Periodic { interval_seconds: _ } => {
            index_resource.index
                .reader_builder()
                .reload_policy(ReloadPolicy::OnCommitWithDelay)
                .try_into()
                .map_err(|_| Error::BadArg)?
        },
        ReaderPolicyType::OnChange { .. } => {
            index_resource.index
                .reader_builder()
                .reload_policy(ReloadPolicy::OnCommitWithDelay)
                .try_into()
                .map_err(|_| Error::BadArg)?
        },
        _ => index_resource.index.reader().map_err(|_| Error::BadArg)?,
    };

    // Store the reader
    let mut readers = manager.readers.write().unwrap();
    readers.insert(reader_id.clone(), Arc::new(reader));

    // Initialize statistics
    let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs();
    let stats = ReaderStats {
        reader_id: reader_id.clone(),
        creation_time: now,
        last_reload_time: now,
        reload_count: 0,
        search_count: 0,
        total_search_time_ms: 0,
        average_search_time_ms: 0.0,
        memory_usage_bytes: estimate_reader_memory_usage(),
        segment_count: 0, // Would need to get from reader
        policy_name: policy_name.clone(),
    };

    let mut reload_stats = manager.reload_stats.lock().unwrap();
    reload_stats.insert(reader_id, stats);

    Ok(rustler::types::atom::ok())
}

/// Manually reload a reader
#[rustler::nif]
pub fn reader_manager_reload_reader(
    manager: ResourceArc<ReaderManagerResource>,
    reader_id: String,
    force_reload: bool,
) -> NifResult<String> {
    let start_time = Instant::now();

    // Get the reader
    let readers = manager.readers.read().unwrap();
    let reader = readers.get(&reader_id).ok_or(Error::BadArg)?;

    // Perform reload
    let reload_result = if force_reload {
        reader.reload()
    } else {
        reader.reload()
    };

    let reload_duration = start_time.elapsed();
    let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs();

    // Update statistics
    let mut reload_stats = manager.reload_stats.lock().unwrap();
    if let Some(stats) = reload_stats.get_mut(&reader_id) {
        stats.last_reload_time = now;
        stats.reload_count += 1;
    }

    match reload_result {
        Ok(_) => {
            let response = serde_json::json!({
                "reader_id": reader_id,
                "success": true,
                "reload_duration_ms": reload_duration.as_millis(),
                "timestamp": now,
                "force_reload": force_reload
            });
            Ok(response.to_string())
        },
        Err(e) => {
            let response = serde_json::json!({
                "reader_id": reader_id,
                "success": false,
                "error": format!("{:?}", e),
                "reload_duration_ms": reload_duration.as_millis(),
                "timestamp": now
            });
            Ok(response.to_string())
        }
    }
}

/// Get reader statistics
#[rustler::nif]
pub fn reader_manager_get_reader_stats(
    manager: ResourceArc<ReaderManagerResource>,
    reader_id: String,
) -> NifResult<String> {
    let reload_stats = manager.reload_stats.lock().unwrap();

    if let Some(stats) = reload_stats.get(&reader_id) {
        let response = serde_json::json!({
            "reader_id": stats.reader_id,
            "creation_time": stats.creation_time,
            "last_reload_time": stats.last_reload_time,
            "reload_count": stats.reload_count,
            "search_count": stats.search_count,
            "total_search_time_ms": stats.total_search_time_ms,
            "average_search_time_ms": stats.average_search_time_ms,
            "memory_usage_bytes": stats.memory_usage_bytes,
            "segment_count": stats.segment_count,
            "policy_name": stats.policy_name
        });
        Ok(response.to_string())
    } else {
        let response = serde_json::json!({
            "found": false,
            "reader_id": reader_id
        });
        Ok(response.to_string())
    }
}

/// Get reader health information
#[rustler::nif]
pub fn reader_manager_get_reader_health(
    manager: ResourceArc<ReaderManagerResource>,
    reader_id: String,
) -> NifResult<String> {
    let reload_stats = manager.reload_stats.lock().unwrap();
    let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs();

    if let Some(stats) = reload_stats.get(&reader_id) {
        let age_seconds = now - stats.creation_time;
        let last_reload_seconds_ago = now - stats.last_reload_time;

        // Calculate search rate
        let search_rate_per_minute = if age_seconds > 0 {
            (stats.search_count as f64 / age_seconds as f64) * 60.0
        } else {
            0.0
        };

        // Calculate average reload time
        let average_reload_time_ms = if stats.reload_count > 0 {
            stats.total_search_time_ms as f64 / stats.reload_count as f64
        } else {
            0.0
        };

        // Generate recommendations
        let mut recommendations = Vec::new();
        if last_reload_seconds_ago > 300 {
            recommendations.push("Consider reloading - reader is over 5 minutes old".to_string());
        }
        if stats.average_search_time_ms > 100.0 {
            recommendations.push("High search latency - consider optimizing index".to_string());
        }
        if stats.memory_usage_bytes > 1024 * 1024 * 1024 {
            recommendations.push("High memory usage - monitor for memory leaks".to_string());
        }

        let health = ReaderHealth {
            reader_id: reader_id.clone(),
            is_healthy: last_reload_seconds_ago < 600 && stats.average_search_time_ms < 200.0,
            age_seconds,
            last_reload_seconds_ago,
            search_rate_per_minute,
            average_reload_time_ms,
            memory_usage_mb: stats.memory_usage_bytes as f64 / (1024.0 * 1024.0),
            recommendations,
        };

        let response = serde_json::json!({
            "reader_id": health.reader_id,
            "is_healthy": health.is_healthy,
            "age_seconds": health.age_seconds,
            "last_reload_seconds_ago": health.last_reload_seconds_ago,
            "search_rate_per_minute": health.search_rate_per_minute,
            "average_reload_time_ms": health.average_reload_time_ms,
            "memory_usage_mb": health.memory_usage_mb,
            "recommendations": health.recommendations
        });

        Ok(response.to_string())
    } else {
        let response = serde_json::json!({
            "found": false,
            "reader_id": reader_id
        });
        Ok(response.to_string())
    }
}

/// Record a search operation for statistics
#[rustler::nif]
pub fn reader_manager_record_search(
    manager: ResourceArc<ReaderManagerResource>,
    reader_id: String,
    search_duration_ms: u64,
) -> NifResult<rustler::types::atom::Atom> {
    let mut reload_stats = manager.reload_stats.lock().unwrap();

    if let Some(stats) = reload_stats.get_mut(&reader_id) {
        stats.search_count += 1;
        stats.total_search_time_ms += search_duration_ms;
        stats.average_search_time_ms = stats.total_search_time_ms as f64 / stats.search_count as f64;
    }

    Ok(rustler::types::atom::ok())
}

/// List all managed readers
#[rustler::nif]
pub fn reader_manager_list_readers(
    manager: ResourceArc<ReaderManagerResource>,
) -> NifResult<String> {
    let readers = manager.readers.read().unwrap();
    let reload_stats = manager.reload_stats.lock().unwrap();
    let policies = manager.policies.lock().unwrap();

    let reader_list: Vec<serde_json::Value> = readers.keys()
        .map(|reader_id| {
            let stats = reload_stats.get(reader_id);
            serde_json::json!({
                "reader_id": reader_id,
                "policy_name": stats.map(|s| &s.policy_name).unwrap_or(&"unknown".to_string()),
                "creation_time": stats.map(|s| s.creation_time).unwrap_or(0),
                "reload_count": stats.map(|s| s.reload_count).unwrap_or(0),
                "search_count": stats.map(|s| s.search_count).unwrap_or(0)
            })
        })
        .collect();

    let response = serde_json::json!({
        "readers": reader_list,
        "total_readers": reader_list.len(),
        "total_policies": policies.len(),
        "policy_names": policies.keys().collect::<Vec<_>>()
    });

    Ok(response.to_string())
}

/// Get all policies
#[rustler::nif]
pub fn reader_manager_list_policies(
    manager: ResourceArc<ReaderManagerResource>,
) -> NifResult<String> {
    let policies = manager.policies.lock().unwrap();

    let policy_list: Vec<serde_json::Value> = policies.iter()
        .map(|(name, policy)| {
            serde_json::json!({
                "name": name,
                "policy_type": format!("{:?}", policy.policy_type),
                "max_age_seconds": policy.max_age_seconds,
                "check_interval_seconds": policy.check_interval_seconds,
                "auto_reload": policy.auto_reload,
                "background_reload": policy.background_reload,
                "preload_segments": policy.preload_segments
            })
        })
        .collect();

    let response = serde_json::json!({
        "policies": policy_list,
        "total_policies": policy_list.len()
    });

    Ok(response.to_string())
}

/// Dispose of a reader
#[rustler::nif]
pub fn reader_manager_dispose_reader(
    manager: ResourceArc<ReaderManagerResource>,
    reader_id: String,
) -> NifResult<rustler::types::atom::Atom> {
    let mut readers = manager.readers.write().unwrap();
    let mut reload_stats = manager.reload_stats.lock().unwrap();

    readers.remove(&reader_id);
    reload_stats.remove(&reader_id);

    Ok(rustler::types::atom::ok())
}

/// Clear all readers and statistics
#[rustler::nif]
pub fn reader_manager_clear_all(
    manager: ResourceArc<ReaderManagerResource>,
) -> NifResult<rustler::types::atom::Atom> {
    let mut readers = manager.readers.write().unwrap();
    let mut reload_stats = manager.reload_stats.lock().unwrap();
    let mut policies = manager.policies.lock().unwrap();

    readers.clear();
    reload_stats.clear();
    policies.clear();

    Ok(rustler::types::atom::ok())
}

// Helper functions

fn estimate_reader_memory_usage() -> u64 {
    // Simplified estimation - in reality would analyze reader internals
    1024 * 1024 * 50 // 50MB placeholder
}
