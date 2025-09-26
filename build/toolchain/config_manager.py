#!/usr/bin/env python3
"""
P1 Dev Guard - Comprehensive Configuration Management System
Centralized configuration for all P1 Dev Guard components
"""

import os
import json
import yaml
from pathlib import Path
from typing import Dict, List, Optional, Any, Union
from dataclasses import dataclass, asdict
from ai_config import AIConfigManager, P1AIConfig

@dataclass
class ScanningConfig:
    """Configuration for vulnerability scanning"""
    enabled: bool = True
    severity_levels: List[str] = None
    timeout_seconds: int = 300
    ignore_unfixed: bool = False
    cache_enabled: bool = True
    custom_policies: Dict[str, str] = None

    def __post_init__(self):
        if self.severity_levels is None:
            self.severity_levels = ["HIGH", "CRITICAL"]
        if self.custom_policies is None:
            self.custom_policies = {}

@dataclass
class PolicyConfig:
    """Configuration for OPA policy validation"""
    enabled: bool = True
    policy_dirs: List[str] = None
    strict_mode: bool = False
    custom_rules: Dict[str, str] = None
    ignore_namespaces: List[str] = None

    def __post_init__(self):
        if self.policy_dirs is None:
            self.policy_dirs = ["/policies", "./policies"]
        if self.custom_rules is None:
            self.custom_rules = {}
        if self.ignore_namespaces is None:
            self.ignore_namespaces = ["kube-system", "kube-public"]

@dataclass
class HelmConfig:
    """Configuration for Helm chart validation"""
    enabled: bool = True
    lint_strict: bool = False
    template_validation: bool = True
    schema_validation: bool = True
    dependency_update: bool = True
    value_overrides: Dict[str, Any] = None

    def __post_init__(self):
        if self.value_overrides is None:
            self.value_overrides = {}

@dataclass
class RegistryConfig:
    """Configuration for container registry settings"""
    ironbank_mirror: str = "${IRONBANK_MIRROR}"
    insecure_registries: List[str] = None
    auth_config: Dict[str, str] = None
    image_pull_timeout: int = 300

    def __post_init__(self):
        if self.insecure_registries is None:
            self.insecure_registries = []
        if self.auth_config is None:
            self.auth_config = {}

@dataclass
class OutputConfig:
    """Configuration for output and reporting"""
    format: str = "text"  # text, json, xml
    artifacts_dir: str = ".p1-artifacts"
    detailed_reports: bool = True
    include_suggestions: bool = True
    cost_reporting: bool = True
    ci_mode: bool = False

@dataclass
class IntegrationConfig:
    """Configuration for external integrations"""
    vscode_enabled: bool = True
    gitlab_integration: bool = False
    github_integration: bool = False
    slack_webhook: Optional[str] = None
    jira_integration: Dict[str, str] = None

    def __post_init__(self):
        if self.jira_integration is None:
            self.jira_integration = {}

@dataclass
class P1ComprehensiveConfig:
    """Complete P1 Dev Guard configuration"""
    version: str = "2025.09.01"
    enabled: bool = True

    # Component configurations
    ai: P1AIConfig = None
    scanning: ScanningConfig = None
    policies: PolicyConfig = None
    helm: HelmConfig = None
    registry: RegistryConfig = None
    output: OutputConfig = None
    integrations: IntegrationConfig = None

    # Environment-specific settings
    environment_overrides: Dict[str, Dict[str, Any]] = None
    organization_defaults: Dict[str, Any] = None

    def __post_init__(self):
        if self.ai is None:
            self.ai = P1AIConfig()
        if self.scanning is None:
            self.scanning = ScanningConfig()
        if self.policies is None:
            self.policies = PolicyConfig()
        if self.helm is None:
            self.helm = HelmConfig()
        if self.registry is None:
            self.registry = RegistryConfig()
        if self.output is None:
            self.output = OutputConfig()
        if self.integrations is None:
            self.integrations = IntegrationConfig()
        if self.environment_overrides is None:
            self.environment_overrides = {}
        if self.organization_defaults is None:
            self.organization_defaults = {}

