-- PC Usage Intelligence — logical SQLite schema baseline
-- Source: docs/07-data-architecture-storage.md
-- Physical tuning (indexes, generated columns, WITHOUT ROWID, WAL policy, etc.)
-- may evolve without changing the semantic contracts in domain-model.md.

PRAGMA foreign_keys = ON;

CREATE TABLE device (
    device_id TEXT PRIMARY KEY,
    installation_id TEXT NOT NULL UNIQUE,
    display_name TEXT,
    created_at_utc TEXT NOT NULL,
    first_seen_at_utc TEXT NOT NULL,
    last_seen_at_utc TEXT,
    app_version TEXT,
    os_family TEXT,
    status TEXT NOT NULL DEFAULT 'Active'
);

CREATE TABLE runtime_session (
    runtime_session_id TEXT PRIMARY KEY,
    device_id TEXT NOT NULL REFERENCES device(device_id),
    windows_session_id INTEGER NOT NULL,
    started_at_utc TEXT NOT NULL,
    ended_at_utc TEXT,
    monotonic_start INTEGER,
    monotonic_end INTEGER,
    clean_shutdown INTEGER NOT NULL CHECK (clean_shutdown IN (0,1)),
    shutdown_reason TEXT,
    last_checkpoint_at_utc TEXT
);

CREATE INDEX ix_runtime_session_device_time
    ON runtime_session(device_id, started_at_utc);

CREATE TABLE canonical_application (
    canonical_application_id TEXT PRIMARY KEY,
    stable_key TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    default_icon_ref TEXT,
    source TEXT NOT NULL,
    created_at_utc TEXT NOT NULL,
    archived_at_utc TEXT
);

CREATE TABLE process_instance (
    process_instance_id TEXT PRIMARY KEY,
    runtime_session_id TEXT REFERENCES runtime_session(runtime_session_id),
    windows_session_id INTEGER NOT NULL,
    pid INTEGER NOT NULL,
    process_start_at_utc TEXT,
    process_end_at_utc TEXT,
    executable_path TEXT,
    executable_name TEXT,
    package_identity TEXT,
    canonical_application_id TEXT REFERENCES canonical_application(canonical_application_id),
    first_seen_at_utc TEXT NOT NULL,
    last_seen_at_utc TEXT NOT NULL
);

CREATE INDEX ix_process_instance_identity
    ON process_instance(windows_session_id, pid, process_start_at_utc);

CREATE INDEX ix_process_instance_app_time
    ON process_instance(canonical_application_id, first_seen_at_utc);

CREATE TABLE window_instance (
    window_instance_id TEXT PRIMARY KEY,
    process_instance_id TEXT REFERENCES process_instance(process_instance_id),
    hwnd_value INTEGER NOT NULL,
    created_at_utc TEXT,
    destroyed_at_utc TEXT,
    first_seen_at_utc TEXT NOT NULL,
    last_seen_at_utc TEXT NOT NULL,
    initial_title TEXT,
    latest_title TEXT,
    canonical_application_id TEXT REFERENCES canonical_application(canonical_application_id)
);

CREATE INDEX ix_window_instance_hwnd_time
    ON window_instance(hwnd_value, first_seen_at_utc);

CREATE TABLE application_identity_rule (
    rule_id TEXT PRIMARY KEY,
    observed_identity_type TEXT NOT NULL,
    observed_identity_key TEXT NOT NULL,
    canonical_application_id TEXT NOT NULL REFERENCES canonical_application(canonical_application_id),
    priority INTEGER NOT NULL,
    confidence REAL CHECK (confidence IS NULL OR (confidence >= 0.0 AND confidence <= 1.0)),
    created_at_utc TEXT NOT NULL,
    effective_from_utc TEXT NOT NULL,
    effective_to_utc TEXT,
    source TEXT NOT NULL
);

CREATE INDEX ix_identity_rule_lookup
    ON application_identity_rule(observed_identity_type, observed_identity_key, priority);

CREATE TABLE category (
    category_id TEXT PRIMARY KEY,
    parent_category_id TEXT REFERENCES category(category_id),
    stable_key TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    system_defined INTEGER NOT NULL CHECK (system_defined IN (0,1)),
    archived_at_utc TEXT,
    created_at_utc TEXT NOT NULL
);

CREATE TABLE productivity_classification (
    classification_id TEXT PRIMARY KEY,
    target_type TEXT NOT NULL,
    target_id TEXT NOT NULL,
    value TEXT NOT NULL,
    confidence REAL CHECK (confidence IS NULL OR (confidence >= 0.0 AND confidence <= 1.0)),
    source TEXT NOT NULL,
    effective_from_utc TEXT NOT NULL,
    effective_to_utc TEXT,
    created_at_utc TEXT NOT NULL
);

CREATE INDEX ix_productivity_target_time
    ON productivity_classification(target_type, target_id, effective_from_utc);

CREATE TABLE raw_observation (
    observation_id TEXT PRIMARY KEY,
    runtime_session_id TEXT NOT NULL REFERENCES runtime_session(runtime_session_id),
    device_id TEXT NOT NULL REFERENCES device(device_id),
    observed_at_utc TEXT NOT NULL,
    monotonic_ticks INTEGER NOT NULL,
    source TEXT NOT NULL,
    source_sequence INTEGER,
    windows_session_id INTEGER,
    hwnd_value INTEGER,
    process_id INTEGER,
    process_start_at_utc TEXT,
    executable_path TEXT,
    executable_name TEXT,
    package_identity TEXT,
    window_title TEXT,
    is_visible INTEGER CHECK (is_visible IS NULL OR is_visible IN (0,1)),
    is_minimized INTEGER CHECK (is_minimized IS NULL OR is_minimized IN (0,1)),
    is_cloaked INTEGER CHECK (is_cloaked IS NULL OR is_cloaked IN (0,1)),
    monitor_key TEXT,
    foreground_state INTEGER CHECK (foreground_state IS NULL OR foreground_state IN (0,1)),
    idle_state TEXT NOT NULL,
    lifecycle_state TEXT NOT NULL
);

