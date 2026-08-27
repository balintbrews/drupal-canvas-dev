<?php

// phpcs:ignoreFile

$databases['default']['default'] = [
  'database' => 'db',
  'username' => 'db',
  'password' => 'db',
  'host' => '127.0.0.1',
  'port' => 3306,
  'driver' => 'mysql',
];

$settings['hash_salt'] = 'canvas-local-development';
$settings['update_free_access'] = FALSE;
$settings['skip_permissions_hardening'] = TRUE;
$settings['trusted_host_patterns'] = ['.*'];
$settings['config_sync_directory'] = 'sites/default/files/sync';
$settings['file_scan_ignore_directories'] = [
  'node_modules',
  'bower_components',
];
$settings['entity_update_batch_size'] = 50;
$settings['entity_update_backup'] = TRUE;
$settings['state_cache'] = TRUE;
$settings['migrate_node_migrate_type_classic'] = FALSE;
$settings['extension_discovery_scan_tests'] = TRUE;

$config['system.logging']['error_level'] = 'verbose';
