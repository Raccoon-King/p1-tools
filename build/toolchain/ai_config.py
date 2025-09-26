#!/usr/bin/env python3
"""
P1 Dev Guard - AI Configuration System
Comprehensive configuration for LLM models and AI analysis parameters
"""

import json
import os
import yaml
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict
from pathlib import Path

@dataclass
class ModelConfig:
    """Configuration for a specific AI model"""
    name: str
    provider: str  # bedrock, openai, azure, local, etc.
    model_id: str
    max_tokens: int = 4000
    temperature: float = 0.1
    region: str = "us-east-1"
    endpoint_url: Optional[str] = None
    api_key: Optional[str] = None
    cost_per_1k_input: float = 0.0
    cost_per_1k_output: float = 0.0
    capabilities: List[str] = None
    enabled: bool = True

    def __post_init__(self):
        if self.capabilities is None:
            self.capabilities = ["analysis", "remediation"]

@dataclass
class AIAnalysisConfig:
    """Configuration for AI analysis behavior"""
    enabled: bool = True
    fallback_enabled: bool = True
    max_retries: int = 3
    timeout_seconds: int = 30
    analysis_depth: str = "standard"  # basic, standard, detailed
    include_code_examples: bool = True
    include_prevention_tips: bool = True
    priority_threshold: str = "medium"  # low, medium, high, critical
    max_issues_per_request: int = 10

@dataclass
class P1AIConfig:
    """Complete P1 Dev Guard AI configuration"""
    default_model: str = "claude-3-haiku"
    models: Dict[str, ModelConfig] = None
    analysis: AIAnalysisConfig = None
    custom_prompts: Dict[str, str] = None

    def __post_init__(self):
        if self.models is None:
            self.models = self._get_default_models()
        if self.analysis is None:
            self.analysis = AIAnalysisConfig()
        if self.custom_prompts is None:
            self.custom_prompts = {}

    def _get_default_models(self) -> Dict[str, ModelConfig]:
        """Get default model configurations"""
        return {
            "claude-3-haiku": ModelConfig(
                name="Claude 3 Haiku",
                provider="bedrock",
                model_id="anthropic.claude-3-haiku-20240307-v1:0",
                max_tokens=4000,
                temperature=0.1,
                cost_per_1k_input=0.00025,
                cost_per_1k_output=0.00125,
                capabilities=["analysis", "remediation", "code_generation"]
            ),
            "claude-3-sonnet": ModelConfig(
                name="Claude 3 Sonnet",
                provider="bedrock",
                model_id="anthropic.claude-3-sonnet-20240229-v1:0",
                max_tokens=4000,
                temperature=0.1,
                cost_per_1k_input=0.003,
                cost_per_1k_output=0.015,
                capabilities=["analysis", "remediation", "code_generation", "detailed_explanation"]
            ),
            "claude-3-opus": ModelConfig(
                name="Claude 3 Opus",
                provider="bedrock",
                model_id="anthropic.claude-3-opus-20240229-v1:0",
                max_tokens=4000,
                temperature=0.1,
                cost_per_1k_input=0.015,
                cost_per_1k_output=0.075,
                capabilities=["analysis", "remediation", "code_generation", "detailed_explanation", "complex_reasoning"]
            ),
            "titan-text": ModelConfig(
                name="Amazon Titan Text",
                provider="bedrock",
                model_id="amazon.titan-text-express-v1",
                max_tokens=4000,
                temperature=0.1,
                cost_per_1k_input=0.0008,
                cost_per_1k_output=0.0016,
                capabilities=["analysis", "remediation"]
            ),
            "gpt-4": ModelConfig(
                name="GPT-4",
                provider="openai",
                model_id="gpt-4",
                max_tokens=4000,
                temperature=0.1,
                cost_per_1k_input=0.03,
                cost_per_1k_output=0.06,
                capabilities=["analysis", "remediation", "code_generation"],
                enabled=False  # Requires API key
            ),
            "gpt-3.5-turbo": ModelConfig(
                name="GPT-3.5 Turbo",
                provider="openai",
                model_id="gpt-3.5-turbo",
                max_tokens=4000,
                temperature=0.1,
                cost_per_1k_input=0.0015,
                cost_per_1k_output=0.002,
                capabilities=["analysis", "remediation"],
                enabled=False  # Requires API key
            )
        }