class ComprehensiveConfigManager:
    """Manages all P1 Dev Guard configuration aspects"""

    def __init__(self, config_path: Optional[str] = None):
        self.config_path = config_path or self._get_default_config_path()
        self.config: Optional[P1ComprehensiveConfig] = None
        self.ai_config_manager = AIConfigManager()

    def _get_default_config_path(self) -> str:
        """Get default configuration file path"""
        possible_paths = [
            os.getenv('P1_CONFIG'),
            '/workspace/.p1guard-config.yaml',
            '/etc/p1guard/config.yaml',
            os.path.expanduser('~/.p1devguard/config.yaml'),
        ]

        for path in possible_paths:
            if path and os.path.exists(path):
                return path

        return os.path.expanduser('~/.p1devguard/config.yaml')

    def load_config(self) -> P1ComprehensiveConfig:
        """Load comprehensive configuration"""
        if self.config:
            return self.config

        config_data = {}

        # Load from file if exists
        if os.path.exists(self.config_path):
            try:
                with open(self.config_path, 'r') as f:
                    if self.config_path.endswith('.json'):
                        config_data = json.load(f)
                    else:
                        config_data = yaml.safe_load(f) or {}
            except Exception as e:
                print(f"Warning: Could not load config from {self.config_path}: {e}")

        # Apply environment variable overrides
        config_data = self._apply_env_overrides(config_data)

        # Parse configuration
        self.config = self._parse_config(config_data)

        return self.config

    def _apply_env_overrides(self, config_data: Dict) -> Dict:
        """Apply environment variable overrides"""
        env_overrides = {
            # Registry settings
            'registry.ironbank_mirror': os.getenv('IRONBANK_MIRROR'),

            # Scanning settings
            'scanning.severity_levels': os.getenv('TRIVY_SEVERITY', '').split(','),

            # Output settings
            'output.format': os.getenv('OUTPUT_FORMAT'),
            'output.artifacts_dir': os.getenv('OUTPUT_DIR'),
            'output.ci_mode': os.getenv('CI') == 'true',

            # AI settings
            'ai.default_model': os.getenv('AI_MODEL'),
            'ai.analysis.enabled': os.getenv('AI_ENABLED') != 'false',

            # Integration settings
            'integrations.slack_webhook': os.getenv('SLACK_WEBHOOK'),

            # Skip flags
            'helm.enabled': os.getenv('SKIP_HELM') != 'true',
            'scanning.enabled': os.getenv('SKIP_SCAN') != 'true',
            'policies.enabled': os.getenv('SKIP_POLICIES') != 'true',
        }

        # Apply non-empty overrides
        for key_path, value in env_overrides.items():
            if value:
                self._set_nested_value(config_data, key_path, value)

        return config_data

    def _set_nested_value(self, data: Dict, key_path: str, value: Any):
        """Set nested dictionary value using dot notation"""
        keys = key_path.split('.')
        current = data

        for key in keys[:-1]:
            if key not in current:
                current[key] = {}
            current = current[key]

        current[keys[-1]] = value

    def _parse_config(self, data: Dict) -> P1ComprehensiveConfig:
        """Parse dictionary into configuration object"""
        # Parse AI config using existing manager
        ai_data = data.get('ai', {})
        if ai_data:
            ai_config = self.ai_config_manager._dict_to_config(ai_data)
        else:
            ai_config = P1AIConfig()

        # Parse other components
        scanning_config = ScanningConfig(**data.get('scanning', {}))
        policies_config = PolicyConfig(**data.get('policies', {}))
        helm_config = HelmConfig(**data.get('helm', {}))
        registry_config = RegistryConfig(**data.get('registry', {}))
        output_config = OutputConfig(**data.get('output', {}))
        integrations_config = IntegrationConfig(**data.get('integrations', {}))

        return P1ComprehensiveConfig(
            version=data.get('version', '2025.09.01'),
            enabled=data.get('enabled', True),
            ai=ai_config,
            scanning=scanning_config,
            policies=policies_config,
            helm=helm_config,
            registry=registry_config,
            output=output_config,
            integrations=integrations_config,
            environment_overrides=data.get('environment_overrides', {}),
            organization_defaults=data.get('organization_defaults', {})
        )

    def save_config(self, config: P1ComprehensiveConfig):
        """Save configuration to file"""
        self.config = config

        # Ensure directory exists
        os.makedirs(os.path.dirname(self.config_path), exist_ok=True)

        # Convert to dictionary
        data = self._config_to_dict(config)

        # Save as YAML
        with open(self.config_path, 'w') as f:
            yaml.dump(data, f, default_flow_style=False, indent=2)

    def _config_to_dict(self, config: P1ComprehensiveConfig) -> Dict:
        """Convert configuration object to dictionary"""
        return {
            'version': config.version,
            'enabled': config.enabled,
            'ai': self.ai_config_manager._config_to_dict(config.ai),
            'scanning': asdict(config.scanning),
            'policies': asdict(config.policies),
            'helm': asdict(config.helm),
            'registry': asdict(config.registry),
            'output': asdict(config.output),
            'integrations': asdict(config.integrations),
            'environment_overrides': config.environment_overrides,
            'organization_defaults': config.organization_defaults
        }

    def get_environment_config(self, env_name: str) -> P1ComprehensiveConfig:
        """Get configuration for specific environment"""
        config = self.load_config()

        if env_name in config.environment_overrides:
            # Apply environment-specific overrides
            override_data = config.environment_overrides[env_name]
            base_data = self._config_to_dict(config)

            # Merge overrides
            merged_data = self._deep_merge(base_data, override_data)
            return self._parse_config(merged_data)

        return config

    def _deep_merge(self, base: Dict, override: Dict) -> Dict:
        """Deep merge two dictionaries"""
        result = base.copy()

        for key, value in override.items():
            if key in result and isinstance(result[key], dict) and isinstance(value, dict):
                result[key] = self._deep_merge(result[key], value)
            else:
                result[key] = value

        return result

    def export_for_container(self) -> Dict[str, str]:
        """Export configuration as environment variables for container use"""
        config = self.load_config()
        env_vars = {}

        # AI settings
        env_vars['AI_MODEL'] = config.ai.default_model
        env_vars['AI_ENABLED'] = 'true' if config.ai.analysis.enabled else 'false'
        env_vars['AWS_REGION'] = config.ai.models[config.ai.default_model].region

        # Registry settings
        env_vars['IRONBANK_MIRROR'] = config.registry.ironbank_mirror

        # Scanning settings
        env_vars['TRIVY_SEVERITY'] = ','.join(config.scanning.severity_levels)

        # Skip flags
        env_vars['SKIP_HELM'] = 'false' if config.helm.enabled else 'true'
        env_vars['SKIP_SCAN'] = 'false' if config.scanning.enabled else 'true'
        env_vars['SKIP_POLICIES'] = 'false' if config.policies.enabled else 'true'

        # Output settings
        env_vars['OUTPUT_FORMAT'] = config.output.format
        env_vars['OUTPUT_DIR'] = config.output.artifacts_dir

        return env_vars

    def validate_config(self) -> List[str]:
        """Validate configuration and return issues"""
        issues = []
        config = self.load_config()

        # Validate AI config using AI manager
        ai_issues = self.ai_config_manager.validate_config()
        issues.extend([f"AI: {issue}" for issue in ai_issues])

        # Validate scanning config
        if config.scanning.timeout_seconds <= 0:
            issues.append("Scanning: timeout_seconds must be positive")

        # Validate registry config
        if not config.registry.ironbank_mirror:
            issues.append("Registry: ironbank_mirror is required")

        # Validate output config
        if config.output.format not in ['text', 'json', 'xml']:
            issues.append("Output: format must be 'text', 'json', or 'xml'")

        return issues

    def create_sample_config(self) -> str:
        """Create a comprehensive sample configuration"""
        config = P1ComprehensiveConfig()

        # Add organization-specific examples
        config.organization_defaults = {
            'registry_mirror': 'registry.myorg.mil/ironbank',
            'default_namespace': 'myorg-apps',
            'security_contact': 'security@myorg.mil'
        }

        # Add environment overrides
        config.environment_overrides = {
            'development': {
                'scanning': {'severity_levels': ['MEDIUM', 'HIGH', 'CRITICAL']},
                'ai': {'analysis': {'analysis_depth': 'basic'}}
            },
            'production': {
                'scanning': {'severity_levels': ['HIGH', 'CRITICAL']},
                'ai': {'analysis': {'analysis_depth': 'detailed'}},
                'policies': {'strict_mode': True}
            }
        }

        sample_path = self.config_path.replace('.yaml', '-sample.yaml')
        data = self._config_to_dict(config)

        with open(sample_path, 'w') as f:
            f.write("# P1 Dev Guard Comprehensive Configuration\n")
            f.write("# Copy this file to remove '-sample' from filename and customize\n\n")
            yaml.dump(data, f, default_flow_style=False, indent=2)

        return sample_path