CREATE INDEX ix_raw_observation_time
    ON raw_observation(device_id, observed_at_utc);

CREATE INDEX ix_raw_observation_process_time
    ON raw_observation(windows_session_id, process_id, process_start_at_utc, observed_at_utc);

CREATE TABLE lifecycle_event (
    lifecycle_event_id TEXT PRIMARY KEY,
    runtime_session_id TEXT NOT NULL REFERENCES runtime_session(runtime_session_id),
    device_id TEXT NOT NULL REFERENCES device(device_id),
    occurred_at_utc TEXT NOT NULL,
    monotonic_ticks INTEGER,
    event_type TEXT NOT NULL,
    windows_session_id INTEGER,
    details_json TEXT
);

CREATE INDEX ix_lifecycle_event_time
    ON lifecycle_event(device_id, occurred_at_utc);

CREATE TABLE usage_interval (
    interval_id TEXT PRIMARY KEY,
    device_id TEXT NOT NULL REFERENCES device(device_id),
    runtime_session_id TEXT REFERENCES runtime_session(runtime_session_id),
    dimension TEXT NOT NULL,
    start_at_utc TEXT NOT NULL,
    end_at_utc TEXT,
    start_monotonic_ticks INTEGER,
    end_monotonic_ticks INTEGER,
    duration_ms INTEGER CHECK (duration_ms IS NULL OR duration_ms >= 0),
    derived_session_id TEXT,
    window_instance_id TEXT REFERENCES window_instance(window_instance_id),
    process_instance_id TEXT REFERENCES process_instance(process_instance_id),
    canonical_application_id TEXT REFERENCES canonical_application(canonical_application_id),
    monitor_key TEXT,
    browser_identity_id TEXT,
    idle_state TEXT NOT NULL,
    provenance TEXT NOT NULL,
    completion_reason TEXT NOT NULL,
    source_version INTEGER NOT NULL,
    derived_at_utc TEXT NOT NULL
);

CREATE INDEX ix_usage_interval_time
    ON usage_interval(device_id, start_at_utc, end_at_utc);

CREATE INDEX ix_usage_interval_app_time
    ON usage_interval(canonical_application_id, start_at_utc);

CREATE INDEX ix_usage_interval_dimension_time
    ON usage_interval(dimension, start_at_utc);

CREATE TABLE browser_instance (
    browser_instance_id TEXT PRIMARY KEY,
    browser_type TEXT NOT NULL,
    process_instance_id TEXT REFERENCES process_instance(process_instance_id),
    profile_key TEXT,
    started_at_utc TEXT NOT NULL,
    ended_at_utc TEXT
);

CREATE TABLE browser_window (
    browser_window_id TEXT PRIMARY KEY,
    browser_instance_id TEXT NOT NULL REFERENCES browser_instance(browser_instance_id),
    window_instance_id TEXT REFERENCES window_instance(window_instance_id),
    browser_window_native_id TEXT,
    private_mode TEXT NOT NULL,
    created_at_utc TEXT NOT NULL,
    closed_at_utc TEXT
);

CREATE INDEX ix_browser_window_native
    ON browser_window(browser_window_native_id);

CREATE TABLE browser_tab (
    browser_tab_instance_id TEXT PRIMARY KEY,
    browser_window_id TEXT NOT NULL REFERENCES browser_window(browser_window_id),
    browser_native_tab_id TEXT,
    created_at_utc TEXT NOT NULL,
    closed_at_utc TEXT
);

CREATE TABLE domain (
    domain_id TEXT PRIMARY KEY,
    normalized_domain TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    domain_kind TEXT NOT NULL
);

CREATE TABLE browser_page_observation (
    observation_id TEXT PRIMARY KEY,
    browser_tab_instance_id TEXT NOT NULL REFERENCES browser_tab(browser_tab_instance_id),
    observed_at_utc TEXT NOT NULL,
    domain_id TEXT REFERENCES domain(domain_id),
    page_title TEXT,
    private_mode TEXT NOT NULL,
    navigation_state TEXT NOT NULL,
    source TEXT NOT NULL
);

CREATE INDEX ix_browser_page_time
    ON browser_page_observation(browser_tab_instance_id, observed_at_utc);

CREATE TABLE aggregate_bucket (
    bucket_id TEXT PRIMARY KEY,
    bucket_kind TEXT NOT NULL,
    bucket_start_utc TEXT NOT NULL,
    bucket_end_utc TEXT NOT NULL,
    canonical_application_id TEXT REFERENCES canonical_application(canonical_application_id),
    domain_id TEXT REFERENCES domain(domain_id),
    category_id TEXT REFERENCES category(category_id),
    productivity_value TEXT,
    foreground_ms INTEGER NOT NULL DEFAULT 0 CHECK (foreground_ms >= 0),
    visible_ms INTEGER NOT NULL DEFAULT 0 CHECK (visible_ms >= 0),
    session_count INTEGER NOT NULL DEFAULT 0 CHECK (session_count >= 0),
    switch_count INTEGER NOT NULL DEFAULT 0 CHECK (switch_count >= 0),
    data_quality TEXT NOT NULL,
    algorithm_version INTEGER NOT NULL
);

CREATE INDEX ix_aggregate_bucket_period
    ON aggregate_bucket(bucket_kind, bucket_start_utc, bucket_end_utc);

CREATE TABLE schema_metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