class AIConfigManager:
    """Manages AI configuration loading, saving, and validation"""

    def __init__(self, config_path: Optional[str] = None):
        self.config_path = config_path or self._get_default_config_path()
        self.config: Optional[P1AIConfig] = None

    def _get_default_config_path(self) -> str:
        """Get default configuration file path"""
        # Check multiple locations in order of preference
        possible_paths = [
            os.getenv('P1_AI_CONFIG'),  # Environment variable
            '/workspace/.p1-ai-config.yaml',  # Project-specific
            '/etc/p1guard/ai-config.yaml',  # System-wide in container
            os.path.expanduser('~/.p1devguard/ai-config.yaml'),  # User-specific
        ]

        for path in possible_paths:
            if path and os.path.exists(path):
                return path

        # Return user-specific path as default (will be created if needed)
        return os.path.expanduser('~/.p1devguard/ai-config.yaml')

    def load_config(self) -> P1AIConfig:
        """Load configuration from file or create default"""
        if self.config:
            return self.config

        if os.path.exists(self.config_path):
            try:
                with open(self.config_path, 'r') as f:
                    if self.config_path.endswith('.json'):
                        data = json.load(f)
                    else:  # YAML
                        data = yaml.safe_load(f)

                self.config = self._dict_to_config(data)
                return self.config

            except Exception as e:
                print(f"Warning: Could not load AI config from {self.config_path}: {e}")

        # Create default configuration
        self.config = P1AIConfig()
        return self.config

    def save_config(self, config: P1AIConfig):
        """Save configuration to file"""
        self.config = config

        # Ensure directory exists
        os.makedirs(os.path.dirname(self.config_path), exist_ok=True)

        # Convert to dictionary
        data = self._config_to_dict(config)

        # Save as YAML (more human-readable)
        with open(self.config_path, 'w') as f:
            yaml.dump(data, f, default_flow_style=False, indent=2)

    def _dict_to_config(self, data: Dict) -> P1AIConfig:
        """Convert dictionary to configuration object"""
        # Parse models
        models = {}
        for name, model_data in data.get('models', {}).items():
            models[name] = ModelConfig(**model_data)

        # Parse analysis config
        analysis_data = data.get('analysis', {})
        analysis = AIAnalysisConfig(**analysis_data)

        return P1AIConfig(
            default_model=data.get('default_model', 'claude-3-haiku'),
            models=models,
            analysis=analysis,
            custom_prompts=data.get('custom_prompts', {})
        )

    def _config_to_dict(self, config: P1AIConfig) -> Dict:
        """Convert configuration object to dictionary"""
        return {
            'default_model': config.default_model,
            'models': {name: asdict(model) for name, model in config.models.items()},
            'analysis': asdict(config.analysis),
            'custom_prompts': config.custom_prompts
        }

    def get_model_config(self, model_name: str) -> Optional[ModelConfig]:
        """Get configuration for a specific model"""
        config = self.load_config()
        return config.models.get(model_name)

    def list_available_models(self) -> List[str]:
        """List all available model names"""
        config = self.load_config()
        return [name for name, model in config.models.items() if model.enabled]

    def add_custom_model(self, name: str, model_config: ModelConfig):
        """Add a custom model configuration"""
        config = self.load_config()
        config.models[name] = model_config
        self.save_config(config)

    def estimate_cost(self, model_name: str, input_tokens: int, output_tokens: int) -> float:
        """Estimate cost for using a specific model"""
        model = self.get_model_config(model_name)
        if not model:
            return 0.0

        input_cost = (input_tokens / 1000) * model.cost_per_1k_input
        output_cost = (output_tokens / 1000) * model.cost_per_1k_output
        return input_cost + output_cost

    def validate_config(self) -> List[str]:
        """Validate configuration and return any issues"""
        issues = []
        config = self.load_config()

        # Check default model exists
        if config.default_model not in config.models:
            issues.append(f"Default model '{config.default_model}' not found in models")

        # Check model configurations
        for name, model in config.models.items():
            if not model.model_id:
                issues.append(f"Model '{name}' missing model_id")
            if model.max_tokens <= 0:
                issues.append(f"Model '{name}' has invalid max_tokens")
            if not 0 <= model.temperature <= 2:
                issues.append(f"Model '{name}' has invalid temperature")

        return issues

    def create_sample_config(self) -> str:
        """Create a sample configuration file"""
        config = P1AIConfig()

        # Add some custom examples
        config.custom_prompts['security_focus'] = """
You are a cybersecurity expert specializing in Kubernetes and container security.
Focus heavily on security implications and provide detailed security remediation.
"""

        config.analysis.analysis_depth = "detailed"
        config.analysis.include_code_examples = True

        sample_path = self.config_path.replace('.yaml', '-sample.yaml')
        data = self._config_to_dict(config)

        with open(sample_path, 'w') as f:
            f.write("# P1 Dev Guard AI Configuration\n")
            f.write("# Copy this file to remove '-sample' from filename and customize\n\n")
            yaml.dump(data, f, default_flow_style=False, indent=2)

        return sample_path

def main():
    """CLI for managing AI configuration"""
    import argparse

    parser = argparse.ArgumentParser(description="P1 Dev Guard AI Configuration")
    parser.add_argument("--config", help="Configuration file path")

    subparsers = parser.add_subparsers(dest='command', help='Commands')

    # List models
    list_parser = subparsers.add_parser('list', help='List available models')

    # Show config
    show_parser = subparsers.add_parser('show', help='Show current configuration')
    show_parser.add_argument('--model', help='Show specific model configuration')

    # Validate config
    validate_parser = subparsers.add_parser('validate', help='Validate configuration')

    # Create sample
    sample_parser = subparsers.add_parser('sample', help='Create sample configuration')

    # Estimate cost
    cost_parser = subparsers.add_parser('cost', help='Estimate usage cost')
    cost_parser.add_argument('--model', required=True, help='Model name')
    cost_parser.add_argument('--input-tokens', type=int, default=1000, help='Input tokens')
    cost_parser.add_argument('--output-tokens', type=int, default=500, help='Output tokens')

    args = parser.parse_args()

    manager = AIConfigManager(args.config)

    if args.command == 'list':
        models = manager.list_available_models()
        print("Available models:")
        for model in models:
            config = manager.get_model_config(model)
            print(f"  {model}: {config.name} ({config.provider})")

    elif args.command == 'show':
        if args.model:
            config = manager.get_model_config(args.model)
            if config:
                print(yaml.dump(asdict(config), default_flow_style=False))
            else:
                print(f"Model '{args.model}' not found")
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

    elif args.command == 'sample':
        path = manager.create_sample_config()
        print(f"Sample configuration created: {path}")

    elif args.command == 'cost':
        cost = manager.estimate_cost(args.model, args.input_tokens, args.output_tokens)
        print(f"Estimated cost for {args.model}: ${cost:.4f}")

    else:
        parser.print_help()

if __name__ == "__main__":
    main()