def main():
    """CLI for comprehensive configuration management"""
    import argparse

    parser = argparse.ArgumentParser(description="P1 Dev Guard Configuration Manager")
    parser.add_argument("--config", help="Configuration file path")

    subparsers = parser.add_subparsers(dest='command', help='Commands')

    # Show config
    show_parser = subparsers.add_parser('show', help='Show configuration')
    show_parser.add_argument('--env', help='Show environment-specific config')

    # Validate config
    validate_parser = subparsers.add_parser('validate', help='Validate configuration')

    # Export for container
    export_parser = subparsers.add_parser('export', help='Export as environment variables')

    # Create sample
    sample_parser = subparsers.add_parser('sample', help='Create sample configuration')

    args = parser.parse_args()

    manager = ComprehensiveConfigManager(args.config)

    if args.command == 'show':
        if args.env:
            config = manager.get_environment_config(args.env)
        else:
            config = manager.load_config()

        print(yaml.dump(manager._config_to_dict(config), default_flow_style=False))

    elif args.command == 'validate':
        issues = manager.validate_config()
        if issues:
            print("Configuration issues:")
            for issue in issues:
                print(f"  - {issue}")
        else:
            print("Configuration is valid")

    elif args.command == 'export':
        env_vars = manager.export_for_container()
        for key, value in env_vars.items():
            print(f"export {key}='{value}'")

    elif args.command == 'sample':
        path = manager.create_sample_config()
        print(f"Sample configuration created: {path}")

    else:
        parser.print_help()

if __name__ == "__main__":
    main()